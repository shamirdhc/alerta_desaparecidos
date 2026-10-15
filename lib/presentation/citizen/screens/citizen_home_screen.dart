import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/session_service.dart';
import 'package:alerta_desaparecidos/services/police_preview_mode_service.dart';
import '../../../services/spectator_mode_service.dart';
import '../../../services/logout_service.dart';
import '../../screens/welcome_screen.dart';
import 'view_missing_screen.dart';
import 'view_found_screen.dart';
import 'report_missing_screen.dart';
import 'feedback_screen.dart';
import 'about_screen.dart';
import 'mi_familia_screen.dart';
import 'comisarias_screen.dart';
import 'directorio_seguro_screen.dart';
import 'central_auxilio_screen.dart';
import 'citizen_dashboard_screen.dart';
import 'domina_tu_app_screen.dart';
import '../widgets/sos_dialog.dart';
import '../../../common/styles/app_colors.dart';
import '../../../services/theme_service.dart';
import '../../../services/language_service.dart';
import '../../../common/localization/app_strings.dart';
import '../../common_widgets/theme_sun_moon_toggle.dart';
import '../../common_widgets/language_selector_toggle.dart';
import '../../common_widgets/altoque_elevated_bottom_nav.dart';
import '../../common_widgets/tactile_surface_container.dart';
import '../../common_widgets/scale_on_tap.dart';
import '../../common_widgets/lazy_indexed_stack.dart';
import '../widgets/citizen_profile_panel.dart';
import '../../../common/constants/peru_locations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart' show navigatorKey;
import '../../../services/pwa_install_service.dart';

class CitizenHomeScreen extends StatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  State<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends State<CitizenHomeScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  DateTime? _lastBackPressed;
  late AnimationController _appBarAnimationController;
  late Animation<double> _appBarAnimation;

  @override
  void initState() {
    super.initState();
    _appBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _appBarAnimation = CurvedAnimation(
      parent: _appBarAnimationController,
      curve: Curves.easeInOut,
    );
    _appBarAnimationController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null &&
          (currentUser.email ?? '').trim().toLowerCase() == 'shamirdhc2022@gmail.com' &&
          !PolicePreviewModeService.isPreviewActive) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/police_home');
          return;
        }
      }

      // Auto-desplegar suavemente el menú lateral al iniciar sesión / ingresar al aplicativo
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted && !(_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
          _scaffoldKey.currentState?.openDrawer();
        }
      });

      PwaInstallService.checkAndShowAutoInstallPrompt(
        context,
        delay: const Duration(seconds: 4),
      );
    });
  }

  @override
  void dispose() {
    _appBarAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF090D16) : AppColors.backgroundColor;

    return Container(
      color: scaffoldBg,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
            _scaffoldKey.currentState?.closeDrawer();
            return;
          }
          if (PolicePreviewModeService.isPreviewActive) {
            PolicePreviewModeService.exitPreviewMode(context);
            return;
          }
          if (_selectedIndex != 0) {
            setState(() {
              _selectedIndex = 0;
            });
            return;
          }
          final now = DateTime.now();
          if (_lastBackPressed == null ||
              now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
            _lastBackPressed = now;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text('Presione nuevamente para salir de Alerta Desaparecidos'),
                  ],
                ),
                backgroundColor: const Color(0xFF1E293B),
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
          key: _scaffoldKey,
          extendBody: true,
          backgroundColor: scaffoldBg,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(66.0),
            child: AnimatedBuilder(
              animation: _appBarAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -50 * (1 - _appBarAnimation.value)),
                  child: Opacity(
                    opacity: _appBarAnimation.value,
                    child: AppBar(
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFF59E0B),
                                  Color(0xFF10B981),
                                  Color(0xFF06B6D4),
                                ],
                              ),
                            ),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF0F172A),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset('assets/icons/icon_police.png'),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              _getSelectedScreenTitle(context, _selectedIndex),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16.0,
                                letterSpacing: 0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      flexibleSpace: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. Contenedor táctil 3D con micro-trama de puntos de AlToque
                          TactileSurfaceContainer(
                            customGradientColors: isDark
                                ? const [
                                    Color(0xFF0F172A), // Slate 900
                                    Color(0xFF131B2E), // Tactical Police Navy
                                    Color(0xFF080D1A), // Dark Midnight
                                  ]
                                : const [
                                    Color(0xFF1B365D), // Institutional PNP Navy
                                    Color(0xFF152A47), // Deep Navy
                                    Color(0xFF0D1C30), // Dark Police Navy
                                  ],
                            showBevelHighlight: true,
                            dotSpacing: 10.0,
                            dotRadius: 1.0,
                            child: const SizedBox.expand(),
                          ),
                          // 2. Bisel especular inferior de iluminación 3D
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 1.5,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: isDark ? 0.20 : 0.40),
                                    Colors.white.withValues(alpha: isDark ? 0.35 : 0.70),
                                    Colors.white.withValues(alpha: isDark ? 0.20 : 0.40),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      elevation: 4.0,
                      shadowColor: Colors.black.withValues(alpha: 0.35),
                      leading: Padding(
                        padding: const EdgeInsets.all(7.5),
                        child: ScaleOnTap(
                          onTap: () {
                            _scaffoldKey.currentState?.openDrawer();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF06B6D4), // Cian Neón
                                  Color(0xFF2563EB), // Azul Rey Policial
                                  Color(0xFF4F46E5), // Índigo Profundo
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(
                                color: const Color(0xFF38BDF8),
                                width: 1.6,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.70 : 0.50),
                                  blurRadius: 14,
                                  spreadRadius: 1.5,
                                  offset: const Offset(0, 2),
                                ),
                                BoxShadow(
                                  color: const Color(0xFF38BDF8).withValues(alpha: isDark ? 0.45 : 0.30),
                                  blurRadius: 22,
                                  spreadRadius: 2.5,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(
                                  Icons.menu_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                // Indicador luminoso en la esquina superior para denotar menú vivo
                                Positioned(
                                  top: 3,
                                  right: 3,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B), // Punto oro/ámbar neón
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.9),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                      border: Border.all(color: Colors.white, width: 1),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      actions: [
                        // Botón de Pánico SOS en AppBar
                        IconButton(
                          icon: const Icon(Icons.emergency_rounded, color: Color(0xFFEF4444)),
                          tooltip: 'Central de Auxilio SOS',
                          onPressed: () => SosDialog.show(context),
                        ),
                        // Opción de instalación de Aplicativo Web (PWA)
                        if (PwaInstallService.isInstallOptionAvailable)
                          IconButton(
                            icon: const Icon(Icons.install_mobile_rounded, color: Color(0xFF38BDF8)),
                            tooltip: 'Instalar Aplicativo Web',
                            onPressed: () => PwaInstallService.promptOrGuideInstall(context),
                          ),
                        // Selector táctico de idioma (Español / Runasimi Quechua)
                        const LanguageSelectorToggle(),
                        // Widget de sol y luna para alternar y elegir tema visual
                        const ThemeSunMoonToggle(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          drawer: CustomCitizenDrawer(
            selectedIndex: _selectedIndex,
            onIndexChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            scaffoldContext: context,
          ),
                    body: Column(
            children: [
              if (PolicePreviewModeService.isPreviewActive)
                _buildPolicePreviewBanner(context),
              if (SpectatorModeService.isSpectator)
                _buildSpectatorBanner(context),
              Expanded(
                child: _CitizenHomeScreenBody(
                  selectedIndex: _selectedIndex,
                  onIndexChanged: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildAlToqueBottomNav(context, isDark),
        ),
      ),
    );
  }

  Widget _buildSpectatorBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C1929), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.visibility_rounded,
              color: Color(0xFF38BDF8),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MODO ESPECTADOR (LIBRE)',
                  style: TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Consulta activa. Inicia sesión para comentar pistas',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => SpectatorModeService.promptLogin(context),
            icon: const Icon(Icons.login_rounded, size: 14, color: Colors.white),
            label: const Text(
              'Acceder',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicePreviewBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF06B6D4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06B6D4).withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.remove_red_eye_rounded,
              color: Color(0xFF06B6D4),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MODO VISTA CIUDADANO (ADMIN)',
                  style: TextStyle(
                    color: Color(0xFF06B6D4),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Acciones de edición y envío bloqueadas',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => PolicePreviewModeService.exitPreviewMode(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 14, color: Colors.white),
            label: const Text(
              'Volver',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _getDockIndex(int screenIndex) {
    switch (screenIndex) {
      case 0:
        return 0; // Inicio (Dashboard)
      case 1:
        return 1; // Buscar (Personas Desaparecidas)
      case 4:
        return 2; // Mi Familia Segura
      case 6:
        return 3; // Buscar Mi Comisaría (Mapa GPS)
      case 9:
        return 4; // Directorio Seguro (Agenda PNP & CEM)
      default:
        return -1; // Otros módulos (Encontrados, Guías, Domina tu App, Sugerencias, Acerca de)
    }
  }

  void _onDockItemTapped(int dockIndex) {
    switch (dockIndex) {
      case 0:
        setState(() => _selectedIndex = 0);
        break;
      case 1:
        setState(() => _selectedIndex = 1);
        break;
      case 2:
        setState(() => _selectedIndex = 4); // Mi Familia Segura
        break;
      case 3:
        setState(() => _selectedIndex = 6); // Buscar Mi Comisaría (Mapa GPS)
        break;
      case 4:
        setState(() => _selectedIndex = 9); // Directorio Seguro (Agenda PNP & CEM)
        break;
    }
  }

  Widget _buildAlToqueBottomNav(BuildContext context, bool isDark) {
    final isQuechua = Provider.of<LanguageService>(context).isQuechua;

    final navItems = [
      AlToqueNavItem(
        label: isQuechua ? 'Qallariy' : 'Inicio',
        activeIcon: Icons.home_rounded,
        inactiveIcon: Icons.home_rounded,
        activeColor: const Color(0xFF3B82F6), // Azul Neón Eléctrico
      ),
      AlToqueNavItem(
        label: isQuechua ? 'Maskay' : 'Buscar',
        activeIcon: Icons.person_search_rounded,
        inactiveIcon: Icons.person_search_rounded,
        activeColor: const Color(0xFFEF4444), // Rojo Neón Alerta
      ),
      AlToqueNavItem(
        label: isQuechua ? 'Ayllu' : 'Mi Familia',
        activeIcon: Icons.family_restroom_rounded,
        inactiveIcon: Icons.family_restroom_rounded,
        activeColor: const Color(0xFFEAB308), // Amarillo Cálido Neón Familiar
      ),
      AlToqueNavItem(
        label: isQuechua ? 'Kumisariya' : 'Comisaría',
        activeIcon: Icons.local_police_rounded,
        inactiveIcon: Icons.local_police_rounded,
        activeColor: const Color(0xFF0D9488), // Teal Neón Policial
      ),
      AlToqueNavItem(
        label: isQuechua ? 'Directorio' : 'Directorio',
        activeIcon: Icons.contact_phone_rounded,
        inactiveIcon: Icons.contact_phone_rounded,
        activeColor: const Color(0xFF6366F1), // Índigo Neón Institucional
      ),
    ];

    return AlToqueElevatedBottomNav(
      selectedIndex: _getDockIndex(_selectedIndex),
      items: navItems,
      onItemSelected: _onDockItemTapped,
      onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
    );
  }

  String _getSelectedScreenTitle(BuildContext context, int selectedIndex) {
    final isQuechua = Provider.of<LanguageService>(context).isQuechua;

    if (isQuechua) {
      switch (selectedIndex) {
        case 0:
          return 'LLAPANCHIKPAQ PANEL';
        case 1:
          return 'CHINKASQA RUNAKUNA';
        case 2:
          return 'TARISQA RUNAKUNA';
        case 3:
          return 'YACHAY GUÍAKUNA';
        case 4:
          return 'AYLLU WAQAYCHAY';
        case 5:
          return 'APP KAMACHIYPAQ (INDUCCIÓN)';
        case 6:
          return 'KUMISARIYA MASKHAY';
        case 7:
          return 'SUGERENCIAKUNA';
        case 8:
          return 'SISTEMAMANTA';
        case 9:
          return 'KALLPACHASQA DIRECTORIO';
        default:
          return 'LLAPANCHIKPAQ PANEL';
      }
    }

    switch (selectedIndex) {
      case 0:
        return 'DASHBOARD CIUDADANO';
      case 1:
        return 'PERSONAS DESAPARECIDAS';
      case 2:
        return 'PERSONAS ENCONTRADAS';
      case 3:
        return 'GUÍAS EDUCATIVAS';
      case 4:
        return 'MI FAMILIA SEGURA';
      case 5:
        return 'DOMINA TU APP (INDUCCIÓN)';
      case 6:
        return 'BUSCAR MI COMISARÍA';
      case 7:
        return 'SUGERENCIAS';
      case 8:
        return 'ACERCA DE LA PLATAFORMA';
      case 9:
        return 'DIRECTORIO SEGURO';
      default:
        return 'DASHBOARD CIUDADANO';
    }
  }
}

class _CitizenHomeScreenBody extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged;

  const _CitizenHomeScreenBody({
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  @override
  State<_CitizenHomeScreenBody> createState() => _CitizenHomeScreenBodyState();
}

class _CitizenHomeScreenBodyState extends State<_CitizenHomeScreenBody> {
  @override
  Widget build(BuildContext context) {
    return LazyIndexedStack(
      index: widget.selectedIndex,
      builders: [
        // Index 0: Dashboard Principal
        (context) => CitizenDashboardScreen(
          onNavigateToModule: (int targetIndex) {
            widget.onIndexChanged(targetIndex);
          },
        ),
        // Index 1: Personas Desaparecidas (Carga sólo al pulsar 'Buscar')
        (context) => const ViewMissingScreen(),
        // Index 2: Personas Encontradas (Carga sólo al pulsar 'Encontrados')
        (context) => const ViewFoundScreen(),
        // Index 3: Guías Educativas (con videos didácticos oficiales)
        (context) => ReportMissingScreen(onNavigateToTab: widget.onIndexChanged),
        // Index 4: Mi Familia Segura (Kit Preventivo)
        (context) => const MiFamiliaScreen(),
        // Index 5: Domina tu App (Inducción Interactiva)
        (context) => DominaTuAppScreen(onNavigateToModule: widget.onIndexChanged),
        // Index 6: Buscar Mi Comisaría (con mapa interactivo y radar GPS en vivo)
        (context) => const ComisariasScreen(isActive: true),
        // Index 7: Sugerencias
        (context) => FeedbackScreen(onBack: () => widget.onIndexChanged(0)),
        // Index 8: Acerca de la Plataforma
        (context) => const AboutScreen(),
        // Index 9: Directorio Seguro (con Agenda Policial y Directorio CEM)
        (context) => const DirectorioSeguroScreen(),
      ],
    );
  }
}

class CustomCitizenDrawer extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged;
  final BuildContext scaffoldContext;

  const CustomCitizenDrawer({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.scaffoldContext,
  });

  @override
  State<CustomCitizenDrawer> createState() => _CustomCitizenDrawerState();
}

class _CustomCitizenDrawerState extends State<CustomCitizenDrawer>
    with TickerProviderStateMixin {
  late AnimationController _slideAnimationController;
  late AnimationController _fadeAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late List<AnimationController> _itemAnimationControllers;
  late List<Animation<double>> _itemAnimations;
  late ScrollController _scrollController;

  // Paleta de colores unificada institucional PNP
  final Color _primaryColor = AppColors.primaryColor;

  // Variables para información del usuario (4 campos: Nombre, Celular, Dept, Prov)
  String _userName = 'Cargando...';
  String _userDepartment = 'LIMA';
  String _userProvincia = 'Lima';
  String _userPhone = '';
  bool _isLoadingUserData = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _initializeAnimations();
    _loadUserData();

    // Verificar si necesitamos hacer scroll al abrir el drawer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndScrollToSelectedItem();
    });
  }

  void _checkAndScrollToSelectedItem() {
    // Si el ítem seleccionado está hacia el final (índices 5, 7, 8 o 9)
    if (widget.selectedIndex == 5 ||
        widget.selectedIndex == 7 ||
        widget.selectedIndex == 8 ||
        widget.selectedIndex == 9) {
      // Hacer scroll hacia abajo para mostrar estos ítems
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent * 0.7,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    }
  }

  void _initializeAnimations() {
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeIn,
    );

    // Inicializar animaciones para cada ítem (14 ítems + margen de seguridad = 16)
    _itemAnimationControllers = List.generate(
      16,
      (index) => AnimationController(
        duration: Duration(milliseconds: 320 + (index * 45)),
        vsync: this,
      ),
    );

    _itemAnimations =
        _itemAnimationControllers
            .map(
              (controller) =>
                  CurvedAnimation(parent: controller, curve: Curves.elasticOut),
            )
            .toList();

    // Iniciar animaciones
    _slideAnimationController.forward();
    _fadeAnimationController.forward();

    // Animar ítems con delay escalonado
    for (int i = 0; i < _itemAnimationControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 140 + (i * 45)), () {
        if (mounted) {
          _itemAnimationControllers[i].forward();
        }
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      if (SpectatorModeService.isSpectator) {
        if (mounted) {
          setState(() {
            _userName = 'Modo Espectador';
            _userDepartment = 'PERÚ';
            _userProvincia = 'Nacional';
            _userPhone = 'Visitante';
            _isLoadingUserData = false;
          });
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      String cachedDept = prefs.getString('user_departamento') ?? prefs.getString('user_department') ?? 'LIMA';
      String cachedProv = prefs.getString('user_provincia') ?? 'Lima';
      String cachedPhone = prefs.getString('last_phone_number') ?? '';
      String cachedName = 'Usuario';

      // 1. Cargar caché local de forma inmediata para UI responsiva
      final userData = await SessionService.getUserSession();
      if (userData != null && userData['name'] != null && userData['name'] != 'Usuario') {
        cachedName = userData['name']!;
        if (userData['departamento'] != null && (userData['departamento'] as String).isNotEmpty) {
          cachedDept = userData['departamento']!;
        }
        if (userData['provincia'] != null && (userData['provincia'] as String).isNotEmpty) {
          cachedProv = userData['provincia']!;
        }
        if (userData['phoneNumber'] != null && (userData['phoneNumber'] as String).isNotEmpty) {
          cachedPhone = userData['phoneNumber']!;
        }
      }

      if (mounted) {
        setState(() {
          _userName = cachedName;
          _userDepartment = cachedDept;
          _userProvincia = cachedProv;
          _userPhone = cachedPhone;
          _isLoadingUserData = false;
        });
      }

      // 2. SIEMPRE sincronizar en segundo plano con la fuente de verdad: FIRESTORE
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('ciudadanos')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 6));

        if (userDoc.exists && userDoc.data() != null) {
          final firestoreData = userDoc.data()!;
          final nombres = firestoreData['nombres'] ?? '';
          final apellidos = firestoreData['apellidos'] ?? '';
          final fullName = (firestoreData['nombre_completo'] as String?)?.trim();
          final effectiveName = (fullName != null && fullName.isNotEmpty)
              ? fullName
              : ('$nombres $apellidos'.trim().isNotEmpty ? '$nombres $apellidos'.trim() : (user.displayName ?? cachedName));

          final phoneNumber = firestoreData['telefono'] ?? firestoreData['celular'] ?? cachedPhone;
          final String? fsDept = firestoreData['departamento'];
          final String? fsProv = firestoreData['provincia'];

          final finalDept = (fsDept != null && fsDept.trim().isNotEmpty)
              ? fsDept.trim().toUpperCase()
              : cachedDept;
          final finalProv = (fsProv != null && fsProv.trim().isNotEmpty)
              ? PeruLocations.matchProvincia(finalDept, fsProv.trim())
              : cachedProv;

          if (mounted) {
            setState(() {
              _userName = effectiveName;
              _userDepartment = finalDept;
              _userProvincia = finalProv;
              _userPhone = phoneNumber ?? '';
            });

            // Actualizar SharedPreferences y SessionService con los datos frescos de Firestore
            await prefs.setString('user_departamento', finalDept);
            await prefs.setString('user_department', finalDept);
            await prefs.setString('user_provincia', finalProv);
            if (phoneNumber != null && (phoneNumber as String).isNotEmpty) {
              await prefs.setString('last_phone_number', phoneNumber);
            }

            await SessionService.saveUserSession(
              userId: user.uid,
              phoneNumber: phoneNumber ?? '',
              userRole: 'citizen',
              userName: effectiveName,
              departamento: finalDept,
              provincia: finalProv,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('ℹ️ [CITIZEN_HOME] Error al sincronizar perfil: $e');
    }
  }

  @override
  void dispose() {
    _slideAnimationController.dispose();
    _fadeAnimationController.dispose();
    _scrollController.dispose();
    for (var controller in _itemAnimationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showLogoutDialog([BuildContext? dialogContext]) {
    final contextToUse = dialogContext ?? context;
    final strings = AppStrings.of(contextToUse);

    showDialog(
      context: contextToUse,
      barrierDismissible: false,
      builder: (BuildContext dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.logout_rounded, color: Colors.red.shade600, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  strings.menuLogout,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${strings.logoutConfirmTitle}\n\n${strings.logoutConfirmMessage}',
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                color: isDark ? const Color(0xFFE2E8F0) : Colors.black87,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                strings.cancel,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop(); // Cerrar diálogo
                if (Navigator.of(contextToUse).canPop()) {
                  Navigator.of(contextToUse).pop(); // Cerrar drawer
                }
                await _performLogout(contextToUse);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: Text(
                strings.menuLogout,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout([BuildContext? logoutContext]) async {
    final contextToUse = logoutContext ?? context;

    try {
      if (SpectatorModeService.isSpectator) {
        await SpectatorModeService.exitSpectatorMode(contextToUse);
        return;
      }

      CitizenLogoutService.markManualLogout();

      // Limpiar sesión usando SessionService y SharedPreferences
      await SessionService.clearUserSession();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_demo_session', false);
        await prefs.setBool('is_superadmin', false);
        await prefs.remove('is_superadmin');
        await prefs.remove('userRole');
        await prefs.remove('user_role');
        await prefs.remove('last_phone_number');
      } catch (_) {}

      // Cerrar sesión de Firebase
      try {
        await FirebaseAuth.instance.signOut();
      } catch (authError) {
        debugPrint('⚠️ [CITIZEN-LOGOUT] Error cerrando FirebaseAuth: $authError');
      }

      // Navegación inmediata a WelcomeScreen limpiando el stack completo
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamedAndRemoveUntil(
          '/welcome',
          (route) => false,
        );
      } else if (contextToUse.mounted) {
        Navigator.of(contextToUse, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }

      Future.delayed(const Duration(milliseconds: 600), () {
        CitizenLogoutService.resetLogoutFlag();
      });
    } catch (e) {
      CitizenLogoutService.resetLogoutFlag();
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamedAndRemoveUntil(
          '/welcome',
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = math.min(screenWidth * 0.84, 325.0);
    final strings = AppStrings.of(context);

    final darkGradient = const [
      Color(0xFF0F172A), // Slate 900
      Color(0xFF131B2E), // Tactical Police Navy
      Color(0xFF080D1A), // Dark Midnight
    ];

    final lightGradient = const [
      Color(0xFF1B365D), // Institutional Police Navy
      Color(0xFF152A47), // Deep Navy
      Color(0xFF0D1C30), // Dark Police Navy
    ];

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SizedBox(
          width: drawerWidth,
          height: double.infinity,
          child: TactileSurfaceContainer(
            customGradientColors: isDark ? darkGradient : lightGradient,
            showBevelHighlight: true,
            dotSpacing: 10.0,
            dotRadius: 1.0,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 30,
                spreadRadius: 8,
                offset: const Offset(6, 0),
              ),
            ],
            child: SafeArea(
              child: Column(
                children: [
                  // 1. Header Interactivo con Panel de Perfil de Usuario (Estilo AlToque)
                  _buildInteractiveUserProfileCard(context),

                  // Línea divisoria con bisel especular
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.18),
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 2. Lista de navegación con módulos y diseño táctil moderno
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: [
                        // SECCIÓN 1: URGENCIA Y BÚSQUEDA ACTIVA (Máxima prioridad de uso)
                        _buildDrawerSectionHeader(
                          strings.isQuechua
                              ? 'UTQAY MASKAY HINASPA PANEL'
                              : 'URGENCIA Y BÚSQUEDA ACTIVA',
                        ),
                        _buildModernDrawerItem(
                          icon: Icons.space_dashboard_rounded,
                          text: strings.isQuechua ? 'Qallariy Panel' : 'Inicio / Panel Principal',
                          index: 0,
                          animationIndex: 0,
                          badgeText: 'Principal',
                          badgeColor: const Color(0xFF2563EB),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onIndexChanged(0);
                          },
                        ),
                        _buildModernDrawerItem(
                          icon: Icons.person_search_rounded,
                          text: strings.menuMissingPersons,
                          index: 1,
                          animationIndex: 1,
                          badgeText: strings.badgeUrgente,
                          badgeColor: const Color(0xFFEF4444),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onIndexChanged(1);
                          },
                        ),
                        _buildModernDrawerItem(
                          icon: Icons.local_police_rounded,
                          text: strings.isQuechua ? 'Kumisariya Maskhay' : 'Buscar Mi Comisaría',
                          index: 6,
                          animationIndex: 2,
                          badgeText: 'GPS Mapa',
                          badgeColor: const Color(0xFF0D9488),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onIndexChanged(6);
                          },
                        ),
                        _buildModernDrawerItem(
                          icon: Icons.contact_phone_rounded,
                          text: strings.isQuechua ? 'Kallpachasqa Directorio' : 'Directorio Seguro',
                          index: 9,
                          animationIndex: 3,
                          badgeText: 'PNP • CEM',
                          badgeColor: const Color(0xFF6366F1),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onIndexChanged(9);
                          },
                        ),

                        const SizedBox(height: 6),
                        // SECCIÓN 2: PREVENCIÓN FAMILIAR Y RESULTADOS (Herramientas personales y esperanza)
                        _buildDrawerSectionHeader(
                          strings.isQuechua
                              ? 'AYLLU WAQAYCHAY'
                              : 'PREVENCIÓN FAMILIAR Y RESULTADOS',
                        ),
                        _buildModernDrawerItem(
                          icon: Icons.family_restroom_rounded,
                          text: strings.isQuechua ? 'Ayllu Waqaychay' : 'Mi Familia Segura',
                          index: 4,
                          animationIndex: 4,
                          badgeText: 'Carnet SOS • Kit',
                          badgeColor: const Color(0xFFEC4899),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onIndexChanged(4);
                          },
                        ),
                        _buildModernDrawerItem(
                          icon: Icons.verified_user_rounded,
                          text: strings.menuFoundPersons,
                          index: 2,
                          animationIndex: 5,
                          badgeText: strings.badgeASalvo,
                          badgeColor: const Color(0xFF10B981),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onIndexChanged(2);
                          },
                        ),

                        const SizedBox(height: 6),
                        // SECCIÓN 3: CAPACITACIÓN Y ORIENTACIÓN PNP (Para usuarios que profundizan)
                        _buildDrawerSectionHeader(
                          strings.isQuechua
                              ? 'YACHAY HINASPA PROTOCOLOS'
                              : 'CAPACITACIÓN Y ORIENTACIÓN PNP',
                        ),
                        _buildModernDrawerItem(
                          icon: Icons.school_rounded,
                          text: strings.menuGuides,
                          index: 3,
                          animationIndex: 6,
                          badgeText: 'Videos y Guías 🎓',
                          badgeColor: const Color(0xFF0D9488),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onIndexChanged(3);
                          },
                        ),
                        _buildModernDrawerItem(
                          icon: Icons.rocket_launch_rounded,
                          text: strings.isQuechua ? 'App Kamachiypaq' : 'Domina tu App (Inducción)',
                          index: 5,
                          animationIndex: 7,
                          badgeText: 'Simulador 🚀',
                          badgeColor: const Color(0xFF0284C7),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onIndexChanged(5);
                          },
                        ),

                        const SizedBox(height: 6),
                        // SECCIÓN 4: PARTICIPACIÓN Y TRANSPARENCIA (Feedback y consulta institucional)
                        _buildDrawerSectionHeader(
                          strings.isQuechua
                              ? 'WILLAYKUNA HINASPA LLAQTA'
                              : 'PARTICIPACIÓN Y TRANSPARENCIA',
                        ),
                        _buildModernDrawerItem(
                          icon: Icons.rate_review_rounded,
                          text: strings.menuSuggestions,
                          index: 7,
                          animationIndex: 8,
                          badgeText: 'Tu Opinión ⭐',
                          badgeColor: const Color(0xFF8B5CF6),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onIndexChanged(7);
                          },
                        ),
                        _buildModernDrawerItem(
                          icon: Icons.info_outline_rounded,
                          text: strings.menuAbout,
                          index: 8,
                          animationIndex: 9,
                          badgeText: 'Institucional',
                          badgeColor: const Color(0xFF64748B),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onIndexChanged(8);
                          },
                        ),

                        const SizedBox(height: 6),
                        // SECCIÓN 5: PREFERENCIAS DEL SISTEMA
                        _buildDrawerSectionHeader(strings.sectionPreferences),
                        Consumer<ThemeProvider>(
                          builder: (context, themeProvider, _) {
                            final isDarkNow = Theme.of(context).brightness == Brightness.dark;

                            return _buildModernDrawerItem(
                              icon: isDarkNow ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              text: isDarkNow ? strings.lightMode : strings.darkMode,
                              index: -2,
                              animationIndex: 10,
                              badgeText: isDarkNow ? (strings.isQuechua ? 'LAQHA' : 'OSCURO') : (strings.isQuechua ? 'K’ANCHAY' : 'CLARO'),
                              badgeColor: isDarkNow ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                              onTap: () {
                                themeProvider.toggleTheme(context);
                              },
                            );
                          },
                        ),
                        if (PwaInstallService.isInstallOptionAvailable) ...[
                          const SizedBox(height: 6),
                          _buildModernDrawerItem(
                            icon: Icons.install_mobile_rounded,
                            text: strings.isQuechua ? 'Aplicativota churay' : 'Instalar Aplicativo Web',
                            index: -3,
                            animationIndex: 11,
                            badgeText: 'PWA',
                            badgeColor: const Color(0xFF10B981),
                            onTap: () {
                              Navigator.pop(context);
                              PwaInstallService.promptOrGuideInstall(context);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 3. Botón de logout moderno en el footer
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    child: ScaleTransition(
                      scale: _itemAnimations[12],
                      child: _buildModernDrawerItem(
                        icon: Icons.logout_rounded,
                        text: strings.menuLogout,
                        index: -1,
                        animationIndex: 12,
                        onTap: () {
                          Navigator.pop(context);
                          _showLogoutDialog(widget.scaffoldContext);
                        },
                        isLogout: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Construye la tarjeta interactiva de usuario en la parte superior del drawer.
  /// Al tocarla, despliega el panel modal CitizenProfilePanel de AlToque.
  Widget _buildInteractiveUserProfileCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: ScaleOnTap(
        onTap: () {
          if (SpectatorModeService.isSpectator) {
            SpectatorModeService.promptLogin(context);
            return;
          }
          CitizenProfilePanel.show(
            context,
            initialName: _userName,
            initialPhone: _userPhone,
            initialDepartamento: _userDepartment,
            initialProvincia: _userProvincia,
            onUserUpdated: (fullName, dept, prov) {
              _loadUserData();
            },
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar con Jewel Ring estilo AlToque (Anillo joya degradado Amber/Emerald/Cyan)
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFF59E0B), // Amber
                          Color(0xFF10B981), // Emerald
                          Color(0xFF06B6D4), // Cyan
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF0F172A),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _isLoadingUserData
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            )
                          : Image.asset(
                              'assets/icons/icon_police.png',
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Nombres y detalles del usuario
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_iphone_rounded,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _userPhone.isNotEmpty
                                    ? 'Cel: $_userPhone'
                                    : (strings.isQuechua ? 'Celular mana churasqa' : 'Celular no registrado'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Badge Región / Ciudad
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 10,
                                    color: Color(0xFF34D399),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$_userProvincia, $_userDepartment',
                                    style: const TextStyle(
                                      color: Color(0xFF34D399),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Botón interactivo "Ver y editar perfil" con flecha
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.manage_accounts_rounded,
                          size: 14,
                          color: Colors.amber.shade300,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          strings.isQuechua ? 'Willakuyniyta qhaway' : 'Ver y modificar mis datos',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: Colors.white.withValues(alpha: 0.65),
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

  Widget _buildDrawerSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 2),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildModernDrawerItem({
    IconData? icon,
    required String text,
    required int index,
    required int animationIndex,
    required VoidCallback onTap,
    bool isLogout = false,
    String? badgeText,
    Color? badgeColor,
  }) {
    final bool isSelected = index == widget.selectedIndex && !isLogout;

    final List<Color> vibrantColors = [
      const Color(0xFF2563EB), // 0: Dashboard - Azul real
      const Color(0xFFEF4444), // 1: Personas Desaparecidas - Rojo alerta
      const Color(0xFF10B981), // 2: Personas Encontradas - Verde esmeralda
      const Color(0xFF0D9488), // 3: Guías Educativas - Teal / Verde azulado
      const Color(0xFFEAB308), // 4: Mi Familia Segura - Amarillo cálido
      const Color(0xFF0284C7), // 5: Domina tu App - Azul cian
      const Color(0xFF0D9488), // 6: Buscar Mi Comisaría - Teal policial / radar
      const Color(0xFF8B5CF6), // 7: Sugerencias - Violeta
      const Color(0xFF64748B), // 8: Acerca de - Pizarra
      const Color(0xFF6366F1), // 9: Directorio Seguro - Índigo institucional
    ];

    final List<IconData> moduleIcons = [
      Icons.space_dashboard_rounded, // 0: Dashboard
      Icons.person_search_rounded,   // 1: Personas Desaparecidas
      Icons.verified_user_rounded,   // 2: Personas Encontradas
      Icons.school_rounded,          // 3: Guías Educativas
      Icons.family_restroom_rounded, // 4: Mi Familia Segura
      Icons.rocket_launch_rounded,   // 5: Domina tu App
      Icons.local_police_rounded,    // 6: Buscar Mi Comisaría
      Icons.rate_review_rounded,     // 7: Sugerencias
      Icons.info_outline_rounded,    // 8: Acerca de
      Icons.contact_phone_rounded,   // 9: Directorio Seguro
    ];

    final Color itemColor = isLogout
        ? const Color(0xFFF43F5E)
        : (index >= 0 && index < vibrantColors.length
            ? vibrantColors[index]
            : _primaryColor);

    final IconData itemIcon = icon ??
        (isLogout
            ? Icons.logout_rounded
            : (index >= 0 && index < moduleIcons.length
                ? moduleIcons[index]
                : Icons.circle_outlined));

    return ScaleTransition(
      scale: _itemAnimations[animationIndex],
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 10.0),
        child: ScaleOnTap(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              vertical: isSelected ? 9.0 : 8.0,
              horizontal: 12.0,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.16)
                  : (isLogout
                      ? Colors.red.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.04)),
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.35)
                    : (isLogout
                        ? Colors.red.withValues(alpha: 0.32)
                        : Colors.white.withValues(alpha: 0.08)),
                width: isSelected ? 1.2 : 0.8,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: itemColor.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Indicador activo lateral izquierdo
                if (isSelected)
                  Container(
                    width: 3.5,
                    height: 20,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: itemColor,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: itemColor,
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),

                // Icono
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: itemColor.withValues(alpha: isSelected ? 0.32 : 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      itemIcon,
                      color: isLogout ? Colors.red.shade300 : itemColor,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Texto del módulo
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isLogout
                          ? Colors.red.shade200
                          : Colors.white.withValues(alpha: isSelected ? 1.0 : 0.9),
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Badge pill opcional
                if (badgeText != null)
                  Container(
                    margin: const EdgeInsets.only(left: 4, right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? Colors.red).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (badgeColor ?? Colors.red).withValues(alpha: 0.65),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor ?? Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),

                // Chevron indicador
                if (isSelected)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

