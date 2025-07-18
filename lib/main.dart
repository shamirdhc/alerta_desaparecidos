import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
// Ya no se necesitan Provider, FirebaseAuth, SharedPreferences, ni las pantallas específicas aquí
// si la lógica se traslada a my_app.dart e InitialFlowScreen.dart
import 'firebase_options.dart';
import 'package:alerta_desaparecidos/injection.dart' as di;
import 'my_app.dart'; // Importamos la clase MyApp desde my_app.dart
// Se elimina la importación de firebase_app_check

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Se elimina la activación de FirebaseAppCheck desde aquí.
  di.init();
  runApp(const MyApp());
}
