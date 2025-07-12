import 'package:flutter/material.dart';
import 'package:alerta_desaparecidos/presentation/citizen/screens/view_missing_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:alerta_desaparecidos/injection.dart' as di;
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_missing_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- AÑADIR ESTA LÍNEA
import 'package:alerta_desaparecidos/presentation/citizen/screens/comisarias_screen.dart'; // Asegúrate que la ruta sea correcta
import 'package:alerta_desaparecidos/presentation/citizen/screens/report_missing_screen.dart'; // Nueva importación

// --- CAMBIO: Convertir a StatefulWidget ---
class CitizenHomeScreen extends StatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  State<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

// --- CAMBIO: Crear el State ---
class _CitizenHomeScreenState extends State<CitizenHomeScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
          appBar: AppBar(
            title: Center(
              child: Text(
                _getSelectedScreenTitle(_selectedIndex),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            backgroundColor: const Color(0xFF004AAB), // Azul Policía
            elevation: 4.0,
            leading: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            ),
            actions: [
              if (_selectedIndex == 0) // ViewMissingScreen
                IconButton(
                  icon: const Icon(Icons.filter_list, color: Colors.white),
                  onPressed: () {
                    // Acción para el filtro
                  },
                ),
            ],
          ),
          drawer: CustomCitizenDrawer(
            selectedIndex: _selectedIndex,
            onIndexChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
              // NO incluir Navigator.pop aquí
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
        return 'LISTA DE PERSONAS';
      case 1:
        return 'REPORTAR DESAPARICIÓN'; // Nuevo título para la pantalla de reporte
      case 2:
        return 'Buscar Mi Comisaría';
      case 3:
        return 'Chat';
      case 4:
        return 'Buscar Ensayos';
      default:
        return 'Inicio Ciudadano';
    }
  }
}

// --- CAMBIO: Hacer que _CitizenHomeScreenBody acepte el índice ---
// ESTA ES LA ÚNICA DEFINICIÓN DE _CitizenHomeScreenBody QUE DEBE EXISTIR
class _CitizenHomeScreenBody extends StatefulWidget {
  final int selectedIndex;

  const _CitizenHomeScreenBody({required this.selectedIndex, super.key});

  @override
  State<_CitizenHomeScreenBody> createState() => _CitizenHomeScreenBodyState();
}

class _CitizenHomeScreenBodyState extends State<_CitizenHomeScreenBody> {
  final List<Widget> _screens = [
    const ViewMissingScreen(),
    const ReportMissingScreen(),
    const ComisariasScreen(),
    // Mejorar pantalla de Chat
    Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline, size: 80, color: Colors.blue),
              SizedBox(height: 20),
              Text(
                'Pantalla de Chat',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Próximamente disponible',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    // Mejorar pantalla de Buscar Ensayos
    Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 80, color: Colors.green),
              SizedBox(height: 20),
              Text(
                'Buscar Ensayos',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Próximamente disponible',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return IndexedStack(index: widget.selectedIndex, children: _screens);
  }
}

// Widget personalizado para el drawer (sin cambios estructurales aquí,
// pero asegúrate que onIndexChanged llame a la función pasada)
class CustomCitizenDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged; // Definición correcta del parámetro

  const CustomCitizenDrawer({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  void _showLogoutDialog(BuildContext context, NavigatorState navigator) {
    showDialog<bool>(
      context: context, // Usa el context para mostrar el diálogo
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: const Text('Aceptar'),
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
          final prefs =
              await SharedPreferences.getInstance(); // <-- OBTENER INSTANCIA
          await prefs.remove('userRole'); // <-- LIMPIAR ROL
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
            // Usar navigator.mounted aquí también
            ScaffoldMessenger.of(navigator.context).showSnackBar(
              // Usar navigator.context
              SnackBar(
                content: Text('Error al cerrar sesión: ${e.toString()}'),
              ),
            );
          }
        }
      }
    });
  }
  // --- Fin de funciones auxiliares ---

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width:
          MediaQuery.of(context).size.width *
          0.25, // Drawer más estrecho como en la imagen
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        child: Column(
          children: <Widget>[
            // Espacio para el logo y la curva
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(30),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Hamburger menu icon
                    Padding(
                      padding: const EdgeInsets.only(top: 40, left: 20),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Column(
                          children: [
                            Container(
                              width: 30,
                              height: 3,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 5),
                            Container(
                              width: 30,
                              height: 3,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 5),
                            Container(
                              width: 30,
                              height: 3,
                              color: Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Logo circular - Usando tu imagen
                    Image.asset(
                      'assets/icons/logo_placeholder.png',
                      width: 70,
                      height: 70,
                    ),
                  ],
                ),
              ),
            ),

            // Dentro de la clase CustomCitizenDrawer, método build

            // Elementos del menú con estilo similar a la imagen
            Expanded(
              child: ListView(
                children: [
                  _buildDrawerItemWithCircle(
                    iconPath: 'assets/icons/missing-icon.png',
                    text: 'Personas\nDesaparecidas',
                    index: 0,
                    onTap: () {
                      Navigator.pop(context);
                      Future.delayed(const Duration(milliseconds: 100), () {
                        onIndexChanged(0);
                      });
                    },
                  ),
                  _buildDrawerItemWithCircle(
                    iconPath: 'assets/icons/reportar_desaparecido_icon.png',
                    text: 'Reportar\nDesaparición',
                    index: 1,
                    onTap: () {
                      Navigator.pop(context);
                      Future.delayed(const Duration(milliseconds: 100), () {
                        onIndexChanged(1);
                      });
                    },
                  ),
                  _buildDrawerItemWithCircle(
                    iconPath: 'assets/icons/encontrados_icon.png',
                    text: 'Buscar Mi\nComisaria',
                    index: 2,
                    onTap: () {
                      Navigator.pop(context);
                      Future.delayed(const Duration(milliseconds: 100), () {
                        onIndexChanged(2);
                      });
                    },
                  ),
                  _buildDrawerItemWithCircle(
                    iconPath: 'assets/icons/chat_icon.png',
                    text: 'Chat',
                    index: 3,
                    onTap: () {
                      Navigator.pop(context);
                      Future.delayed(const Duration(milliseconds: 100), () {
                        onIndexChanged(3);
                      });
                    },
                  ),
                  _buildDrawerItemWithCircle(
                    iconPath: 'assets/icons/search_icon.png',
                    text: 'Buscar\nEnsayos',
                    index: 4,
                    onTap: () {
                      Navigator.pop(context);
                      Future.delayed(const Duration(milliseconds: 100), () {
                        onIndexChanged(4);
                      });
                    },
                  ),
                ],
              ),
            ),

            // Botón de cerrar sesión en la parte inferior
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: _buildDrawerItemWithCircle(
                iconPath: 'assets/icons/logout_icon.png',
                text: 'Cerrar\nSesión',
                index: 6, // Índice para estado visual si es necesario
                onTap: () {
                  final navigator = Navigator.of(context);
                  final currentContext = context;
                  // NO llama a onIndexChanged(6)
                  Navigator.pop(currentContext);
                  _showLogoutDialog(currentContext, navigator);
                },
                textColor: Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para construir cada elemento del menú con círculo
  Widget _buildDrawerItemWithCircle({
    required String iconPath,
    required String text,
    required int index,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    final bool isSelected = index == selectedIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Círculo con icono - cambia de color según selección
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isSelected ? Colors.green : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      red: 0,
                      green: 0,
                      blue: 0,
                      alpha: 0.1,
                    ),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Image.asset(
                  iconPath,
                  width: 24,
                  height: 24,
                  // Eliminamos el parámetro color para mantener la imagen original
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Texto debajo del círculo
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color:
                    textColor ?? (isSelected ? Colors.green : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
