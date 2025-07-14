import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'common/styles/app_theme.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/initial_flow_screen.dart';
import 'presentation/screens/registration_screen.dart';
import 'presentation/citizen/screens/citizen_home_screen.dart';
import 'presentation/police/screens/police_home_screen.dart';
import 'package:alerta_desaparecidos/injection.dart' as di;
import 'package:alerta_desaparecidos/presentation/police/view_models/add_missing_view_model.dart';
import 'package:alerta_desaparecidos/presentation/police/view_models/manage_missing_view_model.dart';
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_missing_view_model.dart';
// Agregar esta importación:
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_found_view_model.dart';

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
        // Agregar esta línea:
        ChangeNotifierProvider(
          create: (_) => di.locator<ViewFoundViewModel>(),
        ),
      ],
      child: MaterialApp(
        title: 'Alerta Desaparecidos PNP',
        debugShowCheckedModeBanner: false, // ← AÑADIR ESTA LÍNEA
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        locale: const Locale('es', 'ES'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'ES'),
          Locale('en', 'US'),
        ],
        home: const SplashScreen(),
        routes: {
          '/initial_flow': (context) => const InitialFlowScreen(),
          '/registro': (context) => const RegistrationScreen(),
          '/citizen_home': (context) => const CitizenHomeScreen(),
          '/police_home': (context) => const PoliceHomeScreen(),
        },
      ),
    );
  }
}