import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/session_service.dart';
import 'package:alerta_desaparecidos/services/police_preview_mode_service.dart';
import '../../../common/styles/app_colors.dart';
import '../../../common/localization/app_strings.dart';
import '../../common_widgets/glass_container.dart';

import '../widgets/sos_dialog.dart';

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

  // 🏛️ Lista estructurada y agrupada de módulos de alta gama y uso cotidiano
  List<DashboardModule> _getModules(AppStrings s) => [
    DashboardModule(
      title: s.isQuechua ? 'Chinkasqa\nRunakuna' : 'Personas\nDesaparecidas',
      subtitle: s.isQuechua ? 'Kunan kasqankuna' : 'Ver casos activos',
      icon: FontAwesomeIcons.userMinus,
      color: const Color(0xFFE11D48), // Crimson Urgencia
      badgeText: s.isQuechua ? 'Urgente' : 'Alertas',
      index: 0,
    ),
    DashboardModule(
      title: s.isQuechua ? 'Tarisqa\nRunakuna' : 'Personas\nEncontradas',
      subtitle: s.isQuechua ? 'Allinllaña kasqanku' : 'Casos resueltos',
      icon: FontAwesomeIcons.userCheck,
      color: const Color(0xFF10B981), // Verde Esperanza
      badgeText: s.isQuechua ? 'Tarisqakuna' : 'Localizados',
      index: 1,
    ),
    DashboardModule(
      title: s.isQuechua ? 'Yachay\nGuíakuna' : 'Guías\nEducativas',
      subtitle: s.isQuechua ? 'Videos yachaykuna' : 'Academia y Videos PNP',
      icon: FontAwesomeIcons.graduationCap,
      color: const Color(0xFF0D9488), // Teal académico
      badgeText: s.isQuechua ? 'Yachay' : 'Videos y Guías',
      index: 2,
    ),
    DashboardModule(
      title: s.isQuechua ? 'Ayllu\nWaqaychay' : 'Mi Familia\nSegura',
      subtitle: s.isQuechua ? 'Wawakuna waqaychay' : 'Kit digital hijos',
      icon: FontAwesomeIcons.peopleRoof,
      color: const Color(0xFFEC4899), // Rose / Magenta
      badgeText: 'Kit Digital',
      index: 3,
    ),
    DashboardModule(
      title: s.isQuechua ? 'App Kamachiypaq\nYachay' : 'Domina tu App\n(Inducción)',
      subtitle: s.isQuechua ? 'Mosoq yachaykuna' : 'Academia y Retos',
      icon: FontAwesomeIcons.rocket,
      color: const Color(0xFF0284C7), // Sky Blue
      badgeText: 'Inducción 🚀',
      index: 4,
    ),
    DashboardModule(
      title: s.isQuechua ? 'Yanapakuy\nHuñu 360°' : 'Central Auxilio\ny Directorios',
      subtitle: s.isQuechua ? 'Kumisariya • CEM' : 'Comisarías • CEM • SOS',
      icon: FontAwesomeIcons.hospitalUser,
      color: const Color(0xFF6366F1), // Indigo
      badgeText: '360°',
      index: 5,
    ),
    DashboardModule(
      title: s.isQuechua ? 'Yuyaychaykuna\nBandeja' : 'Bandeja de\nSugerencias',
      subtitle: s.isQuechua ? 'Willawayku' : 'Canal de feedback',
      icon: FontAwesomeIcons.lightbulb,
      color: const Color(0xFF8B5CF6), // Violet
      badgeText: s.isQuechua ? 'Llaqta' : 'Comunidad',
      index: 6,
    ),
    DashboardModule(
      title: s.isQuechua ? 'Sistemamanta\nWillay' : 'Acerca de la\nPlataforma',
      subtitle: 'Iniciativa Ciudadana',
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
    if (PolicePreviewModeService.isPreviewActive) {
      if (mounted) {
        setState(() {
          _userName = 'Comando Policial (Modo Vista)';
          _userPhone = 'Oficial PNP';
          _isLoadingUserData = false;
        });
      }
      return;
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF090D16) : AppColors.backgroundColor;
    final s = AppStrings.of(context);

    return Container(
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // 🏛️ Header Ejecutivo de Alta Seguridad
              _buildExecutiveHeader(s),

              const SizedBox(height: 16),

              // 🚀 Banner Destacado: Domina tu App (Inducción y Simuladores)
              _buildDominaTuAppDashboardCard(isDark, s),

              const SizedBox(height: 16),

              // 🚨 Cinta de Acción Inmediata (Central 114 + Pistas)
              _buildEmergencyQuickActionBanner(isDark, s),

              const SizedBox(height: 22),

              // 📊 Sección de Módulos Operativos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.servicesAndQueries,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      s.modulesCount,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 🔲 Grid Moderno de Módulos
              _buildModulesGrid(isDark, s),

              const SizedBox(height: 24),

              // 🛡️ Footer Institucional
              _buildInstitutionalFooter(isDark),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildExecutiveHeader(AppStrings s) {
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
                      Text(
                        s.activeNationalNetwork,
                        style: const TextStyle(
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
                        _isLoadingUserData
                            ? (s.isQuechua ? 'Perfilta kargachkan...' : 'Cargando perfil...')
                            : s.welcomeGreeting,
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

  Widget _buildEmergencyQuickActionBanner(bool isDark, AppStrings s) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      customColor: isDark
          ? const Color(0xFF1E293B).withValues(alpha: 0.8)
          : Colors.white.withValues(alpha: 0.9),
      customBorder: Border.all(
        color: isDark ? Colors.amber.withValues(alpha: 0.35) : const Color(0xFFFDE68A),
        width: 1.2,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
              ),
              borderRadius: BorderRadius.circular(14),
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
              children: [
                Text(
                  s.central114Pnp,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.emergencyLine114Desc,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () => SosDialog.show(context),
                icon: const Icon(Icons.emergency_rounded, size: 15, color: Colors.white),
                label: const Text(
                  'SOS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _callCentral114,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB45309),
                  side: const BorderSide(color: Color(0xFFB45309), width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  s.callAction,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 🚀 Banner visual moderno para el módulo autónomo "Domina tu App"
  Widget _buildDominaTuAppDashboardCard(bool isDark, AppStrings s) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF0284C7), const Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            widget.onNavigateToModule(4);
          },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 26),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'APRENDE EN 3 MIN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'NUEVO MÓDULO',
                            style: TextStyle(
                              color: Color(0xFF93C5FD),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '🚀 Domina tu App',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Inducción viva: simuladores de carnets QR, ruta en vivo y comisarías.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModulesGrid(bool isDark, AppStrings s) {
    final modules = _getModules(s);
    return FadeTransition(
      opacity: _cardsAnimation,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final int crossAxisCount = constraints.maxWidth > 800
              ? 4
              : (constraints.maxWidth > 540 ? 3 : 2);
          final double childAspectRatio = constraints.maxWidth > 800
              ? 1.15
              : (constraints.maxWidth > 540 ? 1.10 : 1.05);

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: modules.length,
            itemBuilder: (context, index) {
              final module = modules[index];
              return _buildModernModuleCard(module, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildModernModuleCard(DashboardModule module, bool isDark) {
    return GlassCard(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(14),
      color: isDark
          ? const Color(0xFF1E293B).withValues(alpha: 0.82)
          : Colors.white.withValues(alpha: 0.90),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.75),
        width: 1.2,
      ),
      onTap: () => widget.onNavigateToModule(module.index),
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
                  color: module.color.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  module.icon,
                  color: module.color,
                  size: 20,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  height: 1.15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                module.subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
              color: module.color.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionalFooter(bool isDark) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(16),
      customColor: isDark
          ? const Color(0xFF1E293B).withValues(alpha: 0.75)
          : Colors.white.withValues(alpha: 0.88),
      customBorder: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : AppColors.borderSubtle,
        width: 1.2,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: isDark ? 0.35 : 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              FontAwesomeIcons.shieldHalved,
              color: AppColors.accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alerta Desaparecidos Perú',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Plataforma Ciudadana Independiente • Enlace Cívico de Búsqueda',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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

