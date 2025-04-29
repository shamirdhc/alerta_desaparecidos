import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/desaparecido.dart';
import 'package:intl/intl.dart';
import '../view_models/missing_details_view_model.dart';
import '../../../domain/use_cases/marcar_como_encontrado_use_case.dart';
import '../../../data/repositories/desaparecido_repository_impl.dart';
import '../../../data/data_sources/desaparecido_remote_data_source.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../common/state_enum.dart';

class MissingDetailsScreen extends StatelessWidget {
  final Desaparecido desaparecido;

  const MissingDetailsScreen({super.key, required this.desaparecido});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final desaparecidoRemoteDataSource = DesaparecidoRemoteDataSource(
          FirebaseFirestore.instance,
          FirebaseStorage.instance, // Añadir este parámetro faltante
        );
        final desaparecidoRepository = DesaparecidoRepositoryImpl(
          desaparecidoRemoteDataSource,
        );
        final marcarComoEncontradoUseCase = MarcarComoEncontradoUseCase(
          desaparecidoRepository,
        );
        return MissingDetailsViewModel(marcarComoEncontradoUseCase);
      },
      child: Consumer<MissingDetailsViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.marcarEncontradoState == RequestState.Loaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Persona marcada como encontrada'),
                  duration: Duration(seconds: 2),
                ),
              );
              viewModel
                  .resetState(); // Resetear el estado para futuras acciones
              Navigator.pop(context); // Navegar de vuelta después del SnackBar
            });
          }
          return Scaffold(
            // appBar: AppBar(title: Text(desaparecido.nombreCompleto)), // LÍNEA ANTERIOR
            appBar: AppBar(
              title: Text('${desaparecido.nombres} ${desaparecido.apellidos}'),
            ), // LÍNEA CORREGIDA
            body: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (desaparecido.fotoUrl != null)
                        Image.network(desaparecido.fotoUrl!),
                      const SizedBox(height: 16.0),
                      Text(
                        // LÍNEA CORREGIDA
                        '${desaparecido.nombres} ${desaparecido.apellidos}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8.0),
                      if (desaparecido.sexo != null)
                        Text('Sexo: ${desaparecido.sexo}'),
                      if (desaparecido.dni != null)
                        Text('DNI: ${desaparecido.dni}'),
                      if (desaparecido.telefonoContacto != null)
                        Text(
                          'Teléfono Contacto: ${desaparecido.telefonoContacto}',
                        ),
                      if (desaparecido.fechaDesaparicion != null)
                        Text(
                          'Fecha de Desaparición: ${DateFormat('dd/MM/yyyy HH:mm').format(desaparecido.fechaDesaparicion!)}',
                        ),
                      // Reemplazo del sistema de coordenadas por Ubigeo
                      if (desaparecido.departamento != null)
                        Text('Departamento: ${desaparecido.departamento}'),
                      if (desaparecido.provincia != null)
                        Text('Provincia: ${desaparecido.provincia}'),
                      if (desaparecido.distrito != null)
                        Text('Distrito: ${desaparecido.distrito}'),
                      const SizedBox(height: 16.0),
                      if (desaparecido.detallesAdicionales != null)
                        Text(
                          'Detalles Adicionales:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      if (desaparecido.detallesAdicionales != null)
                        Text(desaparecido.detallesAdicionales!),
                      const SizedBox(height: 60.0),
                      if (viewModel.marcarEncontradoState == RequestState.Error)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            viewModel.mensajeMarcarEncontrado,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed:
                          viewModel.marcarEncontradoState ==
                                      RequestState.Loading ||
                                  viewModel.marcarEncontradoState ==
                                      RequestState.Loaded
                              ? null
                              : () async {
                                await viewModel.marcarComoEncontrado(
                                  desaparecido.id!,
                                );
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            viewModel.marcarEncontradoState ==
                                    RequestState.Loaded
                                ? Colors.grey
                                : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child:
                          viewModel.marcarEncontradoState ==
                                  RequestState.Loading
                              ? const CircularProgressIndicator()
                              : Text(
                                viewModel.marcarEncontradoState ==
                                        RequestState.Loaded
                                    ? 'Marcado como Encontrado'
                                    : 'Marcar como Encontrado',
                              ),
                    ),
                  ),
                ),
                if (viewModel.marcarEncontradoState == RequestState.Loading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          );
        },
      ),
    );
  }
}
