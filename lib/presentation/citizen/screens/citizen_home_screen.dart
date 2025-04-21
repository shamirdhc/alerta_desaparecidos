import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CitizenHomeScreen extends StatelessWidget {
  const CitizenHomeScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inicio Ciudadano')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Menú Ciudadano',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Inicio'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Reportar Desaparición'),
              onTap: () {
                Navigator.pop(context);
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
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Cerrar Sesión'),
              onTap: () {
                showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('¿Cerrar Sesión?'),
                      content: const Text(
                        '¿Estás seguro de que quieres cerrar tu sesión?',
                      ),
                      actions: <Widget>[
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green,
                          ),
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pop(false); // No cerrar sesión
                          },
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          onPressed: () {
                            // Lógica de cierre de sesión (si es necesaria)
                            // Por ejemplo, podrías limpiar tokens de autenticación, etc.
                            Navigator.of(context).pop(true); // Cerrar sesión
                            Navigator.pushReplacementNamed(
                              context,
                              '/registro',
                            ); // Navegar a la pantalla de registro
                          },
                          child: const Text('Salir'),
                        ),
                      ],
                    );
                  },
                ).then((value) {
                  if (value == true) {
                    print('Ciudadano cerró sesión.');
                    // Opcional: Realizar acciones tras el cierre de sesión
                  }
                });
              },
            ),
          ],
        ),
      ),
      body: const Center(
        child: Text('Contenido de la pantalla de inicio del ciudadano'),
      ),
    );
  }
}
