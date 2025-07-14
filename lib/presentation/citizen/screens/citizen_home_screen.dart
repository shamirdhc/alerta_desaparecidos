import 'package:flutter/material.dart';
import 'package:alerta_desaparecidos/presentation/citizen/screens/view_missing_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:alerta_desaparecidos/injection.dart' as di;
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_missing_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alerta_desaparecidos/presentation/citizen/screens/comisarias_screen.dart';
import 'package:alerta_desaparecidos/presentation/citizen/screens/report_missing_screen.dart';
import 'chat_screen.dart';
import 'search_essays_screen.dart';
import 'view_found_screen.dart'; // Este import ya está correcto

class CitizenHomeScreen extends StatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  State<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends State<CitizenHomeScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _appBarAnimationController;
  late Animation<double> _appBarAnimation;

  @override
  void initState() {
    super.initState();
    _appBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _appBarAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _appBarAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _appBarAnimationController.forward();
  }

  @override
  void dispose() {
    _appBarAnimationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ViewMissingViewModel>(
          create: (_) => di.locator<ViewMissingViewModel>(),
        ),
      ],
      child: WillPopScope(
        onWillPop: () async {
          return true;
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
                            colors: [
                              Color(0xFF1565C0), // Azul más profundo
                              Color(0xFF0D47A1), // Azul policía más oscuro
                              Color(0xFF002171), // Azul muy oscuro
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      elevation: 8.0,
                      shadowColor: const Color(0xFF004AAB).withOpacity(0.5),
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
                        if (_selectedIndex == 0)
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
          ),
          body: _CitizenHomeScreenBody(selectedIndex: _selectedIndex),
        ),
      ),
    );
  }

  String _getSelectedScreenTitle(int selectedIndex) {
    switch (selectedIndex) {
      case 0:
        return 'PERSONAS DESAPARECIDAS'; // Actualizado
      case 1:
        return 'PERSONAS ENCONTRADAS'; // Nuevo
      case 2:
        return 'REPORTAR DESAPARICIÓN'; // Actualizado índice
      case 3:
        return 'BUSCAR MI COMISARÍA'; // Actualizado índice
      case 4:
        return 'CHAT'; // Actualizado índice
      case 5:
        return 'BUSCAR ENSAYOS'; // Actualizado índice
      default:
        return 'INICIO CIUDADANO';
    }
  }
}

class _CitizenHomeScreenBody extends StatefulWidget {
  final int selectedIndex;

  const _CitizenHomeScreenBody({required this.selectedIndex, super.key});

  @override
  State<_CitizenHomeScreenBody> createState() => _CitizenHomeScreenBodyState();
}

class _CitizenHomeScreenBodyState extends State<_CitizenHomeScreenBody> {
  final List<Widget> _screens = [
    const ViewMissingScreen(), // Index 0: Personas Desaparecidas
    const ViewFoundScreen(), // Index 1: Personas Encontradas (AGREGAR ESTA LÍNEA)
    const ReportMissingScreen(), // Index 2: Reportar Desaparición
    const ComisariasScreen(), // Index 3: Buscar Mi Comisaría
    const ChatScreen(), // Index 4: Chat
    const SearchEssaysScreen(), // Index 5: Buscar Ensayos
  ];

  @override
  Widget build(BuildContext context) {
    return IndexedStack(index: widget.selectedIndex, children: _screens);
  }
}

class CustomCitizenDrawer extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged;

  const CustomCitizenDrawer({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
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

  // Enhanced color palette
  static const List<Color> _menuItemColors = [
    Color(
      0xFFD32F2F,
    ), // Rojo para personas desaparecidas (coincide con fondo rojizo)
    Color(
      0xFF388E3C,
    ), // Verde para personas encontradas (coincide con fondo verdoso)
    Color(0xFF1976D2), // Azul para reportar
    Color(0xFF7B1FA2), // Púrpura para comisarías
    Color(0xFFFF8F00), // Naranja para chat
  ];

  @override
  void initState() {
    super.initState();

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
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeIn),
    );

    // Initialize item animations
    _itemAnimationControllers = List.generate(
      6, // 5 menu items + 1 logout
      (index) => AnimationController(
        duration: Duration(milliseconds: 400 + (index * 100)),
        vsync: this,
      ),
    );

    _itemAnimations =
        _itemAnimationControllers.map((controller) {
          return Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.elasticOut),
          );
        }).toList();

    // Start animations
    _slideAnimationController.forward();
    _fadeAnimationController.forward();

    // Stagger item animations
    for (int i = 0; i < _itemAnimationControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 200 + (i * 100)), () {
        if (mounted) {
          _itemAnimationControllers[i].forward();
        }
      });
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

  void _showLogoutDialog(BuildContext context, NavigatorState navigator) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Icon(Icons.logout, color: Colors.red.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Cerrar Sesión',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: const Text(
            '¿Estás seguro de que quieres cerrar sesión?',
            style: TextStyle(fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                elevation: 3,
              ),
              child: const Text(
                'Aceptar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('userRole');
          print('Rol de usuario limpiado de SharedPreferences.');

          print('Intentando cerrar sesión de Firebase...');
          await FirebaseAuth.instance.signOut();
          print('Ciudadano cerró sesión de Firebase exitosamente.');

          if (navigator.mounted) {
            print('Navegando a /registro usando NavigatorState...');
            navigator.pushNamedAndRemoveUntil(
              '/registro',
              (Route<dynamic> route) => false,
            );
          } else {
            print('Navigator no está montado después del logout.');
          }
        } catch (e) {
          print('Error durante el cierre de sesión: $e');
          if (navigator.mounted) {
            ScaffoldMessenger.of(navigator.context).showSnackBar(
              SnackBar(
                content: Text('Error al cerrar sesión: ${e.toString()}'),
                backgroundColor: Colors.red.shade600,
              ),
            );
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Drawer(
        width: MediaQuery.of(context).size.width * 0.28,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFF8F9FA), // Blanco muy suave
                Color(0xFFE3F2FD), // Azul muy claro
                Color(0xFFF1F8E9), // Verde muy claro
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.6, 1.0],
            ),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20.0,
                spreadRadius: 5.0,
                offset: const Offset(5, 0),
              ),
              BoxShadow(
                color: const Color(0xFF1565C0).withOpacity(0.1),
                blurRadius: 30.0,
                spreadRadius: 10.0,
                offset: const Offset(10, 0),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              // Enhanced header section - Reduced height for smaller screens
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  height: 160, // Reduced from 180 to 160
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1565C0),
                        Color(0xFF0D47A1),
                        Color(0xFF002171),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1565C0).withOpacity(0.4),
                        blurRadius: 15.0,
                        spreadRadius: 3.0,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceEvenly, // Changed from center to spaceEvenly
                      mainAxisSize:
                          MainAxisSize.min, // Add this to minimize space usage
                      children: [
                        // Enhanced hamburger menu icon - Further reduced spacing
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 10,
                            left: 20,
                          ), // Reduced from 20 to 10
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Container(
                              padding: const EdgeInsets.all(
                                6.0,
                              ), // Reduced from 8.0
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min, // Add this
                                children: [
                                  Container(
                                    width: 20, // Reduced from 25
                                    height: 2, // Reduced from 3
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 3), // Reduced from 4
                                  Container(
                                    width: 20, // Reduced from 25
                                    height: 2, // Reduced from 3
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 3), // Reduced from 4
                                  Container(
                                    width: 20, // Reduced from 25
                                    height: 2, // Reduced from 3
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 2,
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
                        // Flexible spacing instead of fixed SizedBox
                        const Spacer(flex: 1),
                        // Enhanced logo with glow effect - Further reduced size
                        Container(
                          padding: const EdgeInsets.all(
                            4.0,
                          ), // Reduced from 6.0
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.3),
                                blurRadius: 15.0, // Reduced from 20.0
                                spreadRadius: 3.0, // Reduced from 5.0
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8.0, // Reduced from 10.0
                                spreadRadius: 1.0, // Reduced from 2.0
                                offset: const Offset(0, 2), // Reduced from 3
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icons/logo_placeholder.png',
                              width: 60, // Reduced from 70
                              height: 60, // Reduced from 70
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Flexible spacing instead of fixed SizedBox
                        const Spacer(flex: 1),
                        // App title - Further reduced font size and made more compact
                        const Text(
                          'ALERTA\nDESAPARECIDOS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12, // Reduced from 14
                            fontWeight: FontWeight.bold,
                            height:
                                1.1, // Add line height to make text more compact
                            shadows: [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 3,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10), // Small bottom padding
                      ],
                    ),
                  ),
                ),
              ),

              // Enhanced menu items - More flexible layout
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15.0),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildEnhancedDrawerItem(
                        iconPath: 'assets/icons/missing-icon.png',
                        text: 'Personas\nDesaparecidas',
                        index: 0,
                        animationIndex: 0,
                        onTap: () {
                          Navigator.pop(context);
                          Future.delayed(const Duration(milliseconds: 100), () {
                            widget.onIndexChanged(0);
                          });
                        },
                      ),
                      _buildEnhancedDrawerItem(
                        iconPath: 'assets/icons/encontrados_icon.png',
                        text: 'Personas\nEncontradas',
                        index: 1,
                        animationIndex: 1,
                        onTap: () {
                          Navigator.pop(context);
                          Future.delayed(const Duration(milliseconds: 100), () {
                            widget.onIndexChanged(1);
                          });
                        },
                      ),
                      _buildEnhancedDrawerItem(
                        iconPath: 'assets/icons/reportar_desaparecido_icon.png',
                        text: 'Reportar\nDesaparición',
                        index: 2,
                        animationIndex: 2,
                        onTap: () {
                          Navigator.pop(context);
                          Future.delayed(const Duration(milliseconds: 100), () {
                            widget.onIndexChanged(2);
                          });
                        },
                      ),
                      _buildEnhancedDrawerItem(
                        iconPath: 'assets/icons/search_icon.png',
                        text: 'Buscar Mi\nComisaria',
                        index: 3,
                        animationIndex: 3,
                        onTap: () {
                          Navigator.pop(context);
                          Future.delayed(const Duration(milliseconds: 100), () {
                            widget.onIndexChanged(3);
                          });
                        },
                      ),
                      _buildEnhancedDrawerItem(
                        iconPath: 'assets/icons/chat_icon.png',
                        text: 'Chat',
                        index: 4,
                        animationIndex: 4,
                        onTap: () {
                          Navigator.pop(context);
                          Future.delayed(const Duration(milliseconds: 100), () {
                            widget.onIndexChanged(4);
                          });
                        },
                      ),
                      _buildEnhancedDrawerItem(
                        iconPath: 'assets/icons/my_study_icon.png',
                        text: 'Buscar\nEnsayos',
                        index: 5,
                        animationIndex: 5,
                        onTap: () {
                          Navigator.pop(context);
                          Future.delayed(const Duration(milliseconds: 100), () {
                            widget.onIndexChanged(5);
                          });
                        },
                      ),
                      // Add visible divider line
                      const SizedBox(height: 20),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        child: Divider(
                          color: Colors.grey.shade400,
                          thickness: 1.5,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
              ),

              // Enhanced logout button
              Padding(
                padding: const EdgeInsets.only(bottom: 15.0),
                child: ScaleTransition(
                  scale: _itemAnimations[5],
                  child: _buildEnhancedDrawerItem(
                    iconPath: 'assets/icons/logout_icon.png',
                    text: 'Cerrar\nSesión',
                    index: 6,
                    animationIndex: 5,
                    onTap: () {
                      final navigator = Navigator.of(context);
                      final currentContext = context;
                      Navigator.pop(currentContext);
                      _showLogoutDialog(currentContext, navigator);
                    },
                    isLogout: true,
                  ),
                ),
              ),
              // ... resto de elementos del menú con índices actualizados ...
              // Add visible divider line
              const SizedBox(height: 20),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Divider(
                  color: Colors.grey.shade400,
                  thickness: 1.5,
                  height: 1,
                ),
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedDrawerItem({
    required String iconPath,
    required String text,
    required int index,
    required int animationIndex,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    final bool isSelected = index == widget.selectedIndex && !isLogout;
    final Color itemColor =
        isLogout
            ? Colors.red.shade600
            : (index < _menuItemColors.length
                ? _menuItemColors[index]
                : Colors.blue.shade600);

    return ScaleTransition(
      scale: _itemAnimations[animationIndex],
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 6.0,
          horizontal: 16.0,
        ), // Reduced from 8.0
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16.0),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(
                vertical: 10.0,
              ), // Reduced from 12.0
              decoration: BoxDecoration(
                gradient:
                    isSelected
                        ? LinearGradient(
                          colors: [
                            itemColor.withOpacity(0.2),
                            itemColor.withOpacity(0.1),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                        : null,
                borderRadius: BorderRadius.circular(16.0),
                border:
                    isSelected
                        ? Border.all(
                          color: itemColor.withOpacity(0.3),
                          width: 2.0,
                        )
                        : null,
                boxShadow:
                    isSelected
                        ? [
                          BoxShadow(
                            color: itemColor.withOpacity(0.2),
                            blurRadius: 8.0,
                            spreadRadius: 2.0,
                            offset: const Offset(0, 3),
                          ),
                        ]
                        : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Enhanced icon container - Reduced size
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isSelected ? 50 : 45, // Reduced from 60/55
                    height: isSelected ? 50 : 45, // Reduced from 60/55
                    decoration: BoxDecoration(
                      gradient:
                          isSelected
                              ? LinearGradient(
                                colors: [itemColor, itemColor.withOpacity(0.8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                              : LinearGradient(
                                colors: [Colors.white, Colors.grey.shade50],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              isSelected
                                  ? itemColor.withOpacity(0.4)
                                  : Colors.black.withOpacity(0.1),
                          blurRadius: isSelected ? 12.0 : 6.0,
                          spreadRadius: isSelected ? 3.0 : 1.0,
                          offset: const Offset(0, 3),
                        ),
                        if (isSelected)
                          BoxShadow(
                            color: Colors.white.withOpacity(0.8),
                            blurRadius: 8.0,
                            spreadRadius: 1.0,
                            offset: const Offset(0, -2),
                          ),
                      ],
                      border: Border.all(
                        color:
                            isSelected
                                ? Colors.white.withOpacity(0.3)
                                : itemColor.withOpacity(0.2),
                        width: 2.0,
                      ),
                    ),
                    child: Center(
                      child: AnimatedScale(
                        scale: isSelected ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Image.asset(
                          iconPath,
                          width: isSelected ? 24 : 22, // Reduced from 28/26
                          height: isSelected ? 24 : 22, // Reduced from 28/26
                          color: isSelected ? Colors.white : itemColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6), // Reduced from 8
                  // Enhanced text - Reduced font size
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: isSelected ? 11 : 10, // Reduced from 13/12
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? itemColor : Colors.grey.shade700,
                      shadows:
                          isSelected
                              ? [
                                Shadow(
                                  offset: const Offset(1, 1),
                                  blurRadius: 2,
                                  color: Colors.black.withOpacity(0.1),
                                ),
                              ]
                              : null,
                    ),
                    child: Text(text, textAlign: TextAlign.center),
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
