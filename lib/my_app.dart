import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'common/styles/app_theme.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/initial_flow_screen.dart';
import 'presentation/screens/registration_screen.dart';
import 'presentation/screens/welcome_screen.dart';
import 'presentation/screens/modern_login_screen.dart';
import 'presentation/citizen/screens/citizen_home_screen.dart';
import 'presentation/police/screens/police_home_screen.dart';
import 'services/session_service.dart';
import 'services/connectivity_service.dart';
import 'services/logout_service.dart';
import 'main.dart'; // Para acceder al navigatorKey
import 'package:alerta_desaparecidos/injection.dart' as di;
import 'package:alerta_desaparecidos/presentation/police/view_models/add_missing_view_model.dart';
import 'package:alerta_desaparecidos/presentation/police/view_models/manage_missing_view_model.dart';
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_missing_view_model.dart';
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
        ChangeNotifierProvider(create: (_) => di.locator<ViewFoundViewModel>()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey, // Agregar el navigatorKey
        title: 'Alerta Desaparecidos PNP',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        locale: const Locale('es', 'ES'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
        home: const AuthWrapper(),
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
          '/modern_login': (context) => const ModernLoginScreen(),
          '/initial_flow': (context) => const InitialFlowScreen(),
          '/registro': (context) => const RegistrationScreen(),
          '/citizen_home': (context) => const CitizenHomeScreen(),
          '/police_home': (context) => const PoliceHomeScreen(),
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
  bool _hasNavigated = false; // Prevenir navegaciones múltiples
  bool _isCheckingAuth = false; // Prevenir verificaciones múltiples

  // NUEVO: Helper para determinar qué servicio de logout usar
  bool _isManualLogoutActive() {
    // Verificar ambos servicios para determinar si hay logout manual activo
    return CitizenLogoutService.isManualLogout() || PoliceLogoutService.isManualLogout();
  }

  @override
  void initState() {
    super.initState();
    _checkAuthState();
    
    // Escuchar cambios en el estado de autenticación con debounce
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      // Agregar un pequeño delay para evitar múltiples llamadas rápidas
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isCheckingAuth && !_hasNavigated) {
          _handleAuthStateChange(user);
        }
      });
    });
  }

  Future<void> _handleAuthStateChange(User? user) async {
    // NUEVO: Si es un logout manual, manejar la navegación pero no resetear el flag
    if (_isManualLogoutActive()) {
      print('🚫 [AUTH] Logout manual detectado - manejando navegación');
      
      if (user == null && mounted && !_hasNavigated) {
        // Usuario deslogueado por logout manual - navegar a Welcome
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
        // Usuario deslogueado - siempre ir a Welcome
        await SessionService.clearUserSession();
        if (mounted && !_hasNavigated) {
          setState(() {
            _homeWidget = const WelcomeScreen();
            _isLoading = false;
            _hasNavigated = true;
          });
        }
      } else {
        // Usuario logueado - PERO NO navegar automáticamente
        // Solo verificar y limpiar sesión si es necesario
        print('🔍 [AUTH] Usuario detectado: ${user.uid}');
        
        final session = await SessionService.getUserSession();
        if (session != null) {
          // Validar que el usuario aún existe en la base de datos
          final isValid = await SessionService.validateUserInDatabase(
            session['userId'],
            session['userRole'],
          );

          if (!isValid) {
            // Sesión inválida - limpiar y ir a Welcome
            print('❌ [AUTH] Sesión inválida - limpiando');
            await SessionService.clearUserSession();
            await FirebaseAuth.instance.signOut();
            if (mounted && !_hasNavigated) {
              setState(() {
                _homeWidget = const WelcomeScreen();
                _isLoading = false;
                _hasNavigated = true;
              });
            }
          } else {
            // Sesión válida - PERO mantener en Welcome Screen
            // El usuario debe hacer clic en "Iniciar Sesión" para continuar
            print('✅ [AUTH] Sesión válida encontrada - mantener en Welcome');
            if (mounted && !_hasNavigated) {
              setState(() {
                _homeWidget = const WelcomeScreen();
                _isLoading = false;
                _hasNavigated = true;
              });
            }
          }
        } else {
          // No hay sesión guardada - ir a Welcome
          print('ℹ️ [AUTH] No hay sesión guardada - ir a Welcome');
          if (mounted && !_hasNavigated) {
            setState(() {
              _homeWidget = const WelcomeScreen();
              _isLoading = false;
              _hasNavigated = true;
            });
          }
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
      setState(() {
        _isCheckingAuth = false;
      });
    }
  }

  Future<void> _checkAuthState() async {
    if (_hasNavigated || _isCheckingAuth) return;
    
    setState(() {
      _isCheckingAuth = true;
    });
    
    try {
      // Verificar conectividad con timeout
      final hasConnection = await ConnectivityService.hasInternetConnection()
          .timeout(const Duration(seconds: 10), onTimeout: () => false);
      
      if (!hasConnection) {
        setState(() {
          _isLoading = false;
          _homeWidget = const WelcomeScreen();
          _hasNavigated = true;
        });
        return;
      }

      // CAMBIO PRINCIPAL: Siempre ir a WelcomeScreen primero
      print('ℹ️ [AUTH] Navegando a pantalla de bienvenida');
      _homeWidget = const WelcomeScreen();
      
      // Opcional: Verificar sesión en segundo plano para acelerar el login
      final session = await SessionService.getUserSession()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      final currentUser = FirebaseAuth.instance.currentUser;

      if (session != null && currentUser != null) {
        print('🔍 [AUTH] Sesión encontrada en segundo plano - Usuario: ${currentUser.uid}, Rol: ${session['userRole']}');
        // La sesión existe, pero el usuario debe hacer clic en "Iniciar Sesión" para continuar
      } else {
        print('ℹ️ [AUTH] No hay sesión guardada');
        // Limpiar cualquier dato residual
        if (currentUser != null) {
          await FirebaseAuth.instance.signOut();
        }
        await SessionService.clearUserSession();
      }
      
    } catch (e) {
      print('❌ [AUTH] Error verificando estado de autenticación: $e');
      _homeWidget = const WelcomeScreen();
      
      // Limpiar sesión en caso de error crítico
      try {
        await SessionService.clearUserSession();
        await FirebaseAuth.instance.signOut();
      } catch (cleanupError) {
        print('❌ [AUTH] Error limpiando sesión: $cleanupError');
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
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF667eea),
                const Color(0xFF764ba2),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Image.asset(
                      'assets/icons/logo_pnp_policia.png',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                CircularProgressIndicator(
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Verificando sesión...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _homeWidget;
  }
}
