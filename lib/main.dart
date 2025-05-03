import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
// --- Importa las localizaciones ---
import 'package:flutter_localizations/flutter_localizations.dart';
// --- Fin de importaciones de localizaciones ---
import 'firebase_options.dart';
import 'package:alerta_desaparecidos/injection.dart' as di;
import 'package:alerta_desaparecidos/presentation/citizen/screens/citizen_home_screen.dart';
import 'package:alerta_desaparecidos/presentation/screens/registration_screen.dart';
import 'package:alerta_desaparecidos/presentation/police/screens/police_home_screen.dart';
import 'package:alerta_desaparecidos/presentation/police/view_models/add_missing_view_model.dart';
import 'package:alerta_desaparecidos/presentation/police/view_models/manage_missing_view_model.dart';
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_missing_view_model.dart';
// --- Importa una pantalla de carga (o crea una simple) ---
import 'package:alerta_desaparecidos/presentation/common/loading_screen.dart'; // Asegúrate que este archivo exista o crea uno

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  di.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => di.locator<AddMissingViewModel>(),
        ),
        ChangeNotifierProvider(
          create: (_) => di.locator<ManageMissingViewModel>(),
        ),
        ChangeNotifierProvider(
          create: (_) => di.locator<ViewMissingViewModel>(),
        ),
      ],
      child: MaterialApp(
          title: 'Alerta Desaparecidos',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', ''),
            Locale('en', ''),
          ],
          // --- Usa StreamBuilder para determinar la pantalla inicial ---
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              // Mientras se verifica el estado de auth, muestra carga
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingScreen(); // Error occurs here
              }
              // Si hay un usuario logueado (snapshot tiene datos)
              if (snapshot.hasData) {
                // TODO: Aquí deberías determinar si es policía o ciudadano
                // y redirigir a la pantalla correcta.
                // Por ahora, redirigimos a citizen_home como ejemplo.
                // Necesitarás lógica adicional para leer el tipo de usuario
                // (quizás desde Firestore o SharedPreferences después del login).
                print("Usuario logueado: ${snapshot.data?.uid}"); // Log para depurar
                return const CitizenHomeScreen(); // O PoliceHomeScreen() según el tipo
              }
              // Si no hay usuario logueado
              print("Usuario no logueado."); // Log para depurar
              return const RegistrationScreen(); // Ir a la pantalla de registro/login
            },
          ),
          // --- Ya no necesitas initialRoute ni routes aquí si usas home ---
          // initialRoute: '/registro',
          // routes: {
          //   '/registro': (context) => const RegistrationScreen(),
          //   '/citizen_home': (context) => const CitizenHomeScreen(),
          //   '/police_home': (context) => const PoliceHomeScreen(),
          // },
          // --- Puedes mantener las rutas si las necesitas para navegación interna ---
          // --- pero la pantalla inicial la decide el StreamBuilder ---
           routes: {
             // Mantén '/registro' por si necesitas navegar a él explícitamente
             '/registro': (context) => const RegistrationScreen(),
             '/citizen_home': (context) => const CitizenHomeScreen(),
             '/police_home': (context) => const PoliceHomeScreen(),
           },
          ),
    );
  }
}

// --- Ejemplo de pantalla de carga (si no tienes una) ---
// Crea un archivo como lib/presentation/common/loading_screen.dart
// class LoadingScreen extends StatelessWidget {
//   const LoadingScreen({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       body: Center(
//         child: CircularProgressIndicator(),
//       ),
//     );
//   }
// }
