import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../common/constants/peru_locations.dart';
import '../../../common/styles/app_colors.dart';
import '../../../data/models/comisaria_model.dart';
import '../../../data/models/mininter_comisaria_model.dart';
import '../../../services/agenda_policial_service.dart';
import '../../../services/comisaria_matcher_service.dart';
import '../../../services/gps_location_service.dart';
import '../../../services/mininter_geoservice.dart';
import 'citizen_home_screen.dart';

class AgendaPolicialScreen extends StatefulWidget {
  final String? initialSearchQuery;
  final String? initialDepartamento;
  final String? initialProvincia;

  const AgendaPolicialScreen({
    super.key,
    this.initialSearchQuery,
    this.initialDepartamento,
    this.initialProvincia,
  });

  @override
  State<AgendaPolicialScreen> createState() => _AgendaPolicialScreenState();
}

typedef SearchEssaysScreen = AgendaPolicialScreen;

/// Estructura de desglose de dirección física vs geopolítica
class _InfoDireccionComisaria {
  final String calle;
  final bool esCalleExacta;
  final String departamento;
  final String provincia;
  final String distrito;

  const _InfoDireccionComisaria({
    required this.calle,
    required this.esCalleExacta,
    required this.departamento,
    required this.provincia,
    required this.distrito,
  });
}

class _AgendaPolicialScreenState extends State<AgendaPolicialScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  // Datos Generales
  List<ComisariaModel> _todasComisarias = [];
  List<ComisariaModel> _comisariasFiltradas = [];
  List<String> _departamentos = [];
  Map<String, int> _conteoPorDepartamento = {};

  // Estado de Ubicación y Cercanía por GPS
  MininterComisariaModel? _comisariaCercana;
  String? _miDepartamentoGps;
  String? _miProvinciaGps;
  bool _detectandoGps = false;

  // Ubicación declarada en el perfil del ciudadano
  String? _departamentoPerfil;
  String? _provinciaPerfil;

  // Filtros Territoriales
  String? _departamentoSeleccionado; // null = Todo el Perú
  String? _provinciaSeleccionada; // null = Todas las provincias
  List<String> _provinciasDisponibles = [];

  // Estados de Interfaz
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _inicializarDirectorio();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Carga inicial de datos desde prontuario CSV + Firestore y detección GPS
  Future<void> _inicializarDirectorio() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Cargar todas las comisarías en memoria (1,198 dependencias)
      await AgendaPolicialService.inicializarSincronizacion();
      final comisarias = await AgendaPolicialService.getTodasComisarias();
      final depts = await AgendaPolicialService.getDepartamentosDisponibles();

      // Conteo por departamento
      final Map<String, int> conteos = {};
      for (final c in comisarias) {
        if (c.departamento.isNotEmpty) {
          conteos[c.departamento] = (conteos[c.departamento] ?? 0) + 1;
        }
      }

      _todasComisarias = comisarias;

      // 2. Obtener la ubicación inicial (Parámetros del widget o perfil del ciudadano)
      String? initialDept;
      String? initialProv;

      if (widget.initialDepartamento != null && widget.initialDepartamento!.trim().isNotEmpty) {
        initialDept = depts.firstWhere(
          (d) => GpsLocationService.matches(d, widget.initialDepartamento!),
          orElse: () => depts.firstWhere(
            (d) => PeruLocations.normalize(d) == PeruLocations.normalize(widget.initialDepartamento!),
            orElse: () => '',
          ),
        );
        if (initialDept.isEmpty) initialDept = null;

        if (initialDept != null && widget.initialProvincia != null && widget.initialProvincia!.trim().isNotEmpty) {
          final provsDisponibles = _obtenerProvinciasParaDepartamento(initialDept);
          initialProv = provsDisponibles.firstWhere(
            (p) => GpsLocationService.matches(p, widget.initialProvincia!),
            orElse: () => provsDisponibles.firstWhere(
              (p) => PeruLocations.normalize(p) == PeruLocations.normalize(widget.initialProvincia!),
              orElse: () => '',
            ),
          );
          if (initialProv.isEmpty) initialProv = null;
        }
      } else {
        final userProfile = await GpsLocationService.getSavedLocation();
        final bool tieneDeptoValido = userProfile != null &&
            userProfile.departamento.trim().isNotEmpty &&
            userProfile.departamento.toUpperCase() != 'TODOS' &&
            userProfile.departamento.toUpperCase() != 'TODAS' &&
            !userProfile.departamento.toUpperCase().contains('TODO');

        if (tieneDeptoValido) {
          _departamentoPerfil = userProfile.departamento;
          _provinciaPerfil = userProfile.provincia;

          initialDept = depts.firstWhere(
            (d) => GpsLocationService.matches(d, userProfile.departamento),
            orElse: () => depts.firstWhere(
              (d) => PeruLocations.normalize(d) == PeruLocations.normalize(userProfile.departamento),
              orElse: () => '',
            ),
          );
          if (initialDept.isEmpty) initialDept = null;

          if (initialDept != null) {
            final provsDisponibles = _obtenerProvinciasParaDepartamento(initialDept);
            if (userProfile.provincia.trim().isNotEmpty &&
                userProfile.provincia.toUpperCase() != 'TODAS' &&
                userProfile.provincia.toUpperCase() != 'TODOS' &&
                !userProfile.provincia.toUpperCase().contains('TODO') &&
                provsDisponibles.isNotEmpty) {
              initialProv = provsDisponibles.firstWhere(
                (p) => GpsLocationService.matches(p, userProfile.provincia),
                orElse: () => provsDisponibles.firstWhere(
                  (p) => PeruLocations.normalize(p) == PeruLocations.normalize(userProfile.provincia),
                  orElse: () => '',
                ),
              );
              if (initialProv.isEmpty) initialProv = null;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _todasComisarias = comisarias;
          _departamentos = depts;
          _conteoPorDepartamento = conteos;
          _departamentoSeleccionado = initialDept;
          _provinciasDisponibles = initialDept != null ? _obtenerProvinciasParaDepartamento(initialDept) : [];
          _provinciaSeleccionada = initialProv;
          _isLoading = false;
        });
      }

      // Si se proporcionó texto de búsqueda inicial
      if (widget.initialSearchQuery != null && widget.initialSearchQuery!.trim().isNotEmpty) {
        _searchController.text = widget.initialSearchQuery!.trim();
      }

      // 3. Detección automática de ubicación GPS si no se pasó filtro inicial
      if (widget.initialDepartamento == null) {
        _detectarUbicacionYCercana(silencioso: false);
      }

      // 4. Aplicar filtros iniciales
      _aplicarFiltros();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar el directorio: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Detecta la ubicación del ciudadano y encuentra la comisaría más cercana
  Future<void> _detectarUbicacionYCercana({bool silencioso = false}) async {
    if (!mounted) return;

    if (!silencioso) {
      setState(() => _detectandoGps = true);
    }

    try {
      final loc = await GpsLocationService.getCurrentLocation(
        requestPermission: true, // Proactivamente solicitar permiso para ser precisos
      );

      if (loc != null && mounted) {
        final bool locValida = loc.departamento.trim().isNotEmpty &&
            loc.departamento.toUpperCase() != 'TODOS' &&
            loc.departamento.toUpperCase() != 'TODAS' &&
            !loc.departamento.toUpperCase().contains('TODO');

        if (locValida) {
          _miDepartamentoGps = loc.departamento;
          _miProvinciaGps = loc.provincia;
        }

        // Calcular distancias en tiempo real para todas las comisarías con coordenadas GPS
        if (loc.latitude != 0.0 && loc.longitude != 0.0) {
          for (final c in _todasComisarias) {
            if (c.latitud != null && c.longitud != null && c.latitud != 0.0) {
              c.distanciaMetros = ComisariaMatcherService.calcularDistanciaMetros(
                loc.latitude,
                loc.longitude,
                c.latitud!,
                c.longitud!,
              );
            }
          }
        }

        // Consultar con el geoservicio oficial de Mininter las más cercanas
        try {
          final cercanas = await MininterGeoservice.getComisariasCercanas(
            lat: loc.latitude,
            lng: loc.longitude,
            radioMetros: 25000, // 25 km a la redonda
          );

          if (cercanas.isNotEmpty && mounted) {
            setState(() {
              _comisariaCercana = cercanas.first;
            });
          }
        } catch (_) {}

        // Auto-seleccionar departamento y provincia si es primera carga o si no había filtro previo
        if (mounted && locValida && _departamentoSeleccionado == null) {
          _seleccionarDepartamento(loc.departamento, provInicial: loc.provincia);
        } else if (mounted) {
          _aplicarFiltros();
        }
      }
    } catch (e) {
      debugPrint('ℹ️ [AGENDA] Error detectando GPS: $e');
    } finally {
      if (mounted) {
        setState(() => _detectandoGps = false);
      }
    }
  }

  /// Selección controlada de departamento con actualización de sus provincias
  void _seleccionarDepartamento(String? depto, {String? provInicial}) {
    setState(() {
      final bool esNulo = depto == null ||
          depto.trim().isEmpty ||
          depto.toUpperCase() == 'TODAS' ||
          depto.toUpperCase() == 'TODOS' ||
          depto.toUpperCase().contains('TODO');

      _departamentoSeleccionado = esNulo ? null : depto;
      _provinciasDisponibles = _obtenerProvinciasParaDepartamento(_departamentoSeleccionado);

      final bool provInvalida = provInicial == null ||
          provInicial.trim().isEmpty ||
          provInicial.toUpperCase() == 'TODAS' ||
          provInicial.toUpperCase() == 'TODOS' ||
          provInicial.toUpperCase().contains('TODO');

      if (!provInvalida) {
        _provinciaSeleccionada = provInicial;
      } else if (_departamentoSeleccionado != null &&
          _departamentoPerfil != null &&
          GpsLocationService.matches(_departamentoSeleccionado!, _departamentoPerfil!)) {
        final match = _provinciasDisponibles.firstWhere(
          (p) => GpsLocationService.matches(p, _provinciaPerfil ?? ''),
          orElse: () => '',
        );
        _provinciaSeleccionada = match.isNotEmpty ? match : null;
      } else {
        _provinciaSeleccionada = null;
      }
    });
    _aplicarFiltros();
  }

  /// Selección controlada de provincia
  void _seleccionarProvincia(String? prov) {
    setState(() {
      final bool esNula = prov == null ||
          prov.trim().isEmpty ||
          prov.toUpperCase() == 'TODAS' ||
          prov.toUpperCase() == 'TODOS' ||
          prov.toUpperCase().contains('TODO');
      _provinciaSeleccionada = esNula ? null : prov;
    });
    _aplicarFiltros();
  }

  /// Obtiene la lista oficial de provincias de un departamento
  List<String> _obtenerProvinciasParaDepartamento(String? depto) {
    if (depto == null || depto.isEmpty) return [];

    final cleanDept = depto.toUpperCase().trim();

    // 1. Buscar en constantes de Perú
    for (final entry in PeruLocations.departamentosYProvincias.entries) {
      final k = entry.key.toUpperCase();
      if (k == cleanDept || GpsLocationService.matches(k, cleanDept)) {
        return entry.value;
      }
    }

    // 2. Extraer del prontuario local
    final Set<String> provs = {};
    for (final c in _todasComisarias) {
      if (GpsLocationService.matches(c.departamento, cleanDept) && c.provincia.trim().isNotEmpty) {
        provs.add(c.provincia.trim().toUpperCase());
      }
    }
    final list = provs.toList()..sort();
    return list;
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 160), () {
      if (mounted) {
        _aplicarFiltros();
      }
    });
  }

  /// Aplica los filtros combinados: Departamento, Provincia y Texto Omni-Canal
  void _aplicarFiltros() {
    final query = _searchController.text.trim().toUpperCase();
    final cleanQ = query.replaceAll(RegExp(r'[^0-9]'), '');

    List<ComisariaModel> resultado = List.from(_todasComisarias);

    final bool esDeptoFiltro = _departamentoSeleccionado != null &&
        _departamentoSeleccionado!.trim().isNotEmpty &&
        _departamentoSeleccionado!.toUpperCase() != 'TODOS' &&
        _departamentoSeleccionado!.toUpperCase() != 'TODAS' &&
        !_departamentoSeleccionado!.toUpperCase().contains('TODO');

    final bool esProvFiltro = _provinciaSeleccionada != null &&
        _provinciaSeleccionada!.trim().isNotEmpty &&
        _provinciaSeleccionada!.toUpperCase() != 'TODAS' &&
        _provinciaSeleccionada!.toUpperCase() != 'TODOS' &&
        !_provinciaSeleccionada!.toUpperCase().contains('TODO');

    // 1. Filtro por Departamento
    if (esDeptoFiltro) {
      resultado = resultado
          .where((c) => GpsLocationService.matches(c.departamento, _departamentoSeleccionado!))
          .toList();
    }

    // 2. Filtro por Provincia
    if (esProvFiltro) {
      final pUpper = _provinciaSeleccionada!.toUpperCase();
      resultado = resultado.where((c) {
        final provC = c.provincia.toUpperCase();
        final distC = c.distrito.toUpperCase();
        final nomC = c.nombre.toUpperCase();
        return provC.contains(pUpper) ||
            GpsLocationService.matches(provC, pUpper) ||
            distC.contains(pUpper) ||
            nomC.contains(pUpper);
      }).toList();
    }

    // 3. Filtro por Texto de Búsqueda Omni-Canal
    if (query.isNotEmpty) {
      final conPuntuacion = resultado.map((c) {
        int score = 0;
        final nom = c.nombre.toUpperCase();
        final dis = c.distrito.toUpperCase();
        final prov = c.provincia.toUpperCase();
        final dep = c.departamento.toUpperCase();
        final uni = c.unidad.toUpperCase();
        final dir = c.direccion.toUpperCase();
        final tel = c.telefono.replaceAll(RegExp(r'[^0-9]'), '');

        if (nom.startsWith(query)) {
          score += 160;
        } else if (nom.contains(query)) {
          score += 110;
        }

        if (dis.startsWith(query)) {
          score += 90;
        } else if (dis.contains(query)) {
          score += 70;
        }

        if (prov.contains(query)) score += 50;
        if (dep.contains(query)) score += 35;
        if (uni.contains(query)) score += 30;
        if (dir.contains(query)) score += 40;

        if (cleanQ.isNotEmpty && tel.contains(cleanQ)) {
          score += 140;
        }

        return MapEntry(c, score);
      }).where((e) => e.value > 0).toList();

      conPuntuacion.sort((a, b) => b.value.compareTo(a.value));
      resultado = conPuntuacion.map((e) => e.key).toList();
    }

    setState(() {
      _comisariasFiltradas = resultado;
    });
  }

  /// Estructura de dirección desglosada (calle exacta vs jurisdicción territorial)
  _InfoDireccionComisaria _extraerInfoDireccion(ComisariaModel c) {
    final raw = c.direccion.trim();
    final dep = c.departamento.trim();
    final prov = c.provincia.trim();
    final dist = c.distrito.trim();

    // Fallback cívico natural para dependencias rurales sin numeración municipal
    final String fallback;
    if (dist.isNotEmpty) {
      fallback = 'Plaza de Armas / Centro Cívico S/N, Distrito de $dist';
    } else if (prov.isNotEmpty) {
      fallback = 'Plaza Principal S/N, Provincia de $prov';
    } else {
      fallback = 'Sede Policial Central';
    }

    // Detectar si la dirección es genérica o repetitiva (ej. "ANDAHUAYLAS, ANDAHUAYLAS - APURÍMAC")
    bool esGenerica = raw.isEmpty ||
        raw.toLowerCase().startsWith('jurisdicción') ||
        raw.toLowerCase().startsWith('jurisdiccion');

    if (!esGenerica) {
      final cleanRaw = PeruLocations.normalize(raw).replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final cleanDp = PeruLocations.normalize('$dist$prov$dep').replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final cleanP = PeruLocations.normalize('$dist$prov').replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final cleanD = PeruLocations.normalize(dist).replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (cleanRaw == cleanDp || cleanRaw == cleanP || cleanRaw == cleanD || cleanRaw == '$cleanD$cleanD') {
        esGenerica = true;
      } else if (!raw.contains(RegExp(r'\b(Jr|Av|Avenida|Jirón|Jiron|Calle|Plaza|Pasaje|Carretera|Panamericana|Mz|Lote|Prolongación|Prolongacion|Centro|Sede)\b', caseSensitive: false))) {
        if (raw.contains(' - ') || raw.contains(' – ')) {
          esGenerica = true;
        }
      }
    }

    if (esGenerica) {
      // Mapeo inteligente para unidades de Apurímac con sede física conocida
      final nomUpper = PeruLocations.normalize(c.nombre);
      final distUpper = PeruLocations.normalize(dist);
      String calleAsignada = fallback;

      if (distUpper.contains('ANDAHUAYLAS')) {
        if (nomUpper.contains('ROBO') || nomUpper.contains('UPROVE')) {
          calleAsignada = 'Jr. Los Chankas S/N, Andahuaylas';
        } else if (nomUpper.contains('DEPINCRI')) {
          calleAsignada = 'Jr. Guillermo Cáceres 614, Andahuaylas 03701';
        } else if (nomUpper.contains('OPERACIONES') ||
            nomUpper.contains('TRANSITO') ||
            nomUpper.contains('EMERGENCIA') ||
            nomUpper.contains('FAMILIA') ||
            nomUpper.contains('SECTORIAL')) {
          calleAsignada = 'Av. Perú 189, Andahuaylas';
        }
      } else if (distUpper.contains('ABANCAY')) {
        if (nomUpper.contains('DEPINCRI') ||
            nomUpper.contains('DIVINCRI') ||
            nomUpper.contains('DIVOPUS')) {
          calleAsignada = 'Jr. Lima 520, Abancay';
        } else if (nomUpper.contains('TRANSITO')) {
          calleAsignada = 'Av. Arenas S/N, Abancay';
        }
      }

      return _InfoDireccionComisaria(
        calle: calleAsignada,
        esCalleExacta: calleAsignada != fallback,
        departamento: dep,
        provincia: prov,
        distrito: dist,
      );
    }

    // Retornar directamente la dirección real normalizada (Jr., Av., Calle, Plaza, etc.)
    return _InfoDireccionComisaria(
      calle: raw,
      esCalleExacta: !raw.startsWith('Plaza de Armas / Centro Cívico') && !raw.startsWith('Plaza Principal'),
      departamento: dep,
      provincia: prov,
      distrito: dist,
    );
  }

  // --- ACCIONES TÁCTICAS ---

  Future<void> _llamar(String telefono) async {
    final cleanPhone = telefono.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      _mostrarSnackBar(
        'Esta dependencia no tiene teléfono directo. Llama a la Central 105.',
        icono: Icons.phone_missed,
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        _mostrarSnackBar('No se pudo abrir la marcación telefónica.');
      }
    } catch (e) {
      _mostrarSnackBar('Error al intentar llamar: $e');
    }
  }

  Future<void> _copiarTelefono(String telefono) async {
    final clean = telefono.trim();
    if (clean.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: clean));
    HapticFeedback.lightImpact();
    _mostrarSnackBar(
      'Teléfono copiado: $clean',
      icono: Icons.copy_rounded,
      esExito: true,
    );
  }

  Future<void> _compartirComisaria(ComisariaModel c) async {
    HapticFeedback.selectionClick();
    final info = _extraerInfoDireccion(c);
    final String mapLink = (c.latitud != null && c.longitud != null && c.latitud != 0.0)
        ? 'https://www.google.com/maps/search/?api=1&query=${c.latitud},${c.longitud}'
        : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('Comisaria PNP ${c.nombre}, ${c.distrito}, ${c.departamento}, Peru')}';

    final mensaje =
        '🚨 *FICHA OFICIAL DE COMISARÍA PNP*\n\n'
        '👮 *Dependencia:* ${c.nombre}\n'
        '🏢 *Unidad:* ${c.unidad.isNotEmpty ? c.unidad : 'POLICÍA NACIONAL DEL PERÚ'}\n'
        '🏠 *Dirección de Calle:* ${info.calle} ${info.esCalleExacta ? '(Calle Exacta)' : '(Referencial)'}\n'
        '🇵🇪 *Departamento:* ${info.departamento}\n'
        '🏛️ *Provincia:* ${info.provincia}\n'
        '📍 *Distrito:* ${info.distrito.isNotEmpty ? info.distrito : info.provincia}\n'
        '📞 *Teléfono Oficial:* ${c.telefono.isNotEmpty ? c.telefono : 'Central 105'}\n\n'
        '🗺️ *Abrir en Google Maps (GPS):* $mapLink\n\n'
        '🛡️ *Sistema Nacional de Búsqueda y Localización PNP*\n'
        '🌐 https://pnpalerta.web.app';

    await Share.share(mensaje, subject: 'Información de Comisaría PNP: ${c.nombre}');
  }

  Future<void> _abrirEnMapa(ComisariaModel c) async {
    final String url;
    if (c.latitud != null && c.longitud != null && c.latitud != 0.0) {
      url = 'https://www.google.com/maps/search/?api=1&query=${c.latitud},${c.longitud}';
    } else {
      final busqueda = Uri.encodeComponent(
        'Comisaria PNP ${c.nombre}, ${c.distrito}, ${c.provincia}, ${c.departamento}, Peru',
      );
      url = 'https://www.google.com/maps/search/?api=1&query=$busqueda';
    }

    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      _mostrarSnackBar('No se pudo abrir el mapa.');
    }
  }

  void _mostrarSnackBar(
    String mensaje, {
    IconData? icono,
    bool esExito = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icono ?? (esExito ? Icons.check_circle : Icons.info_outline),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: esExito
            ? const Color(0xFF059669)
            : const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- MODAL SELECTOR DE DEPARTAMENTO ---

  void _mostrarSelectorDepartamento() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String queryModal = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final deptsFiltrados = _departamentos
                .where((d) => d.toUpperCase().contains(queryModal.toUpperCase()))
                .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.map_rounded, color: AppColors.primaryColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Seleccionar Departamento',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Filtra las comisarías por región política',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar departamento...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() => queryModal = val);
                      },
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.public_rounded, color: AppColors.accentColor),
                    title: const Text('Todo el Perú (Nacional)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${_todasComisarias.length} comisarías en todo el país'),
                    trailing: _departamentoSeleccionado == null
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryColor)
                        : null,
                    onTap: () {
                      _seleccionarDepartamento(null);
                      Navigator.pop(ctx);
                    },
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: deptsFiltrados.length,
                      itemBuilder: (context, idx) {
                        final dept = deptsFiltrados[idx];
                        final count = _conteoPorDepartamento[dept] ?? 0;
                        final esSeleccionado = _departamentoSeleccionado == dept;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: esSeleccionado
                                ? AppColors.primaryColor
                                : const Color(0xFFF1F5F9),
                            foregroundColor: esSeleccionado ? Colors.white : const Color(0xFF334155),
                            radius: 16,
                            child: Text(
                              dept.isNotEmpty ? dept[0] : '?',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            dept,
                            style: TextStyle(
                              fontWeight: esSeleccionado ? FontWeight.w800 : FontWeight.w600,
                              color: esSeleccionado ? AppColors.primaryColor : const Color(0xFF1E293B),
                            ),
                          ),
                          subtitle: Text('$count comisarías', style: const TextStyle(fontSize: 12)),
                          trailing: esSeleccionado
                              ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryColor)
                              : null,
                          onTap: () {
                            _seleccionarDepartamento(dept);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- MODAL SELECTOR DE PROVINCIA ---

  void _mostrarSelectorProvincia() {
    if (_departamentoSeleccionado == null && _provinciasDisponibles.isEmpty) {
      _mostrarSnackBar('Primero selecciona un Departamento para filtrar sus provincias.');
      _mostrarSelectorDepartamento();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String queryModal = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final provsFiltradas = _provinciasDisponibles
                .where((p) => p.toUpperCase().contains(queryModal.toUpperCase()))
                .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.70,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF047857).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_city_rounded, color: Color(0xFF047857), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Provincias de $_departamentoSeleccionado',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Text(
                                'Elige una provincia para afinar tu búsqueda',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar provincia...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() => queryModal = val);
                      },
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.clear_all_rounded, color: Color(0xFF047857)),
                    title: const Text('Todas las Provincias', style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: _provinciaSeleccionada == null
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF047857))
                        : null,
                    onTap: () {
                      _seleccionarProvincia(null);
                      Navigator.pop(ctx);
                    },
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: provsFiltradas.length,
                      itemBuilder: (context, idx) {
                        final prov = provsFiltradas[idx];
                        final esSeleccionada = _provinciaSeleccionada == prov;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: esSeleccionada
                                ? const Color(0xFF047857)
                                : const Color(0xFFF1F5F9),
                            foregroundColor: esSeleccionada ? Colors.white : const Color(0xFF334155),
                            radius: 16,
                            child: Text(
                              prov.isNotEmpty ? prov[0] : '?',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            prov,
                            style: TextStyle(
                              fontWeight: esSeleccionada ? FontWeight.w800 : FontWeight.w600,
                              color: esSeleccionada ? const Color(0xFF047857) : const Color(0xFF1E293B),
                            ),
                          ),
                          trailing: esSeleccionada
                              ? const Icon(Icons.check_circle_rounded, color: Color(0xFF047857))
                              : null,
                          onTap: () {
                            _seleccionarProvincia(prov);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- CONSTRUCCIÓN PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // 1. Cabecera Institucional
            _buildAppBar(),

            // 2. Marcación Directa de Emergencias 24/7
            _buildQuickEmergencyDial(),

            // 3. Contenido de Directorio
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _errorMessage != null
                  ? _buildErrorState()
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _inicializarDirectorio();
                      },
                      child: ListView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.only(bottom: 40),
                        children: [
                          const SizedBox(height: 12),

                          // Hero: Comisaría Más Cercana por GPS
                          _buildNearestPoliceHeroCard(),

                          const SizedBox(height: 14),

                          // Barra de Búsqueda Omni-Canal
                          _buildSearchBar(),

                          const SizedBox(height: 12),

                          // Barra de Filtrado Territorial (Dpto y Provincia)
                          _buildTerritorialFilterBar(),

                          // Carrusel Horizontal de Provincias (si hay depto seleccionado)
                          if (_departamentoSeleccionado != null && _provinciasDisponibles.isNotEmpty)
                            _buildProvincesChipCarousel(),

                          const SizedBox(height: 10),

                          // Contador de Resultados
                          _buildResultsHeader(),

                          const SizedBox(height: 8),

                          // Lista de Comisarías
                          if (_comisariasFiltradas.isEmpty)
                            _buildEmptyResults()
                          else
                            ...List.generate(_comisariasFiltradas.length, (index) {
                              return _buildComisariaCard(_comisariasFiltradas[index]);
                            }),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// App Bar Táctico Institucional
  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.policeHeroGradient,
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Regresar',
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const CitizenHomeScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentColor.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.accentColor.withValues(alpha: 0.6)),
                          ),
                          child: const Text(
                            'DIRECTORIO NACIONAL',
                            style: TextStyle(
                              color: AppColors.accentColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_todasComisarias.length} Comisarías',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Agenda Policial PNP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Recalcular mi ubicación GPS',
                icon: _detectandoGps
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentColor),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: const Icon(
                          Icons.my_location_rounded,
                          color: AppColors.accentColor,
                          size: 20,
                        ),
                      ),
                onPressed: _detectandoGps
                    ? null
                    : () => _detectarUbicacionYCercana(silencioso: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Marcación Rápida de Líneas Nacionales de Emergencia (24/7)
  Widget _buildQuickEmergencyDial() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: AppColors.accentColor, size: 16),
            const SizedBox(width: 6),
            const Text(
              'Emergencias 24h:',
              style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            _buildEmergencyPill(numero: '105', titulo: 'Emergencias PNP', color: const Color(0xFFEF4444)),
            const SizedBox(width: 6),
            _buildEmergencyPill(numero: '114', titulo: 'Desaparecidos', color: const Color(0xFFF59E0B)),
            const SizedBox(width: 6),
            _buildEmergencyPill(numero: '1818', titulo: 'Central Mininter', color: const Color(0xFF3B82F6)),
            const SizedBox(width: 6),
            _buildEmergencyPill(numero: '100', titulo: 'Línea Mujer', color: const Color(0xFFA855F7)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyPill({
    required String numero,
    required String titulo,
    required Color color,
  }) {
    return InkWell(
      onTap: () => _llamar(numero),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_rounded, color: color, size: 12),
            const SizedBox(width: 4),
            Text(
              numero,
              style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 4),
            Text(
              titulo,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta Hero: La Comisaría Más Cercana (Localización Inteligente)
  Widget _buildNearestPoliceHeroCard() {
    if (_comisariaCercana != null) {
      final c = _comisariaCercana!;
      final phone = (c.telefono != null && c.telefono!.isNotEmpty)
          ? c.telefono!
          : '105 (Central)';
      final direccionHero = c.direccion ?? '${c.distrito}, ${c.provincia} (${c.departamento})';

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F2544), Color(0xFF0A182C)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.accentColor.withValues(alpha: 0.5),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F2544).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -15,
              bottom: -20,
              child: Opacity(
                opacity: 0.08,
                child: Image.asset('assets/icons/icon_police.png', height: 140),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.near_me_rounded, color: Color(0xFF34D399), size: 13),
                            SizedBox(width: 5),
                            Text(
                              'TU COMISARÍA MÁS CERCANA (GPS)',
                              style: TextStyle(
                                color: Color(0xFF34D399),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'A ${c.formattedDistancia}',
                        style: const TextStyle(
                          color: AppColors.accentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    c.nombre,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Ficha de Ubicación Hero
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.home_work_outlined, color: Colors.white70, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                direccionHero,
                                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.map_outlined, color: Colors.white60, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '${c.distrito} • ${c.provincia} (${c.departamento})',
                              style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (c.tiempoAutoMin != null || c.tiempoPieMin != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '🚗 En auto: ~${c.formattedTiempoAuto}  •  🚶 A pie: ~${c.formattedTiempoPie}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: ElevatedButton.icon(
                          onPressed: () => _llamar(phone),
                          icon: const Icon(Icons.call_rounded, color: Colors.white, size: 18),
                          label: Text(
                            'LLAMAR ($phone)',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            launchUrl(Uri.parse(c.googleMapsUrl), mode: LaunchMode.externalApplication);
                          },
                          icon: const Icon(Icons.directions_rounded, color: Colors.white, size: 16),
                          label: const Text(
                            'Cómo llegar',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white38, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.my_location_rounded, color: AppColors.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Buscas la comisaría más cercana?',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                ),
                Text(
                  _miDepartamentoGps != null
                      ? 'Zona detectada: $_miProvinciaGps ($_miDepartamentoGps)'
                      : 'Activa tu GPS para calcular distancias en vivo.',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _detectarUbicacionYCercana(silencioso: false),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primaryColor.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              _detectandoGps ? 'Buscando...' : 'Detectar',
              style: const TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Barra de Búsqueda Omni-Canal
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre, dirección, distrito o teléfono...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryColor, size: 22),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.cancel_rounded, color: Color(0xFF94A3B8), size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _aplicarFiltros();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ),
    );
  }

  /// Barra de Filtrado Territorial: Botones Principales para Departamento y Provincia
  Widget _buildTerritorialFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Selector de Departamento
          Expanded(
            child: InkWell(
              onTap: _mostrarSelectorDepartamento,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _departamentoSeleccionado != null
                      ? AppColors.primaryColor
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _departamentoSeleccionado != null
                        ? AppColors.primaryColor
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.map_rounded,
                      size: 16,
                      color: _departamentoSeleccionado != null ? Colors.white : const Color(0xFF475569),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _departamentoSeleccionado ?? '🇵🇪 Todo el Perú',
                        style: TextStyle(
                          color: _departamentoSeleccionado != null ? Colors.white : const Color(0xFF1E293B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: _departamentoSeleccionado != null ? Colors.white : const Color(0xFF475569),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Selector de Provincia
          Expanded(
            child: InkWell(
              onTap: _mostrarSelectorProvincia,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _provinciaSeleccionada != null
                      ? const Color(0xFF047857)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _provinciaSeleccionada != null
                        ? const Color(0xFF047857)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_city_rounded,
                      size: 16,
                      color: _provinciaSeleccionada != null ? Colors.white : const Color(0xFF475569),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _provinciaSeleccionada ?? '🏛️ Provincias',
                        style: TextStyle(
                          color: _provinciaSeleccionada != null ? Colors.white : const Color(0xFF1E293B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: _provinciaSeleccionada != null ? Colors.white : const Color(0xFF475569),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Carrusel Horizontal de Chips de Provincias para Filtrado en 1 Toque
  Widget _buildProvincesChipCarousel() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _provinciasDisponibles.length + 1,
        itemBuilder: (context, idx) {
          if (idx == 0) {
            final esTodas = _provinciaSeleccionada == null;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: const Text('Todas las provincias'),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: esTodas ? Colors.white : const Color(0xFF334155),
                ),
                selected: esTodas,
                selectedColor: const Color(0xFF047857),
                backgroundColor: const Color(0xFFF1F5F9),
                onSelected: (_) => _seleccionarProvincia(null),
              ),
            );
          }

          final prov = _provinciasDisponibles[idx - 1];
          final esSeleccionada = _provinciaSeleccionada == prov;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              avatar: Icon(
                Icons.location_city_rounded,
                size: 13,
                color: esSeleccionada ? Colors.white : const Color(0xFF047857),
              ),
              label: Text(prov),
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: esSeleccionada ? Colors.white : const Color(0xFF047857),
              ),
              selected: esSeleccionada,
              selectedColor: const Color(0xFF047857),
              backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.10),
              side: BorderSide(
                color: esSeleccionada ? const Color(0xFF047857) : const Color(0xFF10B981).withValues(alpha: 0.35),
              ),
              onSelected: (sel) {
                _seleccionarProvincia(sel ? prov : null);
              },
            ),
          );
        },
      ),
    );
  }

  /// Encabezado de Resultados y Conteo
  Widget _buildResultsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            '${_comisariasFiltradas.length} comisarías encontradas',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
          ),
          const Spacer(),
          if (_departamentoSeleccionado != null ||
              _provinciaSeleccionada != null ||
              _searchController.text.isNotEmpty)
            InkWell(
              onTap: () {
                setState(() {
                  _departamentoSeleccionado = null;
                  _provinciaSeleccionada = null;
                  _provinciasDisponibles.clear();
                  _searchController.clear();
                });
                _aplicarFiltros();
              },
              child: const Text(
                'Limpiar filtros',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Tarjeta Compacta de Dependencia Policial (Diseño Moderno de Alta Densidad)
  Widget _buildComisariaCard(ComisariaModel c) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool esFamilia = c.nombre.toUpperCase().contains('FAMILIA') || c.unidad.toUpperCase().contains('FAMILIA');
    final bool esDepincri = c.nombre.toUpperCase().contains('DEPINCRI') || c.nombre.toUpperCase().contains('DIVINCRI');
    final String telefono = c.telefono.trim();
    final infoDir = _extraerInfoDireccion(c);

    // Identidad visual según la especialidad de la unidad
    final Color badgeBg;
    final Color badgeText;
    final Color cardBorder;
    final IconData iconPrincipal;
    final String categoriaLabel;

    if (esFamilia) {
      badgeBg = isDark ? const Color(0xFF3B185F) : const Color(0xFFEDE9FE);
      badgeText = isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9);
      cardBorder = isDark ? const Color(0xFF5B21B6) : const Color(0xFFDDD6FE);
      iconPrincipal = Icons.family_restroom_rounded;
      categoriaLabel = 'FAMILIA';
    } else if (esDepincri) {
      badgeBg = isDark ? const Color(0xFF431407) : const Color(0xFFFFEDD5);
      badgeText = isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C);
      cardBorder = isDark ? const Color(0xFF9A3412) : const Color(0xFFFED7AA);
      iconPrincipal = Icons.security_rounded;
      categoriaLabel = 'DEPINCRI';
    } else {
      badgeBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      badgeText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);
      cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
      iconPrincipal = Icons.local_police_rounded;
      categoriaLabel = 'COMISARÍA PNP';
    }

    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final textTitleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. CABECERA COMPACTA: Icono Circular + Badges + Nombre Oficial
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconPrincipal, color: badgeText, size: 17),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              categoriaLabel,
                              style: TextStyle(
                                color: badgeText,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (c.tipo != null && c.tipo!.trim().isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFF0F172A).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'TIPO ${c.tipo!.trim().toUpperCase()}',
                                style: TextStyle(
                                  color: textMutedColor,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (c.distanciaMetros != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.near_me_rounded, size: 9, color: Color(0xFF059669)),
                                  const SizedBox(width: 2),
                                  Text(
                                    c.formattedDistancia,
                                    style: const TextStyle(
                                      color: Color(0xFF059669),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        c.nombre,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: textTitleColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (c.unidad.isNotEmpty && c.unidad.toUpperCase() != c.nombre.toUpperCase()) ...[
                        const SizedBox(height: 1),
                        Text(
                          c.unidad,
                          style: TextStyle(
                            fontSize: 11,
                            color: textMutedColor,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // 2. BLOQUE DE UBICACIÓN TÁCTICO CON FONDO OSCURO (FORMATO HERO OFICIAL)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Fila 1: Dirección exacta de la calle con icono de edificio (Home / Work)
                  Row(
                    children: [
                      const Icon(Icons.home_work_outlined, color: Colors.white70, size: 14),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          infoDir.calle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Fila 2: DISTRITO • PROVINCIA (DEPARTAMENTO) con icono de mapa
                  Row(
                    children: [
                      const Icon(Icons.map_outlined, color: Colors.white60, size: 14),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '${(c.distrito.isNotEmpty ? c.distrito : c.provincia).toUpperCase()} • ${c.provincia.toUpperCase()} (${c.departamento.toUpperCase()})',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 3. BOTONERA DE ACCIÓN RÁPIDA (ALTURA 34PX)
            Row(
              children: [
                // Botón Verde LLAMAR
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: ElevatedButton.icon(
                      onPressed: () => _llamar(telefono),
                      icon: const Icon(Icons.call_rounded, color: Colors.white, size: 14),
                      label: Text(
                        telefono.isNotEmpty ? telefono : 'Central 105',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // Botón Copiar
                if (telefono.isNotEmpty)
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: IconButton(
                      tooltip: 'Copiar número',
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                      icon: Icon(Icons.copy_rounded, size: 15, color: textMutedColor),
                      onPressed: () => _copiarTelefono(telefono),
                    ),
                  ),

                const SizedBox(width: 6),

                // Botón Compartir Ficha
                SizedBox(
                  width: 34,
                  height: 34,
                  child: IconButton(
                    tooltip: 'Compartir ficha completa',
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    icon: Icon(Icons.share_outlined, size: 15, color: textMutedColor),
                    onPressed: () => _compartirComisaria(c),
                  ),
                ),

                const SizedBox(width: 6),

                // Botón Ver Mapa / Ruta GPS
                SizedBox(
                  width: 34,
                  height: 34,
                  child: IconButton(
                    tooltip: 'Cómo llegar en Google Maps (GPS)',
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryColor.withValues(alpha: isDark ? 0.3 : 0.10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    icon: const Icon(Icons.directions_rounded, size: 16, color: AppColors.primaryColor),
                    onPressed: () => _abrirEnMapa(c),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- ESTADOS DE CARGA, VACÍO Y ERROR ---

  Widget _buildEmptyResults() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No encontramos comisarías',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            Text(
              'No hay dependencias que coincidan con los filtros actuales. Prueba buscando con otro término o limpiando filtros.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _departamentoSeleccionado = null;
                  _provinciaSeleccionada = null;
                  _provinciasDisponibles.clear();
                  _searchController.clear();
                });
                _aplicarFiltros();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Restablecer Filtros'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
          ),
          SizedBox(height: 16),
          Text(
            'Cargando Directorio Nacional PNP...',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
          ),
          SizedBox(height: 4),
          Text(
            'Sincronizando comisarías en todo el Perú',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 52),
            const SizedBox(height: 12),
            const Text(
              'No se pudo cargar la agenda',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Ocurrió un error inesperado.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _inicializarDirectorio,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
