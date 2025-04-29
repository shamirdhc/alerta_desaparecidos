// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'my_app.dart';
import 'presentation/police/view_models/manage_missing_view_model.dart';
import 'data/repositories/desaparecido_repository_impl.dart';
import 'domain/repositories/desaparecido_repository.dart';
import 'domain/use_cases/obtener_desaparecidos_use_case.dart';
import 'data/data_sources/desaparecido_remote_data_source.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importa FirebaseFirestore
import 'presentation/police/view_models/add_missing_view_model.dart';
import 'domain/use_cases/reportar_desaparicion_use_case.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Configurar App Check en modo debug
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
      webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'), // Añade esto
    );

    final FirebaseStorage storage = FirebaseStorage.instance;
    storage.setMaxUploadRetryTime(Duration(seconds: 10)); // Añade timeout

    final FirebaseFirestore firestore =
        FirebaseFirestore.instance; // Añade esta línea

    // 2. Crear la instancia del RemoteDataSource, inyectando FirebaseFirestore
    final DesaparecidoRemoteDataSource remoteDataSource =
        DesaparecidoRemoteDataSource(firestore, storage);

    // 3. Crear la implementación del repositorio, inyectando el RemoteDataSource
    final DesaparecidoRepository desaparecidoRepository =
        DesaparecidoRepositoryImpl(remoteDataSource);

    // 4. Crear el Use Case para obtener desaparecidos, inyectando el repositorio
    final ObtenerDesaparecidosUseCase obtenerDesaparecidosUseCase =
        ObtenerDesaparecidosUseCase(desaparecidoRepository);

    // 5. Crear el Use Case para reportar desaparecidos, inyectando el repositorio
    final ReportarDesaparicionUseCase reportarDesaparicionUseCase =
        ReportarDesaparicionUseCase(desaparecidoRepository);

    // 6. Proporcionar los ViewModels, inyectando los Use Cases
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create:
                (context) =>
                    ManageMissingViewModel(obtenerDesaparecidosUseCase),
          ),
          ChangeNotifierProvider(
            create:
                (context) => AddMissingViewModel(
                  reportarDesaparicionUseCase,
                ), // Nuevo Provider
          ),
          // ... otros Providers si los tienes ...
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    print('Error al inicializar Firebase: $e');
  }
}
