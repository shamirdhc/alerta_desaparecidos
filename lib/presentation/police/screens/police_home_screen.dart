import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:provider/provider.dart';
import '../../../domain/use_cases/policia_management_use_cases.dart';
import '../../../domain/entities/policia.dart';
import 'manage_reports_selection_screen.dart';
import 'police_manage_missing_screen.dart';
import '../view_models/police_manage_missing_view_model.dart';
import 'manage_found_screen.dart';
import '../view_models/manage_found_view_model.dart';
import 'report_desaparecido_screen.dart';
import 'package:alerta_desaparecidos/services/session_service.dart';
import 'package:alerta_desaparecidos/presentation/screens/welcome_screen.dart';
import 'policia_management_screen.dart';
import '../view_models/policia_management_view_model.dart';
import '../../../injection.dart' as di;
import 'tutorial_library_screen.dart';
import 'tutorials/tutorial_main_screen.dart';
import 'police_agenda_screen.dart';
import '../../citizen/screens/directorio_cem_screen.dart';
import '../../common_widgets/theme_sun_moon_toggle.dart';
import 'about_police_screen.dart';
import 'police_profile_screen.dart';
import 'police_ai_copilot_screen.dart';
import '../../superadmin/screens/superadmin_sync_monitor_screen.dart';
import '../../superadmin/screens/superadmin_analytics_screen.dart';
import 'package:alerta_desaparecidos/services/police_notification_service.dart';
import 'package:alerta_desaparecidos/services/police_logout_service.dart';
import '../widgets/notification_center_dialog.dart';
import 'package:alerta_desaparecidos/services/police_preview_mode_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../services/pwa_install_service.dart';

class PoliceHomeScreen extends StatefulWidget {
  const PoliceHomeScreen({super.key});

  @override
  State<PoliceHomeScreen> createState() => _PoliceHomeScreenState();
}

class _PoliceHomeScreenState extends State<PoliceHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  DateTime? _lastBackPressed;
  late Future<Policia?> _policeInfoFuture;

  @override
  void initState() {
    super.initState();
    _policeInfoFuture = _getCurrentPoliceInfo();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    _slideController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PwaInstallService.checkAndShowAutoInstallPrompt(
        context,
        delay: const Duration(seconds: 3),
      );
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Presione nuevamente para salir de Alerta Desaparecidos PNP'),
                ],
              ),
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [
                      Color(0xFF0F172A),
                      Color(0xFF1E293B),
                      Color(0xFF0B132B),
                    ]
                  : const [
                      Color(0xFFF8FAFC),
                      Color(0xFFF1F5F9),
                      Color(0xFFEFF6FF),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildModernAppBar(isDark),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildDashboardContent(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: _buildFloatingActionButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _buildModernBottomBar(isDark),
      ),
    );
  }

  Widget _buildModernAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.4) : Colors.white.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF004D40), Color(0xFF00796B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF004D40).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const FaIcon(
              FontAwesomeIcons.shieldHalved,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedTextKit(
                  animatedTexts: [
                    TypewriterAnimatedText(
                      'COMANDO POLICIAL PNP',
                      textStyle: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                      speed: const Duration(milliseconds: 90),
                    ),
                  ],
                  totalRepeatCount: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  'Sistema Operativo de Desaparecidos',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const ThemeSunMoonToggle(compact: true),
          const SizedBox(width: 8),
          _buildProfileButton(isDark),
        ],
      ),
    );
  }

  Widget _buildProfileButton(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showProfileMenu(isDark),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: FaIcon(
            FontAwesomeIcons.userTie,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(bool isDark) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSuperAdminSyncHeroBanner(isDark),
              _buildPoliceInfoCard(isDark),
              const SizedBox(height: 20),
              _buildOperationalMetricsSection(isDark),
              const SizedBox(height: 20),
              _buildTacticalCopilotBanner(isDark),
              const SizedBox(height: 25),
              _buildQuickActions(isDark),
              const SizedBox(height: 80), // Margen para el FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuperAdminSyncHeroBanner(bool isDark) {
    final userEmail = (FirebaseAuth.instance.currentUser?.email ?? '').trim().toLowerCase();
    final isSuperEmail = userEmail == 'shamirdhc2022@gmail.com';

    return FutureBuilder<Policia?>(
      future: _policeInfoFuture,
      builder: (context, snapshot) {
        final pol = snapshot.data;
        final shouldShow = isSuperEmail || pol?.rol == 'superadmin';
        if (!shouldShow) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF1E293B), Color(0xFF0F172A)]
                  : const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFF59E0B).withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.15 : 0.2),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB300), Color(0xFFF59E0B)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.black, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                              ),
                              child: const Text(
                                'SUPERADMIN PNP',
                                style: TextStyle(
                                  color: Color(0xFFB45309),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sincronización Total del Portal PNP',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Descarga notas de alerta y concilia personas ubicadas',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SuperAdminSyncMonitorScreen()),
                      );
                    },
                    icon: const Icon(Icons.sync_rounded, color: Colors.black, size: 16),
                    label: const Text(
                      'SINCRONIZAR',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB300),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPoliceInfoCard(bool isDark) {
    return FutureBuilder<Policia?>(
      future: _policeInfoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final policia = snapshot.data;
        if (policia == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
              ),
            ),
            child: Center(
              child: Text(
                'Personal Policial en Servicio',
                style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B)),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF004D40).withOpacity(0.5)
                  : const Color(0xFF004D40).withOpacity(0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF004D40), Color(0xFF00796B)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF004D40).withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.userShield,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OFICIAL AL MANDO',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF00796B),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          policia.nombreCompleto,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (policia.rol == 'superadmin')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFB300), Color(0xFFF59E0B)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars_rounded, color: Colors.black, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'SUPERADMIN',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (policia.admin)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF0284C7)),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
                          color: Color(0xFF0284C7),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      'Rango',
                      policia.rango.isNotEmpty ? policia.rango : 'Oficial',
                      FontAwesomeIcons.medal,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoItem(
                      'CIP',
                      policia.numeroCip.isNotEmpty ? policia.numeroCip : '---',
                      FontAwesomeIcons.idCard,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      'Unidad',
                      policia.unidad.isNotEmpty ? policia.unidad : 'Comisaría PNP',
                      FontAwesomeIcons.buildingShield,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoItem(
                      'Departamento',
                      policia.departamento.isNotEmpty ? policia.departamento : 'Nacional',
                      FontAwesomeIcons.mapLocationDot,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => PolicePreviewModeService.enterPreviewMode(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF0284C7).withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const FaIcon(FontAwesomeIcons.eye, color: Color(0xFF0284C7), size: 14),
                        const SizedBox(width: 8),
                        Text(
                          'Modo Vista: Ver como Ciudadano',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0369A1),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF0284C7), size: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(
                icon,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                size: 11,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalMetricsSection(bool isDark) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('system_status').doc('sync_pnp').snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final totalFirestore = (data?['total_firestore_actual'] as num?)?.toInt() ?? 0;
        final totalUbicados = (data?['total_ubicados_portal'] as num?)?.toInt() ?? 0;
        final nuevosCasos = (data?['casos_nuevos'] as num?)?.toInt() ?? 0;

        final casosActivos = totalFirestore > 0 && totalUbicados > 0
            ? (totalFirestore - totalUbicados > 0 ? totalFirestore - totalUbicados : totalFirestore)
            : totalFirestore;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PANEL OPERATIVO EN TIEMPO REAL',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'EN VIVO PNP',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 650;
                if (isWide) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Casos Activos',
                          value: casosActivos > 0 ? NumberFormat('#,###').format(casosActivos) : 'En línea',
                          subtitle: 'Alertas vigentes',
                          icon: FontAwesomeIcons.personCircleExclamation,
                          color: const Color(0xFFE11D48),
                          isDark: isDark,
                          onTap: _navigateToManageMissing,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Nuevos Reportes',
                          value: nuevosCasos > 0 ? '+$nuevosCasos' : 'Al día',
                          subtitle: 'Última conciliación',
                          icon: FontAwesomeIcons.bell,
                          color: const Color(0xFFF59E0B),
                          isDark: isDark,
                          onTap: _navigateToManageReports,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Personas Ubicadas',
                          value: totalUbicados > 0 ? NumberFormat('#,###').format(totalUbicados) : 'Ver casos',
                          subtitle: 'Resueltos con éxito',
                          icon: FontAwesomeIcons.circleCheck,
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                          onTap: _navigateToManageFound,
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Casos Activos',
                            value: casosActivos > 0 ? NumberFormat('#,###').format(casosActivos) : 'En línea',
                            subtitle: 'Alertas vigentes',
                            icon: FontAwesomeIcons.personCircleExclamation,
                            color: const Color(0xFFE11D48),
                            isDark: isDark,
                            onTap: _navigateToManageMissing,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Nuevos Reportes',
                            value: nuevosCasos > 0 ? '+$nuevosCasos' : 'Al día',
                            subtitle: 'Última conciliación',
                            icon: FontAwesomeIcons.bell,
                            color: const Color(0xFFF59E0B),
                            isDark: isDark,
                            onTap: _navigateToManageReports,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildMetricCard(
                      title: 'Personas Ubicadas (Casos Resueltos)',
                      value: totalUbicados > 0 ? NumberFormat('#,###').format(totalUbicados) : 'Consultar historial',
                      subtitle: 'Reincorporadas a sus hogares por la PNP',
                      icon: FontAwesomeIcons.circleCheck,
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                      onTap: _navigateToManageFound,
                      isFullWidth: true,
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(isDark ? 0.35 : 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(isDark ? 0.08 : 0.05),
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
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FaIcon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isDark ? Colors.white24 : Colors.black26,
                size: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTacticalCopilotBanner(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF1E1B4B), Color(0xFF0F172A)]
              : const [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(isDark ? 0.15 : 0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _navigateToPoliceAiCopilot,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.robot,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'COPILOTO TÁCTICO IA',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'EN LÍNEA 24/7',
                              style: TextStyle(
                                color: Color(0xFF059669),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Protocolos DL 1428 • Geolocalización Art. 13 • Directorio Operativo',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Color(0xFF6366F1),
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HERRAMIENTAS OPERATIVAS PNP',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final int crossAxisCount = constraints.maxWidth > 750
                ? 4
                : (constraints.maxWidth > 500 ? 3 : 2);
            final double childAspectRatio = constraints.maxWidth > 750
                ? 1.25
                : 1.15;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: childAspectRatio,
              children: [
                _buildActionCard(
                  'Gestionar\nCasos PNP',
                  FontAwesomeIcons.folderOpen,
                  const Color(0xFF0284C7),
                  isDark,
                  _navigateToManageMissing,
                ),
                _buildActionCard(
                  'Personas\nUbicadas',
                  FontAwesomeIcons.circleCheck,
                  const Color(0xFF10B981),
                  isDark,
                  _navigateToManageFound,
                ),
                _buildActionCard(
                  'Copiloto IA\nTáctico',
                  FontAwesomeIcons.robot,
                  const Color(0xFF6366F1),
                  isDark,
                  _navigateToPoliceAiCopilot,
                ),
                _buildActionCard(
                  'Agenda\nPolicial',
                  FontAwesomeIcons.addressBook,
                  const Color(0xFF059669),
                  isDark,
                  _navigateToPoliceAgenda,
                ),
                _buildActionCard(
                  'Directorio\nCEM (MIMP)',
                  FontAwesomeIcons.personDress,
                  const Color(0xFFEC4899),
                  isDark,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DirectorioCemScreen()),
                  ),
                ),
                _buildActionCard(
                  'Transferir\nArchivos',
                  FontAwesomeIcons.fileArrowUp,
                  const Color(0xFFF59E0B),
                  isDark,
                  _navigateToFileTransferTutorials,
                ),
                _buildActionCard(
                  'Biblioteca\nTutoriales',
                  FontAwesomeIcons.bookOpen,
                  const Color(0xFF8B5CF6),
                  isDark,
                  _navigateToTutorials,
                ),
                _buildActionCard(
                  'Gestión\nPolicías',
                  FontAwesomeIcons.userShield,
                  const Color(0xFFD97706),
                  isDark,
                  _navigateToPoliceManagement,
                ),
                _buildActionCard(
                  'Vista\nCiudadano',
                  FontAwesomeIcons.eye,
                  const Color(0xFF06B6D4),
                  isDark,
                  () => PolicePreviewModeService.enterPreviewMode(context),
                ),
                _buildActionCard(
                  'Acerca de',
                  FontAwesomeIcons.circleInfo,
                  const Color(0xFF64748B),
                  isDark,
                  _navigateToAbout,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    bool isDark,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(isDark ? 0.35 : 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: FaIcon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE11D48),
            Color(0xFFBE123C),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        tooltip: 'Registrar Caso Desaparecido PNP',
        onPressed: _navigateToAddCase,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(
          Icons.person_add_alt_1_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildModernBottomBar(bool isDark) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBottomNavItem(
            FontAwesomeIcons.userTie,
            'Perfil',
            true,
            isDark,
            onTap: () => _showProfileMenu(isDark),
          ),
          _buildBottomNavItem(
            FontAwesomeIcons.addressBook,
            'Agenda',
            false,
            isDark,
            onTap: _navigateToPoliceAgenda,
          ),
          const SizedBox(width: 56), // Espacio para FAB
          _buildNotificationBellItem(isDark),
          _buildBottomNavItem(
            FontAwesomeIcons.gear,
            'Config',
            false,
            isDark,
            onTap: () => _showSettingsDialog(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBellItem(bool isDark) {
    final notificationService = PoliceNotificationService();
    final counterService = notificationService.counterService;

    if (counterService == null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _handleNotificationsTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(
                  FontAwesomeIcons.bell,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  size: 18,
                ),
                const SizedBox(height: 3),
                Text(
                  'Alertas',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: counterService.unreadCount,
      builder: (context, unreadCount, child) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _handleNotificationsTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.bell,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        size: 18,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Alertas',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: -6,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE11D48).withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleNotificationsTap() async {
    HapticFeedback.lightImpact();
    _showNotificationsDialog();

    try {
      final counterService = PoliceNotificationService().counterService;
      if (counterService != null) {
        await counterService.markAllAsRead();
      }
    } catch (e) {
      debugPrint('Error al marcar notificaciones como leídas: $e');
    }
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const NotificationCenterDialog(),
    );
  }

  Widget _buildBottomNavItem(
    IconData icon,
    String label,
    bool isActive,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    final activeColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF00796B);
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(
                icon,
                color: isActive ? activeColor : inactiveColor,
                size: 18,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? activeColor : inactiveColor,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Policia?> _getCurrentPoliceInfo() async {
    try {
      final getCurrentPoliciaUseCase = di.getIt<GetCurrentPoliciaUseCase>();
      return await getCurrentPoliciaUseCase();
    } catch (e) {
      debugPrint('Error al obtener información del policía: $e');
      return null;
    }
  }

  void _showProfileMenu(bool isDark) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF004D40), Color(0xFF00796B)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const FaIcon(
                        FontAwesomeIcons.userShield,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'MENÚ POLICIAL PNP',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white70 : Colors.black54,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (FirebaseAuth.instance.currentUser?.email == 'shamirdhc2022@gmail.com') ...[
                  _buildModernMenuOption(
                    icon: FontAwesomeIcons.arrowsRotate,
                    title: 'Centro de Sincronización PNP',
                    subtitle: 'Casos nuevos, ubicados y telemetría en vivo',
                    color: const Color(0xFF0284C7),
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SuperAdminSyncMonitorScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildModernMenuOption(
                    icon: FontAwesomeIcons.chartLine,
                    title: 'Métricas & Reportes SuperAdmin',
                    subtitle: 'Adopción ciudadana y reportes en PDF',
                    color: const Color(0xFF0D9488),
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SuperAdminAnalyticsScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                _buildModernMenuOption(
                  icon: FontAwesomeIcons.userShield,
                  title: 'Gestión de Oficiales',
                  subtitle: 'Administrar credenciales y comisarías',
                  color: const Color(0xFF1E3E62),
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToPoliceManagement();
                  },
                ),
                const SizedBox(height: 10),
                _buildModernMenuOption(
                  icon: FontAwesomeIcons.idCard,
                  title: 'Mi Perfil Institucional',
                  subtitle: 'CIP, rango y datos de servicio',
                  color: const Color(0xFF6B21A8),
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToProfile();
                  },
                ),
                const SizedBox(height: 10),
                _buildModernMenuOption(
                  icon: FontAwesomeIcons.eye,
                  title: 'Modo Vista Ciudadano',
                  subtitle: 'Explorar la app con perfil ciudadano',
                  color: const Color(0xFF0284C7),
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    PolicePreviewModeService.enterPreviewMode(context);
                  },
                ),
                const SizedBox(height: 10),
                _buildModernMenuOption(
                  icon: FontAwesomeIcons.circleInfo,
                  title: 'Acerca del Sistema',
                  subtitle: 'Decreto Legislativo N° 1428 y normativas',
                  color: const Color(0xFF00796B),
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToAbout();
                  },
                ),
                const SizedBox(height: 14),
                Divider(color: isDark ? Colors.white12 : Colors.black12),
                const SizedBox(height: 8),
                _buildModernMenuOption(
                  icon: FontAwesomeIcons.rightFromBracket,
                  title: 'Cerrar Sesión Policial',
                  subtitle: 'Salir del sistema de forma segura',
                  color: const Color(0xFFE11D48),
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog();
                  },
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FaIcon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDestructive
                            ? const Color(0xFFE11D48)
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isDark ? Colors.white24 : Colors.black26,
                size: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog(bool isDark) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.gear,
                      color: Color(0xFF0284C7),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONFIGURACIÓN TÁCTICA',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          'Ajustes del sistema policial',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_active_outlined, color: Color(0xFF10B981), size: 18),
                ),
                title: Text(
                  'Alertas de Casos Urgentes',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Notificación inmediata de menores y N.A. emitidas',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
                trailing: Switch(
                  value: true,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (val) {},
                ),
              ),
              Divider(color: isDark ? Colors.white12 : Colors.black12),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('system_status').doc('sync_pnp').snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final estado = data?['estado'] as String? ?? 'exitoso';
                  final isOnline = estado == 'exitoso';
                  final casosNuevos = data?['casos_nuevos'] ?? 0;
                  final origen = data?['origen'] as String? ?? 'Cloud/Auto';
                  DateTime? fechaSinc;
                  if (data?['ultima_sincronizacion'] is Timestamp) {
                    fechaSinc = (data!['ultima_sincronizacion'] as Timestamp).toDate();
                  }

                  String fechaStr = 'Al día';
                  if (fechaSinc != null) {
                    fechaStr = DateFormat('dd/MM HH:mm').format(fechaSinc.toLocal());
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isOnline
                            ? const Color(0xFF10B981).withOpacity(0.3)
                            : const Color(0xFFE11D48).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: (isOnline ? const Color(0xFF10B981) : const Color(0xFFE11D48)).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.sync,
                                color: isOnline ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sincronización Portal PNP',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Última: $fechaStr | Nuevos: $casosNuevos',
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isOnline ? const Color(0xFF10B981) : const Color(0xFFE11D48)).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isOnline ? 'EN LÍNEA' : 'ERROR',
                                style: TextStyle(
                                  color: isOnline ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Canal: $origen',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Divider(color: isDark ? Colors.white12 : Colors.black12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cleaning_services_outlined, color: Color(0xFFF59E0B), size: 18),
                ),
                title: Text(
                  'Limpiar Caché Local',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Refresca imágenes y fichas descargadas',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Caché táctica optimizada y actualizada'),
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004D40),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout, color: Color(0xFFE11D48)),
              SizedBox(width: 8),
              Text('Cerrar Sesión Policial'),
            ],
          ),
          content: const Text(
            '¿Está seguro de cerrar sesión?\n\nDeberá volver a identificarse con su CIP y credenciales institucionales.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    try {
      PoliceLogoutService.markManualLogout();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      await SessionService.clearUserSession();
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.of(context).pop();
      }

      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }

      Future.delayed(const Duration(seconds: 35), () {
        PoliceLogoutService.resetLogoutFlag();
      });
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
      PoliceLogoutService.resetLogoutFlag();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Error al cerrar sesión. Inténtelo de nuevo.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PoliceProfileScreen()),
    );
  }

  void _navigateToAbout() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AboutPoliceScreen()),
    );
  }

  void _navigateToPoliceAiCopilot() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PoliceAiCopilotScreen(),
      ),
    );
  }

  void _navigateToManageReports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ManageReportsSelectionScreen(),
      ),
    );
  }

  void _navigateToManageMissing() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (context) => di.locator<PoliceManageMissingViewModel>(),
          child: const PoliceManageMissingScreen(),
        ),
      ),
    );
  }

  void _navigateToManageFound() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (context) => di.locator<ManageFoundViewModel>(),
          child: const ManageFoundScreen(),
        ),
      ),
    );
  }

  void _navigateToAddCase() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReportDesaparecidoScreen(),
      ),
    );
  }

  void _navigateToTutorials() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TutorialLibraryScreen()),
    );
  }

  void _navigateToPoliceManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (context) => di.getIt<PoliciaManagementViewModel>(),
          child: const PoliciaManagementScreen(),
        ),
      ),
    );
  }

  void _navigateToPoliceAgenda() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PoliceAgendaScreen()),
    );
  }

  void _navigateToFileTransferTutorials() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TutorialMainScreen()),
    );
  }
}
