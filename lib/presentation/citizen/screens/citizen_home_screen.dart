import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CitizenHomeScreen extends StatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  State<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends State<CitizenHomeScreen> {
  // Índice del elemento seleccionado (por defecto "Mi Estudio Actual")
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inicio Ciudadano')),
      drawer: CustomCitizenDrawer(
        selectedIndex: _selectedIndex,
        onIndexChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      body: const Center(
        child: Text('Contenido de la pantalla de inicio del ciudadano'),
      ),
    );
  }
}

// Widget personalizado para el drawer
class CustomCitizenDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged;

  const CustomCitizenDrawer({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  // --- Funciones auxiliares para acciones ---
  final String _reportNumber = '+51948269740';

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'No se pudo realizar la llamada a $launchUri';
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    final Uri whatsappUri = Uri.parse(
      'https://wa.me/$phoneNumber?text=Hola,%20necesito%20reportar%20una%20desaparición.',
    );
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri);
    } else {
      throw 'No se pudo abrir WhatsApp';
    }
  }

  void _showReportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reportar Desaparición'),
          content: const Text('¿Cómo deseas contactarnos?'),
          actions: <Widget>[
            TextButton.icon(
              icon: const FaIcon(FontAwesomeIcons.phone),
              label: const Text('Llamar'),
              onPressed: () {
                Navigator.pop(context);
                _makePhoneCall(_reportNumber);
              },
            ),
            TextButton.icon(
              icon: const FaIcon(FontAwesomeIcons.whatsapp),
              label: const Text('WhatsApp'),
              onPressed: () {
                Navigator.pop(context);
                _openWhatsApp(_reportNumber);
              },
            ),
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('¿Cerrar Sesión?'),
          content: const Text('¿Estás seguro de que quieres cerrar tu sesión?'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.green),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                Navigator.of(context).pop(true); // Indicar que sí quiere salir
              },
              child: const Text('Salir'),
            ),
          ],
        );
      },
    ).then((value) {
      if (value == true) {
        // Lógica de cierre de sesión y navegación
        print('Ciudadano cerró sesión.');
        Navigator.pushReplacementNamed(context, '/registro');
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

            // Elementos del menú con estilo similar a la imagen
            Expanded(
              child: ListView(
                children: [
                  _buildDrawerItemWithCircle(
                    iconPath: 'assets/icons/my_study_icon.png',
                    text: 'Mi Estudio\nActual',
                    index: 0,
                    onTap: () {
                      onIndexChanged(0);
                      Navigator.pop(context);
                      print('Navegar a Mi Estudio Actual');
                    },
                  ),
                  _buildDrawerItemWithCircle(
                    iconPath: 'assets/icons/archives_icon.png',
                    text: 'Mis Archivos',
                    index: 1,
                    onTap: () {
                      onIndexChanged(1);
                      Navigator.pop(context);
                      print('Navegar a Mis Archivos');
                    },
                  ),
                  _buildDrawerItemWithCircle(
                    iconPath: 'assets/icons/profile_icon.png',
                    text: 'Mi Perfil',
                    index: 2,
                    onTap: () {
                      onIndexChanged(2);
                      Navigator.pop(context);
                      print('Navegar a Mi Perfil');
                    },
                  ),
                  _buildDrawerItemWithCircle(
                    iconPath: 'assets/icons/chat_icon.png',
                    text: 'Chat',
                    index: 3,
                    onTap: () {
                      onIndexChanged(3);
                      Navigator.pop(context);
                      print('Navegar a Chat');
                    },
                  ),
                  _buildDrawerItemWithCircle(
                    iconPath: 'assets/icons/search_icon.png',
                    text: 'Buscar\nEnsayos',
                    index: 4,
                    onTap: () {
                      onIndexChanged(4);
                      Navigator.pop(context);
                      print('Navegar a Buscar Ensayos');
                    },
                  ),
                  _buildDrawerItemWithCircle(
                    iconPath: 'assets/icons/report_icon.png',
                    text: 'Reportar\nDesaparición',
                    index: 5,
                    onTap: () {
                      onIndexChanged(5);
                      Navigator.pop(context);
                      _showReportDialog(context);
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
                index: 6,
                onTap: () {
                  onIndexChanged(6);
                  Navigator.pop(context);
                  _showLogoutDialog(context);
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
