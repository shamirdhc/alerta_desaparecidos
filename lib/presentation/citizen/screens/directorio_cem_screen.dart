import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/cem_model.dart';
import '../../../services/cem_service.dart';
import '../../../services/gps_location_service.dart';
import '../../../services/session_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../common/constants/peru_locations.dart';

class DirectorioCemScreen extends StatefulWidget {
  const DirectorioCemScreen({super.key});

  @override
  State<DirectorioCemScreen> createState() => _DirectorioCemScreenState();
}

class _DirectorioCemScreenState extends State<DirectorioCemScreen> {
  final ScrollController _scrollController = ScrollController();

  List<CemModel> _cemsFiltrados = [];
  List<String> _departamentos = [];
  Map<String, int> _conteoPorDepartamento = {};

  String? _departamentoSeleccionado;
  String? _provinciaSeleccionada;
  List<String> _provinciasDisponibles = [];

  String? _departamentoPerfil;
  String? _provinciaPerfil;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarDirectorio();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargarDirectorio() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await CemService.getTodos();
      final depts = await CemService.getDepartamentos();
      final conteos = await CemService.getConteosPorDepartamento();

      _departamentos = depts;
      _conteoPorDepartamento = conteos;

      // 1. Obtener la ubicación declarada en el perfil del ciudadano desde múltiples fuentes sincronizadas
      String? deptPerfil;
      String? provPerfil;

      // Fuente 1: SharedPreferences (inmediato en caché local)
      try {
        final prefs = await SharedPreferences.getInstance();
        deptPerfil = prefs.getString('user_departamento') ?? prefs.getString('user_department');
        provPerfil = prefs.getString('user_provincia');
      } catch (_) {}

      // Fuente 2: SessionService
      if (deptPerfil == null || deptPerfil.isEmpty) {
        try {
          final session = await SessionService.getUserSession();
          if (session != null && session['departamento'] != null && (session['departamento'] as String).isNotEmpty) {
            deptPerfil = session['departamento'];
            provPerfil = session['provincia'];
          }
        } catch (_) {}
      }

      // Fuente 3: GpsLocationService
      if (deptPerfil == null || deptPerfil.isEmpty) {
        try {
          final userProfile = await GpsLocationService.getSavedLocation();
          if (userProfile != null && userProfile.departamento.isNotEmpty) {
            deptPerfil = userProfile.departamento;
            provPerfil = userProfile.provincia;
          }
        } catch (_) {}
      }

      // Fuente 4: Firestore (fuente viva si el usuario está autenticado)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('ciudadanos')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 3));
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            final fsDept = data['departamento'] as String?;
            if (fsDept != null && fsDept.trim().isNotEmpty) {
              deptPerfil = fsDept.trim();
              final fsProv = data['provincia'] as String?;
              if (fsProv != null && fsProv.trim().isNotEmpty) {
                provPerfil = fsProv.trim();
              }
            }
          }
        } catch (_) {}
      }

      String? initialDept;
      String? initialProv;

      if (deptPerfil != null && deptPerfil.trim().isNotEmpty) {
        final cleanDept = deptPerfil.trim();
        _departamentoPerfil = cleanDept;
        _provinciaPerfil = provPerfil?.trim();

        // Buscar coincidencia tolerante a tildes (ej. Áncash -> ANCASH, San Martín -> SAN MARTIN)
        initialDept = depts.firstWhere(
          (d) => GpsLocationService.matches(d, cleanDept),
          orElse: () => depts.firstWhere(
            (d) => PeruLocations.normalize(d) == PeruLocations.normalize(cleanDept),
            orElse: () => '',
          ),
        );

        if (initialDept.isNotEmpty) {
          final provs = await CemService.getProvincias(initialDept);
          _provinciasDisponibles = provs;

          if (provPerfil != null && provPerfil.trim().isNotEmpty && provs.isNotEmpty) {
            final cleanProv = provPerfil.trim();
            initialProv = provs.firstWhere(
              (p) => GpsLocationService.matches(p, cleanProv),
              orElse: () => provs.firstWhere(
                (p) => PeruLocations.normalize(p) == PeruLocations.normalize(cleanProv),
                orElse: () => '',
              ),
            );
            if (initialProv.isEmpty) initialProv = null;
          }
        } else {
          initialDept = null;
        }
      }

      _departamentoSeleccionado = initialDept;
      _provinciaSeleccionada = initialProv;

      _aplicarFiltros();
    } catch (e) {
      debugPrint('⚠️ [CEM] Error inicializando directorio CEM: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'No se pudo cargar el directorio de Centros Emergencia Mujer.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onDepartamentoChanged(String? nuevoDept) async {
    List<String> nuevasProvs = [];
    if (nuevoDept != null && nuevoDept.isNotEmpty) {
      nuevasProvs = await CemService.getProvincias(nuevoDept);
    }

    setState(() {
      _departamentoSeleccionado = (nuevoDept != null && nuevoDept.isNotEmpty) ? nuevoDept : null;
      _provinciaSeleccionada = null;
      _provinciasDisponibles = nuevasProvs;
    });

    _aplicarFiltros();
  }

  void _onProvinciaChanged(String? nuevaProv) {
    setState(() {
      _provinciaSeleccionada = (nuevaProv != null && nuevaProv.isNotEmpty) ? nuevaProv : null;
    });
    _aplicarFiltros();
  }

  void _limpiarFiltros() {
    setState(() {
      _departamentoSeleccionado = null;
      _provinciaSeleccionada = null;
      _provinciasDisponibles = [];
    });
    _aplicarFiltros();
  }

  Future<void> _aplicarFiltros() async {
    final filtrados = await CemService.buscar(
      query: null,
      departamento: _departamentoSeleccionado,
      provincia: _provinciaSeleccionada,
    );

    if (mounted) {
      setState(() {
        _cemsFiltrados = filtrados;
        _isLoading = false;
      });
    }
  }

  Future<void> _llamarNumero(String numero) async {
    final cleaned = numero.replaceAll(RegExp(r'\D'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _mostrarMensaje('No se pudo abrir la app de llamadas para: $numero');
    }
  }

  Future<void> _abrirWhatsApp(String numero, String nombreCem) async {
    final cleaned = numero.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != 9) return;
    final mensaje = 'Hola, me comunico con $nombreCem para solicitar orientación y asistencia.';
    final uri = Uri.parse('https://wa.me/51$cleaned?text=${Uri.encodeComponent(mensaje)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _mostrarMensaje('No se pudo abrir WhatsApp');
    }
  }

  Future<void> _abrirEnlace(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _mostrarMensaje('No se pudo abrir el mapa.');
    }
  }

  void _copiarTexto(String texto, String descripcion) {
    Clipboard.setData(ClipboardData(text: texto));
    _mostrarMensaje('📋 $descripcion copiado al portapapeles');
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _compartirCem(CemModel cem) async {
    await Share.share(
      cem.mensajeCompartir,
      subject: 'Información de ${cem.nombre} - MIMP',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF8FAFC);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDark),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState(isDark)
                    : _errorMessage != null
                        ? _buildErrorState(isDark)
                        : _buildContenido(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final canPop = Navigator.canPop(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          if (canPop) ...[
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                size: 20,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: 'Atrás',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            const SizedBox(width: 4),
          ],
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9333EA).withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'DIRECTORIO CEM',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC4899).withOpacity(isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFEC4899), width: 0.8),
                      ),
                      child: const Text(
                        'MIMP / AURORA',
                        style: TextStyle(
                          color: Color(0xFFEC4899),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Centros Emergencia Mujer - 240 sedes en todo el Perú',
                  style: TextStyle(
                    color: isDark ? Colors.white.withOpacity(0.65) : const Color(0xFF64748B),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
              size: 20,
            ),
            tooltip: 'Recargar',
            onPressed: _cargarDirectorio,
          ),
        ],
      ),
    );
  }

  Widget _buildContenido(bool isDark) {
    return Column(
      children: [
        // 🎛️ FILTROS COMPACTOS (Solo Selectores de Departamento y Provincia)
        _buildFiltrosCompactos(isDark),

        // 📋 LISTA DESPLAZABLE DE TARJETAS CEM (Espacio maximizado)
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargarDirectorio,
            color: const Color(0xFFEC4899),
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                // Banner Oficial de Línea 100
                _buildBannerLinea100(isDark),
                const SizedBox(height: 12),

                // Lista de Tarjetas CEM
                if (_cemsFiltrados.isEmpty)
                  _buildEmptyState(isDark)
                else
                  ..._cemsFiltrados.map((cem) => _buildCemCard(cem, isDark)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerLinea100(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF701A75).withOpacity(0.95),
            const Color(0xFF831843).withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF472B6).withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC4899).withOpacity(isDark ? 0.18 : 0.22),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_in_talk_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'LÍNEA 100',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '• Gratuita y 24/7',
                      style: TextStyle(
                        color: Color(0xFFFBCFE8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Orientación confidencial en violencia familiar o de género a nivel nacional.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _llamarNumero('100'),
            icon: const Icon(Icons.call, size: 14),
            label: const Text('Llamar 100', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltrosCompactos(bool isDark) {
    final bool tieneFiltrosActivos =
        _departamentoSeleccionado != null || _provinciaSeleccionada != null;

    final borderColor = isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFCBD5E1);
    final inputBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    const accentPink = Color(0xFFEC4899);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? accentPink.withOpacity(0.28) : accentPink.withOpacity(0.18),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // 1. Selector Departamento
              Expanded(
                flex: 6,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _departamentoSeleccionado != null ? accentPink : borderColor,
                      width: _departamentoSeleccionado != null ? 1.4 : 1,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _departamentoSeleccionado,
                      hint: Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 14, color: accentPink),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Todo el Perú (240)',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: accentPink, size: 20),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            'Todo el Perú (240 sedes)',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 12,
                              fontWeight: _departamentoSeleccionado == null ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        ..._departamentos.map((d) {
                          final count = _conteoPorDepartamento[d] ?? 0;
                          final esMiDepto = _departamentoPerfil != null &&
                              GpsLocationService.matches(d, _departamentoPerfil!);

                          return DropdownMenuItem<String>(
                            value: d,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    d,
                                    style: TextStyle(
                                      color: d == _departamentoSeleccionado
                                          ? accentPink
                                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                      fontWeight: (d == _departamentoSeleccionado || esMiDepto)
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: _onDepartamentoChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Selector Provincia
              Expanded(
                flex: 5,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _departamentoSeleccionado == null
                        ? (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC))
                        : inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _provinciaSeleccionada != null
                          ? accentPink
                          : (_departamentoSeleccionado == null
                              ? (isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0))
                              : borderColor),
                      width: _provinciaSeleccionada != null ? 1.4 : 1,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _provinciaSeleccionada,
                      hint: Text(
                        _departamentoSeleccionado == null ? 'Provincia' : 'Todas prov.',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          fontSize: 11.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      icon: Icon(
                        Icons.arrow_drop_down_rounded,
                        color: _departamentoSeleccionado == null
                            ? (isDark ? Colors.white24 : const Color(0xFFCBD5E1))
                            : accentPink,
                        size: 20,
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            'Todas las provincias',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        ..._provinciasDisponibles.map((p) {
                          final esMiProv = _provinciaPerfil != null &&
                              GpsLocationService.matches(p, _provinciaPerfil!);

                          return DropdownMenuItem<String>(
                            value: p,
                            child: Text(
                              p,
                              style: TextStyle(
                                color: p == _provinciaSeleccionada
                                    ? accentPink
                                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                fontWeight: (p == _provinciaSeleccionada || esMiProv)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: _departamentoSeleccionado == null ? null : _onProvinciaChanged,
                    ),
                  ),
                ),
              ),

              // 3. Botón para restablecer filtros (aparece solo si hay filtro activo)
              if (tieneFiltrosActivos) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: _limpiarFiltros,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(isDark ? 0.18 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.clear_rounded, color: Colors.redAccent, size: 14),
                        SizedBox(width: 2),
                        Text(
                          'Limpiar',
                          style: TextStyle(
                            color: Colors.redAccent,
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
          const SizedBox(height: 6),
          // Resumen compacto de 1 línea para dar feedback inmediato sin ocupar altura
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: accentPink,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_cemsFiltrados.length} ${_cemsFiltrados.length == 1 ? "sede de atención" : "sedes de atención"}'
                  '${_departamentoSeleccionado != null ? " en $_departamentoSeleccionado" : " a nivel nacional"}'
                  '${_provinciaSeleccionada != null ? " › $_provinciaSeleccionada" : ""}',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCemCard(CemModel cem, bool isDark) {
    final tieneCelular = cem.tieneCelular;
    final celular = cem.primerCelular;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withOpacity(0.95) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera: Nombre y Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF9333EA).withOpacity(isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF9333EA), width: 1.2),
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  color: Color(0xFF9333EA),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cem.nombre,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEC4899).withOpacity(isDark ? 0.15 : 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'CEM REGULAR',
                            style: TextStyle(
                              color: Color(0xFFEC4899),
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${cem.distrito}, ${cem.provincia} (${cem.departamento})',
                            style: TextStyle(
                              color: isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF64748B),
                              fontSize: 11,
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
              IconButton(
                icon: Icon(
                  Icons.share_rounded,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  size: 18,
                ),
                tooltip: 'Compartir sede',
                onPressed: () => _compartirCem(cem),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),

          // Bloque de datos de la sede (Solo Lectura)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 11,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'INFORMACIÓN DE LA SEDE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                if (cem.direccion.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF0284C7)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          cem.direccion,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _abrirEnlace(cem.googleMapsUrl),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withOpacity(isDark ? 0.2 : 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.5), width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.directions, size: 11, color: Color(0xFF0284C7)),
                              SizedBox(width: 3),
                              Text('Mapa', style: TextStyle(color: Color(0xFF0284C7), fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (cem.coordinador.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 13,
                        color: isDark ? Colors.white.withOpacity(0.4) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Coordinador/a: ${cem.coordinador}',
                          style: TextStyle(
                            color: isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF64748B),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          const SizedBox(height: 10),

          // Teléfonos y Botonera de Acción
          Row(
            children: [
              // Botón de llamada principal (Elevado, táctil)
              if (cem.tieneTelefono) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _llamarNumero(cem.telefonoPrincipal),
                    icon: const Icon(Icons.phone_rounded, size: 14),
                    label: Text(
                      'Llamar: ${cem.telefonoPrincipal}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                      shadowColor: const Color(0xFF059669).withOpacity(0.4),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Botón copiar teléfono
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.copy_rounded,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                      size: 16,
                    ),
                    tooltip: 'Copiar teléfono',
                    onPressed: () => _copiarTexto(cem.telefonoPrincipal, 'Teléfono de ${cem.nombre}'),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 6),

                // Botón WhatsApp si es celular
                if (tieneCelular)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withOpacity(isDark ? 0.15 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF25D366).withOpacity(0.5)),
                    ),
                    child: IconButton(
                      icon: const FaIcon(
                        FontAwesomeIcons.whatsapp,
                        color: Color(0xFF25D366),
                        size: 18,
                      ),
                      tooltip: 'WhatsApp',
                      onPressed: () => _abrirWhatsApp(celular, cem.nombre),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                  ),
              ] else ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.phone_disabled_rounded,
                          size: 13,
                          color: isDark ? Colors.white.withOpacity(0.4) : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Sin teléfono local registrado',
                          style: TextStyle(
                            color: isDark ? Colors.white.withOpacity(0.45) : const Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(width: 6),
              // Botón rápido de emergencia 100
              ElevatedButton(
                onPressed: () => _llamarNumero('100'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48).withOpacity(isDark ? 0.2 : 0.1),
                  foregroundColor: const Color(0xFFE11D48),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE11D48), width: 1),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone_in_talk_rounded, size: 13, color: Color(0xFFE11D48)),
                    SizedBox(width: 4),
                    Text('100', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),

          // Mostrar teléfonos alternativos si hay más de 1
          if (cem.telefonos.length > 1) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: cem.telefonos.skip(1).map((tel) {
                return InkWell(
                  onTap: () => _llamarNumero(tel),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_in_talk,
                          size: 10,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Alt: $tel',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 40,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No se encontraron sedes CEM',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Intenta seleccionando otro departamento o provincia para encontrar sedes de atención.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _limpiarFiltros,
            icon: const Icon(Icons.clear_all_rounded, size: 16),
            label: const Text('Restablecer Filtros', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFEC4899)),
          const SizedBox(height: 16),
          Text(
            'Cargando Directorio CEM...',
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFF43F5E), size: 44),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Ocurrió un error inesperado',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargarDirectorio,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC4899),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
