import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'injection.dart' as di;
import 'my_app.dart';
import 'services/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Inicializar inyección de dependencias de forma síncrona
    di.init();
    print('✅ Inyección de dependencias inicializada');
    
    // Inicializar Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase inicializado');
    
    // Configurar persistencia de Firebase Auth
    await SessionService.initializeFirebaseAuth();
    
    // Configurar listener de cambios de autenticación
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      print('🔄 [AUTH] Estado de autenticación cambió: ${user?.uid ?? 'null'}');
    });
    
    runApp(MyApp());
  } catch (e) {
    print('❌ Error durante la inicialización: $e');
    runApp(MyApp());
  }
}
