import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'agenda_policial.dart';
import 'educational_guides_screen.dart';
import 'about_screen.dart';
import 'citizen_dashboard_screen.dart';
import '../../../common/styles/app_colors.dart';

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
      color: AppColors.backgroundColor,
      child: WillPopScope(
        onWillPop: () async {
          return false; // Deshabilitar navegación del sistema
        },
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.backgroundColor,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64.0),
            child: AnimatedBuilder(
              animation: _appBarAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -50 * (1 - _appBarAnimation.value)),
                  child: Opacity(
                    opacity: _appBarAnimation.value,
                    child: AppBar(
                      title: Text(
                        _getSelectedScreenTitle(_selectedIndex),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16.5,
                          letterSpacing: 0.3,
                        ),
                      ),
                      flexibleSpace: Container(
                        decoration: const BoxDecoration(
                          gradient: AppColors.policeHeroGradient,
                        ),
                      ),
                      elevation: 2.0,
                      shadowColor: Colors.black26,
                      leading: Container(
                        margin: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.menu_rounded,
                            color: Colors.white,
                            size: 22,
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
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -2),
                ),
              ],
              border: const Border(
                top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: SafeArea(
              child: NavigationBar(
                selectedIndex: _selectedIndex <= 3 ? _selectedIndex : 0,
                onDestinationSelected: (int index) {
                  if (index == 4) {
                    _scaffoldKey.currentState?.openDrawer();
                  } else {
                    setState(() {
                      _selectedIndex = index;
                    });
                  }
                },
                backgroundColor: Colors.white,
                indicatorColor: AppColors.primaryColor.withOpacity(0.12),
                height: 64,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded, color: AppColors.primaryColor),
                    label: 'Inicio',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_search_outlined),
                    selectedIcon: Icon(Icons.person_search_rounded, color: Color(0xFFE11D48)),
                    label: 'Desaparecidos',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.check_circle_outline_rounded),
                    selectedIcon: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
                    label: 'Encontrados',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.add_alert_outlined),
                    selectedIcon: Icon(Icons.add_alert_rounded, color: Color(0xFFF59E0B)),
                    label: 'Reportar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.menu_rounded),
                    label: 'Menú',
                  ),
                ],
              ),
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
        return 'SUGERENCIAS';
      case 6:
        return 'AGENDA DE COMISARÍAS';
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
      const FeedbackScreen(), // Index 5: Sugerencias
      const SearchEssaysScreen(), // Index 6: Agenda de Comisarías (desde agenda_policial.dart)
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
  late ScrollController _scrollController;

  // Paleta de colores unificada institucional PNP
  final Color _primaryColor = AppColors.primaryColor;
  final Color _secondaryColor = AppColors.primaryColorLight;
  final Color _darkPrimary = const Color(0xFF0F172A);
  final Color _darkSecondary = const Color(0xFF1E293B);
  final Color _darkAccent = AppColors.accentColor;

  // Variables para información del usuario
  String _userName = 'Cargando...';
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
    // Si el ítem seleccionado está entre los 4 últimos (índices 5, 6, 7, 8)
    if (widget.selectedIndex >= 5 && widget.selectedIndex <= 8) {
      // Hacer scroll hacia abajo para mostrar estos ítems
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
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
      // Primero intentar cargar desde SessionService
      final userData = await SessionService.getUserSession();
      print('🔍 [DEBUG] Datos de usuario desde SessionService: $userData');
      
      if (userData != null && userData['name'] != null && userData['name'] != 'Usuario') {
        // Si tenemos datos válidos en SessionService, usarlos
        if (mounted) {
          setState(() {
            _userName = userData['name'] ?? 'Usuario';
            _userPhone = userData['phoneNumber'] ?? '';
            _isLoadingUserData = false;
          });
          print('🔍 [DEBUG] Nombre de usuario establecido desde SessionService: $_userName');
        }
      } else {
        // Si no hay datos válidos en SessionService, cargar desde Firestore
        print('🔍 [DEBUG] Cargando datos desde Firestore...');
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('ciudadanos')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            final firestoreData = userDoc.data() as Map<String, dynamic>;
            final nombres = firestoreData['nombres'] ?? '';
            final apellidos = firestoreData['apellidos'] ?? '';
            final fullName = '$nombres $apellidos'.trim();
            final phoneNumber = user.phoneNumber ?? '';

            if (mounted) {
              setState(() {
                _userName = fullName.isNotEmpty ? fullName : 'Usuario';
                _userPhone = phoneNumber;
                _isLoadingUserData = false;
              });
              print('🔍 [DEBUG] Nombre de usuario establecido desde Firestore: $_userName');
              
              // Actualizar SessionService con los datos de Firestore
              await SessionService.saveUserSession(
                userId: user.uid,
                phoneNumber: phoneNumber,
                userRole: 'citizen',
                userName: _userName,
              );
            }
          }
        }
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
    _scrollController.dispose();
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
      if (contextToUse.mounted) {
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
      if (contextToUse.mounted) {
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
                          controller: _scrollController,
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
                              icon: FontAwesomeIcons.userMinus,
                              text: 'Personas\nDesaparecidas',
                              index: 1,
                              animationIndex: 1,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onIndexChanged(1);
                              },
                            ),
                            _buildModernDrawerItem(
                              icon: FontAwesomeIcons.userCheck,
                              text: 'Personas\nEncontradas',
                              index: 2,
                              animationIndex: 2,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onIndexChanged(2);
                              },
                            ),
                            _buildModernDrawerItem(
                              icon: FontAwesomeIcons.exclamationTriangle,
                              text: 'Reportar\nDesaparición',
                              index: 3,
                              animationIndex: 3,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onIndexChanged(3);
                              },
                            ),
                            _buildModernDrawerItem(
                              icon: FontAwesomeIcons.mapMarkerAlt,
                              text: 'Buscar Mi\nComisaría',
                              index: 4,
                              animationIndex: 4,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onIndexChanged(4);
                              },
                            ),
                            _buildModernDrawerItem(
                              icon: FontAwesomeIcons.lightbulb,
                              text: 'Sugerencias',
                              index: 5,
                              animationIndex: 5,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onIndexChanged(5);
                              },
                            ),
                            _buildModernDrawerItem(
                              icon: FontAwesomeIcons.addressBook,
                              text: 'Agenda de\nComisarías',
                              index: 6,
                              animationIndex: 6,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onIndexChanged(6);
                              },
                            ),
                            _buildModernDrawerItem(
                              icon: FontAwesomeIcons.graduationCap,
                              text: 'Guías\nEducativas',
                              index: 7,
                              animationIndex: 7,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onIndexChanged(7);
                              },
                            ),
                            _buildModernDrawerItem(
                              icon: FontAwesomeIcons.infoCircle,
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
                              icon: FontAwesomeIcons.signOutAlt,
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
    IconData? icon,
    required String text,
    required int index,
    required int animationIndex,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    final bool isSelected = index == widget.selectedIndex && !isLogout;
    
    // Colores vibrantes que coinciden con el dashboard
    final List<Color> vibrantColors = [
      const Color(0xFF667eea), // Dashboard - Azul principal
      const Color(0xFFE74C3C), // Personas Desaparecidas - Rojo vibrante
      const Color(0xFF27AE60), // Personas Encontradas - Verde vibrante
      const Color(0xFFF39C12), // Reportar Desaparición - Naranja vibrante
      const Color(0xFF3498DB), // Buscar Mi Comisaría - Azul vibrante
      const Color(0xFF9B59B6), // Recomendaciones - Púrpura vibrante
      const Color(0xFF1ABC9C), // Agenda de Comisarías - Verde azulado vibrante
      const Color(0xFFE91E63), // Guías Educativas - Rosa vibrante
      const Color(0xFF34495E), // Acerca de - Gris azulado vibrante
    ];

    // Iconos que coinciden con el dashboard
    final List<IconData> moduleIcons = [
      FontAwesomeIcons.chartLine,      // Dashboard
      FontAwesomeIcons.userMinus,      // Personas Desaparecidas
      FontAwesomeIcons.userCheck,      // Personas Encontradas
      FontAwesomeIcons.triangleExclamation, // Reportar Desaparición
      FontAwesomeIcons.locationDot,    // Buscar Mi Comisaría
      FontAwesomeIcons.lightbulb,      // Sugerencias
      FontAwesomeIcons.addressBook,    // Agenda de Comisarías
      FontAwesomeIcons.graduationCap,  // Guías Educativas
      FontAwesomeIcons.circleInfo,     // Acerca de
    ];

    final Color itemColor = isLogout
        ? Colors.red.shade400
        : (index >= 0 && index < vibrantColors.length
            ? vibrantColors[index]
            : _primaryColor);

    final IconData itemIcon = isLogout
        ? FontAwesomeIcons.signOutAlt
        : (index >= 0 && index < moduleIcons.length
            ? moduleIcons[index]
            : FontAwesomeIcons.questionCircle);

    return ScaleTransition(
      scale: _itemAnimations[animationIndex],
      child: AnimatedScale(
        scale: isSelected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutBack,
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
                padding: EdgeInsets.symmetric(
                  vertical: isSelected ? 14.0 : 12.0,
                  horizontal: isSelected ? 16.0 : 14.0,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.15) // Blanco transparente para seleccionado
                      : Colors.transparent, // Transparente para no seleccionado
                  borderRadius: BorderRadius.circular(16.0),
                  border: isSelected
                      ? Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        )
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 6,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    // Icono
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: itemColor.withOpacity(isSelected ? 0.3 : 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        itemIcon,
                        color: itemColor,
                        size: 18,
                      ),
                    ),
                    
                    const SizedBox(width: 14),
                    
                    // Texto
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 13, // Reducido de 15 a 13
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, // Bold para seleccionado
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                    
                    // Flecha indicadora
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Icon(
                          FontAwesomeIcons.chevronRight,
                          color: Colors.white,
                          size: 10,
                        ),
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
}
