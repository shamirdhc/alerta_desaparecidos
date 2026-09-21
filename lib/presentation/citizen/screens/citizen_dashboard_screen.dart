import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/session_service.dart';
import '../../../common/styles/app_colors.dart';

class CitizenDashboardScreen extends StatefulWidget {
  final Function(int) onNavigateToModule;

  const CitizenDashboardScreen({super.key, required this.onNavigateToModule});

  @override
  State<CitizenDashboardScreen> createState() => _CitizenDashboardScreenState();
}

class _CitizenDashboardScreenState extends State<CitizenDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late AnimationController _cardsAnimationController;
  late Animation<double> _headerAnimation;
  late Animation<double> _cardsAnimation;

  String _userName = '';
  String _userPhone = '';
  bool _isLoadingUserData = true;

  // 🏛️ Lista estructurada de módulos de alta gama
  final List<DashboardModule> _modules = [
    DashboardModule(
      title: 'Personas\nDesaparecidas',
      subtitle: 'Ver casos activos',
      icon: FontAwesomeIcons.userMinus,
      color: const Color(0xFFE11D48), // Crimson Urgencia
      badgeText: 'Alerta PNP',
      index: 0,
    ),
    DashboardModule(
      title: 'Personas\nEncontradas',
      subtitle: 'Casos resueltos',
      icon: FontAwesomeIcons.userCheck,
      color: const Color(0xFF10B981), // Verde Esperanza
      badgeText: 'Localizados',
      index: 1,
    ),
    DashboardModule(
      title: 'Reportar\nDesaparición',
      subtitle: 'Nuevo reporte',
      icon: FontAwesomeIcons.triangleExclamation,
      color: const Color(0xFFF59E0B), // Oro Amber
      badgeText: 'Ciudadano',
      index: 2,
    ),
    DashboardModule(
      title: 'Buscar Mi\nComisaría',
      subtitle: 'Ubicar dependencias',
      icon: FontAwesomeIcons.locationDot,
      color: const Color(0xFF0284C7), // Sky Blue
      badgeText: 'GPS',
      index: 3,
    ),
    DashboardModule(
      title: 'Agenda de\nComisarías',
      subtitle: 'Directorio nacional',
      icon: FontAwesomeIcons.addressBook,
      color: const Color(0xFF6366F1), // Indigo
      badgeText: 'Oficial',
      index: 5,
    ),
    DashboardModule(
      title: 'Guías\nEducativas',
      subtitle: 'Alerta Amber y tips',
      icon: FontAwesomeIcons.graduationCap,
      color: const Color(0xFF0D9488), // Teal
      badgeText: 'Educativo',
      index: 6,
    ),
    DashboardModule(
      title: 'Bandeja de\nSugerencias',
      subtitle: 'Canal de feedback',
      icon: FontAwesomeIcons.lightbulb,
      color: const Color(0xFF8B5CF6), // Violet
      badgeText: 'Comunidad',
      index: 4,
    ),
    DashboardModule(
      title: 'Acerca del\nSistema',
      subtitle: 'Alerta PNP v2.0',
      icon: FontAwesomeIcons.circleInfo,
      color: const Color(0xFF475569), // Slate
      badgeText: 'Info',
      index: 7,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
  }

  void _initializeAnimations() {
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _cardsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _headerAnimation = CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
    );

    _cardsAnimation = CurvedAnimation(
      parent: _cardsAnimationController,
      curve: Curves.easeOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headerAnimationController.forward();
      _cardsAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _cardsAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final session = await SessionService.getUserSession();
      if (session != null && session['name'] != null && session['name'] != 'Usuario') {
        if (mounted) {
          setState(() {
            _userName = session['name'];
            _userPhone = session['phoneNumber'] ?? 'Teléfono vinculado';
            _isLoadingUserData = false;
          });
        }
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final phoneNumber = user.phoneNumber ?? 'Teléfono vinculado';

        final userDoc = await FirebaseFirestore.instance
            .collection('ciudadanos')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final nombres = userData['nombres'] ?? '';
          final apellidos = userData['apellidos'] ?? '';
          final fullName = '$nombres $apellidos'.trim();

          if (mounted) {
            setState(() {
              _userName = fullName.isNotEmpty ? fullName : (user.displayName ?? 'Ciudadano');
              _userPhone = phoneNumber;
              _isLoadingUserData = false;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _userName = session?['name'] ?? 'Ciudadano';
          _userPhone = session?['phoneNumber'] ?? 'Alerta PNP';
          _isLoadingUserData = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _userName = 'Ciudadano';
          _userPhone = 'Alerta PNP';
          _isLoadingUserData = false;
        });
      }
    }
  }

  Future<void> _callCentral114() async {
    final uri = Uri.parse('tel:114');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Línea gratuita 114 PNP disponible en teléfonos móviles.')),
          );
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundColor,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🏛️ Header Ejecutivo de Alta Seguridad
              _buildExecutiveHeader(),

              const SizedBox(height: 18),

              // 🚨 Cinta de Acción Inmediata (Central 114 + Pistas)
              _buildEmergencyQuickActionBanner(),

              const SizedBox(height: 22),

              // 📊 Sección de Módulos Operativos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SERVICIOS Y CONSULTAS',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '8 Módulos',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 🔲 Grid Moderno de Módulos
              _buildModulesGrid(),

              const SizedBox(height: 24),

              // 🛡️ Footer Institucional
              _buildInstitutionalFooter(),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveHeader() {
    return FadeTransition(
      opacity: _headerAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.policeHeroGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryColor.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge superior: Red activa
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Red Nacional Activa',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                // Escudo PNP
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.accentColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    FontAwesomeIcons.shieldHalved,
                    color: AppColors.accentColor,
                    size: 16,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Perfil de usuario
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentColor,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoadingUserData ? 'Cargando perfil...' : 'Bienvenido/a,',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 13,
                            color: AppColors.accentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _userPhone,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyQuickActionBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.phone_in_talk_rounded,
              color: Color(0xFFB45309),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Central 114 PNP',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Línea de emergencia y personas desaparecidas',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _callCentral114,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB45309),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Llamar',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModulesGrid() {
    return FadeTransition(
      opacity: _cardsAnimation,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.05,
        ),
        itemCount: _modules.length,
        itemBuilder: (context, index) {
          final module = _modules[index];
          return _buildModernModuleCard(module);
        },
      ),
    );
  }

  Widget _buildModernModuleCard(DashboardModule module) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => widget.onNavigateToModule(module.index),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderSubtle, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Icon badge + Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: module.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      module.icon,
                      color: module.color,
                      size: 20,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      module.badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: module.color,
                      ),
                    ),
                  ),
                ],
              ),

              // Title & Subtitle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    module.subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              // Bottom arrow micro-indicator
              Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: module.color.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstitutionalFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              FontAwesomeIcons.shieldHalved,
              color: AppColors.primaryColorLight,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Policía Nacional del Perú',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryColor,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Dirección Contra la Trata de Personas y Tráfico Ilícito de Migrantes • DEPITPTIM',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardModule {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String badgeText;
  final int index;

  DashboardModule({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.badgeText,
    required this.index,
  });
}
