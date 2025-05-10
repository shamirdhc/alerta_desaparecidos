import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'manage_missing_screen.dart'; // Importa la pantalla de gestión de reportes
import 'package:provider/provider.dart';
import '../view_models/manage_missing_view_model.dart';
import '../../../domain/use_cases/obtener_desaparecidos_use_case.dart';
import '../../../data/repositories/desaparecido_repository_impl.dart';
import '../../../data/data_sources/desaparecido_remote_data_source.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- AÑADIR ESTA LÍNEA
import 'package:shared_preferences/shared_preferences.dart'; // <-- AÑADIR ESTA LÍNEA
import '../../screens/registration_screen.dart'; // <-- AÑADIR PARA NAVEGACIÓN

class PoliceHomeScreen extends StatelessWidget {
  const PoliceHomeScreen({super.key});

  // --- FUNCIÓN PARA MOSTRAR DIÁLOGO DE CIERRE DE SESIÓN ---
  Future<void> _showLogoutDialog(BuildContext context) async {
    final navigator = Navigator.of(context); // Guardar Navigator antes de async
    final confirmed = await showDialog<bool>(
      context: context,
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
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('userRole');
        print('Rol de policía limpiado de SharedPreferences.');

        await FirebaseAuth.instance.signOut();
        print('Policía cerró sesión de Firebase exitosamente.');

        // Usar el navigator guardado
        if (navigator.mounted) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const RegistrationScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } catch (e) {
        print('Error durante el cierre de sesión del policía: $e');
        if (navigator.mounted) {
          ScaffoldMessenger.of(navigator.context).showSnackBar(
            SnackBar(content: Text('Error al cerrar sesión: ${e.toString()}')),
          );
        }
      }
    }
  }
  // --- FIN FUNCIÓN ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inicio Policía')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Menú Policía',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Gestionar Reportes'),
              onTap: () {
                Navigator.pop(context); // Cierra el drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ChangeNotifierProvider(
                          create: (_) {
                            final remoteDataSource = DesaparecidoRemoteDataSource(
                              FirebaseFirestore.instance,
                              FirebaseStorage
                                  .instance, // <-- Add the missing argument here
                            );
                            final repository = DesaparecidoRepositoryImpl(
                              remoteDataSource,
                            );
                            final useCase = ObtenerDesaparecidosUseCase(
                              repository,
                            );
                            return ManageMissingViewModel(useCase);
                          },
                          child: const ManageMissingScreen(),
                        ),
                  ),
                );
              },
            ),
            // *** SE HA ELIMINADO EL LISTTILE DE "BUSCAR DESAPARECIDOS" ***
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar Sesión'),
              onTap: () {
                Navigator.pop(context); // Cierra el drawer
                _showLogoutDialog(context); // Llama a la función de logout
              },
            ),
            // --- FIN OPCIÓN ---
          ],
        ),
      ),
      body: const Center(
        child: Text('Contenido de la pantalla de inicio de la policía'),
      ),
    );
  }
}
