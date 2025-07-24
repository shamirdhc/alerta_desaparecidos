import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'package:alerta_desaparecidos/injection.dart' as di;
import 'my_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options:
        DefaultFirebaseOptions
            .currentPlatform, // Agregado para cargar configuraciones de plataforma
  );
  await FirebaseAppCheck.instance.activate(

    androidProvider: AndroidProvider.debug, // O playIntegrity para producción
  );
  di.init();
  runApp(MyApp());
}
