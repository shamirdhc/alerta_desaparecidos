import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:provider/provider.dart';
import '../view_models/manage_missing_view_model.dart';
import '../view_models/add_missing_view_model.dart';
import '../../../domain/use_cases/obtener_desaparecidos_use_case.dart';
import '../../../domain/use_cases/reportar_desaparicion_use_case.dart';
import '../../../domain/use_cases/policia_management_use_cases.dart';
import '../../../domain/entities/policia.dart';
import '../../../data/repositories/desaparecido_repository_impl.dart';
import '../../../data/data_sources/desaparecido_remote_data_source.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'add_missing_screen.dart';
import 'manage_missing_screen.dart';
import 'manage_reports_selection_screen.dart';
// Import para la pantalla de reporte de desaparecido
import 'report_desaparecido_screen.dart';
import '../view_models/report_desaparecido_view_model.dart';
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
// Import para la pantalla "Acerca de"
import 'about_police_screen.dart';
// Import para la pantalla de perfil
import 'police_profile_screen.dart';
import 'dart:ui';

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
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false; // Deshabilitar navegación del sistema
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildStatsCards(),
          const SizedBox(height: 25),
          _buildQuickActions(),
        ],
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
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
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
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
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
                  if (policia.admin)
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
              FaIcon(
                icon,
                color: Colors.white.withOpacity(0.7),
                size: 12,
              ),
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

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: FaIcon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: 1.2,
          children: [
            _buildActionCard(
              'Gestionar\nReportes',
              FontAwesomeIcons.folderOpen,
              const Color(0xFF457B9D),
              () => _navigateToManageReports(),
            ),
            _buildActionCard(
              'Transferir\nArchivos',
              FontAwesomeIcons.fileArrowUp,
              const Color(0xFFFF6B35),
              () => _navigateToFileTransferTutorials(),
            ),
            _buildActionCard(
              'Agenda\nPolicial',
              FontAwesomeIcons.addressBook,
              const Color(0xFF8E44AD),
              () => _navigateToPoliceAgenda(),
            ),
            _buildActionCard(
              'Biblioteca\nTutoriales',
              FontAwesomeIcons.bookOpen,
              const Color(0xFF6A4C93),
              () => _navigateToTutorials(),
            ),
            _buildActionCard(
              'Gestión\nPolicías',
              FontAwesomeIcons.userShield,
              const Color(0xFF1B998B),
              () => _navigateToPoliceManagement(),
            ),
            _buildActionCard(
              'Acerca de',
              FontAwesomeIcons.infoCircle,
              const Color(0xFF17A2B8),
              () => _navigateToAbout(),
            ),
          ],
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
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACTIVIDAD RECIENTE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 15),
          _buildActivityItem(
            'Nuevo caso reportado',
            'Hace 2 horas',
            FontAwesomeIcons.plus,
            const Color(0xFFFF6B35),
          ),
          _buildActivityItem(
            'Persona encontrada',
            'Hace 4 horas',
            FontAwesomeIcons.checkCircle,
            const Color(0xFF2D5016),
          ),
          _buildActivityItem(
            'Actualización de caso',
            'Hace 6 horas',
            FontAwesomeIcons.edit,
            const Color(0xFF457B9D),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        onPressed: () => _navigateToAddCase(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const FaIcon(
          FontAwesomeIcons.triangleExclamation, // Ícono más preocupante
          color: Colors.white,
          size: 26,
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
          _buildBottomNavItem(FontAwesomeIcons.bell, 'Alertas', false),
          _buildBottomNavItem(FontAwesomeIcons.cog, 'Config', false),
        ],
      ),
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
      builder: (context) => Dialog(
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
                              colors: [Color(0xFF1B998B), Color(0xFF2D5016)],
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
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
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
              child: FaIcon(
                icon,
                color: Colors.white,
                size: 18,
              ),
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
      MaterialPageRoute(
        builder: (context) => const PoliceProfileScreen(),
      ),
    );
  }

  void _navigateToAbout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AboutPoliceScreen(),
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
        builder: (context) => ChangeNotifierProvider(
          create: (context) => ReportDesaparecidoViewModel(
            ReportarDesaparicionUseCase(
              DesaparecidoRepositoryImpl(
                DesaparecidoRemoteDataSource(
                  FirebaseFirestore.instance,
                  FirebaseStorage.instance,
                ),
              ),
            ),
          ),
          child: const ReportDesaparecidoScreen(),
        ),
      ),
    );
  }

  void _navigateToSearch() {
    // Implementar navegación a búsqueda avanzada
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Búsqueda avanzada en desarrollo')),
    );
  }

  void _navigateToReports() {
    // Implementar navegación a reportes estadísticos
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reportes estadísticos en desarrollo')),
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
