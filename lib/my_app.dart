import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'common/styles/app_theme.dart';
import 'presentation/screens/initial_flow_screen.dart';
import 'presentation/screens/registration_screen.dart';
import 'presentation/screens/welcome_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/modern_login_screen.dart';
import 'presentation/citizen/screens/citizen_home_screen.dart';
import 'presentation/police/screens/police_home_screen.dart';
import 'presentation/superadmin/screens/superadmin_sync_monitor_screen.dart';
import 'presentation/superadmin/screens/superadmin_analytics_screen.dart';
import 'services/session_service.dart';
import 'services/logout_service.dart';
import 'services/spectator_mode_service.dart';
import 'main.dart'; // Para acceder al navigatorKey
import 'package:alerta_desaparecidos/injection.dart' as di;
import 'package:alerta_desaparecidos/presentation/police/view_models/police_manage_missing_view_model.dart';
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_missing_view_model.dart';
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_found_view_model.dart';
import 'services/theme_service.dart';
import 'services/language_service.dart';

/// Permite el arrastre táctil y con mouse/trackpad en toda la app en Web y Escritorio
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => LanguageService(),
        ),
        ChangeNotifierProvider(
          create: (_) => di.locator<PoliceManageMissingViewModel>(),
        ),
        ChangeNotifierProvider(
          create: (_) => di.locator<ViewMissingViewModel>(),
        ),
        ChangeNotifierProvider(create: (_) => di.locator<ViewFoundViewModel>()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Alerta Desaparecidos Perú',
            scrollBehavior: const AppScrollBehavior(),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: const Locale('es', 'ES'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
            home: const AuthWrapper(),
            routes: {
              '/splash': (context) => const SplashScreen(),
              '/welcome': (context) => const WelcomeScreen(),
              '/modern_login': (context) => const ModernLoginScreen(),
              '/initial_flow': (context) => const InitialFlowScreen(),
              '/registro': (context) => const RegistrationScreen(),
              '/citizen_home': (context) => const CitizenHomeScreen(),
              '/police_home': (context) => const PoliceHomeScreen(),
              '/sync_monitor': (context) => const SuperAdminSyncMonitorScreen(),
              '/superadmin_analytics': (context) => const SuperAdminAnalyticsScreen(),
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  Widget _homeWidget = const WelcomeScreen();
  bool _hasNavigated = false;
  bool _isCheckingAuth = false;

  bool _isManualLogoutActive() {
    return CitizenLogoutService.isManualLogout() || PoliceLogoutService.isManualLogout();
  }

  @override
  void initState() {
    super.initState();
    _checkAuthState();
    
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isCheckingAuth && !_hasNavigated) {
          _handleAuthStateChange(user);
        }
      });
    });
  }

  Future<String> _resolveUserRole(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && (user.email ?? '').trim().toLowerCase() == 'shamirdhc2022@gmail.com') {
        print('⭐ [AUTH] _resolveUserRole asignando rol police a Superadmin shamirdhc2022@gmail.com');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userRole', 'police');
        await prefs.setString('user_role', 'police');
        await prefs.setBool('is_superadmin', true);
        return 'police';
      }

      final prefs = await SharedPreferences.getInstance();
      final cachedRole = prefs.getString('userRole') ?? prefs.getString('user_role');
      if (cachedRole == 'citizen') {
        return 'citizen';
      }
      final session = await SessionService.getUserSession();
      if (session != null && session['userRole'] != null) {
        return session['userRole'].toString();
      }
      if (cachedRole != null && cachedRole.isNotEmpty) {
        return cachedRole;
      }
      final policeDoc = await FirebaseFirestore.instance
          .collection('policias')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 2));
      if (policeDoc.exists) {
        return 'police';
      }
      return 'citizen';
    } catch (_) {
      return 'citizen';
    }
  }

  Future<void> _handleAuthStateChange(User? user) async {
    if (_isManualLogoutActive()) {
      print('🚫 [AUTH] Logout manual detectado - manejando navegación');
      if (user == null && mounted && !_hasNavigated) {
        await SessionService.clearUserSession();
        setState(() {
          _homeWidget = const WelcomeScreen();
          _isLoading = false;
          _hasNavigated = true;
        });
        print('✅ [AUTH] Navegación a WelcomeScreen completada por logout manual');
      }
      return;
    }

    if (_isCheckingAuth || _hasNavigated) return;
    
    setState(() {
      _isCheckingAuth = true;
    });

    try {
      if (user == null) {
        await SessionService.clearUserSession();
        if (mounted && !_hasNavigated) {
          setState(() {
            _homeWidget = const WelcomeScreen();
            _isLoading = false;
            _hasNavigated = true;
          });
        }
      } else {
        print('🔍 [AUTH] Usuario detectado: ${user.uid}');
        final role = await _resolveUserRole(user.uid);
        if (mounted && !_hasNavigated) {
          setState(() {
            _homeWidget = role == 'police' ? const PoliceHomeScreen() : const CitizenHomeScreen();
            _isLoading = false;
            _hasNavigated = true;
          });
          print('✅ [AUTH] Redirigiendo automáticamente a ${role == "police" ? "PoliceHomeScreen" : "CitizenHomeScreen"}');
        }
      }
    } catch (e) {
      print('❌ [AUTH] Error manejando cambio de estado: $e');
      if (mounted && !_hasNavigated) {
        setState(() {
          _homeWidget = const WelcomeScreen();
          _isLoading = false;
          _hasNavigated = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    }
  }

  Future<void> _checkAuthState() async {
    if (_hasNavigated || _isCheckingAuth) return;
    
    setState(() {
      _isCheckingAuth = true;
    });
    // Tiempo moderado y óptimo de permanencia del SplashScreen (3.2s)
    // Permite al usuario apreciar la animación oficial sin demorarse en exceso
    final minSplashDuration = Future.delayed(const Duration(milliseconds: 3200));

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final role = await _resolveUserRole(currentUser.uid);
        await minSplashDuration;
        if (mounted && !_hasNavigated) {
          setState(() {
            _homeWidget = role == 'police' ? const PoliceHomeScreen() : const CitizenHomeScreen();
            _isLoading = false;
            _hasNavigated = true;
          });
          print('✅ [AUTH] Sesión persistente restaurada para ${currentUser.uid} (rol: $role)');
        }
        return;
      }

      // Verificar si hay sesión activa en Modo Espectador
      final prefs = await SharedPreferences.getInstance();
      final bool isSpectator = prefs.getBool('is_spectator_mode') ?? false;
      if (isSpectator) {
        await SpectatorModeService.init();
        await minSplashDuration;
        if (mounted && !_hasNavigated) {
          setState(() {
            _homeWidget = const CitizenHomeScreen();
            _isLoading = false;
            _hasNavigated = true;
          });
          print('✅ [AUTH] Sesión en Modo Espectador restaurada con éxito');
        }
        return;
      }

      await minSplashDuration;
      if (mounted && !_hasNavigated) {
        setState(() {
          _homeWidget = const WelcomeScreen();
          _isLoading = false;
          _hasNavigated = true;
        });
      }
    } catch (e) {
      print('❌ [AUTH] Error verificando estado de autenticación: $e');
      await minSplashDuration;
      if (mounted && !_hasNavigated) {
        setState(() {
          _homeWidget = const WelcomeScreen();
          _isLoading = false;
          _hasNavigated = true;
        });
      }
    } finally {
      if (mounted && !_hasNavigated) {
        setState(() {
          _isLoading = false;
          _hasNavigated = true;
          _isCheckingAuth = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _isLoading
          ? const SplashScreen(key: ValueKey('splash_screen'))
          : KeyedSubtree(
              key: const ValueKey('home_widget'),
              child: _homeWidget,
            ),
    );
  }
}

