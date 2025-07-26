import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../injection.dart' as di;
import '../../../services/session_service.dart';
import '../../../services/logout_service.dart';
import '../view_models/view_missing_view_model.dart';
import '../../screens/welcome_screen.dart';
import 'view_missing_screen.dart';
import 'view_found_screen.dart';
import 'report_missing_screen.dart';
import 'comisarias_screen.dart';
import 'feedback_screen.dart';
import 'search_essays_screen.dart';
import 'educational_guides_screen.dart';
import 'about_screen.dart';
import 'citizen_dashboard_screen.dart';

class CitizenHomeScreen extends StatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  State<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends State<CitizenHomeScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
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
  }

  @override
  void dispose() {
    _appBarAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: WillPopScope(
        onWillPop: () async {
          return false; // Deshabilitar navegación del sistema
        },
        child: Scaffold(
          key: _scaffoldKey,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(70.0),
            child: AnimatedBuilder(
              animation: _appBarAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -50 * (1 - _appBarAnimation.value)),
                  child: Opacity(
                    opacity: _appBarAnimation.value,
                    child: AppBar(
                      title: Center(
                        child: Text(
                          _getSelectedScreenTitle(_selectedIndex),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            shadows: [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 3,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                        ),
                      ),
                      flexibleSpace: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      elevation: 8.0,
                      shadowColor: const Color(0xFF667eea).withOpacity(0.5),
                      leading: Container(
                        margin: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.menu,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () {
                            _scaffoldKey.currentState?.openDrawer();
                          },
                        ),
                      ),
                      actions: [
                        // Botón para volver al dashboard
                        if (_selectedIndex != 0)
                          Container(
                            margin: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.dashboard,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedIndex = 0;
                                });
                              },
                            ),
                          ),
                        if (_selectedIndex == 1)
                          Container(
                            margin: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.filter_list,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: () {
                                // Acción para el filtro
                              },
                            ),
                          ),
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
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<ViewMissingViewModel>(
                create: (_) => di.locator<ViewMissingViewModel>(),
              ),
            ],
            child: _CitizenHomeScreenBody(
              selectedIndex: _selectedIndex,
              onIndexChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  String _getSelectedScreenTitle(int selectedIndex) {
    switch (selectedIndex) {
      case 0:
        return 'DASHBOARD CIUDADANO';
      case 1:
        return 'PERSONAS DESAPARECIDAS';
      case 2:
        return 'PERSONAS ENCONTRADAS';
      case 3:
        return 'REPORTAR DESAPARICIÓN';
      case 4:
        return 'BUSCAR MI COMISARÍA';
      case 5:
        return 'RECOMENDACIONES';
      case 6:
        return 'BUSCAR ENSAYOS';
      case 7:
        return 'GUÍAS EDUCATIVAS';
      case 8:
        return 'ACERCA DE';
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
    super.key,
  });

  @override
  State<_CitizenHomeScreenBody> createState() => _CitizenHomeScreenBodyState();
}

class _CitizenHomeScreenBodyState extends State<_CitizenHomeScreenBody> {
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      CitizenDashboardScreen(
        onNavigateToModule: (int index) {
          // Ajustamos el índice porque el dashboard está en posición 0
          // pero los módulos empiezan desde el índice 1
          widget.onIndexChanged(index + 1);
        },
      ), // Index 0: Dashboard Principal
      const ViewMissingScreen(), // Index 1: Personas Desaparecidas
      const ViewFoundScreen(), // Index 2: Personas Encontradas
      const ReportMissingScreen(), // Index 3: Reportar Desaparición
      const ComisariasScreen(), // Index 4: Buscar Mi Comisaría
      const FeedbackScreen(), // Index 5: Recomendaciones
      const SearchEssaysScreen(), // Index 6: Buscar Ensayos
      const EducationalGuidesScreen(), // Index 7: Guías Educativas
      const AboutScreen(), // Index 8: Acerca de
    ];
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(index: widget.selectedIndex, children: _screens);
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

  // Colores específicos para cada ítem del menú
  final List<Color> _menuItemColors = [
    const Color(0xFF667eea), // Dashboard - Azul principal
    const Color(0xFFFF6B6B), // Personas Desaparecidas - Rojo
    const Color(0xFF4ECDC4), // Personas Encontradas - Verde azulado
    const Color(0xFFFFE66D), // Reportar Desaparición - Amarillo
    const Color(0xFF95E1D3), // Buscar Mi Comisaría - Verde claro
    const Color(0xFFA8E6CF), // Recomendaciones - Verde pastel
    const Color(0xFFDDA0DD), // Buscar Ensayos - Violeta claro
    const Color(0xFFFFB6C1), // Guías Educativas - Rosa claro
    const Color(0xFFFFA07A), // Acerca de - Salmón
  ];

  // Paleta de colores unificada
  final Color _primaryColor = const Color(0xFF667eea);
  final Color _secondaryColor = const Color(0xFF764ba2);
  final Color _darkPrimary = const Color(0xFF2C3E50);
  final Color _darkSecondary = const Color(0xFF34495E);
  final Color _darkAccent = const Color(0xFF3498DB);

  // Variables para información del usuario
  String _userName = 'Cargando...';
  String _userPhone = '';
  bool _isLoadingUserData = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
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

    // Inicializar animaciones para cada ítem (9 ítems + logout = 10)
    _itemAnimationControllers = List.generate(
      10,
      (index) => AnimationController(
        duration: Duration(milliseconds: 400 + (index * 100)),
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

    // Animar ítems con delay
    for (int i = 0; i < _itemAnimationControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 200 + (i * 100)), () {
        if (mounted) {
          _itemAnimationControllers[i].forward();
        }
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await SessionService.getUserSession();
      if (mounted && userData != null) {
        setState(() {
          _userName = userData['name'] ?? 'Usuario';
          _userPhone = userData['phoneNumber'] ?? '';
          _isLoadingUserData = false;
        });
      }
    } catch (e) {
      print('Error al cargar datos del usuario: $e');
      if (mounted) {
        setState(() {
          _userName = 'Usuario';
          _userPhone = '';
          _isLoadingUserData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _slideAnimationController.dispose();
    _fadeAnimationController.dispose();
    for (var controller in _itemAnimationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showLogoutDialog([BuildContext? dialogContext]) {
    final contextToUse = dialogContext ?? context;

    showDialog(
      context: contextToUse,
      barrierDismissible: false, // Prevenir cierre accidental
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red.shade600, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Cerrar Sesión',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Text(
              '¿Estás seguro de que quieres cerrar sesión?\n\nEsto te llevará de vuelta a la pantalla de bienvenida.',
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
                'Cancelar',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Cerrar diálogo primero
                await _performLogout(
                  contextToUse,
                ); // Pasar el contexto correcto
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
              child: const Text(
                'Cerrar Sesión',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
      // NUEVO: Marcar que es un logout manual usando el servicio específico de ciudadano
      CitizenLogoutService.markManualLogout();
      print('🔍 [CITIZEN-LOGOUT] Iniciando proceso de logout...');

      // Mostrar indicador de carga
      if (mounted) {
        showDialog(
          context: contextToUse,
          barrierDismissible: false,
          builder:
              (context) => Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text(
                        'Cerrando sesión...',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
        );
      }

      print('🔍 [CITIZEN-LOGOUT] Limpiando sesión...');
      // Limpiar sesión usando SessionService (método consistente)
      await SessionService.clearUserSession();

      print('🔍 [CITIZEN-LOGOUT] Cerrando sesión de Firebase...');
      // Cerrar sesión de Firebase
      await FirebaseAuth.instance.signOut();

      print('✅ [CITIZEN-LOGOUT] Logout completado');

      // Cerrar indicador de carga
      if (mounted) {
        Navigator.of(contextToUse).pop();
      }

      // Esperar un momento antes de navegar para asegurar que el logout se complete
      await Future.delayed(const Duration(milliseconds: 500));

      print('🔍 [CITIZEN-LOGOUT] Navegando a WelcomeScreen...');
      print('🔍 [CITIZEN-LOGOUT] Estado mounted: $mounted');
      print('🔍 [CITIZEN-LOGOUT] Context válido: ${contextToUse.mounted}');

      // Navegar usando el contexto correcto
      if (contextToUse.mounted) {
        try {
          print(
            '🔍 [CITIZEN-LOGOUT] Iniciando navegación con contexto válido...',
          );
          await Navigator.of(
            contextToUse,
            rootNavigator: true,
          ).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) {
                print('🔍 [CITIZEN-LOGOUT] Builder de WelcomeScreen ejecutado');
                return const WelcomeScreen();
              },
            ),
            (route) => false,
          );
          print('🔍 [CITIZEN-LOGOUT] ✅ Navegación completada exitosamente');
        } catch (e) {
          print('❌ [CITIZEN-LOGOUT] Error en navegación: $e');
        }
      } else {
        print('❌ [CITIZEN-LOGOUT] Widget no está mounted o context no válido');
      }

      print('🔍 [CITIZEN-LOGOUT] Configurando reseteo del flag con delay...');
      // NUEVO: Resetear el flag después de la navegación
      // MODIFICADO: Extender el delay a 35 segundos para cubrir el timeout de SMS
      Future.delayed(const Duration(seconds: 35), () {
        CitizenLogoutService.resetLogoutFlag();
        print(
          '🔄 [CITIZEN-LOGOUT] Flag reseteado después del logout (35s delay)',
        );
      });
    } catch (e) {
      print('❌ [CITIZEN-LOGOUT] Error al cerrar sesión: $e');
      print('❌ [CITIZEN-LOGOUT] Stack trace: ${StackTrace.current}');

      // En caso de error, también resetear el flag
      Future.delayed(const Duration(seconds: 5), () {
        CitizenLogoutService.resetLogoutFlag();
        print(
          '🔄 [CITIZEN-LOGOUT] Flag reseteado después del error (5s delay)',
        );
      });

      // Cerrar indicador de carga si está abierto
      if (mounted) {
        Navigator.of(contextToUse).pop();

        ScaffoldMessenger.of(contextToUse).showSnackBar(
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: screenWidth * 0.5, // Reducido a la mitad del ancho de pantalla
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  isDark
                      ? [_darkPrimary, _darkSecondary, _darkAccent]
                      : [_primaryColor, _secondaryColor, _primaryColor],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
                offset: const Offset(5, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header moderno con glassmorphism
              Container(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Logo con efecto de brillo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child:
                          _isLoadingUserData
                              ? const Center(
                                child: SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                              : Padding(
                                padding: const EdgeInsets.all(16),
                                child: Image.asset(
                                  'assets/icons/logo_pnp_policia.png',
                                  // Removido: color: Colors.white, para mostrar imagen original
                                ),
                              ),
                    ),
                    const SizedBox(height: 16),
                    // Información del usuario
                    Text(
                      _userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userPhone,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Título encerrado en rectángulo redondeado transparente - ACOMODADO
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'Alerta Desaparecidos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de ítems del menú
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      // Ítems del menú
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            _buildModernDrawerItem(
                              icon: FontAwesomeIcons.chartLine,
                              text: 'Dashboard\nPrincipal',
                              index: 0,
                              animationIndex: 0,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onIndexChanged(0);
                              },
                            ),
                            _buildModernDrawerItem(
                              iconPath: 'assets/icons/missing-icon.png',
                              text: 'Personas\nDesaparecidas',
                              index: 1,
                              animationIndex: 1,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onIndexChanged(1);
                              },
                            ),
                            _buildModernDrawerItem(
                              iconPath: 'assets/icons/encontrados_icon.png',
                              text: 'Personas\nEncontradas',
                              index: 2,
                              animationIndex: 2,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onIndexChanged(2);
                              },
                            ),
                            _buildModernDrawerItem(
                              iconPath:
                                  'assets/icons/reportar_desaparecido_icon.png',
                              text: 'Reportar\nDesaparición',
                              index: 3,
                              animationIndex: 3,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onIndexChanged(3);
                              },
                            ),
                            _buildModernDrawerItem(
                              iconPath: 'assets/icons/llamada_pnp_icon.png',
                              text: 'Buscar Mi\nComisaría',
                              index: 4,
                              animationIndex: 4,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onIndexChanged(4);
                              },
                            ),
                            _buildModernDrawerItem(
                              iconPath: 'assets/icons/chat_icon.png',
                              text: 'Recomendaciones',
                              index: 5,
                              animationIndex: 5,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onIndexChanged(5);
                              },
                            ),
                            _buildModernDrawerItem(
                              iconPath: 'assets/icons/search_icon.png',
                              text: 'Buscar\nEnsayos',
                              index: 6,
                              animationIndex: 6,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onIndexChanged(6);
                              },
                            ),
                            _buildModernDrawerItem(
                              iconPath: 'assets/icons/my_study_icon.png',
                              text: 'Guías\nEducativas',
                              index: 7,
                              animationIndex: 7,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onIndexChanged(7);
                              },
                            ),
                            _buildModernDrawerItem(
                              iconPath: 'assets/icons/profile_icon.png',
                              text: 'Acerca de',
                              index: 8,
                              animationIndex: 8,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onIndexChanged(8);
                              },
                            ),
                          ],
                        ),
                      ),

                      // Botón de logout moderno
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ScaleTransition(
                          scale: _itemAnimations[9],
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: _buildModernDrawerItem(
                              iconPath: 'assets/icons/logout_icon.png',
                              text: 'Cerrar Sesión',
                              index: -1,
                              animationIndex: 9,
                              onTap: () {
                                Navigator.pop(context);
                                _showLogoutDialog(widget.scaffoldContext);
                              },
                              isLogout: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernDrawerItem({
    String? iconPath,
    IconData? icon,
    required String text,
    required int index,
    required int animationIndex,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    final bool isSelected = index == widget.selectedIndex && !isLogout;
    final Color itemColor =
        isLogout
            ? Colors.red.shade400
            : (index >= 0 && index < _menuItemColors.length
                ? _menuItemColors[index]
                : _primaryColor);

    return ScaleTransition(
      scale: _itemAnimations[animationIndex],
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 12.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16.0),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(
                vertical: 12.0,
                horizontal: 16.0,
              ),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? Colors.white.withOpacity(0.2)
                        : itemColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16.0),
                border:
                    isSelected
                        ? Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 1.5,
                        )
                        : Border.all(
                          color: itemColor.withOpacity(0.3),
                          width: 1,
                        ),
                boxShadow:
                    isSelected
                        ? [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 8.0,
                            spreadRadius: 1.0,
                            offset: const Offset(0, 2),
                          ),
                        ]
                        : null,
              ),
              child: Row(
                children: [
                  // Icono moderno
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? Colors.white.withOpacity(0.9)
                              : itemColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              isSelected
                                  ? Colors.white.withOpacity(0.3)
                                  : itemColor.withOpacity(0.2),
                          blurRadius: isSelected ? 8.0 : 4.0,
                          spreadRadius: isSelected ? 1.0 : 0.5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color:
                            isSelected
                                ? Colors.white.withOpacity(0.3)
                                : itemColor.withOpacity(0.4),
                        width: 1.0,
                      ),
                    ),
                    child: Center(
                      child: AnimatedScale(
                        scale: isSelected ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child:
                            icon != null
                                ? Icon(
                                  icon,
                                  size: 18,
                                  color: isSelected ? itemColor : Colors.white,
                                )
                                : Image.asset(
                                  iconPath!,
                                  width: 18,
                                  height: 18,
                                  color: isSelected ? itemColor : Colors.white,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback icon si la imagen no se puede cargar
                                    return Icon(
                                      FontAwesomeIcons.questionCircle,
                                      size: 18,
                                      color:
                                          isSelected ? itemColor : Colors.white,
                                    );
                                  },
                                ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Texto moderno
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontSize: isSelected ? 14 : 13,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        color: Colors.white,
                        shadows:
                            isSelected
                                ? [
                                  Shadow(
                                    offset: const Offset(0.5, 0.5),
                                    blurRadius: 1,
                                    color: Colors.black.withOpacity(0.2),
                                  ),
                                ]
                                : null,
                      ),
                      child: Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // Indicador de selección
                  if (isSelected)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 3,
                      height: 20,
                      decoration: BoxDecoration(
                        color: itemColor,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: itemColor.withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
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
}
