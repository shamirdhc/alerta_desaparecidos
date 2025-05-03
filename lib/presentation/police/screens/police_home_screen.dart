import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'manage_missing_screen.dart'; // Importa la pantalla de gestión de reportes
import 'package:provider/provider.dart';
import '../view_models/manage_missing_view_model.dart';
import '../../../domain/use_cases/obtener_desaparecidos_use_case.dart';
import '../../../data/repositories/desaparecido_repository_impl.dart';
import '../../../data/data_sources/desaparecido_remote_data_source.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PoliceHomeScreen extends StatelessWidget {
  const PoliceHomeScreen({super.key});

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
                            Navigator.of(context).pop(true); // Cerrar sesión
                            Navigator.pushReplacementNamed(
                              context,
                              '/registro',
                            ); // Navegar a registro
                          },
                          child: const Text('Salir'),
                        ),
                      ],
                    );
                  },
                ).then((value) {
                  if (value == true) {
                    print('Policía cerró sesión.');
                    // Opcional: Realizar acciones tras el cierre de sesión
                  }
                });
              },
            ),
          ],
        ),
      ),
      body: const Center(
        child: Text('Contenido de la pantalla de inicio de la policía'),
      ),
    );
  }
}
