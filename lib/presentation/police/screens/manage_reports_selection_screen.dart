import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../view_models/manage_missing_view_model.dart';
import '../view_models/manage_found_view_model.dart';
import '../view_models/police_manage_missing_view_model.dart';
import '../../../domain/use_cases/obtener_desaparecidos_use_case.dart';
import '../../../domain/use_cases/marcar_como_encontrado_use_case.dart';
import '../../../domain/use_cases/get_missing_cases_usecase.dart';
import '../../../domain/use_cases/mark_case_as_found_usecase.dart';
import '../../../data/repositories/desaparecido_repository_impl.dart';
import '../../../data/data_sources/desaparecido_remote_data_source.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'manage_missing_screen.dart';
import 'manage_found_screen.dart';
import 'police_manage_missing_screen.dart';

class ManageReportsSelectionScreen extends StatefulWidget {
  const ManageReportsSelectionScreen({super.key});

  @override
  State<ManageReportsSelectionScreen> createState() =>
      _ManageReportsSelectionScreenState();
}

class _ManageReportsSelectionScreenState
    extends State<ManageReportsSelectionScreen>
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
    return Scaffold(
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
                    child: _buildSelectionContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
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
                FontAwesomeIcons.arrowLeft,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GESTIÓN DE REPORTES',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Text(
                  'Seleccione el tipo de gestión',
                  style: TextStyle(
                    color: Color(0xFF778DA9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const FaIcon(
              FontAwesomeIcons.folderOpen,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Título principal
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                const FaIcon(
                  FontAwesomeIcons.clipboardList,
                  color: Color(0xFF778DA9),
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'CENTRO DE GESTIÓN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Herramientas profesionales para la gestión policial de casos',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Opciones de gestión
          Expanded(
            child: Column(
              children: [
                _buildManagementOption(
                  title: 'GESTIONAR\nDESAPARECIDOS',
                  subtitle: 'Control y seguimiento de casos activos',
                  icon: FontAwesomeIcons.userMinus,
                  color: const Color(0xFFE74C3C),
                  onTap: () => _navigateToManageMissing(),
                ),

                const SizedBox(height: 20),

                _buildManagementOption(
                  title: 'GESTIONAR\nENCONTRADOS',
                  subtitle: 'Administración de casos resueltos',
                  icon: FontAwesomeIcons.userCheck,
                  color: const Color(0xFF27AE60),
                  onTap: () => _navigateToManageFound(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Información adicional
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF457B9D).withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: const Color(0xFF457B9D).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const FaIcon(
                  FontAwesomeIcons.infoCircle,
                  color: Color(0xFF457B9D),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Acceso a herramientas especializadas para la gestión policial de casos',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: FaIcon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const FaIcon(
              FontAwesomeIcons.chevronRight,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToManageMissing() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => ChangeNotifierProvider(
              create:
                  (context) => PoliceManageMissingViewModel(
                    getMissingCasesUseCase: GetMissingCasesUseCase(
                      DesaparecidoRepositoryImpl(
                        DesaparecidoRemoteDataSource(
                          FirebaseFirestore.instance,
                          FirebaseStorage.instance,
                        ),
                      ),
                    ),
                    markCaseAsFoundUseCase: MarkCaseAsFoundUseCase(
                      DesaparecidoRepositoryImpl(
                        DesaparecidoRemoteDataSource(
                          FirebaseFirestore.instance,
                          FirebaseStorage.instance,
                        ),
                      ),
                    ),
                  ),
              child: const PoliceManageMissingScreen(),
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _navigateToManageFound() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChangeNotifierProvider(
              create:
                  (context) => ManageFoundViewModel(
                    ObtenerDesaparecidosUseCase(
                      DesaparecidoRepositoryImpl(
                        DesaparecidoRemoteDataSource(
                          FirebaseFirestore.instance,
                          FirebaseStorage.instance,
                        ),
                      ),
                    ),
                  ),
              child: const ManageFoundScreen(),
            ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}
