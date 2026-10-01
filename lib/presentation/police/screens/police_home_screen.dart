import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:provider/provider.dart';
import '../../../domain/use_cases/policia_management_use_cases.dart';
import '../../../domain/entities/policia.dart';
import 'manage_reports_selection_screen.dart';
// Import para la pantalla de reporte de desaparecido
import 'report_desaparecido_screen.dart';
import 'package:alerta_desaparecidos/services/session_service.dart';
import 'package:alerta_desaparecidos/presentation/screens/welcome_screen.dart';
import 'package:alerta_desaparecidos/services/logout_service.dart';
// Imports para gestión de policías
import 'policia_management_screen.dart';
import '../view_models/policia_management_view_model.dart';
import '../../../injection.dart' as di;
// Import para el módulo de tutoriales
import 'tutorial_library_screen.dart';
// Import para tutoriales de transferencia de archivos
import 'tutorials/tutorial_main_screen.dart';
// Import para la agenda policial
import 'police_agenda_screen.dart';
import '../../citizen/screens/directorio_cem_screen.dart';
import '../../common_widgets/theme_sun_moon_toggle.dart';
// Import para la pantalla "Acerca de"
import 'about_police_screen.dart';
// Import para la pantalla de perfil
import 'police_profile_screen.dart';
import 'police_ai_copilot_screen.dart';
import '../../superadmin/screens/superadmin_sync_monitor_screen.dart';
import '../../superadmin/screens/superadmin_analytics_screen.dart';
import 'dart:ui';
// Import para el servicio de notificaciones policiales
import 'package:alerta_desaparecidos/services/police_notification_service.dart';
// Import para el servicio de logout específico de policía
import 'package:alerta_desaparecidos/services/police_logout_service.dart';
// Import para el diálogo del centro de notificaciones
import '../widgets/notification_center_dialog.dart';
import '../../../common/styles/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
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
  Widget build(BuildContext context) {
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
              backgroundColor: const Color(0xFF1B263B),
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
        backgroundColor: const Color(0xFF0D1B2A),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF415A77)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.6, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildModernAppBar(),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildDashboardContent(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: _buildFloatingActionButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _buildModernBottomBar(),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF415A77), Color(0xFF778DA9)],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const FaIcon(
              FontAwesomeIcons.shield,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedTextKit(
                  animatedTexts: [
                    TypewriterAnimatedText(
                      'COMANDO POLICIAL',
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                      speed: const Duration(milliseconds: 100),
                    ),
                  ],
                  totalRepeatCount: 1,
                ),
                const Text(
                  'Sistema de Gestión Avanzada',
                  style: TextStyle(
                    color: Color(0xFF778DA9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const ThemeSunMoonToggle(),
          _buildProfileButton(),
        ],
      ),
    );
  }

  Widget _buildProfileButton() {
    return GestureDetector(
      onTap: () => _showProfileMenu(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: const FaIcon(
          FontAwesomeIcons.userTie,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildSuperAdminSyncHeroBanner(),
              _buildStatsCards(),
              const SizedBox(height: 20),
              _buildTacticalCopilotBanner(),
              const SizedBox(height: 25),
              _buildQuickActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuperAdminSyncHeroBanner() {
    final userEmail = (FirebaseAuth.instance.currentUser?.email ?? '').trim().toLowerCase();
    final isSuperEmail = userEmail == 'shamirdhc2022@gmail.com';

    return FutureBuilder<Policia?>(
      future: _getCurrentPoliceInfo(),
      builder: (context, snapshot) {
        final pol = snapshot.data;
        final shouldShow = isSuperEmail || pol?.rol == 'superadmin';
        if (!shouldShow) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0B132B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFFFD700).withOpacity(0.7),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.bolt_rounded, color: Colors.black, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFFD700), width: 1),
                              ),
                              child: const Text(
                                '⚡ CONTROL EXCLUSIVO SUPERADMIN PNP',
                                style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Sincronización Total del Portal PNP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Descarga los casos nuevos del portal policial, concilia automáticamente a las personas que ya fueron ubicadas y genera el registro de auditoría en tiempo real con animación en vivo.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SuperAdminSyncMonitorScreen()),
                          );
                        },
                        icon: const Icon(Icons.rocket_launch_rounded, color: Colors.black, size: 20),
                        label: const Text(
                          'HACER TODO EL TRABAJO AHORA',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SuperAdminSyncMonitorScreen()),
                          );
                        },
                        icon: const Icon(Icons.history_edu_rounded, color: Color(0xFF38BDF8), size: 18),
                        label: const Text(
                          'Ver Bitácora & Telemetría',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTacticalCopilotBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.2),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _navigateToPoliceAiCopilot,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.robot,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'COPILOTO TÁCTICO IA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF10B981),
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              'EN LÍNEA 24/7',
                              style: TextStyle(
                                color: Color(0xFF34D399),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Protocolos DL 1428 • Geolocalización Art. 13 • Directorio Operativo de Comisarías',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Color(0xFF818CF8),
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return _buildPoliceInfoCard();
  }

  Widget _buildPoliceInfoCard() {
    return FutureBuilder<Policia?>(
      future: _getCurrentPoliceInfo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        }

        final policia = snapshot.data;
        if (policia == null) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: const Center(
              child: Text(
                'Error al cargar información',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1B998B).withOpacity(0.8),
                const Color(0xFF2D5016).withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B998B).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
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
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.userTie,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INFORMACIÓN DEL OFICIAL',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          policia.nombreCompleto,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (policia.rol == 'superadmin')
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SuperAdminSyncMonitorScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.workspace_premium, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'SUPERADMIN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (policia.admin)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      'Rango',
                      policia.rango,
                      FontAwesomeIcons.medal,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildInfoItem(
                      'CIP',
                      policia.numeroCip,
                      FontAwesomeIcons.idCard,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      'Unidad',
                      policia.unidad,
                      FontAwesomeIcons.building,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildInfoItem(
                      'Departamento',
                      policia.departamento,
                      FontAwesomeIcons.mapMarkerAlt,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 15),
              InkWell(
                onTap: () => PolicePreviewModeService.enterPreviewMode(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF06B6D4).withOpacity(0.5),
                      width: 1.2,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(FontAwesomeIcons.eye, color: Color(0xFF06B6D4), size: 14),
                      SizedBox(width: 8),
                      Text(
                        'Modo Vista: Ver como Ciudadano',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF06B6D4), size: 12),
                    ],
                  ),
                ),
              ),
],
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(icon, color: Colors.white.withOpacity(0.7), size: 12),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
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

  Future<Policia?> _getCurrentPoliceInfo() async {
    try {
      final getCurrentPoliciaUseCase = di.getIt<GetCurrentPoliciaUseCase>();
      return await getCurrentPoliciaUseCase();
    } catch (e) {
      print('Error al obtener información del policía: $e');
      return null;
    }
  }


  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACCIONES RÁPIDAS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 15),
        LayoutBuilder(
          builder: (context, constraints) {
            final int crossAxisCount = constraints.maxWidth > 700
                ? 4
                : (constraints.maxWidth > 500 ? 3 : 2);
            final double childAspectRatio = constraints.maxWidth > 700
                ? 1.25
                : 1.2;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: childAspectRatio,
              children: [
            _buildActionCard(
              'Copiloto IA\nTáctico',
              FontAwesomeIcons.robot,
              const Color(0xFF6366F1),
              () => _navigateToPoliceAiCopilot(),
            ),
            _buildActionCard(
              'Gestionar\nReportes',
              FontAwesomeIcons.folderOpen,
              const Color(0xFF38BDF8),
              () => _navigateToManageReports(),
            ),
            _buildActionCard(
              'Transferir\nArchivos',
              FontAwesomeIcons.fileArrowUp,
              AppColors.accentColor,
              () => _navigateToFileTransferTutorials(),
            ),
            _buildActionCard(
              'Agenda\nPolicial',
              FontAwesomeIcons.addressBook,
              const Color(0xFF34D399),
              () => _navigateToPoliceAgenda(),
            ),
            _buildActionCard(
              'Directorio\nCEM (MIMP)',
              FontAwesomeIcons.personDress,
              const Color(0xFFEC4899),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DirectorioCemScreen()),
              ),
            ),
            _buildActionCard(
              'Biblioteca\nTutoriales',
              FontAwesomeIcons.bookOpen,
              const Color(0xFFA78BFA),
              () => _navigateToTutorials(),
            ),
            _buildActionCard(
              'Gestión\nPolicías',
              FontAwesomeIcons.userShield,
              const Color(0xFFFBBF24),
              () => _navigateToPoliceManagement(),
            ),
            _buildActionCard(
              'Vista\nCiudadano',
              FontAwesomeIcons.eye,
              const Color(0xFF06B6D4),
              () => PolicePreviewModeService.enterPreviewMode(context),
            ),
            _buildActionCard(
              'Acerca de',
              FontAwesomeIcons.infoCircle,
              const Color(0xFF94A3B8),
              () => _navigateToAbout(),
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
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withOpacity(0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 12,
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
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: FaIcon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFloatingActionButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE63946), // Rojo más preocupante
            Color(0xFFDC2626),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE63946).withOpacity(0.5),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: FloatingActionButton(
        tooltip: 'Registrar Desaparecido',
        onPressed: () => _navigateToAddCase(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(
          Icons.person_add_alt_1_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildModernBottomBar() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
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
            onTap: () => _showProfileMenu(),
          ),
          _buildBottomNavItem(
            FontAwesomeIcons.addressBook,
            'Agenda',
            false,
            onTap: () => _navigateToPoliceAgenda(),
          ),
          const SizedBox(width: 60), // Espacio para FAB
          _buildNotificationBellItem(),
          _buildBottomNavItem(
            FontAwesomeIcons.cog,
            'Config',
            false,
            onTap: () => _showSettingsDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBellItem() {
    final notificationService = PoliceNotificationService();
    final counterService = notificationService.counterService;
    
    // Si counterService es null, mostrar 0 notificaciones
    if (counterService == null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleNotificationsTap(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(
                  FontAwesomeIcons.bell,
                  color: Colors.white.withOpacity(0.5),
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  'Alertas',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
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
            onTap: () => _handleNotificationsTap(),
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
                        color: Colors.white.withOpacity(0.5),
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Alertas',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
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
                          color: const Color(0xFFE63946),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE63946).withOpacity(0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
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
    // Mostrar feedback inmediato
    HapticFeedback.lightImpact();

    // Mostrar el diálogo inmediatamente
    _showNotificationsDialog();

    // Marcar como leídas en segundo plano con verificación de null safety
    try {
      final counterService = PoliceNotificationService().counterService;
      if (counterService != null) {
        await counterService.markAllAsRead();
      } else {
        print('⚠️ Counter service no está disponible');
      }
    } catch (e) {
      print('Error al marcar notificaciones como leídas: $e');
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
    bool isActive, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(
            icon,
            color:
                isActive
                    ? const Color(0xFF778DA9)
                    : Colors.white.withOpacity(0.5),
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color:
                  isActive
                      ? const Color(0xFF778DA9)
                      : Colors.white.withOpacity(0.5),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Métodos de navegación y funcionalidad
  void _showProfileMenu() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0D1B2A).withOpacity(0.9),
                          const Color(0xFF1B263B).withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header del diálogo
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1B998B),
                                    Color(0xFF2D5016),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const FaIcon(
                                FontAwesomeIcons.userTie,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 15),
                            const Expanded(
                              child: Text(
                                'MENÚ POLICIAL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const FaIcon(
                                  FontAwesomeIcons.xmark,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),

                        // Opciones del menú
                        if (FirebaseAuth.instance.currentUser?.email == 'shamirdhc2022@gmail.com') ...[
                          _buildModernMenuOption(
                            icon: FontAwesomeIcons.arrowsRotate,
                            title: 'Centro de Sincronización PNP',
                            subtitle: 'Casos nuevos, ubicados y telemetría en vivo',
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0284C7), Color(0xFF0F172A)],
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SuperAdminSyncMonitorScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 15),
                          _buildModernMenuOption(
                            icon: FontAwesomeIcons.chartLine,
                            title: 'Métricas & Reportes SuperAdmin',
                            subtitle: 'Adopción ciudadana y reportes en PDF',
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0D9488), Color(0xFF134E4A)],
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SuperAdminAnalyticsScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 15),
                        ],

                        _buildModernMenuOption(
                          icon: FontAwesomeIcons.userShield,
                          title: 'Gestión de Cuentas',
                          subtitle: 'Administrar cuentas de policías',
                          gradient: const LinearGradient(
                            colors: [Color(0xFF457B9D), Color(0xFF1D3557)],
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _navigateToPoliceManagement();
                          },
                        ),
                        const SizedBox(height: 15),

                        _buildModernMenuOption(
                          icon: FontAwesomeIcons.idCard,
                          title: 'Mi Perfil',
                          subtitle: 'Ver y editar información personal',
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8E44AD), Color(0xFF6A4C93)],
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _navigateToProfile();
                          },
                        ),
                        const SizedBox(height: 15),

                        _buildModernMenuOption(
                          icon: FontAwesomeIcons.eye,
                          title: 'Modo Vista Ciudadano',
                          subtitle: 'Explorar la app tal como la ve un ciudadano',
                          gradient: const LinearGradient(
                            colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            PolicePreviewModeService.enterPreviewMode(context);
                          },
                        ),
                        const SizedBox(height: 15),

                        _buildModernMenuOption(
                          icon: FontAwesomeIcons.circleInfo,
                          title: 'Acerca del Sistema',
                          subtitle: 'Información y características',
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1B998B), Color(0xFF2D5016)],
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _navigateToAbout();
                          },
                        ),
                        const SizedBox(height: 20),

                        // Separador
                        Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        _buildModernMenuOption(
                          icon: FontAwesomeIcons.rightFromBracket,
                          title: 'Cerrar Sesión',
                          subtitle: 'Salir del sistema de forma segura',
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE63946), Color(0xFFDC2626)],
                          ),
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
            ),
          ),
    );
  }

  Widget _buildModernMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: gradient.colors.first.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FaIcon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive ? Colors.red.shade300 : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FaIcon(
                FontAwesomeIcons.chevronRight,
                color: Colors.white.withOpacity(0.6),
                size: 12,
              ),
            ),
          ],
        ),
      ),
    );
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
        builder:
            (context) => ChangeNotifierProvider(
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

  void _showSettingsDialog() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
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
                      color: const Color(0xFF38BDF8).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.gear,
                      color: Color(0xFF38BDF8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONFIGURACIÓN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          'Preferencias operativas y del sistema',
                          style: TextStyle(
                            color: Color(0xFF778DA9),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_active_outlined, color: Color(0xFF34D399), size: 20),
                ),
                title: const Text('Notificaciones Prioritarias', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Alertas inmediatas de menores y casos urgentes', style: TextStyle(color: Colors.white60, fontSize: 11)),
                trailing: Switch(
                  value: true,
                  activeColor: const Color(0xFF34D399),
                  onChanged: (val) {},
                ),
              ),
              const Divider(color: Colors.white12),
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
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isOnline ? const Color(0xFF34D399).withOpacity(0.3) : const Color(0xFFF87171).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isOnline ? const Color(0xFF34D399) : const Color(0xFFF87171)).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.sync, color: isOnline ? const Color(0xFF34D399) : const Color(0xFFF87171), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Sincronización PNP', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  Text(
                                    'Última: $fechaStr | Nuevos: $casosNuevos',
                                    style: const TextStyle(color: Color(0xFF778DA9), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isOnline ? const Color(0xFF34D399) : const Color(0xFFF87171)).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isOnline ? 'EN LÍNEA' : 'ERROR',
                                style: TextStyle(
                                  color: isOnline ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Canal: $origen',
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                            InkWell(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Row(
                                      children: [
                                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                        SizedBox(width: 12),
                                        Expanded(child: Text('Verificando casos PNP en tiempo real...')),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFF1B263B),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.refresh, color: Color(0xFF38BDF8), size: 14),
                                    SizedBox(width: 4),
                                    Text('Verificar', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cleaning_services_outlined, color: Color(0xFFFBBF24), size: 20),
                ),
                title: const Text('Limpiar Caché Local', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Refresca imágenes e historial descargado', style: TextStyle(color: Colors.white60, fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Caché local optimizada y actualizada'),
                      backgroundColor: const Color(0xFF1B263B),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF415A77),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cerrar'),
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
      barrierDismissible: false, // Prevenir cierre accidental
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red.shade600),
              const SizedBox(width: 8),
              const Text('Cerrar Sesión'),
            ],
          ),
          content: const Text(
            '¿Estás seguro de que quieres cerrar sesión?\n\nEsto te llevará de vuelta a la pantalla de bienvenida.',
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
                Navigator.of(context).pop(); // Cerrar diálogo primero
                await _performLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
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
      // NUEVO: Marcar que es un logout manual usando el servicio específico de policía
      PoliceLogoutService.markManualLogout();

      // Mostrar indicador de carga
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      // Limpiar sesión usando SessionService (método consistente)
      await SessionService.clearUserSession();

      // Cerrar sesión de Firebase
      await FirebaseAuth.instance.signOut();

      // Cerrar indicador de carga si está montado
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Esperar un momento antes de navegar para asegurar que el logout se complete
      await Future.delayed(const Duration(milliseconds: 500));

      // Navegar a la pantalla de bienvenida usando pushAndRemoveUntil con MaterialPageRoute
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }

      // NUEVO: Resetear el flag después de la navegación
      // MODIFICADO: Extender el delay a 35 segundos para cubrir el timeout de SMS
      Future.delayed(const Duration(seconds: 35), () {
        PoliceLogoutService.resetLogoutFlag();
        print(
          '🔄 [POLICE-LOGOUT] Flag reseteado después del logout (35s delay)',
        );
      });
    } catch (e) {
      print('Error al cerrar sesión: $e');

      // NUEVO: Resetear flag en caso de error
      PoliceLogoutService.resetLogoutFlag();

      // Cerrar indicador de carga si está abierto
      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Error al cerrar sesión. Inténtalo de nuevo.'),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
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

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}

