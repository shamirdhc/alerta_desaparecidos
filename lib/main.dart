import 'package:alerta_desaparecidos/presentation/citizen/screens/missing_person_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'injection.dart' as di;
import 'my_app.dart';
import 'services/session_service.dart';
import 'services/agenda_policial_service.dart';
import 'services/cem_service.dart';
import 'services/police_notification_service.dart';
import 'services/fcm_notification_service.dart';
import 'presentation/police/screens/police_comments_management_screen.dart';
import 'domain/entities/desaparecido.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/services/error_telemetry_service.dart';
import 'core/services/analytics_telemetry_service.dart';

// GlobalKey para navegación desde notificaciones
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Variables globales para controlar servicios
PoliceNotificationService? _currentNotificationService;
FCMNotificationService? _fcmService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Inicializar inyección de dependencias
    di.init();
    print('✅ Inyección de dependencias inicializada');

    // Inicializar Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase inicializado');

    // Inicializar servicio de telemetría de errores
    try {
      final telemetry = ErrorTelemetryService();
      await telemetry.init();

      // Interceptar errores del framework Flutter (UI y widgets)
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        telemetry.recordError(
          exception: details.exception,
          stackTrace: details.stack,
          reason: details.context?.toString() ?? 'Flutter Framework Error',
          isFatal: false,
        );
      };

      // Interceptar errores de la plataforma y tareas asíncronas no controladas
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        telemetry.recordError(
          exception: error,
          stackTrace: stack,
          reason: 'Platform Uncaught Asynchronous Error',
          isFatal: true,
        );
        return true; // Marcado como manejado para evitar caída abrupta
      };
      print('✅ Telemetría de errores global activada');
    } catch (telemetryErr) {
      print('⚠️ Aviso al inicializar telemetría de errores: $telemetryErr');
    }

    // Configurar persistencia offline en móvil y desactivar en Web para evitar datos obsoletos en IndexedDB
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: !kIsWeb,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      print('✅ Configuración de Firestore: persistencia ${kIsWeb ? "desactivada en Web (datos en vivo)" : "activada en móvil"}');
    } catch (e) {
      print('⚠️ [Firestore Cache] Aviso al configurar caché: $e');
    }

    // Configurar persistencia de Firebase Auth
    await SessionService.initializeFirebaseAuth();

    // Renderizar la aplicación inmediatamente para que la UI y el SplashScreen oficial
    // aparezcan al instante sin demoras ni pantallas en blanco
    runApp(MyApp());

    // Inicializar servicios secundarios de red en segundo plano (no bloquean el inicio de la app)
    _initializeBackgroundServices();
  } catch (e, stack) {
    print('❌ Error durante la inicialización: $e');
    try {
      ErrorTelemetryService().recordError(
        exception: e,
        stackTrace: stack,
        reason: 'Error crítico en main()',
        isFatal: true,
      );
    } catch (_) {}
    runApp(MyApp());
  }
}

// Inicialización asíncrona de servicios en segundo plano sin congelar la interfaz
void _initializeBackgroundServices() {
  // Inicializar analítica y telemetría de instalaciones de forma silenciosa
  try {
    AnalyticsTelemetryService().init();
  } catch (e) {
    print('⚠️ [Analytics] Error al arrancar telemetría de uso: $e');
  }

  // Configurar Firebase App Check (no bloqueante)
  try {
    FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider:
          kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
      webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    ).then((_) {
      print('✅ Firebase App Check configurado en segundo plano');
    }).catchError((e) {
      print('⚠️ [AppCheck] App Check en segundo plano (modo tolerante): $e');
    });
  } catch (e) {
    print('⚠️ [AppCheck] Error activando App Check: $e');
  }

  // Configurar manejador de mensajes en segundo plano (solo en plataformas nativas)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Inicializar FCM con callbacks diferenciados (no bloqueante)
  _fcmService = FCMNotificationService();
  _fcmService!.initialize(
    onPoliceNotificationTapped: _navigateToCommentsManagement,
    onCitizenNotificationTapped: _navigateToMissingPersonDetails,
  ).then((_) {
    print('✅ FCM inicializado en segundo plano');
  }).catchError((e) {
    print('⚠️ Error al inicializar FCM en segundo plano: $e');
  });

  // Configurar listener de cambios de autenticación con protección de concurrencia
  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    print('🔄 [AUTH] Estado de autenticación cambió: ${user?.uid ?? 'null'}');

    if (user != null) {
      // En Web damos un margen de 2.5s para que la pantalla de login termine
      // de verificar el perfil y navegar antes de abrir streams de notificaciones
      if (kIsWeb) {
        Future.delayed(const Duration(milliseconds: 2500), () async {
          if (FirebaseAuth.instance.currentUser != null) {
            await _checkAndConfigureNotifications();
          }
        });
      } else {
        await _checkAndConfigureNotifications();
      }
    } else {
      print('🛑 [AUTH] Usuario no autenticado, deteniendo notificaciones');
      await _safeDisposeNotificationService();
    }
  });

  // Inicializar servicio de agenda policial
  AgendaPolicialService.inicializarSincronizacion()
      .then((_) {
        print('✅ Servicio de agenda policial inicializado');
      })
      .catchError((e) {
        print('⚠️ Error al inicializar agenda policial: $e');
      });

  // Inicializar servicio del directorio CEM nacional (MIMP)
  CemService.inicializar()
      .then((_) {
        print('✅ Directorio CEM nacional inicializado (240 sedes)');
      })
      .catchError((e) {
        print('⚠️ Error al inicializar directorio CEM: $e');
      });
}

// Función segura para disponer servicios
Future<void> _safeDisposeNotificationService() async {
  try {
    if (_currentNotificationService != null) {
      _currentNotificationService!.dispose();
      _currentNotificationService = null;
    }

    // Actualizar FCM para rol no-policía
    if (_fcmService != null) {
      await _fcmService!.updateUserRole('citizen', '');
    }
  } catch (e) {
    print('⚠️ [AUTH] Error al disponer servicios: $e');
    _currentNotificationService = null;
  }
}

// Verificar tipo de usuario y configurar notificaciones
Future<void> _checkAndConfigureNotifications() async {
  try {
    print('🔍 [NOTIFICATIONS] Verificando tipo de usuario...');

    await _safeDisposeNotificationService();

    final session = await SessionService.getUserSession();
    if (session == null) {
      print('❌ [NOTIFICATIONS] No hay sesión activa');
      return;
    }

    final userRole = session['userRole'];
    final userId = session['userId'];
    final userName = session['name'] ?? 'Usuario';

    print('👤 [NOTIFICATIONS] Usuario: $userName');
    print('🏷️ [NOTIFICATIONS] Rol: $userRole');

    // Actualizar FCM con el nuevo rol
    if (_fcmService != null) {
      await _fcmService!.updateUserRole(userRole, userId);
    }

    if (userRole == 'police') {
      print(
        '👮 [NOTIFICATIONS] Usuario POLICÍA - Inicializando notificaciones locales',
      );
      await _initializePoliceNotifications();
    } else {
      print('👤 [NOTIFICATIONS] Usuario CIUDADANO - Solo FCM activo');
    }
  } catch (e) {
    print('❌ [NOTIFICATIONS] Error verificando tipo de usuario: $e');
    await _safeDisposeNotificationService();
  }
}

// Inicializar notificaciones locales para policías
Future<void> _initializePoliceNotifications() async {
  try {
    print('🚀 [POLICE-NOTIFICATIONS] Inicializando servicio local...');

    _currentNotificationService = PoliceNotificationService();

    await _currentNotificationService!.initialize(
      onNotificationTapped: _navigateToCommentsManagement,
    );

    print('✅ [POLICE-NOTIFICATIONS] Servicio local inicializado');
  } catch (e) {
    print('❌ [POLICE-NOTIFICATIONS] Error: $e');
    _currentNotificationService = null;
  }
}

// Función para navegar a gestión de comentarios (POLICÍAS)
Future<void> _navigateToCommentsManagement(String desaparecidoId) async {
  try {
    print(
      '🧭 [NAVIGATION] Navegando POLICÍA a gestión de comentarios para caso: $desaparecidoId',
    );

    // Obtener datos del desaparecido
    final doc =
        await FirebaseFirestore.instance
            .collection('desaparecidos')
            .doc(desaparecidoId)
            .get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final desaparecido = Desaparecido.fromMap(data, doc.id);

      print(
        '✅ [NAVIGATION] Caso encontrado: ${desaparecido.nombres} ${desaparecido.apellidos}',
      );

      // Navegar a la pantalla de gestión de comentarios
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder:
              (context) =>
                  PoliceCommentsManagementScreen(desaparecido: desaparecido),
        ),
      );

      print('📱 [NAVIGATION] Navegación exitosa a gestión de comentarios');
    } else {
      print('❌ [NAVIGATION] Caso no encontrado: $desaparecidoId');
    }
  } catch (e) {
    print('❌ [NAVIGATION] Error al navegar a gestión de comentarios: $e');
  }
}

// Función para navegar a detalles de persona desaparecida (CIUDADANOS)
Future<void> _navigateToMissingPersonDetails(String desaparecidoId) async {
  try {
    print(
      '🧭 [NAVIGATION] Navegando CIUDADANO a detalles de persona desaparecida para caso: $desaparecidoId',
    );

    // Obtener datos del desaparecido
    final doc =
        await FirebaseFirestore.instance
            .collection('desaparecidos')
            .doc(desaparecidoId)
            .get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final desaparecido = Desaparecido.fromMap(data, doc.id);

      print(
        '✅ [NAVIGATION] Caso encontrado: ${desaparecido.nombres} ${desaparecido.apellidos}',
      );

      // Navegar a la pantalla de detalles para ciudadanos
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder:
              (context) =>
                  MissingPersonDetailsScreen(desaparecido: desaparecido),
        ),
      );

      print(
        '📱 [NAVIGATION] Navegación exitosa a detalles de persona desaparecida',
      );
    } else {
      print('❌ [NAVIGATION] Caso no encontrado: $desaparecidoId');
    }
  } catch (e) {
    print(
      '❌ [NAVIGATION] Error al navegar a detalles de persona desaparecida: $e',
    );
  }
}
