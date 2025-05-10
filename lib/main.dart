import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
// Ya no se necesitan Provider, FirebaseAuth, SharedPreferences, ni las pantallas específicas aquí
// si la lógica se traslada a my_app.dart e InitialFlowScreen.dart
import 'firebase_options.dart';
import 'package:alerta_desaparecidos/injection.dart' as di;
import 'my_app.dart'; // Importamos la clase MyApp desde my_app.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  di.init();
  runApp(const MyApp()); // Esto ahora usará la MyApp de my_app.dart
}
