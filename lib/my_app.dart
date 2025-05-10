import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart'; // <--- ADD THIS LINE
import 'common/styles/app_theme.dart'; // Asumiendo que tienes este archivo para temas
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/initial_flow_screen.dart';
import 'presentation/screens/registration_screen.dart';
import 'presentation/citizen/screens/citizen_home_screen.dart';
import 'presentation/police/screens/police_home_screen.dart';
import 'package:alerta_desaparecidos/injection.dart' as di;
import 'package:alerta_desaparecidos/presentation/police/view_models/add_missing_view_model.dart';
import 'package:alerta_desaparecidos/presentation/police/view_models/manage_missing_view_model.dart';
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_missing_view_model.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider( // Now this should be recognized
      providers: [
        ChangeNotifierProvider( // And this
          create: (_) => di.locator<AddMissingViewModel>(),
        ),
        ChangeNotifierProvider( // And this
          create: (_) => di.locator<ManageMissingViewModel>(),
        ),
        ChangeNotifierProvider( // And this
          create: (_) => di.locator<ViewMissingViewModel>(),
        ),
      ],
      child: MaterialApp(
        title: 'Alerta Desaparecidos PNP', // O el que uses
        theme: AppTheme.lightTheme, // Configura tus temas
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        locale: const Locale('es', 'ES'), // Configura tu locale
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'ES'), // O 'es', ''
          Locale('en', 'US'), // O 'en', ''
        ],
        home: const SplashScreen(), // SplashScreen será la pantalla inicial
        routes: {
          // Estas rutas deben coincidir con las usadas en tu app
          '/initial_flow': (context) => const InitialFlowScreen(),
          '/registro': (context) => const RegistrationScreen(),
          '/citizen_home': (context) => const CitizenHomeScreen(),
          '/police_home': (context) => const PoliceHomeScreen(),
        },
      ),
    );
  }
}