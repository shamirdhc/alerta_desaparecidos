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
import 'services/police_notification_service.dart';
import 'services/fcm_notification_service.dart';
import 'presentation/police/screens/police_comments_management_screen.dart';
import 'domain/entities/desaparecido.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

    // Configurar Firebase App Check
    try {
      await FirebaseAppCheck.instance.activate(
        // Para Android (debug en desarrollo, playIntegrity en producción)
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        // Para iOS (debug en desarrollo, appAttest en producción)
        appleProvider:
            kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
        // Para desarrollo/debug en web
        webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
      );
      print('✅ Firebase App Check configurado');
    } catch (e) {
      print('⚠️ [AppCheck] App Check no inicializado (modo tolerante): $e');
    }

    // Configurar manejador de mensajes en segundo plano (solo en plataformas nativas)
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    // Inicializar FCM con callbacks diferenciados
    _fcmService = FCMNotificationService();
    await _fcmService!.initialize(
      onPoliceNotificationTapped: _navigateToCommentsManagement,
      onCitizenNotificationTapped: _navigateToMissingPersonDetails,
    );

    // Configurar persistencia de Firebase Auth
    await SessionService.initializeFirebaseAuth();

    // Configurar listener de cambios de autenticación
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      print('🔄 [AUTH] Estado de autenticación cambió: ${user?.uid ?? 'null'}');

      if (user != null) {
        await _checkAndConfigureNotifications();
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

    runApp(MyApp());
  } catch (e) {
    print('❌ Error durante la inicialización: $e');
    runApp(MyApp());
  }
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
