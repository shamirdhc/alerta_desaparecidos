import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_service.dart';
import 'notification_history_service.dart';
import 'notification_counter_service.dart';

class FCMNotificationService {
  static final FCMNotificationService _instance =
      FCMNotificationService._internal();
  factory FCMNotificationService() => _instance;
  FCMNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _currentToken;
  String? _currentUserRole;
  String? _currentUserId;
  Function(String)? _onPoliceNotificationTapped;
  Function(String)? _onCitizenNotificationTapped;
  
  // Servicios de historial y contador
  NotificationHistoryService? _historyService;
  NotificationCounterService? _counterService;
  bool _servicesInitialized = false;

  // Inicializar FCM con callbacks diferenciados
  Future<void> initialize({
    Function(String)? onPoliceNotificationTapped,
    Function(String)? onCitizenNotificationTapped,
  }) async {
    try {
      print('🚀 [FCM] Inicializando Firebase Cloud Messaging...');
      
      _onPoliceNotificationTapped = onPoliceNotificationTapped;
      _onCitizenNotificationTapped = onCitizenNotificationTapped;
      
      // Inicializar servicios de historial y contador
      await _initializeNotificationServices();
      
      // Solicitar permisos
      await _requestPermissions();
      
      // Configurar notificaciones locales
      await _initializeLocalNotifications();
      
      // Obtener token FCM
      await _getAndSaveToken();
      
      // Configurar listeners
      _setupMessageHandlers();
      
      print('✅ [FCM] Firebase Cloud Messaging inicializado exitosamente');
    } catch (e) {
      print('❌ [FCM] Error al inicializar FCM: $e');
    }
  }

  // Inicializar servicios de notificaciones
  Future<void> _initializeNotificationServices() async {
    try {
      // Obtener información del usuario actual
      final session = await SessionService.getUserSession();
      if (session != null) {
        _currentUserRole = session['userRole'];
        _currentUserId = session['userId'];
        
        // Solo inicializar servicios para policías
        if (_currentUserRole == 'police') {
          print('👮 [FCM] Inicializando servicios para policía...');
          
          // Inicializar servicio de historial
          _historyService = NotificationHistoryService();
          await _historyService!.initialize();
          print('📚 [FCM] Servicio de historial inicializado');
          
          // Inicializar servicio de contador
          _counterService = NotificationCounterService();
          await _counterService!.initialize();
          print('📊 [FCM] Servicio de contador inicializado');
          
          _servicesInitialized = true;
        } else {
          print('👤 [FCM] Usuario ciudadano - servicios de historial no requeridos');
        }
      }
    } catch (e) {
      print('❌ [FCM] Error al inicializar servicios de notificaciones: $e');
      _servicesInitialized = false;
    }
  }

  // Solicitar permisos de notificación
  Future<void> _requestPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    print('🔐 [FCM] Permisos de notificación: ${settings.authorizationStatus}');
  }

  // Configurar notificaciones locales
  Future<void> _initializeLocalNotifications() async {
    if (kIsWeb) {
      print('🌐 [FCM] Notificaciones locales omitidas en Web');
      return;
    }
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          // Usar la nueva lógica de navegación diferenciada
          _handleNotificationTapFromPayload(response.payload!);
        }
      },
    );

    // Crear canales mejorados para Android
    const urgentChannel = AndroidNotificationChannel(
      'police_notifications',
      '🚨 Notificaciones Policiales Urgentes',
      description: 'Notificaciones críticas para personal policial sobre casos activos',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFFD32F2F),
      showBadge: true,
    );

    const generalChannel = AndroidNotificationChannel(
      'police_general',
      '📋 Notificaciones Policiales Generales',
      description: 'Notificaciones generales para personal policial',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Nuevo canal para alertas de personas desaparecidas
    const missingPersonChannel = AndroidNotificationChannel(
      'missing_person_alerts',
      '🆘 Alertas de Personas Desaparecidas',
      description: 'Notificaciones sobre nuevas personas desaparecidas para todos los usuarios',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFFFF6B35),
      showBadge: true,
    );

    final androidPlugin =
        _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    await androidPlugin?.createNotificationChannel(urgentChannel);
    await androidPlugin?.createNotificationChannel(generalChannel);
    await androidPlugin?.createNotificationChannel(missingPersonChannel);
  }

  // Obtener y guardar token FCM
  Future<void> _getAndSaveToken() async {
    try {
      _currentToken = await _firebaseMessaging.getToken();
      print('📱 [FCM] Token obtenido: ${_currentToken?.substring(0, 20)}...');
      
      // Guardar token en Firestore según el rol del usuario
      await _saveTokenToFirestore();
      
      // Escuchar cambios de token
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('🔄 [FCM] Token actualizado');
        _currentToken = newToken;
        _saveTokenToFirestore();
      });
      
    } catch (e) {
      print('❌ [FCM] Error al obtener token: $e');
    }
  }

  // Guardar token en Firestore
  Future<void> _saveTokenToFirestore() async {
    try {
      final session = await SessionService.getUserSession();
      if (session == null || _currentToken == null) return;

      _currentUserRole = session['userRole'];
      _currentUserId = session['userId'];

      if (_currentUserRole == 'police') {
        // Guardar token en la colección 'policias'
        await FirebaseFirestore.instance
            .collection('policias')
            .doc(_currentUserId)
            .update({
          'fcmToken': _currentToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('✅ [FCM] Token guardado para policía: $_currentUserId');
      } else if (_currentUserRole == 'citizen') {
        // Guardar token en la colección 'ciudadanos'
        await FirebaseFirestore.instance
            .collection('ciudadanos')
            .doc(_currentUserId)
            .update({
          'fcmToken': _currentToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('✅ [FCM] Token guardado para ciudadano: $_currentUserId');
      }
    } catch (e) {
      print('❌ [FCM] Error al guardar token: $e');
    }
  }

  // Configurar manejadores de mensajes
  void _setupMessageHandlers() {
    // Mensaje recibido cuando la app está en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 [FCM] Mensaje recibido en primer plano: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Mensaje tocado cuando la app está en segundo plano
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('👆 [FCM] Notificación tocada desde segundo plano');
      _handleNotificationTap(message);
    });

    // Verificar si la app se abrió desde una notificación
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('🚀 [FCM] App abierta desde notificación');
        _handleNotificationTap(message);
      }
    });
  }

  // Manejar toque de notificación desde payload
  void _handleNotificationTapFromPayload(String missingPersonId) {
    print('👆 [FCM] Procesando toque de notificación desde payload - Rol: $_currentUserRole');

    // Navegación diferenciada según el rol del usuario
    if (_currentUserRole == 'police') {
      // POLICÍAS → Gestión de comentarios
      print('👮 [FCM] Navegando policía a gestión de comentarios');
      if (_onPoliceNotificationTapped != null) {
        _onPoliceNotificationTapped!(missingPersonId);
      }
    } else {
      // CIUDADANOS → Detalles de persona desaparecida
      print('👤 [FCM] Navegando ciudadano a detalles de persona desaparecida');
      if (_onCitizenNotificationTapped != null) {
        _onCitizenNotificationTapped!(missingPersonId);
      }
    }
  }

  // Manejar toque de notificación con navegación diferenciada
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final notificationType = data['type'] ?? 'unknown';
    final missingPersonId = data['missingPersonId'] ?? data['desaparecidoId'];
    
    if (missingPersonId == null) {
      print('❌ [FCM] No se encontró ID de persona desaparecida en la notificación');
      return;
    }

    print('👆 [FCM] Procesando toque de notificación - Tipo: $notificationType, Rol: $_currentUserRole');

    // Usar la función común para manejar la navegación
    _handleNotificationTapFromPayload(missingPersonId);
  }

  // Mostrar notificación local mejorada
  Future<void> _showLocalNotification(RemoteMessage message) async {
    if (kIsWeb) {
      print('🌐 [FCM] Mensaje recibido en Web (omitida notificación local nativa): ${message.notification?.title}');
      return;
    }
    final notification = message.notification;
    if (notification == null) return;

    final data = message.data;
    final notificationType = data['type'] ?? 'unknown';

    if (notificationType == 'new_missing_person') {
      await _showMissingPersonNotification(message);
    } else if (notificationType == 'comment') {
      await _showCommentNotification(message);
    } else {
      await _showGenericNotification(message);
    }
  }

  // Guardar notificación en historial (solo para policías)
  Future<void> _saveNotificationToHistory({
    required String desaparecidoId,
    required String desaparecidoNombre,
    required String title,
    required String body,
    required String departamento,
    String? commentId,
  }) async {
    try {
      // Solo guardar en historial si es policía y los servicios están inicializados
      if (_currentUserRole == 'police' && _servicesInitialized && _historyService != null) {
        await _historyService!.addNotification(
          desaparecidoId: desaparecidoId,
          desaparecidoNombre: desaparecidoNombre,
          title: title,
          body: body,
          departamento: departamento,
          commentId: commentId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        );
        
        // Incrementar contador de notificaciones no leídas
        if (_counterService != null && !_counterService!.isDisposed) {
          await _counterService!.incrementUnreadCount();
        }
        
        print('📝 [FCM] Notificación guardada en historial: $title');
      }
    } catch (e) {
      print('❌ [FCM] Error al guardar notificación en historial: $e');
    }
  }

  // Mostrar notificación de nueva persona desaparecida
  Future<void> _showMissingPersonNotification(RemoteMessage message) async {
    final data = message.data;
    
    final nombreCompleto = data['nombreCompleto'] ?? 'Persona desaparecida';
    final edad = data['edad'] ?? '';
    final genero = data['genero'] ?? '';
    final ubicacion = data['ubicacion'] ?? 'Ubicación no especificada';
    final fechaDesaparicion = data['fechaDesaparicion'] ?? '';
    final fechaRegistro = data['fechaRegistro'] ?? '';
    final telefono = data['telefono'] ?? '';
    final descripcion = data['descripcion'] ?? '';
    final circunstancias = data['circunstancias'] ?? '';
    final fechaNotificacion = data['fechaNotificacion'] ?? '';
    final departamento = data['departamento'] ?? '';
    final missingPersonId = data['missingPersonId'] ?? data['desaparecidoId'] ?? '';

    // Crear título y cuerpo para la notificación
    final title = '🆘 NUEVA PERSONA DESAPARECIDA';
    final body = '👤 $nombreCompleto${edad.isNotEmpty ? ' ($edad años)' : ''}\n📍 $ubicacion\n⚠️ Tu ayuda es importante';

    // Guardar en historial si es policía
    await _saveNotificationToHistory(
      desaparecidoId: missingPersonId,
      desaparecidoNombre: nombreCompleto,
      title: title,
      body: body,
      departamento: departamento,
    );

    // Crear texto expandido mejorado
    final bigText = '''
🆘 NUEVA PERSONA DESAPARECIDA

👤 NOMBRE: $nombreCompleto
${edad.isNotEmpty ? '🎂 EDAD: $edad años' : ''}
${genero.isNotEmpty ? '⚧ GÉNERO: $genero' : ''}
📍 UBICACIÓN: $ubicacion
${fechaDesaparicion.isNotEmpty ? '📅 FECHA DESAPARICIÓN: $fechaDesaparicion' : ''}
${telefono.isNotEmpty ? '📞 CONTACTO: $telefono' : ''}
${fechaRegistro.isNotEmpty ? '📋 REGISTRADO: $fechaRegistro' : ''}

${descripcion.isNotEmpty ? '📝 DESCRIPCIÓN:\n$descripcion\n' : ''}
${circunstancias.isNotEmpty ? '⚠️ CIRCUNSTANCIAS:\n$circunstancias\n' : ''}

🚨 Si tienes información sobre esta persona, contacta inmediatamente a las autoridades.

📞 Línea de emergencia: 105
📞 Policía Nacional: 911

🕐 Notificación: $fechaNotificacion
    ''';

    final androidDetails = AndroidNotificationDetails(
      'missing_person_alerts',
      '🆘 Alertas de Personas Desaparecidas',
      channelDescription: 'Notificaciones sobre nuevas personas desaparecidas',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: const Color(0xFFFF6B35),
      colorized: true,
      autoCancel: false,
      ongoing: false,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 250, 500, 250, 500]),
      enableLights: true,
      ledColor: const Color(0xFFFF6B35),
      ledOnMs: 1000,
      ledOffMs: 500,
      ticker: '🆘 Nueva persona desaparecida: $nombreCompleto',
      styleInformation: BigTextStyleInformation(
        bigText,
        htmlFormatBigText: false,
        contentTitle: '🆘 NUEVA PERSONA DESAPARECIDA',
        htmlFormatContentTitle: false,
        summaryText: '📍 $ubicacion${edad.isNotEmpty ? ' • $edad años' : ''}',
        htmlFormatSummaryText: false,
      ),
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      timeoutAfter: 3600000, // 1 hora
      actions: const [
        AndroidNotificationAction(
          'view_details',
          '👁️ Ver Detalles',
          icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'share_info',
          '📤 Compartir',
          icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          showsUserInterface: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
      subtitle: '🆘 Nueva Persona Desaparecida',
      threadIdentifier: 'missing_person_alerts',
      categoryIdentifier: 'MISSING_PERSON_CATEGORY',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      details,
      payload: missingPersonId,
    );
  }

  // Mostrar notificación de comentario
  Future<void> _showCommentNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    
    final nombreCompleto = data['nombreCompleto'] ?? 'Persona desaparecida';
    final phoneNumber = data['phoneNumber'] ?? 'Número desconocido';
    final comentarioCompleto = data['comentarioCompleto'] ?? notification?.body ?? '';
    final ubicacion = data['ubicacion'] ?? 'Ubicación no especificada';
    final fechaHora = data['fechaHora'] ?? DateTime.now().toString();
    final departamento = data['departamento'] ?? '';
    final edad = data['edad'] ?? '';
    final genero = data['genero'] ?? '';
    final missingPersonId = data['missingPersonId'] ?? data['desaparecidoId'] ?? '';

    // Crear título y cuerpo para la notificación
    final title = '🚨 NUEVO COMENTARIO - CASO ACTIVO';
    final body = '👤 $nombreCompleto\n📱 $phoneNumber\n💬 ${comentarioCompleto.length > 50 ? comentarioCompleto.substring(0, 50) + '...' : comentarioCompleto}';

    // Guardar en historial si es policía
    await _saveNotificationToHistory(
      desaparecidoId: missingPersonId,
      desaparecidoNombre: nombreCompleto,
      title: title,
      body: body,
      departamento: departamento,
      commentId: data['commentId'],
    );

    // Crear texto expandido para BigText
    final bigText = '''
📋 CASO: $nombreCompleto${edad.isNotEmpty ? ' ($edad años)' : ''}${genero.isNotEmpty ? ' - $genero' : ''}

📱 CONTACTO: $phoneNumber

📍 UBICACIÓN: $ubicacion

💬 COMENTARIO COMPLETO:
$comentarioCompleto

🕐 FECHA Y HORA: $fechaHora

🏢 DEPARTAMENTO: $departamento

⚠️ Esta es una notificación urgente que requiere atención inmediata del personal policial.
    ''';

    final androidDetails = AndroidNotificationDetails(
      'police_notifications',
      '🚨 Notificaciones Policiales Urgentes',
      channelDescription: 'Notificaciones críticas para personal policial sobre casos activos',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: const Color(0xFFD32F2F),
      colorized: true,
      autoCancel: false,
      ongoing: false,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      usesChronometer: false,
      chronometerCountDown: false,
      showProgress: false,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      enableLights: true,
      ledColor: const Color(0xFFD32F2F),
      ledOnMs: 1000,
      ledOffMs: 500,
      ticker: '🚨 Nuevo comentario en caso: $nombreCompleto',
      styleInformation: BigTextStyleInformation(
        bigText,
        htmlFormatBigText: false,
        contentTitle: '🚨 NUEVO COMENTARIO - CASO ACTIVO',
        htmlFormatContentTitle: false,
        summaryText: '📱 $phoneNumber • 🏢 $departamento',
        htmlFormatSummaryText: false,
      ),
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      timeoutAfter: 300000, // 5 minutos
      actions: const [
        AndroidNotificationAction(
          'view_case',
          '👁️ Ver Caso',
          icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'call_contact',
          '📞 Llamar',
          icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          showsUserInterface: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
      subtitle: '🚨 Caso Activo',
      threadIdentifier: 'police_notifications',
      categoryIdentifier: 'COMMENT_CATEGORY',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      details,
      payload: missingPersonId,
    );

    // Mostrar notificación adicional de resumen si hay múltiples casos
    await _showSummaryNotificationIfNeeded();
  }

  // Mostrar notificación genérica
  Future<void> _showGenericNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'police_general',
      '📋 Notificaciones Generales',
      channelDescription: 'Notificaciones generales',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title ?? 'Notificación',
      notification.body ?? '',
      details,
      payload:
          message.data['missingPersonId'] ?? message.data['desaparecidoId'],
    );
  }

  // Mostrar notificación de resumen si hay múltiples casos activos
  Future<void> _showSummaryNotificationIfNeeded() async {
    try {
      final activeNotifications =
          await _localNotifications.getActiveNotifications();
      final policeNotifications =
          activeNotifications
              .where((n) => n.channelId == 'police_notifications')
              .toList();

      if (policeNotifications.length >= 3) {
        final summaryDetails = AndroidNotificationDetails(
          'police_general',
          '📋 Notificaciones Policiales Generales',
          channelDescription: 'Resumen de notificaciones policiales',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF1565C0),
          colorized: true,
          styleInformation: InboxStyleInformation(
            [],
            contentTitle: '📊 RESUMEN DE CASOS ACTIVOS',
            summaryText: 'Tienes ${policeNotifications.length} casos que requieren atención',
          ),
          groupKey: 'police_notifications_group',
          setAsGroupSummary: true,
        );

        await _localNotifications.show(
          999999, // ID fijo para el resumen
          '📊 CASOS ACTIVOS',
          'Tienes ${policeNotifications.length} casos que requieren atención inmediata',
          NotificationDetails(android: summaryDetails),
        );
      }
    } catch (e) {
      print('⚠️ [FCM] Error al mostrar notificación de resumen: $e');
    }
  }

  // Actualizar rol de usuario
  Future<void> updateUserRole(String newRole, String userId) async {
    _currentUserRole = newRole;
    _currentUserId = userId;
    
    // Reinicializar servicios si cambió a policía
    if (newRole == 'police' && !_servicesInitialized) {
      await _initializeNotificationServices();
    }
    
    if (newRole == 'police' || newRole == 'citizen') {
      await _saveTokenToFirestore();
    } else {
      // Si no es un rol válido, remover el token
      await _removeTokenFromFirestore();
    }
  }

  // Remover token de Firestore
  Future<void> _removeTokenFromFirestore() async {
    try {
      if (_currentUserId != null) {
        final collection = _currentUserRole == 'police' ? 'policias' : 'ciudadanos';
        await FirebaseFirestore.instance
            .collection(collection)
            .doc(_currentUserId)
            .update({
          'fcmToken': FieldValue.delete(),
        });
        print('🗑️ [FCM] Token removido para usuario: $_currentUserId');
      }
    } catch (e) {
      print('❌ [FCM] Error al remover token: $e');
    }
  }

  // Limpiar servicio
  void dispose() {
    _currentToken = null;
    _currentUserRole = null;
    _currentUserId = null;
    _onPoliceNotificationTapped = null;
    _onCitizenNotificationTapped = null;
    _historyService = null;
    _counterService = null;
    _servicesInitialized = false;
  }
}

// Manejador de mensajes en segundo plano
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 [FCM] Mensaje en segundo plano: ${message.notification?.title}');
}
