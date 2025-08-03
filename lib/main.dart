import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'injection.dart' as di;
import 'my_app.dart';
import 'services/session_service.dart';
import 'services/agenda_policial_service.dart';
import 'services/police_notification_service.dart';
import 'services/notification_counter_service.dart';
import 'presentation/police/screens/police_missing_details_screen.dart';
import 'presentation/police/screens/police_comments_management_screen.dart';
import 'domain/entities/desaparecido.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// GlobalKey para navegación desde notificaciones
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Variable global para controlar el estado del servicio
PoliceNotificationService? _currentNotificationService;

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
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      print('🔄 [AUTH] Estado de autenticación cambió: ${user?.uid ?? 'null'}');
      
      if (user != null) {
        // Usuario autenticado, verificar tipo y configurar notificaciones
        await _checkAndConfigureNotifications();
      } else {
        // Usuario no autenticado, detener todas las notificaciones
        print('🛑 [AUTH] Usuario no autenticado, deteniendo notificaciones');
        await _safeDisposeNotificationService();
      }
    });
    
    // Inicializar servicio de agenda policial en background
    AgendaPolicialService.inicializarSincronizacion().then((_) {
      print('✅ Servicio de agenda policial inicializado');
    }).catchError((e) {
      print('⚠️ Error al inicializar agenda policial: $e');
    });
    
    runApp(MyApp());
  } catch (e) {
    print('❌ Error durante la inicialización: $e');
    runApp(MyApp());
  }
}

// Función segura para disponer el servicio de notificaciones
Future<void> _safeDisposeNotificationService() async {
  try {
    if (_currentNotificationService != null) {
      _currentNotificationService!.dispose();
      _currentNotificationService = null;
    }
  } catch (e) {
    print('⚠️ [AUTH] Error al disponer servicio de notificaciones: $e');
    _currentNotificationService = null;
  }
}

// Verificar tipo de usuario y configurar notificaciones apropiadamente
Future<void> _checkAndConfigureNotifications() async {
  try {
    print('🔍 [NOTIFICATIONS] Verificando tipo de usuario...');
    
    // Primero, detener cualquier servicio anterior de forma segura
    await _safeDisposeNotificationService();
    
    final session = await SessionService.getUserSession();
    
    if (session == null) {
      print('❌ [NOTIFICATIONS] No hay sesión activa');
      return;
    }
    
    final userRole = session['userRole'];
    final userName = session['name'] ?? 'Usuario';
    
    print('👤 [NOTIFICATIONS] Usuario: $userName');
    print('🏷️ [NOTIFICATIONS] Rol: $userRole');
    
    if (userRole == 'police') {
      print('👮 [NOTIFICATIONS] Usuario POLICÍA detectado - INICIALIZANDO notificaciones');
      await _initializePoliceNotifications();
    } else if (userRole == 'citizen') {
      print('👤 [NOTIFICATIONS] Usuario CIUDADANO detectado - NO inicializando notificaciones');
      // No hacer nada, ya se dispuso el servicio arriba
    } else {
      print('❓ [NOTIFICATIONS] Rol desconocido: $userRole - NO inicializando notificaciones');
      // No hacer nada, ya se dispuso el servicio arriba
    }
  } catch (e) {
    print('❌ [NOTIFICATIONS] Error verificando tipo de usuario: $e');
    await _safeDisposeNotificationService();
  }
}

// Inicializar notificaciones EXCLUSIVAMENTE para policías
Future<void> _initializePoliceNotifications() async {
  try {
    print('🚀 [POLICE-NOTIFICATIONS] Inicializando servicio para policía...');
    
    // Crear nueva instancia del servicio
    _currentNotificationService = PoliceNotificationService();
    
    await _currentNotificationService!.initialize(
      onNotificationTapped: (desaparecidoId) {
        print('📱 [POLICE-NOTIFICATIONS] Notificación tocada para caso: $desaparecidoId');
        // Navegar a la gestión de comentarios del caso específico
        _navigateToCommentsManagement(desaparecidoId);
      },
    );
    
    print('✅ [POLICE-NOTIFICATIONS] Servicio de notificaciones policiales inicializado exitosamente');
  } catch (e) {
    print('❌ [POLICE-NOTIFICATIONS] Error al inicializar notificaciones policiales: $e');
    _currentNotificationService = null;
  }
}

// Función para navegar a gestión de comentarios del desaparecido
Future<void> _navigateToCommentsManagement(String desaparecidoId) async {
  try {
    print('🧭 [NAVIGATION] Navegando a gestión de comentarios para caso: $desaparecidoId');
    
    // Obtener datos del desaparecido
    final doc = await FirebaseFirestore.instance
        .collection('desaparecidos')
        .doc(desaparecidoId)
        .get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final desaparecido = Desaparecido.fromMap(data, doc.id);
      
      print('✅ [NAVIGATION] Caso encontrado: ${desaparecido.nombres} ${desaparecido.apellidos}');
      
      // Navegar a la pantalla de gestión de comentarios usando el navigatorKey global
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => PoliceCommentsManagementScreen(
            desaparecido: desaparecido,
          ),
        ),
      );
      
      print('📱 [NAVIGATION] Navegación exitosa a gestión de comentarios');
    } else {
      print('❌ [NAVIGATION] Caso no encontrado: $desaparecidoId');
      // Mostrar mensaje de error al usuario si es necesario
    }
  } catch (e) {
    print('❌ [NAVIGATION] Error al navegar a gestión de comentarios: $e');
    
    // Fallback: navegar a detalles del caso
    print('🔄 [NAVIGATION] Intentando fallback a detalles del caso...');
    _navigateToMissingPersonDetails(desaparecidoId);
  }
}

// Función de fallback para navegar a detalles del desaparecido
Future<void> _navigateToMissingPersonDetails(String desaparecidoId) async {
  try {
    // Obtener datos del desaparecido
    final doc = await FirebaseFirestore.instance
        .collection('desaparecidos')
        .doc(desaparecidoId)
        .get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final desaparecido = Desaparecido.fromMap(data, doc.id);
      
      // Navegar a la pantalla de detalles usando el navigatorKey global
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => PoliceMissingDetailsScreen(
            desaparecido: desaparecido,
          ),
        ),
      );
      
      print('📱 [NAVIGATION] Navegación fallback exitosa a detalles del caso');
    }
  } catch (e) {
    print('❌ [NAVIGATION] Error en navegación fallback: $e');
  }
}
