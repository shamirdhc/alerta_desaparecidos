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

  // Filtros Territoriales (Departamento y Provincia)
  String? _departamentoSeleccionado; // null = Todo el Perú
  String? _provinciaSeleccionada; // null = Todas las provincias
  List<String> _provinciasDisponibles = [];
  bool _filtroModificadoManualmente = false;

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

        // Auto-seleccionar departamento y provincia SOLO en primera carga si el usuario NO ha modificado manualmente
        if (mounted && locValida && _departamentoSeleccionado == null && !_filtroModificadoManualmente) {
          _seleccionarDepartamento(loc.departamento, provInicial: loc.provincia, manual: false);
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
  void _seleccionarDepartamento(String? depto, {String? provInicial, bool manual = true}) {
    if (manual) _filtroModificadoManualmente = true;
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
      } else {
        _provinciaSeleccionada = null;
      }
    });
    _aplicarFiltros();
  }

  /// Selección controlada de provincia
  void _seleccionarProvincia(String? prov) {
    _filtroModificadoManualmente = true;
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

  /// Aplica el filtrado unificado y sincronizado: Departamento + Provincia + Búsqueda
  void _aplicarFiltros() {
    final rawQuery = _searchController.text.trim();
    final cleanDigits = rawQuery.replaceAll(RegExp(r'[^0-9]'), '');
    final tokens = PeruLocations.normalize(rawQuery)
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final bool tieneDepto = _departamentoSeleccionado != null &&
        _departamentoSeleccionado!.trim().isNotEmpty &&
        _departamentoSeleccionado!.toUpperCase() != 'TODAS' &&
        _departamentoSeleccionado!.toUpperCase() != 'TODOS' &&
        !_departamentoSeleccionado!.toUpperCase().contains('TODO');

    final bool tieneProv = _provinciaSeleccionada != null &&
        _provinciaSeleccionada!.trim().isNotEmpty &&
        _provinciaSeleccionada!.toUpperCase() != 'TODAS' &&
        _provinciaSeleccionada!.toUpperCase() != 'TODOS' &&
        !_provinciaSeleccionada!.toUpperCase().contains('TODO');

    final targetDeptCanonical = tieneDepto
        ? (PeruLocations.canonicalDepartment(_departamentoSeleccionado!) ??
            PeruLocations.normalize(_departamentoSeleccionado!).toUpperCase())
        : null;

    final targetProvNorm = tieneProv
        ? PeruLocations.normalize(_provinciaSeleccionada!).toLowerCase()
        : null;

    List<ComisariaModel> resultado = _todasComisarias.where((c) {
      // 1. Filtro Combinado: DEPARTAMENTO
      if (tieneDepto) {
        final cDeptCanonical = PeruLocations.canonicalDepartment(c.departamento) ??
            PeruLocations.normalize(c.departamento).toUpperCase();
        final bool deptMatch = cDeptCanonical == targetDeptCanonical ||
            GpsLocationService.matches(c.departamento, _departamentoSeleccionado!) ||
            PeruLocations.matchesDepartment(
              caseDept: c.departamento,
              targetDept: _departamentoSeleccionado!,
              caseProv: c.provincia,
              caseDist: c.distrito,
            );
        if (!deptMatch) return false;
      }

      // 2. Filtro Combinado: PROVINCIA
      if (tieneProv) {
        final provNorm = PeruLocations.normalize(c.provincia).toLowerCase();
        final distNorm = PeruLocations.normalize(c.distrito).toLowerCase();
        final nomNorm = PeruLocations.normalize(c.nombre).toLowerCase();
        final bool provMatch = provNorm == targetProvNorm ||
            provNorm.contains(targetProvNorm!) ||
            distNorm.contains(targetProvNorm) ||
            nomNorm.contains(targetProvNorm) ||
            GpsLocationService.matches(c.provincia, _provinciaSeleccionada!) ||
            PeruLocations.matchesProvince(
              caseProv: c.provincia,
              caseDist: c.distrito,
              targetProv: _provinciaSeleccionada!,
            );
        if (!provMatch) return false;
      }

      // 3. Filtro Combinado: BÚSQUEDA (Nombres, distritos, direcciones, teléfonos)
      if (tokens.isNotEmpty) {
        final cand = PeruLocations.normalize(
          '${c.nombre} ${c.distrito} ${c.provincia} ${c.departamento} ${c.unidad} ${c.direccion}',
        ).toLowerCase();
        final tel = c.telefono.replaceAll(RegExp(r'[^0-9]'), '');
        final bool textMatch = tokens.every((t) => cand.contains(t));
        final bool telMatch = cleanDigits.length >= 3 && tel.contains(cleanDigits);
        if (!textMatch && !telMatch) return false;
      }

      return true;
    }).toList();

    // Ordenar resultados por relevancia en el nombre
    if (tokens.isNotEmpty) {
      final firstToken = tokens.first;
      resultado.sort((a, b) {
        final aNom = PeruLocations.normalize(a.nombre).toLowerCase();
        final bNom = PeruLocations.normalize(b.nombre).toLowerCase();
        final aStarts = aNom.startsWith(firstToken);
        final bStarts = bNom.startsWith(firstToken);
        if (aStarts && !bStarts) return -1;
        if (!aStarts && bStarts) return 1;
        return 0;
      });
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

  Future<void> _compartirMininterComisaria(MininterComisariaModel c) async {
    HapticFeedback.selectionClick();
    final phone = (c.telefono != null && c.telefono!.trim().isNotEmpty) ? c.telefono!.trim() : 'Central 105';
    final mensaje =
        '🚨 *COMISARÍA PNP MÁS CERCANA (GPS)*\n\n'
        '👮 *Dependencia:* ${c.nombre}\n'
        '🏢 *Tipo:* ${c.tipoSubtitulo}\n'
        '🏠 *Dirección:* ${c.direccion ?? '${c.distrito}, ${c.provincia}'}\n'
        '🇵🇪 *Ubicación:* ${c.distrito} - ${c.provincia} (${c.departamento})\n'
        '📍 *Distancia:* ${c.formattedDistancia}\n'
        '📞 *Teléfono:* $phone\n\n'
        '🗺️ *Abrir en Google Maps:* ${c.googleMapsUrl}\n\n'
        '🛡️ *Alerta Desaparecidos PNP*\n'
        '🌐 https://pnpalerta.web.app';

    await Share.share(mensaje, subject: 'Comisaría Cercana: ${c.nombre}');
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070D18) : const Color(0xFFF8FAFC),
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
                          // Panel Unificado de Filtros y Búsqueda (Fondo Neutral Policial Diferenciado)
                          _buildPoliceFilterPanel(isDark),

                          const SizedBox(height: 4),

                          // Contador de Resultados
                          _buildResultsHeader(),

                          const SizedBox(height: 6),

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
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const CitizenHomeScreen(),
                      ),
                    );
                  }
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

  /// Modal Ficha Táctica: Comisaría Más Cercana (GPS)
  void _mostrarModalComisariaCercana() {
    final c = _comisariaCercana;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
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
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (c == null) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.my_location_rounded, color: AppColors.primaryColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ubicar Comisaría Cercana',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              _miDepartamentoGps != null
                                  ? 'Zona detectada: $_miProvinciaGps ($_miDepartamentoGps)'
                                  : 'Activa tu ubicación GPS para calcular la más próxima en vivo.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _detectarUbicacionYCercana(silencioso: false);
                      },
                      icon: const Icon(Icons.gps_fixed_rounded, size: 18),
                      label: const Text('DETECTAR AHORA CON GPS', style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.near_me_rounded, color: Color(0xFF059669), size: 12),
                            SizedBox(width: 4),
                            Text(
                              'COMISARÍA MÁS CERCANA (GPS)',
                              style: TextStyle(
                                color: Color(0xFF059669),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'A ${c.formattedDistancia}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    c.nombre,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.tipoSubtitulo,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 15, color: Color(0xFF059669)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                c.direccion ?? '${c.distrito}, ${c.provincia}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.map_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              '${c.distrito} • ${c.provincia} (${c.departamento})',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        if (c.tiempoAutoMin != null || c.tiempoPieMin != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '🚗 En auto: ~${c.formattedTiempoAuto}  •  🚶 A pie: ~${c.formattedTiempoPie}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              final phone = (c.telefono != null && c.telefono!.trim().isNotEmpty)
                                  ? c.telefono!.trim()
                                  : '105';
                              _llamar(phone);
                            },
                            icon: const Icon(Icons.call_rounded, color: Colors.white, size: 16),
                            label: Text(
                              (c.telefono != null && c.telefono!.trim().isNotEmpty)
                                  ? 'LLAMAR (${c.telefono!.trim()})'
                                  : 'LLAMAR 105',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              launchUrl(Uri.parse(c.googleMapsUrl), mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(Icons.directions_rounded, size: 16),
                            label: const Text('Cómo llegar', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0284C7),
                              side: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (c.telefono != null && c.telefono!.trim().isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _copiarTelefono(c.telefono!.trim());
                          },
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text('Copiar Tel.', style: TextStyle(fontSize: 11.5)),
                        ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _compartirMininterComisaria(c);
                        },
                        icon: const Icon(Icons.share_outlined, size: 14),
                        label: const Text('Compartir Ficha', style: TextStyle(fontSize: 11.5)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Panel Unificado de Filtros y Búsqueda (Fondo Neutral Policial Diferenciado de los Cards)
  Widget _buildPoliceFilterPanel(bool isDark) {
    final panelBg = isDark ? const Color(0xFF0F1E33) : const Color(0xFFEDF2F7);
    final panelBorder = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFCBD5E1);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Barra de Búsqueda Omni-Canal
          _buildSearchBar(isDark),

          const SizedBox(height: 8),

          // 2. ÚNICA Fila de Filtros Territoriales: Departamento y Provincia
          _buildTerritorialFilterRow(isDark),

          const SizedBox(height: 8),

          // 3. Botón Táctico: Comisaría Más Cercana (GPS)
          _buildNearestPoliceButton(isDark),
        ],
      ),
    );
  }

  /// Barra de Búsqueda Omni-Canal Compacta
  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFCBD5E1),
          width: 1.1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => _onSearchChanged(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: 'Buscar por comisaría, distrito o teléfono...',
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF94A3B8),
            fontSize: 12,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF059669), size: 19),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.cancel_rounded, size: 17),
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF94A3B8),
                  onPressed: () {
                    _searchController.clear();
                    _aplicarFiltros();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
    );
  }

  /// Única Fila de Filtros Territoriales: Departamento y Provincia
  Widget _buildTerritorialFilterRow(bool isDark) {
    return Row(
      children: [
        // Selector de Departamento
        Expanded(
          child: InkWell(
            onTap: _mostrarSelectorDepartamento,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _departamentoSeleccionado != null
                    ? const Color(0xFF065F46)
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _departamentoSeleccionado != null
                      ? const Color(0xFF059669)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.map_rounded,
                    size: 15,
                    color: _departamentoSeleccionado != null ? Colors.white : const Color(0xFF059669),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _departamentoSeleccionado ?? '🇵🇪 Todo el Perú',
                      style: TextStyle(
                        color: _departamentoSeleccionado != null
                            ? Colors.white
                            : (isDark ? Colors.white : const Color(0xFF1E293B)),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: _departamentoSeleccionado != null
                        ? Colors.white
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Selector de Provincia
        Expanded(
          child: InkWell(
            onTap: _mostrarSelectorProvincia,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _provinciaSeleccionada != null
                    ? const Color(0xFF047857)
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _provinciaSeleccionada != null
                      ? const Color(0xFF047857)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_city_rounded,
                    size: 15,
                    color: _provinciaSeleccionada != null ? Colors.white : const Color(0xFF047857),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _provinciaSeleccionada ??
                          (_departamentoSeleccionado != null ? 'Todas las provincias' : '🏛️ Provincias'),
                      style: TextStyle(
                        color: _provinciaSeleccionada != null
                            ? Colors.white
                            : (isDark ? Colors.white : const Color(0xFF1E293B)),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: _provinciaSeleccionada != null
                        ? Colors.white
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Botón Táctico Compacto: Comisaría Más Cercana (GPS)
  Widget _buildNearestPoliceButton(bool isDark) {
    final c = _comisariaCercana;
    return InkWell(
      onTap: _mostrarModalComisariaCercana,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F2544), const Color(0xFF0B192E)]
                : [const Color(0xFF064E3B), const Color(0xFF065F46)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.5),
            width: 1.1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6)),
              ),
              child: const Icon(Icons.near_me_rounded, color: Color(0xFF34D399), size: 13),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  const Text(
                    'GPS: ',
                    style: TextStyle(
                      color: Color(0xFF6EE7B7),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      c != null ? c.nombre : 'Ubicar comisaría más cercana',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (c != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  c.formattedDistancia,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Detectar',
                  style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 14),
          ],
        ),
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
                _filtroModificadoManualmente = true;
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

  /// Modal Detalle Táctico de Ficha Policial Completa
  void _mostrarModalFichaComisaria(ComisariaModel c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final infoDir = _extraerInfoDireccion(c);
        final telefono = c.telefono.trim();

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
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
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF065F46).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_police_rounded, color: Color(0xFF059669), size: 13),
                          SizedBox(width: 4),
                          Text(
                            'DEPENDENCIA OFICIAL PNP',
                            style: TextStyle(
                              color: Color(0xFF059669),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '🟢 ATENCIÓN 24 HORAS',
                        style: TextStyle(
                          color: Color(0xFF059669),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  c.nombre,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                if (c.unidad.isNotEmpty && c.unidad.toUpperCase() != c.nombre.toUpperCase()) ...[
                  const SizedBox(height: 2),
                  Text(
                    c.unidad,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.home_work_outlined, size: 16, color: Color(0xFF059669)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              infoDir.calle,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.map_outlined, size: 15, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Text(
                            '${c.distrito} • ${c.provincia} (${c.departamento})',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      if (c.distanciaMetros != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.near_me_rounded, size: 14, color: Color(0xFF059669)),
                            const SizedBox(width: 8),
                            Text(
                              'Distancia GPS: ${c.formattedDistancia}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _llamar(telefono.isNotEmpty ? telefono : '105');
                          },
                          icon: const Icon(Icons.call_rounded, color: Colors.white, size: 16),
                          label: Text(
                            telefono.isNotEmpty ? 'LLAMAR ($telefono)' : 'LLAMAR CENTRAL 105',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _abrirEnMapa(c);
                          },
                          icon: const Icon(Icons.directions_rounded, size: 16),
                          label: const Text('Cómo llegar', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (telefono.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _copiarTelefono(telefono);
                        },
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Copiar Tel.', style: TextStyle(fontSize: 11.5)),
                      ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _compartirComisaria(c);
                      },
                      icon: const Icon(Icons.share_outlined, size: 14),
                      label: const Text('Compartir Ficha', style: TextStyle(fontSize: 11.5)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Tarjeta de Dependencia Policial (Diseño Táctico Institucional PNP Compacto)
  Widget _buildComisariaCard(ComisariaModel c) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool esFamilia = c.nombre.toUpperCase().contains('FAMILIA') || c.unidad.toUpperCase().contains('FAMILIA');
    final bool esDepincri = c.nombre.toUpperCase().contains('DEPINCRI') ||
        c.nombre.toUpperCase().contains('DIVINCRI') ||
        c.unidad.toUpperCase().contains('DEPINCRI');
    final bool esTransito = c.nombre.toUpperCase().contains('TRANSITO') ||
        c.nombre.toUpperCase().contains('TRÁNSITO') ||
        c.nombre.toUpperCase().contains('CARRETERA');
    final String telefono = c.telefono.trim();
    final infoDir = _extraerInfoDireccion(c);

    // Identidad visual táctica policial
    final Color stripeStart;
    final Color stripeEnd;
    final Color badgeBg;
    final Color badgeText;
    final IconData iconPrincipal;
    final String categoriaLabel;

    if (esFamilia) {
      stripeStart = const Color(0xFF7C3AED);
      stripeEnd = const Color(0xFF4C1D95);
      badgeBg = isDark ? const Color(0xFF3B185F) : const Color(0xFFEDE9FE);
      badgeText = isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9);
      iconPrincipal = Icons.family_restroom_rounded;
      categoriaLabel = 'FAMILIA';
    } else if (esDepincri) {
      stripeStart = const Color(0xFFD97706);
      stripeEnd = const Color(0xFF9A3412);
      badgeBg = isDark ? const Color(0xFF431407) : const Color(0xFFFFEDD5);
      badgeText = isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C);
      iconPrincipal = Icons.security_rounded;
      categoriaLabel = 'DEPINCRI';
    } else if (esTransito) {
      stripeStart = const Color(0xFF2563EB);
      stripeEnd = const Color(0xFF1E3A8A);
      badgeBg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFDBEAFE);
      badgeText = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
      iconPrincipal = Icons.traffic_rounded;
      categoriaLabel = 'TRÁNSITO';
    } else {
      stripeStart = const Color(0xFF059669);
      stripeEnd = const Color(0xFF064E3B);
      badgeBg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFD1FAE5);
      badgeText = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46);
      iconPrincipal = Icons.local_police_rounded;
      categoriaLabel = 'COMISARÍA PNP';
    }

    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final textTitleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _mostrarModalFichaComisaria(c),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Tira Táctica Superior Estilo Patrullero PNP
              Container(
                height: 3.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [stripeStart, stripeEnd],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fila Superior: Insignia + Categoría Oficial + Distancia GPS
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(iconPrincipal, color: stripeStart, size: 14),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            categoriaLabel,
                            style: TextStyle(
                              color: badgeText,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (c.distanciaMetros != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
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

                    const SizedBox(height: 4),

                    // Fila Central: Nombre Oficial de la Comisaría
                    Text(
                      c.nombre,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: textTitleColor,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 2),

                    // Fila de Ubicación Táctica Condensada en 1 Línea
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: Color(0xFF059669), size: 12),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '${infoDir.calle} • ${(c.distrito.isNotEmpty ? c.distrito : c.provincia).toUpperCase()}',
                            style: TextStyle(
                              fontSize: 11,
                              color: textMutedColor,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Fila Inferior: Botonera Táctica Compacta (30px)
                    Row(
                      children: [
                        // Botón Verde Patrulla LLAMAR
                        Expanded(
                          child: SizedBox(
                            height: 30,
                            child: ElevatedButton.icon(
                              onPressed: () => _llamar(telefono),
                              icon: const Icon(Icons.call_rounded, color: Colors.white, size: 13),
                              label: Text(
                                telefono.isNotEmpty ? telefono : 'Central 105',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 5),

                        // Botón Mapa GPS
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: IconButton(
                            tooltip: 'Ver en Google Maps',
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.25 : 0.12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.directions_rounded, size: 15, color: Color(0xFF0284C7)),
                            onPressed: () => _abrirEnMapa(c),
                          ),
                        ),

                        const SizedBox(width: 5),

                        // Botón Copiar
                        if (telefono.isNotEmpty)
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: IconButton(
                              tooltip: 'Copiar número',
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: Icon(Icons.copy_rounded, size: 13, color: textMutedColor),
                              onPressed: () => _copiarTelefono(telefono),
                            ),
                          ),

                        const SizedBox(width: 5),

                        // Botón Compartir
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: IconButton(
                            tooltip: 'Compartir ficha',
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: Icon(Icons.share_outlined, size: 13, color: textMutedColor),
                            onPressed: () => _compartirComisaria(c),
                          ),
                        ),
                      ],
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
                _filtroModificadoManualmente = true;
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
