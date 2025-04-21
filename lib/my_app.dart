// lib/my_app.dart
import 'package:flutter/material.dart';
import 'common/styles/app_theme.dart';
import 'presentation/screens/splash_screen.dart'; // Importa SplashScreen
import 'presentation/screens/initial_flow_screen.dart';
import 'presentation/screens/registration_screen.dart';
import 'package:alerta_desaparecidos/presentation/citizen/screens/citizen_home_screen.dart';
import 'package:alerta_desaparecidos/presentation/police/screens/police_home_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alerta Desaparecido PNP',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(), // Ahora SplashScreen es la pantalla de inicio
      routes: {
        '/initial_flow':
            (context) =>
                const InitialFlowScreen(), // Añade una ruta para InitialFlowScreen
        '/registro': (context) => const RegistrationScreen(),
        '/ciudadano_home': (context) => const CitizenHomeScreen(),
        '/policia_home': (context) => const PoliceHomeScreen(),
        // ... otras rutas de tu aplicación ...
      },
    );
  }
}
