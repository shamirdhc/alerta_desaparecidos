import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import 'package:alerta_desaparecidos/common/styles/app_colors.dart';
import 'package:alerta_desaparecidos/data/models/mininter_comisaria_model.dart';
import 'package:alerta_desaparecidos/helpers/share_helper.dart';
import 'package:alerta_desaparecidos/services/mininter_geoservice.dart';
import 'package:alerta_desaparecidos/services/gps_location_service.dart';
import 'package:alerta_desaparecidos/services/comisaria_matcher_service.dart';
import 'package:alerta_desaparecidos/common/constants/peru_locations.dart';
import 'package:alerta_desaparecidos/common/localization/app_strings.dart';

class ComisariasScreen extends StatefulWidget {
  final bool isActive;
  final String? initialSearchQuery;
  final String? initialDepartamento;
  final String? initialDistrito;

  const ComisariasScreen({
    super.key,
    this.isActive = true,
    this.initialSearchQuery,
    this.initialDepartamento,
    this.initialDistrito,
  });

  @override
  State<ComisariasScreen> createState() => _ComisariasScreenState();
}

class _ComisariasScreenState extends State<ComisariasScreen>
    with TickerProviderStateMixin {
  // Controladores
  final MapController _mapController = MapController();
  final PageController _pageController = PageController(viewportFraction: 0.88);
  final TextEditingController _searchController = TextEditingController();

  // Animaciones de radar y pulso
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _radarRotateController;

  // Estado de ubicación y mapa
  LatLng? _userLocation;
  bool _isGpsActive = false;
  bool _isLoading = true;
  bool _viewAsList = false;
  final String _mapStyle = 'dark'; // 'dark' | 'voyager'
  bool _actualizandoGps = false;
  String _ubicacionLabel = 'Detectando ubicación...';
  LocationSource _locationSource = LocationSource.nationalDefault;
  LatLng? _centroMapaActual;

  // Datos
  List<MininterComisariaModel> _todasLasComisariasEnRadio = [];
  List<MininterComisariaModel> _comisarias = [];
  MininterComisariaModel? _selectedComisaria;
  double _radioMetros = 5000; // 5 km por defecto
  TipoComisaria? _filtroTipo;
  bool _isCardMinimized = false; // Control de tarjeta minimizada flotante

  // Variables de ruteo callejero real (OSRM - recorridos reales por calles y curvas)
  List<LatLng> _puntosRutaCallejera = [];
  bool _calculandoRuta = false;
  bool _modoRutaAuto = true; // true: auto, false: peatonal
  RutaCallejeraModel? _rutaActual;
  int _rutaRequestId = 0;

  // Matriz de color para convertir OpenStreetMap a modo táctico azul medianoche / ciberpolicía sin marcas de agua ni API key
  static const List<double> _darkTacticalMatrix = <double>[
    -0.45,  0.00,  0.00, 0.0, 115.0,
     0.00, -0.65,  0.00, 0.0, 166.0,
     0.00,  0.00, -0.85, 0.0, 237.0,
     0.00,  0.00,  0.00, 1.0,   0.0,
  ];

  // Ubicación por defecto de Perú (Plaza Mayor de Lima / Centro Histórico)
  static const LatLng _defaultPeruLocation = LatLng(-12.046374, -77.042793);



  @override
  void initState() {
    super.initState();

    // Pulso constante para la baliza del usuario
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    // Rotación del escáner de radar en carga
    _radarRotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _inicializarUbicacionYComisarias();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _radarRotateController.dispose();
    _mapController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ComisariasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El GPS ya NO se actualiza automáticamente al cambiar de pestaña;
    // la actualización del recorrido y posición es 100% manual a petición del usuario.
  }

  /// Obtiene o refresca coordenadas con jerarquía robusta (GPS Sensor -> Perfil Guardado -> Selección Manual -> Centroide Nacional)
  Future<void> _refrescarUbicacionGpsReal({
    bool centrarMapa = true,
    bool forceCenter = true,
    bool mostrarFeedback = false,
  }) async {
    if (_actualizandoGps) return;
    setState(() => _actualizandoGps = true);

    LatLng? nuevaCoord;
    bool gpsConseguido = false;
    String label = _ubicacionLabel;
    LocationSource source = _locationSource;

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      if (!serviceEnabled && mostrarFeedback) {
        _mostrarDialogoPermiso(
          titulo: 'Servicio de GPS Desactivado',
          mensaje:
              'El sensor de ubicación está apagado en tu dispositivo. Puedes activarlo o seleccionar tu ciudad manualmente sin necesidad de GPS.',
          esServicioDesactivado: true,
        );
      } else if (permission == LocationPermission.deniedForever && mostrarFeedback) {
        _mostrarDialogoPermiso(
          titulo: 'Permiso de Ubicación Bloqueado',
          mensaje:
              'El navegador o dispositivo tiene bloqueado el permiso de ubicación. Puedes habilitarlo en ajustes o seleccionar tu ciudad manualmente.',
          esBloqueoPermanente: true,
        );
      } else {
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          // Intento 1: Alta precisión en vivo con timeout de 6 segundos
          try {
            final position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 6),
              ),
            );
            nuevaCoord = LatLng(position.latitude, position.longitude);
            gpsConseguido = true;
            source = LocationSource.gpsSensor;
            label = 'GPS en vivo';
          } catch (_) {
            // Intento 2: Última posición registrada por el sensor
            final lastPos = await Geolocator.getLastKnownPosition();
            if (lastPos != null) {
              nuevaCoord = LatLng(lastPos.latitude, lastPos.longitude);
              gpsConseguido = true;
              source = LocationSource.gpsSensor;
              label = 'GPS (Última conocida)';
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [GPS] Error consultando sensor de ubicación: $e');
    }

    // Fallback jerárquico inteligente si no hubo señal GPS
    if (!gpsConseguido) {
      final saved = await GpsLocationService.getSavedLocation();
      if (saved != null &&
          saved.departamento.trim().isNotEmpty &&
          saved.departamento != 'TODOS' &&
          saved.departamento != 'TODAS') {
        nuevaCoord = LatLng(saved.latitude, saved.longitude);
        source = saved.source;
        label = saved.provincia.isNotEmpty
            ? '${saved.provincia}, ${saved.departamento}'
            : saved.departamento;
      } else {
        nuevaCoord = _defaultPeruLocation;
        source = LocationSource.nationalDefault;
        label = 'Lima Centro (Predeterminada)';
      }
    }

    final coordDefinitiva = nuevaCoord ?? _userLocation ?? _defaultPeruLocation;

    // Actualizar perfil de ubicación si obtuvimos GPS real
    if (gpsConseguido && nuevaCoord != null) {
      GpsLocationService.saveCoordinates(
        latitud: nuevaCoord.latitude,
        longitud: nuevaCoord.longitude,
      );
    }

    if (mounted) {
      setState(() {
        _userLocation = coordDefinitiva;
        _isGpsActive = gpsConseguido;
        _actualizandoGps = false;
        _ubicacionLabel = label;
        _locationSource = source;
      });

      if (centrarMapa || forceCenter) {
        try {
          _mapController.move(coordDefinitiva, 14.5);
        } catch (_) {}
      }

      if (mostrarFeedback && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  gpsConseguido ? Icons.gps_fixed_rounded : Icons.location_city_rounded,
                  color: gpsConseguido ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    gpsConseguido
                        ? 'Ubicación GPS precisa actualizada'
                        : 'Mostrando comisarías en: $label',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: gpsConseguido ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                width: 1,
              ),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    await _cargarComisarias(lat: coordDefinitiva.latitude, lng: coordDefinitiva.longitude);
  }

  /// Diálogo pedagógico cuando el GPS está apagado o bloqueado
  void _mostrarDialogoPermiso({
    required String titulo,
    required String mensaje,
    bool esServicioDesactivado = false,
    bool esBloqueoPermanente = false,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.location_disabled_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          mensaje,
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _mostrarSelectorCiudad();
            },
            child: const Text('Elegir ciudad manual', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              if (esServicioDesactivado) {
                await Geolocator.openLocationSettings();
              } else if (esBloqueoPermanente) {
                await Geolocator.openAppSettings();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Abrir Ajustes'),
          ),
        ],
      ),
    );
  }

  /// Modal para seleccionar Departamento y Provincia manualmente sin depender del GPS
  void _mostrarSelectorCiudad() {
    String tempDept = _ubicacionLabel.contains(',')
        ? _ubicacionLabel.split(',').last.trim()
        : 'LIMA';
    final normalizedTempDept = PeruLocations.departamentos.firstWhere(
      (d) => PeruLocations.normalize(d) == PeruLocations.normalize(tempDept),
      orElse: () => 'LIMA',
    );
    String selectedDept = normalizedTempDept;
    List<String> provincias = PeruLocations.getProvincias(selectedDept);
    String selectedProv = provincias.isNotEmpty ? provincias.first : 'Lima';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0xFF38BDF8), width: 1.5)),
                boxShadow: [
                  BoxShadow(color: Colors.black54, blurRadius: 25, offset: Offset(0, -6)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_city_rounded, color: Color(0xFF38BDF8), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Seleccionar Ciudad o Región',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Ubica comisarías y dependencias sin necesidad de GPS',
                                style: TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Dropdown Departamento
                    const Text('DEPARTAMENTO',
                        style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedDept,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E293B),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
                          items: PeruLocations.departamentos.map((d) {
                            return DropdownMenuItem(
                              value: d,
                              child: Text(d, style: const TextStyle(color: Colors.white, fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (newDept) {
                            if (newDept != null) {
                              setModalState(() {
                                selectedDept = newDept;
                                provincias = PeruLocations.getProvincias(newDept);
                                selectedProv = provincias.isNotEmpty ? provincias.first : 'Lima';
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Dropdown Provincia
                    const Text('PROVINCIA',
                        style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedProv,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E293B),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
                          items: provincias.map((p) {
                            return DropdownMenuItem(
                              value: p,
                              child: Text(p, style: const TextStyle(color: Colors.white, fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (newProv) {
                            if (newProv != null) {
                              setModalState(() => selectedProv = newProv);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final manualResult = GpsLocationService.fromManualSelection(selectedDept, selectedProv);
                              await GpsLocationService.saveLocation(manualResult.departamento, manualResult.provincia);
                              if (mounted) {
                                setState(() {
                                  _userLocation = LatLng(manualResult.latitude, manualResult.longitude);
                                  _isGpsActive = false;
                                  _locationSource = LocationSource.manualSelection;
                                  _ubicacionLabel = '${manualResult.provincia}, ${manualResult.departamento}';
                                });
                                try {
                                  _mapController.move(_userLocation!, 13.8);
                                } catch (_) {}
                                await _cargarComisarias(lat: _userLocation!.latitude, lng: _userLocation!.longitude);
                              }
                            },
                            icon: const Icon(Icons.search_rounded, size: 18),
                            label: const Text('Ver comisarías en esta zona', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }



  /// Inicialización de arranque
  Future<void> _inicializarUbicacionYComisarias() async {
    await _refrescarUbicacionGpsReal(forceCenter: true);
    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.trim().isNotEmpty) {
      final q = widget.initialSearchQuery!.trim();
      _searchController.text = q;
      await _ejecutarBusquedaTexto(q);
    }
  }

  /// Consulta dependencias policiales cercanas en tiempo real.
  /// Comienza buscando en 5 km; si no encuentra ninguna comisaría, amplía 5 km más (10 km, 15 km...)
  /// sucesivamente hasta encontrar las dependencias policiales más cercanas.
  Future<void> _cargarComisarias({
    required double lat,
    required double lng,
  }) async {
    setState(() => _isLoading = true);

    try {
      double radioActual = 5000; // Comenzar en radio inicial de 5 km
      const double radioPaso = 5000; // Ampliar de 5 km en 5 km
      const double radioMaximo = 60000; // Máximo alcance: 60 km
      List<MininterComisariaModel> listaFiltrada = [];

      while (radioActual <= radioMaximo) {
        final lista = await MininterGeoservice.getComisariasCercanas(
          lat: lat,
          lng: lng,
          radioMetros: radioActual,
          filtroTipo: null,
        );

        // Excluimos tránsito y otras unidades: solo comisaría, depincri y familia
        listaFiltrada = lista.where((c) =>
          c.tipo == TipoComisaria.comisaria ||
          c.tipo == TipoComisaria.depincri ||
          c.tipo == TipoComisaria.familia
        ).toList();

        // Si encontramos comisarías en este radio, nos quedamos con este radio y salimos
        if (listaFiltrada.isNotEmpty) {
          debugPrint('✅ [ComisariasScreen] Se encontraron ${listaFiltrada.length} dependencias en radio de ${(radioActual / 1000).round()} km');
          break;
        }

        debugPrint('🔍 [ComisariasScreen] Sin comisarías en ${(radioActual / 1000).round()} km. Ampliando 5 km más...');
        radioActual += radioPaso;
      }

      // Si aún estuviera vacío tras el bucle, buscar las más cercanas en catálogo nacional offline
      if (listaFiltrada.isEmpty) {
        await ComisariaMatcherService.inicializar();
        final masCercanas = await ComisariaMatcherService.buscarComisariasMasCercanas(
          userLat: lat,
          userLng: lng,
          limit: 5,
        );
        if (masCercanas.isNotEmpty) {
          listaFiltrada = masCercanas.map((c) {
            final upperNom = c.nombre.toUpperCase();
            TipoComisaria tipo = TipoComisaria.comisaria;
            if (upperNom.contains('FAMILIA')) tipo = TipoComisaria.familia;
            if (upperNom.contains('DEPINCRI')) tipo = TipoComisaria.depincri;
            return MininterComisariaModel(
              id: 'local_${c.id}',
              nombre: c.nombre,
              tipo: tipo,
              departamento: c.departamento,
              provincia: c.provincia,
              distrito: c.distrito,
              latitud: c.latitud ?? lat,
              longitud: c.longitud ?? lng,
              telefono: c.telefono.isNotEmpty ? c.telefono : '105',
              direccion: c.direccion.isNotEmpty ? c.direccion : '${c.distrito}, ${c.provincia}',
              distanciaMetros: c.distanciaMetros,
            );
          }).toList();
          if (listaFiltrada.isNotEmpty && listaFiltrada.first.distanciaMetros != null) {
            radioActual = listaFiltrada.first.distanciaMetros!;
          }
        }
      }

      if (mounted) {
        setState(() {
          _radioMetros = radioActual;
          _todasLasComisariasEnRadio = listaFiltrada;
          _isLoading = false;
          if (_filtroTipo == null) {
            _comisarias = MininterGeoservice.deduplicarPorProximidadEspacial(listaFiltrada);
          } else {
            final filtradasPorTipo = listaFiltrada.where((c) => c.tipo == _filtroTipo).toList();
            _comisarias = MininterGeoservice.deduplicarPorProximidadEspacial(filtradasPorTipo);
          }

          if (_comisarias.isNotEmpty) {
            _selectedComisaria = _comisarias.first;
          } else {
            _selectedComisaria = null;
            _puntosRutaCallejera = [];
            _rutaActual = null;
          }
        });

        // Traza automáticamente la ruta por calles hacia la dependencia policial más cercana
        if (_comisarias.isNotEmpty && !_viewAsList) {
          _trazarRutaA(_comisarias.first);
        }
      }
    } catch (e) {
      debugPrint('❌ Error cargando comisarías: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Aplica el filtro de categoría (Todas, Comisarías, DEPINCRI, Familia, Tránsito, Otras)
  void _aplicarFiltroTipo(TipoComisaria? tipo) {
    setState(() {
      _filtroTipo = tipo;
      if (tipo == null) {
        _comisarias = MininterGeoservice.deduplicarPorProximidadEspacial(_todasLasComisariasEnRadio);
      } else {
        final filtradasPorTipo = _todasLasComisariasEnRadio.where((c) => c.tipo == tipo).toList();
        _comisarias = MininterGeoservice.deduplicarPorProximidadEspacial(filtradasPorTipo);
      }

      if (_comisarias.isNotEmpty) {
        _selectedComisaria = _comisarias.first;
      } else {
        _selectedComisaria = null;
        _puntosRutaCallejera = [];
        _rutaActual = null;
      }
    });

    if (_comisarias.isNotEmpty && !_viewAsList) {
      _trazarRutaA(_comisarias.first);
      try {
        _mapController.move(
          LatLng(_comisarias.first.latitud, _comisarias.first.longitud),
          14.2,
        );
      } catch (_) {}
    }
  }

  /// Cantidad de dependencias según tipo dentro del radio actual de 5 KM
  int _contarPorTipo(TipoComisaria tipo) {
    return _todasLasComisariasEnRadio.where((c) => c.tipo == tipo).length;
  }

  /// Búsqueda por texto directo (nombre o distrito)
  Future<void> _ejecutarBusquedaTexto(String query) async {
    if (query.trim().isEmpty) {
      if (_userLocation != null) {
        await _cargarComisarias(
          lat: _userLocation!.latitude,
          lng: _userLocation!.longitude,
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    final results = await MininterGeoservice.buscarPorTexto(
      query,
      departamento: widget.initialDepartamento,
      distrito: widget.initialDistrito,
      userLat: _userLocation?.latitude,
      userLng: _userLocation?.longitude,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _comisarias = MininterGeoservice.deduplicarPorProximidadEspacial(results);
        if (results.isNotEmpty) {
          _selectedComisaria = results.first;
        } else {
          _selectedComisaria = null;
          _puntosRutaCallejera = [];
          _rutaActual = null;
        }
      });
      if (results.isNotEmpty && !_viewAsList) {
        // Centrar de inmediato en la comisaría encontrada
        _mapController.move(
          LatLng(results.first.latitud, results.first.longitud),
          15.0,
        );
        _trazarRutaA(results.first);
      }
    }
  }



  /// Selecciona una comisaría, anima el carrusel y traza su ruta por calles
  void _seleccionarComisaria(MininterComisariaModel c, {int? pageIndex}) {
    setState(() => _selectedComisaria = c);

    if (pageIndex != null && _pageController.hasClients) {
      if (_pageController.page?.round() != pageIndex) {
        _pageController.animateToPage(
          pageIndex,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
      }
    } else {
      final idx = _comisarias.indexOf(c);
      if (idx >= 0 && _pageController.hasClients && _pageController.page?.round() != idx) {
        _pageController.animateToPage(
          idx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
      }
    }

    _trazarRutaA(c);
  }

  /// Evento cuando el usuario desliza una tarjeta en el carrusel
  void _onCarouselPageChanged(int index) {
    if (index >= 0 && index < _comisarias.length) {
      final c = _comisarias[index];
      setState(() => _selectedComisaria = c);
      _trazarRutaA(c);
    }
  }

  /// Traza la ruta real por calles, esquinas y avenidas (OSRM)
  Future<void> _trazarRutaA(MininterComisariaModel c) async {
    final currentRequestId = ++_rutaRequestId;
    setState(() {
      _selectedComisaria = c;
      _calculandoRuta = true;
    });

    final LatLng origen = _userLocation ?? _centroMapaActual ?? _defaultPeruLocation;

    final ruta = await MininterGeoservice.obtenerRutaPorCalles(
      latOrigen: origen.latitude,
      lngOrigen: origen.longitude,
      latDestino: c.latitud,
      lngDestino: c.longitud,
      modoAuto: _modoRutaAuto,
    );

    if (currentRequestId != _rutaRequestId || !mounted) return;

    setState(() {
      _calculandoRuta = false;
      if (ruta != null && ruta.puntos.isNotEmpty) {
        _puntosRutaCallejera = ruta.puntos;
        _rutaActual = ruta;
      } else {
        _puntosRutaCallejera = [
          origen,
          LatLng(c.latitud, c.longitud),
        ];
        _rutaActual = null;
      }
    });

    // Ajustar cámara para mostrar toda la ruta por calles con padding óptimo
    if (_puntosRutaCallejera.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(_puntosRutaCallejera);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(
            top: 170,
            bottom: 240,
            left: 55,
            right: 55,
          ),
        ),
      );
    }
  }

  /// Lanza navegación externa paso a paso (Google Maps / Waze)
  Future<void> _lanzarNavegacionGps(MininterComisariaModel c) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.navigation_rounded,
                      color: AppColors.accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Iniciar Navegación GPS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          c.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                tileColor: Colors.white.withOpacity(0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const FaIcon(
                  FontAwesomeIcons.google,
                  color: Colors.blueAccent,
                  size: 26,
                ),
                title: const Text(
                  'Google Maps (Voz paso a paso)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Estimado: ${c.formattedTiempoAuto} en auto',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white38, size: 16),
                onTap: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(c.googleMapsUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                tileColor: Colors.white.withOpacity(0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const FaIcon(
                  FontAwesomeIcons.waze,
                  color: Color(0xFF33CCFF),
                  size: 26,
                ),
                title: const Text(
                  'Waze (Tráfico en tiempo real)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Evitar congestiones viales',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white38, size: 16),
                onTap: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(c.wazeUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Llamada directa de emergencia 105 o central
  Future<void> _llamarEmergencia([String numero = '105']) async {
    final uri = Uri(scheme: 'tel', path: numero);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Compartir comisaría y coordenadas por WhatsApp o redes
  Future<void> _compartirComisaria(MininterComisariaModel c) async {
    final mensaje = '🚨 *COMISARÍA CERCANA PNP*\n\n'
        '🏢 *${c.nombre}*\n'
        '📍 *Ubicación:* ${c.direccion ?? "${c.distrito}, ${c.departamento}"}\n'
        '📏 *Distancia:* ${c.formattedDistancia}\n'
        '⏱️ *Tiempo estimado:* ${c.formattedTiempoAuto} (auto) / ${c.formattedTiempoPie} (a pie)\n'
        '🗺️ *Ruta Google Maps:* ${c.googleMapsUrl}\n'
        '📞 *Central de Emergencias PNP:* 105';

    await ShareHelper.shareCase(
      context: context,
      message: mensaje,
      subject: 'Comisaría PNP Cercana - Alerta Desaparecidos',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: Stack(
        children: [
          // 1. CAPA DEL MAPA INTERACTIVO
          if (!_viewAsList) _buildTacticalMap(),

          // 2. VISTA ALTERNATIVA: LISTA VERTICAL COMPLETA
          if (_viewAsList) _buildVerticalListView(),

          // 3. HUD SUPERIOR FLOTANTE CON GLASSMORPHISM
          _buildTopFloatingHUD(),

          // 4. CARRUSEL FLOTANTE INFERIOR DE COMISARÍAS (Sólo en modo mapa)
          if (!_viewAsList && _comisarias.isNotEmpty)
            _buildBottomCarousel(),

          // 5. BOTÓN DE RECENTRAR MI UBICACIÓN
          if (!_viewAsList)
            Positioned(
              right: 16,
              bottom: _comisarias.isNotEmpty ? (_isCardMinimized ? 154 : 260) : 96,
              child: _buildLocationFab(),
            ),

          // 6. OVERLAY DE CARGA CON RADAR TÁCTICO
          if (_isLoading) _buildTacticalLoadingOverlay(),
        ],
      ),
    );
  }

  /// Construye el mapa táctico interactivo con OpenStreetMap / CartoDB Dark Matter
  Widget _buildTacticalMap() {
    final centerPos = _userLocation ?? _defaultPeruLocation;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: centerPos,
        initialZoom: 14.2,
        minZoom: 4,
        maxZoom: 18.5,
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture) {
            _centroMapaActual = camera.center;
          }
        },
        onTap: (_, __) {
          // Si hace tap en el mapa, deseleccionar foco si lo desea
        },
      ),
      children: [
        // Tiles Cartográficas 100% libres de API Key y sin marcas de agua (OpenStreetMap Oficial)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'pe.gob.pnp.alerta_desaparecidos',
          tileBuilder: (context, tileWidget, tile) {
            if (_mapStyle == 'dark') {
              return ColorFiltered(
                colorFilter: const ColorFilter.matrix(_darkTacticalMatrix),
                child: tileWidget,
              );
            }
            return tileWidget;
          },
        ),

        // Círculo de cobertura de radar alrededor del usuario
        if (_userLocation != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: _userLocation!,
                radius: _radioMetros,
                useRadiusInMeter: true,
                color: const Color(0xFF00E5FF).withOpacity(0.06),
                borderColor: const Color(0xFF00E5FF).withOpacity(0.35),
                borderStrokeWidth: 1.5,
              ),
              // Pulso sutil de precisión
              CircleMarker(
                point: _userLocation!,
                radius: 120,
                useRadiusInMeter: true,
                color: AppColors.accentColor.withOpacity(0.12),
                borderColor: AppColors.accentColor.withOpacity(0.6),
                borderStrokeWidth: 1.0,
              ),
            ],
          ),

        // Línea táctica de ruta trazada por calles reales (OSRM)
        if (_userLocation != null && _selectedComisaria != null && _puntosRutaCallejera.length >= 2)
          PolylineLayer(
            polylines: [
              // Sombra / resplandor neón exterior sobre las calles
              Polyline(
                points: _puntosRutaCallejera,
                strokeWidth: 8.0,
                color: const Color(0xFF00E5FF).withOpacity(0.35),
              ),
              // Línea principal sólida trazando cada esquina y curva
              Polyline(
                points: _puntosRutaCallejera,
                strokeWidth: 4.5,
                color: const Color(0xFF00E5FF),
              ),
            ],
          ),

        // Marcadores: Usuario y Comisarías
        MarkerLayer(
          markers: [
            // 1. Marcador del Usuario (Baliza pulsante)
            if (_userLocation != null)
              Marker(
                point: _userLocation!,
                width: 60,
                height: 60,
                child: _buildUserLocationMarker(),
              ),

            // 2. Marcadores de las Comisarías
            ..._comisarias.map((c) {
              final isSelected = _selectedComisaria?.id == c.id;
              return Marker(
                point: LatLng(c.latitud, c.longitud),
                width: isSelected ? 58 : 46,
                height: isSelected ? 66 : 52,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => _seleccionarComisaria(c),
                  child: _buildPolicePin(c, isSelected),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  /// Baliza táctica de ubicación del usuario
  Widget _buildUserLocationMarker() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Halo de onda sonar expansiva
            Container(
              width: 32 + (20 * _pulseAnimation.value),
              height: 32 + (20 * _pulseAnimation.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E5FF)
                    .withOpacity(0.3 * (1.1 - _pulseAnimation.value)),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withOpacity(0.6),
                  width: 1.5,
                ),
              ),
            ),
            // Núcleo central
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.8),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Pin táctico de Comisaría o Dependencia Policial
  Widget _buildPolicePin(MininterComisariaModel c, bool isSelected) {
    Color primaryColor;
    Color accentBg;
    IconData icon;

    switch (c.tipo) {
      case TipoComisaria.comisaria:
        primaryColor = const Color(0xFF10B981);
        accentBg = const Color(0xFF047857);
        icon = Icons.local_police_rounded;
        break;
      case TipoComisaria.depincri:
        primaryColor = const Color(0xFFF97316);
        accentBg = const Color(0xFFC2410C);
        icon = Icons.security_rounded;
        break;
      case TipoComisaria.familia:
        primaryColor = const Color(0xFFEC4899);
        accentBg = const Color(0xFFBE185D);
        icon = Icons.family_restroom_rounded;
        break;
      case TipoComisaria.transito:
        primaryColor = const Color(0xFFF59E0B);
        accentBg = const Color(0xFFD97706);
        icon = Icons.traffic_rounded;
        break;
      case TipoComisaria.otras:
        primaryColor = const Color(0xFF8B5CF6);
        accentBg = const Color(0xFF6D28D9);
        icon = Icons.emergency_rounded;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge flotante con distancia si está seleccionada
        if (isSelected && c.formattedDistancia != '--')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF00E5FF), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Text(
              c.formattedDistancia,
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ).animate().scale(duration: 200.ms),

        // Cuerpo del Pin
        Container(
          width: isSelected ? 44 : 36,
          height: isSelected ? 44 : 36,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [primaryColor, accentBg],
              center: Alignment.topLeft,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? const Color(0xFF00E5FF) : Colors.white,
              width: isSelected ? 2.5 : 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFF00E5FF).withOpacity(0.6)
                    : primaryColor.withOpacity(0.4),
                blurRadius: isSelected ? 14 : 8,
                spreadRadius: isSelected ? 2 : 0,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              size: isSelected ? 23 : 19,
              color: Colors.white,
            ),
          ),
        ),

        // Punta inferior del Pin
        CustomPaint(
          size: Size(isSelected ? 10 : 8, isSelected ? 6 : 5),
          painter: _TrianglePainter(
            color: isSelected ? const Color(0xFF00E5FF) : accentBg,
          ),
        ),
      ],
    );
  }



  /// HUD Superior Flotante: Dependencias Cercanas, Filtros y Herramientas
  Widget _buildTopFloatingHUD() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra Superior de Dependencias Policiales Cercanas
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.94),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Botón Volver o Insignia PNP
                  if (Navigator.of(context).canPop())
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.local_police_rounded,
                          color: Color(0xFF00E5FF), size: 22),
                    ),

                  const SizedBox(width: 4),

                  // Título y Radio de Búsqueda Dinámico
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Comisarías Cercanas',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Radio: ${(_radioMetros / 1000).toStringAsFixed(0)} km',
                              style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_todasLasComisariasEnRadio.isNotEmpty) ...[
                              Text(
                                ' • ${_todasLasComisariasEnRadio.length} encontrada${_todasLasComisariasEnRadio.length == 1 ? "" : "s"}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Botón Actualizar GPS
                  IconButton(
                    tooltip: 'Actualizar GPS',
                    icon: _actualizandoGps
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00E5FF),
                            ),
                          )
                        : Icon(
                            _isGpsActive ? Icons.my_location_rounded : Icons.location_searching_rounded,
                            color: _isGpsActive ? const Color(0xFF10B981) : Colors.orange,
                            size: 20,
                          ),
                    onPressed: _actualizandoGps
                        ? null
                        : () => _refrescarUbicacionGpsReal(centrarMapa: true, mostrarFeedback: true),
                    visualDensity: VisualDensity.compact,
                  ),

                  // Divisor vertical
                  Container(
                    height: 22,
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: Colors.white.withOpacity(0.15),
                  ),

                  // Toggle Mapa / Lista
                  IconButton(
                    tooltip: _viewAsList ? 'Ver en Mapa' : 'Ver en Lista',
                    icon: Icon(
                      _viewAsList
                          ? Icons.map_rounded
                          : Icons.format_list_bulleted_rounded,
                      color: const Color(0xFFD4AF37), // Oro policial
                      size: 21,
                    ),
                    onPressed: () {
                      setState(() => _viewAsList = !_viewAsList);
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Fila 2: Chips de Categoría
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Builder(
                builder: (context) {
                  final strings = AppStrings.of(context);
                  return Row(
                    children: [
                      // 1. Todas las dependencias
                      _buildFilterChip(
                        label: '${strings.isQuechua ? "Llapankuna" : "Todas"} (${_todasLasComisariasEnRadio.length})',
                        isSelected: _filtroTipo == null,
                        icon: Icons.shield_rounded,
                        selectedColor: const Color(0xFF00E5FF),
                        onTap: () => _aplicarFiltroTipo(null),
                      ),

                      // 2. Comisarías distritales / sectoriales
                      _buildFilterChip(
                        label: 'Comisarías (${_contarPorTipo(TipoComisaria.comisaria)})',
                        isSelected: _filtroTipo == TipoComisaria.comisaria,
                        icon: Icons.local_police_rounded,
                        selectedColor: const Color(0xFF10B981),
                        onTap: () => _aplicarFiltroTipo(TipoComisaria.comisaria),
                      ),

                      // 3. DEPINCRI / Investigación Criminal
                      _buildFilterChip(
                        label: 'DEPINCRI (${_contarPorTipo(TipoComisaria.depincri)})',
                        isSelected: _filtroTipo == TipoComisaria.depincri,
                        icon: Icons.security_rounded,
                        selectedColor: const Color(0xFFF97316),
                        onTap: () => _aplicarFiltroTipo(TipoComisaria.depincri),
                      ),

                      // 4. Familia (MIMP / Violencia contra la mujer)
                      _buildFilterChip(
                        label: 'Familia (${_contarPorTipo(TipoComisaria.familia)})',
                        isSelected: _filtroTipo == TipoComisaria.familia,
                        icon: Icons.family_restroom_rounded,
                        selectedColor: const Color(0xFFEC4899),
                        onTap: () => _aplicarFiltroTipo(TipoComisaria.familia),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Fila 3: Banner de Estado del Recorrido Callejero en tiempo real
            if (!_viewAsList && (_calculandoRuta || _rutaActual != null))
              _buildRouteStatusBanner(),
          ],
        ),
      ),
    );
  }

  /// Banner flotante de estado de la ruta por calles
  Widget _buildRouteStatusBanner() {
    if (_calculandoRuta) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF00E5FF).withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withOpacity(0.15),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF00E5FF),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Trazando recorrido más cercano por calles...',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_rutaActual != null && _selectedComisaria != null) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF00E5FF).withOpacity(0.6),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withOpacity(0.2),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _modoRutaAuto
                  ? Icons.directions_car_rounded
                  : Icons.directions_walk_rounded,
              size: 15,
              color: const Color(0xFF00E5FF),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${_rutaActual!.formattedDistancia} (${_rutaActual!.formattedDuracion})${_rutaActual!.viasPrincipales.isNotEmpty ? " vía ${_rutaActual!.viasPrincipales}" : ""}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_rutaActual!.pasos.isNotEmpty) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: _mostrarModalPasosRuta,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withOpacity(0.6),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.turn_right_rounded, size: 12, color: Color(0xFF00E5FF)),
                      SizedBox(width: 3),
                      Text(
                        'Ver giros',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// Modal interactivo con los giros y calles paso a paso
  void _mostrarModalPasosRuta() {
    if (_rutaActual == null || _selectedComisaria == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra superior de arrastre
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Cabecera del modal
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF00E5FF), width: 1.2),
                    ),
                    child: Icon(
                      _modoRutaAuto ? Icons.directions_car_rounded : Icons.directions_walk_rounded,
                      color: const Color(0xFF00E5FF),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recorrido hacia ${_selectedComisaria!.nombre}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Distancia: ${_rutaActual!.formattedDistancia} • Tiempo: ${_rutaActual!.formattedDuracion}',
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),

              Text(
                'INDICACIONES POR CALLES (${_rutaActual!.pasos.length} tramos)',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              // Lista de giros y calles
              Expanded(
                child: _rutaActual!.pasos.isEmpty
                    ? const Center(
                        child: Text(
                          'Sigue la línea cian marcada en el mapa por las calles principales.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: _rutaActual!.pasos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final paso = _rutaActual!.pasos[i];
                          final isLast = i == _rutaActual!.pasos.length - 1;
                          final isFirst = i == 0;

                          IconData iconData = Icons.straight_rounded;
                          Color iconColor = Colors.white70;

                          if (isFirst) {
                            iconData = Icons.trip_origin_rounded;
                            iconColor = const Color(0xFF00E5FF);
                          } else if (isLast) {
                            iconData = Icons.location_on_rounded;
                            iconColor = const Color(0xFF10B981);
                          } else if (paso.instruccion.toLowerCase().contains('izquierda')) {
                            iconData = Icons.turn_left_rounded;
                            iconColor = const Color(0xFF38BDF8);
                          } else if (paso.instruccion.toLowerCase().contains('derecha')) {
                            iconData = Icons.turn_right_rounded;
                            iconColor = const Color(0xFF38BDF8);
                          } else if (paso.instruccion.toLowerCase().contains('rotonda')) {
                            iconData = Icons.roundabout_right_rounded;
                            iconColor = Colors.amberAccent;
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isLast
                                    ? const Color(0xFF10B981).withOpacity(0.4)
                                    : Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: iconColor.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(iconData, size: 18, color: iconColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        paso.instruccion,
                                        style: TextStyle(
                                          color: isLast ? const Color(0xFF10B981) : Colors.white,
                                          fontSize: 13,
                                          fontWeight: isLast ? FontWeight.bold : FontWeight.w500,
                                        ),
                                      ),
                                      if (paso.distanciaMetros > 5 && !isLast)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            'Durante ${paso.formattedDistancia}',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 12),
              // Botón para abrir en Google Maps / Waze
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _lanzarNavegacionGps(_selectedComisaria!);
                  },
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('Abrir Navegación Turn-by-Turn en GPS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: const Color(0xFF0A0F1D),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
    Color selectedColor = const Color(0xFF00E5FF),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withOpacity(0.25)
              : const Color(0xFF0F172A).withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? selectedColor : Colors.white.withOpacity(0.12),
            width: 1.1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedColor.withOpacity(0.3),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? selectedColor : Colors.white70,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _recargarConParametros() {
    if (_userLocation != null) {
      _cargarComisarias(
        lat: _userLocation!.latitude,
        lng: _userLocation!.longitude,
      );
    }
  }

  /// Carrusel Flotante Inferior de Comisarías
  Widget _buildBottomCarousel() {
    if (_isCardMinimized) {
      final c = _selectedComisaria ?? (_comisarias.isNotEmpty ? _comisarias.first : null);
      if (c == null) return const SizedBox.shrink();

      Color badgeColor;
      IconData badgeIcon;

      switch (c.tipo) {
        case TipoComisaria.comisaria:
          badgeColor = const Color(0xFF10B981);
          badgeIcon = Icons.local_police_rounded;
          break;
        case TipoComisaria.depincri:
          badgeColor = const Color(0xFFF97316);
          badgeIcon = Icons.security_rounded;
          break;
        case TipoComisaria.familia:
          badgeColor = const Color(0xFFEC4899);
          badgeIcon = Icons.family_restroom_rounded;
          break;
        case TipoComisaria.transito:
          badgeColor = const Color(0xFFF59E0B);
          badgeIcon = Icons.traffic_rounded;
          break;
        case TipoComisaria.otras:
          badgeColor = const Color(0xFF8B5CF6);
          badgeIcon = Icons.emergency_rounded;
          break;
      }

      return Positioned(
        left: 12,
        right: 12,
        bottom: 96,
        height: 52,
        child: GestureDetector(
          onTap: () => setState(() => _isCardMinimized = false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.96),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00E5FF).withOpacity(0.55),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor, width: 1),
                  ),
                  child: Icon(badgeIcon, color: badgeColor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_rutaActual != null ? _rutaActual!.formattedDistancia : c.formattedDistancia} • ${c.tipoSubtitulo}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF00E5FF).withOpacity(0.9),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Expandir',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: Color(0xFF00E5FF),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 96,
      height: 155,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _comisarias.length,
        onPageChanged: _onCarouselPageChanged,
        itemBuilder: (context, index) {
          final c = _comisarias[index];
          final isSelected = _selectedComisaria?.id == c.id;
          return _buildComisariaCard(c, isSelected);
        },
      ),
    );
  }

  /// Tarjeta de Comisaría o Dependencia Policial en Carrusel (compacta)
  Widget _buildComisariaCard(MininterComisariaModel c, bool isSelected) {
    final strings = AppStrings.of(context);
    Color badgeColor;
    IconData badgeIcon;

    switch (c.tipo) {
      case TipoComisaria.comisaria:
        badgeColor = const Color(0xFF10B981);
        badgeIcon = Icons.local_police_rounded;
        break;
      case TipoComisaria.depincri:
        badgeColor = const Color(0xFFF97316);
        badgeIcon = Icons.security_rounded;
        break;
      case TipoComisaria.familia:
        badgeColor = const Color(0xFFEC4899);
        badgeIcon = Icons.family_restroom_rounded;
        break;
      case TipoComisaria.transito:
        badgeColor = const Color(0xFFF59E0B);
        badgeIcon = Icons.traffic_rounded;
        break;
      case TipoComisaria.otras:
        badgeColor = const Color(0xFF8B5CF6);
        badgeIcon = Icons.emergency_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? const Color(0xFF00E5FF) : Colors.white.withOpacity(0.12),
          width: isSelected ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF00E5FF).withOpacity(0.2)
                : Colors.black.withOpacity(0.5),
            blurRadius: isSelected ? 14 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabecera: Nombre, Badge, Distancia y Minimizar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor, width: 1),
                ),
                child: Icon(badgeIcon, color: badgeColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          c.tipoSubtitulo,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (c.distrito.isNotEmpty) ...[
                          const Text(' • ',
                              style: TextStyle(color: Colors.white38, fontSize: 9)),
                          Flexible(
                            child: Text(
                              c.distrito,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Chip Distancia
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.near_me_rounded,
                        size: 9, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 3),
                    Text(
                      isSelected && _rutaActual != null
                          ? _rutaActual!.formattedDistancia
                          : c.formattedDistancia,
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Minimizar
              InkWell(
                onTap: () => setState(() => _isCardMinimized = true),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white60,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Fila unificada: Auto / A pie (selectores compactos inline)
          Row(
            children: [
              // Selector Auto
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (!_modoRutaAuto) {
                      setState(() => _modoRutaAuto = true);
                      _trazarRutaA(c);
                    }
                  },
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: _modoRutaAuto
                          ? const Color(0xFF00E5FF).withOpacity(0.15)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: _modoRutaAuto
                            ? const Color(0xFF00E5FF).withOpacity(0.6)
                            : Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_car_rounded,
                            size: 12,
                            color: _modoRutaAuto
                                ? const Color(0xFF00E5FF)
                                : Colors.white54),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _rutaActual != null && isSelected && _modoRutaAuto
                                ? _rutaActual!.formattedDuracion
                                : c.formattedTiempoAuto,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _modoRutaAuto
                                  ? const Color(0xFF00E5FF)
                                  : Colors.white54,
                              fontSize: 10,
                              fontWeight: _modoRutaAuto
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              // Selector A pie
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (_modoRutaAuto) {
                      setState(() => _modoRutaAuto = false);
                      _trazarRutaA(c);
                    }
                  },
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: !_modoRutaAuto
                          ? const Color(0xFF00E5FF).withOpacity(0.15)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: !_modoRutaAuto
                            ? const Color(0xFF00E5FF).withOpacity(0.6)
                            : Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_walk_rounded,
                            size: 12,
                            color: !_modoRutaAuto
                                ? const Color(0xFF00E5FF)
                                : Colors.white54),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _rutaActual != null && isSelected && !_modoRutaAuto
                                ? _rutaActual!.formattedDuracion
                                : c.formattedTiempoPie,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: !_modoRutaAuto
                                  ? const Color(0xFF00E5FF)
                                  : Colors.white54,
                              fontSize: 10,
                              fontWeight: !_modoRutaAuto
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Botonera de Acciones (compacta)
          Row(
            children: [
              // Trazar Ruta / Ver Giros
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (isSelected && _rutaActual != null && _rutaActual!.pasos.isNotEmpty) {
                        _mostrarModalPasosRuta();
                      } else {
                        _trazarRutaA(c);
                      }
                    },
                    icon: _calculandoRuta && isSelected
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Color(0xFF0A0F1D),
                            ),
                          )
                        : Icon(
                            isSelected && _rutaActual != null
                                ? Icons.turn_right_rounded
                                : Icons.alt_route_rounded,
                            size: 13,
                          ),
                    label: Text(
                      _calculandoRuta && isSelected
                          ? (strings.isQuechua ? 'Maskachkan...' : 'Ruteando...')
                          : (isSelected && _rutaActual != null
                              ? strings.turns
                              : strings.route),
                      style: const TextStyle(fontSize: 10.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: const Color(0xFF0A0F1D),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // Iniciar GPS Externo
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () => _lanzarNavegacionGps(c),
                    icon: const Icon(Icons.navigation_rounded, size: 13),
                    label: const Text('GPS', style: TextStyle(fontSize: 10.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.white.withOpacity(0.12)),
                      ),
                      elevation: 0,
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // Llamar 105
              SizedBox(
                width: 32,
                height: 32,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDC2626), width: 1),
                  ),
                  child: IconButton(
                    tooltip: strings.call105,
                    icon: const Icon(Icons.phone_in_talk_rounded,
                        color: Color(0xFFEF4444), size: 14),
                    onPressed: () => _llamarEmergencia('105'),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // Compartir
              SizedBox(
                width: 32,
                height: 32,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: IconButton(
                    tooltip: strings.share,
                    icon: const Icon(Icons.share_rounded,
                        color: Colors.white70, size: 14),
                    onPressed: () => _compartirComisaria(c),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Botón flotante para actualización manual de GPS (claramente visible e intuitivo)
  Widget _buildLocationFab() {
    return Material(
      color: Colors.transparent,
      elevation: 6,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: _actualizandoGps
            ? null
            : () => _refrescarUbicacionGpsReal(
                  centrarMapa: true,
                  mostrarFeedback: true,
                ),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF00E5FF),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_actualizandoGps)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00E5FF),
                  ),
                )
              else
                const Icon(
                  Icons.my_location_rounded,
                  color: Color(0xFF00E5FF),
                  size: 19,
                ),
              Builder(
                builder: (context) {
                  final strings = AppStrings.of(context);
                  return Text(
                    _actualizandoGps
                        ? (strings.isQuechua ? 'GPS Musuqyachkan...' : 'Actualizando GPS...')
                        : strings.updateGps,
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Vista Vertical de Lista de Comisarías
  Widget _buildVerticalListView() {
    return Container(
      color: const Color(0xFF0A0F1D),
      padding: const EdgeInsets.only(top: 130),
      child: _comisarias.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_rounded,
                      size: 64, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Text(
                    'No se encontraron comisarías en este radio',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (_userLocation != null) {
                        _recargarConParametros();
                      } else {
                        _refrescarUbicacionGpsReal(centrarMapa: true, mostrarFeedback: true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Reintentar búsqueda de cercanas'),
                  ),
                ],
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                  itemCount: _comisarias.length,
                  itemBuilder: (context, index) {
                    final c = _comisarias[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildComisariaCard(c, _selectedComisaria?.id == c.id),
                    );
                  },
                ),
              ),
            ),
    );
  }

  /// Overlay de Carga Táctico con Radar Animado
  Widget _buildTacticalLoadingOverlay() {
    return Container(
      color: const Color(0xFF0A0F1D).withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: _radarRotateController,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withOpacity(0.35),
                    width: 2,
                  ),
                  gradient: SweepGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFF00E5FF).withOpacity(0.5),
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.local_police_rounded,
                    color: Color(0xFF00E5FF),
                    size: 38,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'CONECTANDO CON MININTER...',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Rastreando comisarías activas y comisarías de familia',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dibuja el vértice triangular inferior del pin policial
class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
