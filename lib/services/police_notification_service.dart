import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Agregar esta importación
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../domain/entities/desaparecido.dart';
import '../domain/entities/policia.dart';
import '../helpers/database_helpers.dart'; // Agregar esta importación
import 'session_service.dart';
import 'notification_counter_service.dart';
import 'notification_history_service.dart'; // Agregar esta importación

class PoliceNotificationService {
  static final PoliceNotificationService _instance = PoliceNotificationService._internal();
  factory PoliceNotificationService() => _instance;
  PoliceNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  StreamSubscription<QuerySnapshot>? _commentsSubscription;
  final Set<String> _processedComments = <String>{};
  bool _isInitialized = false;
  Policia? _currentPolicia;
  Function(String)? _onNotificationTapped;
  NotificationCounterService? _counterService;
  NotificationHistoryService? _historyService; // Agregar servicio de historial

  // Inicializar el servicio de notificaciones
  Future<void> initialize({Function(String)? onNotificationTapped}) async {
    try {
      print('🚀 [POLICE-NOTIFICATIONS] Iniciando inicialización del servicio...');
      
      // Verificar múltiples veces que el usuario es policía
      final session = await SessionService.getUserSession();
      if (session == null) {
        print('❌ [POLICE-NOTIFICATIONS] No hay sesión activa');
        return;
      }

      final userRole = session['userRole'];
      if (userRole != 'police') {
        print('❌ [POLICE-NOTIFICATIONS] Usuario no es policía: $userRole');
        return;
      }

      final userId = session['userId'];
      if (userId == null) {
        print('❌ [POLICE-NOTIFICATIONS] No hay userId en la sesión');
        return;
      }

      print('✅ [POLICE-NOTIFICATIONS] Verificación de usuario policía exitosa');

      // Obtener datos del policía desde Firestore
      final policiaDoc = await FirebaseFirestore.instance
          .collection('policias')
          .doc(userId)
          .get();

      if (!policiaDoc.exists) {
        print('❌ [POLICE-NOTIFICATIONS] Policía no encontrado en Firestore');
        return;
      }

      _currentPolicia = Policia.fromMap({...policiaDoc.data()!, 'uid': policiaDoc.id});
      print('👮 [POLICE-NOTIFICATIONS] Policía cargado: ${_currentPolicia!.nombre} ${_currentPolicia!.apellido}');
      print('🏢 [POLICE-NOTIFICATIONS] Departamento: ${_currentPolicia!.departamento}');

      // Verificar nuevamente que es policía
      if (_currentPolicia == null) {
        print('❌ [POLICE-NOTIFICATIONS] Error al cargar datos del policía');
        return;
      }

      // Inicializar el servicio de conteo de notificaciones
      _counterService = NotificationCounterService();
      await _counterService!.initialize();
      print('📊 [POLICE-NOTIFICATIONS] Servicio de conteo inicializado');

      // Inicializar el servicio de historial de notificaciones
      _historyService = NotificationHistoryService();
      await _historyService!.initialize();
      print('📚 [POLICE-NOTIFICATIONS] Servicio de historial inicializado');

      // Configurar notificaciones locales
      await _initializeLocalNotifications();
      
      // Configurar callback de notificación
      _onNotificationTapped = onNotificationTapped;
      
      // Suscribirse a comentarios de casos en su jurisdicción
      await _subscribeToComments();
      
      _isInitialized = true;
      print('✅ [POLICE-NOTIFICATIONS] Servicio inicializado exitosamente para ${_currentPolicia!.nombre}');
      
    } catch (e) {
      print('❌ [POLICE-NOTIFICATIONS] Error durante la inicialización: $e');
      _isInitialized = false;
    }
  }

  // Configurar notificaciones locales
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Crear canal de notificación para Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'police_comments_channel',
      'Comentarios de Casos',
      description: 'Notificaciones de nuevos comentarios en casos de personas desaparecidas',
      importance: Importance.high,
      playSound: true,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    print('📱 [POLICE-NOTIFICATIONS] Notificaciones locales configuradas');
  }

  // Suscribirse a comentarios de casos
  Future<void> _subscribeToComments() async {
    try {
      if (_currentPolicia == null) {
        print('❌ [POLICE-NOTIFICATIONS] No hay policía configurado');
        return;
      }

      print('🔍 [POLICE-NOTIFICATIONS] Suscribiéndose a comentarios para departamento: ${_currentPolicia!.departamento}');

      // Obtener casos del departamento del policía
      final casosQuery = await FirebaseFirestore.instance
          .collection('desaparecidos')
          .where('departamento', isEqualTo: _currentPolicia!.departamento?.toUpperCase() ?? '')
          .where('status', isEqualTo: 'activo')
          .get();

      print('📋 [POLICE-NOTIFICATIONS] Encontrados ${casosQuery.docs.length} casos activos en ${_currentPolicia!.departamento}');

      // Si no se encontraron casos por departamento, buscar por provincias del departamento
      List<QueryDocumentSnapshot> casosPorProvincia = [];
      if (casosQuery.docs.isEmpty) {
        print('🔍 [POLICE-NOTIFICATIONS] Buscando casos por provincias del departamento...');
        casosPorProvincia = await _getCasosPorProvinciasDelDepartamento();
      }

      // Combinar casos encontrados por departamento y por provincia
      final todosCasos = [...casosQuery.docs, ...casosPorProvincia];
      print('📋 [POLICE-NOTIFICATIONS] Total de casos encontrados: ${todosCasos.length}');

      // Guardar el timestamp de inicio para solo procesar comentarios nuevos
      final startTime = Timestamp.now();
      
      // Suscribirse a comentarios de todos los casos del departamento
      // Removemos el filtro de timestamp para capturar todos los comentarios nuevos
      _commentsSubscription = FirebaseFirestore.instance
          .collectionGroup('comments')
          .snapshots()
          .listen((snapshot) async {
        await _handleNewComments(snapshot, todosCasos, startTime);
      });

      print('👂 [POLICE-NOTIFICATIONS] Suscripción a comentarios activa');
    } catch (e) {
      print('❌ [POLICE-NOTIFICATIONS] Error al suscribirse a comentarios: $e');
    }
  }

  // Obtener casos por provincias del departamento del policía
  Future<List<QueryDocumentSnapshot>> _getCasosPorProvinciasDelDepartamento() async {
    try {
      if (_currentPolicia == null) return [];

      // Obtener el ID del departamento del policía desde la base de datos local
      final dbHelper = DatabaseHelper();
      final departamentos = await dbHelper.getDepartamentos();
      
      // Buscar el departamento que coincida con el del policía
      final departamentoPolicia = _currentPolicia!.departamento?.toUpperCase()?.trim() ?? '';
      final departamentoEncontrado = departamentos.firstWhere(
        (dept) => (dept['name'] as String?)?.toUpperCase()?.trim() == departamentoPolicia,
        orElse: () => <String, dynamic>{},
      );

      if (departamentoEncontrado.isEmpty) {
        print('⚠️ [POLICE-NOTIFICATIONS] No se encontró el departamento en la base de datos local');
        return [];
      }

      // Obtener las provincias del departamento
      final departamentoId = departamentoEncontrado['id'] as String?;
      if (departamentoId == null) {
        print('⚠️ [POLICE-NOTIFICATIONS] ID de departamento no encontrado');
        return [];
      }

      final provincias = await dbHelper.getProvincias(departamentoId);
      print('🏘️ [POLICE-NOTIFICATIONS] Provincias del departamento $departamentoPolicia: ${provincias.length}');

      // Buscar casos para cada provincia
      List<QueryDocumentSnapshot> casosPorProvincia = [];
      for (final provincia in provincias) {
        final nombreProvincia = (provincia['name'] as String?)?.toUpperCase()?.trim();
        if (nombreProvincia != null) {
          print('🔍 [POLICE-NOTIFICATIONS] Buscando casos en provincia: $nombreProvincia');
          
          final casosProvinciaQuery = await FirebaseFirestore.instance
              .collection('desaparecidos')
              .where('departamento', isEqualTo: nombreProvincia)
              .where('status', isEqualTo: 'activo')
              .get();

          casosPorProvincia.addAll(casosProvinciaQuery.docs);
          print('📋 [POLICE-NOTIFICATIONS] Encontrados ${casosProvinciaQuery.docs.length} casos en provincia $nombreProvincia');
        }
      }

      return casosPorProvincia;
    } catch (e) {
      print('❌ [POLICE-NOTIFICATIONS] Error al obtener casos por provincias: $e');
      return [];
    }
  }

  // Manejar nuevos comentarios
  Future<void> _handleNewComments(QuerySnapshot snapshot, List<QueryDocumentSnapshot> casosDelDepartamento, Timestamp startTime) async {
    try {
      if (_currentPolicia == null || !_isInitialized) {
        print('⚠️ [POLICE-NOTIFICATIONS] Servicio no inicializado o policía no configurado');
        return;
      }

      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final comentario = change.doc.data() as Map<String, dynamic>;
          final comentarioId = change.doc.id;
          
          // Verificar si ya procesamos este comentario
          if (_processedComments.contains(comentarioId)) {
            continue;
          }

          // Verificar timestamp del comentario - solo procesar comentarios posteriores al inicio del servicio
          final timestamp = comentario['timestamp'] as Timestamp?;
          if (timestamp == null || timestamp.compareTo(startTime) <= 0) {
            // Marcar como procesado para evitar procesarlo en el futuro
            _processedComments.add(comentarioId);
            continue;
          }

          // Obtener el ID del caso desde la ruta del documento
          final docPath = change.doc.reference.path;
          final pathParts = docPath.split('/');
          if (pathParts.length < 2) continue;
          
          final desaparecidoId = pathParts[1]; // desaparecidos/{id}/comments/{commentId}
          
          // Verificar si el caso pertenece al departamento del policía
          QueryDocumentSnapshot? casoDoc;
          try {
            casoDoc = casosDelDepartamento.firstWhere(
              (doc) => doc.id == desaparecidoId,
            );
          } catch (e) {
            // Caso no encontrado en la lista de casos del departamento, continuar
            _processedComments.add(comentarioId);
            continue;
          }

          try {
            final casoData = casoDoc.data() as Map<String, dynamic>;
            final desaparecido = Desaparecido.fromMap(casoData, casoDoc.id);
            
            // Verificar jurisdicción (ahora es asíncrona)
            final isInJurisdiction = await _isInJurisdictionAsync(desaparecido);
            if (!isInJurisdiction) {
              print('🚫 [POLICE-NOTIFICATIONS] Caso fuera de jurisdicción: ${desaparecido.departamento} vs ${_currentPolicia!.departamento}');
              _processedComments.add(comentarioId);
              continue;
            }

            print('🆕 [POLICE-NOTIFICATIONS] Nuevo comentario detectado en caso: ${desaparecido.nombres} ${desaparecido.apellidos}');
            print('📱 [POLICE-NOTIFICATIONS] De: ${comentario['phoneNumber']}');
            print('💬 [POLICE-NOTIFICATIONS] Texto: ${comentario['text']}');

            // Crear título y cuerpo para la notificación
            final nombreCompleto = '${desaparecido.nombres} ${desaparecido.apellidos}';
            final title = '🚨 Nuevo comentario - $nombreCompleto';
            final body = '📱 ${comentario['phoneNumber']}\n💬 ${comentario['text']}';

            // Agregar al historial de notificaciones
            if (_historyService != null) {
              await _historyService!.addNotification(
                desaparecidoId: desaparecidoId,
                desaparecidoNombre: nombreCompleto,
                title: title,
                body: body,
                departamento: _currentPolicia!.departamento ?? '',
                commentId: comentarioId,
              );
              print('📝 [POLICE-NOTIFICATIONS] Notificación agregada al historial');
            }

            // Incrementar contador de notificaciones no leídas
            if (_counterService != null && !_counterService!.isDisposed) {
              await _counterService!.incrementUnreadCount();
            }

            // Mostrar notificación
            await _showEnhancedNotification(
              comentario['text'] ?? 'Nuevo comentario',
              desaparecidoId,
              comentario['phoneNumber'] ?? 'Número desconocido',
              desaparecido,
            );

            // Marcar como procesado
            _processedComments.add(comentarioId);
            
          } catch (e) {
            print('⚠️ [POLICE-NOTIFICATIONS] Error al procesar caso $desaparecidoId: $e');
            _processedComments.add(comentarioId);
            continue;
          }
        }
      }
    } catch (e) {
      print('❌ [POLICE-NOTIFICATIONS] Error al manejar nuevos comentarios: $e');
    }
  }

  // Verificar si el caso está en la jurisdicción del policía (versión asíncrona)
  Future<bool> _isInJurisdictionAsync(Desaparecido desaparecido) async {
    if (_currentPolicia == null) return false;
    
    final policiaDepartamento = _currentPolicia!.departamento?.toUpperCase()?.trim() ?? '';
    final desaparecidoDepartamento = desaparecido.departamento?.toUpperCase()?.trim() ?? '';
    
    // Verificación directa por departamento
    bool isInJurisdiction = policiaDepartamento == desaparecidoDepartamento;
    
    // Si no coincide directamente, verificar si el caso está en una provincia del departamento del policía
    if (!isInJurisdiction) {
      isInJurisdiction = await _isProvinciaDelDepartamento(desaparecidoDepartamento, policiaDepartamento);
    }
    
    print('🔍 [POLICE-NOTIFICATIONS] Verificando jurisdicción:');
    print('   👮 Policía: $policiaDepartamento');
    print('   👤 Caso: $desaparecidoDepartamento');
    print('   ✅ En jurisdicción: $isInJurisdiction');
    
    return isInJurisdiction;
  }

  // Verificar si una provincia pertenece a un departamento específico
  Future<bool> _isProvinciaDelDepartamento(String nombreProvincia, String nombreDepartamento) async {
    try {
      final dbHelper = DatabaseHelper();
      final departamentos = await dbHelper.getDepartamentos();
      
      // Buscar el departamento
      final departamentoEncontrado = departamentos.firstWhere(
        (dept) => (dept['name'] as String?)?.toUpperCase()?.trim() == nombreDepartamento,
        orElse: () => <String, dynamic>{},
      );

      if (departamentoEncontrado.isEmpty) return false;

      final departamentoId = departamentoEncontrado['id'] as String?;
      if (departamentoId == null) return false;

      // Obtener las provincias del departamento
      final provincias = await dbHelper.getProvincias(departamentoId);
      
      // Verificar si la provincia está en la lista
      final provinciaEncontrada = provincias.any(
        (prov) => (prov['name'] as String?)?.toUpperCase()?.trim() == nombreProvincia,
      );

      if (provinciaEncontrada) {
        print('✅ [POLICE-NOTIFICATIONS] Provincia $nombreProvincia pertenece al departamento $nombreDepartamento');
      }

      return provinciaEncontrada;
    } catch (e) {
      print('❌ [POLICE-NOTIFICATIONS] Error al verificar provincia del departamento: $e');
      return false;
    }
  }

  // Verificar si el caso está en la jurisdicción del policía (mantener versión síncrona para compatibilidad)
  bool _isInJurisdiction(Desaparecido desaparecido) {
    if (_currentPolicia == null) return false;
    
    final policiaDepartamento = _currentPolicia!.departamento?.toUpperCase()?.trim() ?? '';
    final desaparecidoDepartamento = desaparecido.departamento?.toUpperCase()?.trim() ?? '';
    
    final isInJurisdiction = policiaDepartamento == desaparecidoDepartamento;
    
    print('🔍 [POLICE-NOTIFICATIONS] Verificando jurisdicción (síncrona):');
    print('   👮 Policía: $policiaDepartamento');
    print('   👤 Caso: $desaparecidoDepartamento');
    print('   ✅ En jurisdicción: $isInJurisdiction');
    
    return isInJurisdiction;
  }

  // Descargar imagen para la notificación
  Future<String?> _downloadImageForNotification(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/notification_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File(imagePath);
        await file.writeAsBytes(response.bodyBytes);
        return imagePath;
      }
    } catch (e) {
      print('❌ Error al descargar imagen: $e');
    }
    return null;
  }

  // Mostrar notificación mejorada con foto y información del desaparecido
  Future<void> _showEnhancedNotification(
    String comentarioTexto, 
    String desaparecidoId, 
    String phoneNumber, 
    Desaparecido desaparecido
  ) async {
    try {
      // Descargar imagen si está disponible
      final imagePath = await _downloadImageForNotification(desaparecido.fotoUrl);
      
      // Truncar el texto del comentario si es muy largo
      final truncatedText = comentarioTexto.length > 80 
          ? '${comentarioTexto.substring(0, 80)}...' 
          : comentarioTexto;

      // Crear el título con el nombre completo del desaparecido
      final nombreCompleto = '${desaparecido.nombres} ${desaparecido.apellidos}';
      final title = '🚨 $nombreCompleto';
      
      // Crear el cuerpo con información relevante
      final body = '📱 $phoneNumber\n💬 $truncatedText';

      // Calcular edad si hay fecha de nacimiento
      String edadInfo = 'Sin edad';
      if (desaparecido.fechaNacimiento != null) {
        final now = DateTime.now();
        final edad = now.year - desaparecido.fechaNacimiento!.year;
        edadInfo = '$edad años';
      }

      // Configuración para Android con imagen
      AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'police_comments_channel',
        'Comentarios de Casos',
        channelDescription: 'Notificaciones de nuevos comentarios en casos de personas desaparecidas',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF1565C0), // Azul policía
        largeIcon: imagePath != null ? FilePathAndroidBitmap(imagePath) : null,
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          contentTitle: title,
          htmlFormatContentTitle: false,
          summaryText: '$edadInfo • ${desaparecido.departamento}',
          htmlFormatSummaryText: false,
        ),
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        subtitle: 'Nuevo comentario en caso',
      );

      NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000), // ID único
        title,
        body,
        platformChannelSpecifics,
        payload: json.encode({
          'desaparecidoId': desaparecidoId,
          'phoneNumber': phoneNumber,
          'action': 'view_case',
        }),
      );

      print('🔔 Notificación mejorada enviada para: $nombreCompleto');
      
      // Limpiar imagen temporal después de un tiempo
      if (imagePath != null) {
        Timer(const Duration(minutes: 5), () {
          try {
            File(imagePath).delete();
          } catch (e) {
            print('⚠️ Error al limpiar imagen temporal: $e');
          }
        });
      }
    } catch (e) {
      print('❌ Error al mostrar notificación mejorada: $e');
      // Fallback a notificación simple
      await _showSimpleNotification(comentarioTexto, desaparecidoId, phoneNumber, desaparecido);
    }
  }

  // Notificación simple como fallback
  Future<void> _showSimpleNotification(
    String comentarioTexto, 
    String desaparecidoId, 
    String phoneNumber,
    Desaparecido desaparecido
  ) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'police_comments_channel',
      'Comentarios de Casos',
      channelDescription: 'Notificaciones de nuevos comentarios en casos de personas desaparecidas',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF1565C0), // Azul policía - Agregar const
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Truncar el texto del comentario si es muy largo
    final truncatedText = comentarioTexto.length > 50 
        ? '${comentarioTexto.substring(0, 50)}...' 
        : comentarioTexto;

    final nombreCompleto = '${desaparecido.nombres} ${desaparecido.apellidos}';

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000), // ID único
      '🚨 $nombreCompleto',
      'De $phoneNumber: $truncatedText',
      platformChannelSpecifics,
      payload: desaparecidoId,
    );
  }

  // Manejar tap en notificación
  void _onNotificationResponse(NotificationResponse response) {
    if (response.payload != null && _onNotificationTapped != null) {
      print('👆 [POLICE-NOTIFICATIONS] Notificación tocada, navegando a caso: ${response.payload}');
      
      try {
        // Intentar parsear como JSON para obtener información adicional
        final payloadData = json.decode(response.payload!);
        final desaparecidoId = payloadData['desaparecidoId'] as String;
        
        _onNotificationTapped!(desaparecidoId);
      } catch (e) {
        // Si no es JSON, usar como ID directo
        _onNotificationTapped!(response.payload!);
      }
    }
  }

  // Obtener el servicio de conteo
  NotificationCounterService? get counterService => _counterService;

  // Verificar si el servicio está inicializado
  bool get isInitialized => _isInitialized;

  // Detener el servicio
  void dispose() {
    if (!_isInitialized) {
      print('⚠️ [POLICE-NOTIFICATIONS] Servicio ya está detenido');
      return;
    }
    
    print('🛑 [POLICE-NOTIFICATIONS] Deteniendo servicio de notificaciones...');
    
    try {
      _commentsSubscription?.cancel();
      _commentsSubscription = null;
      
      _processedComments.clear();
      
      if (_counterService != null && !_counterService!.isDisposed) {
        _counterService!.dispose();
      }
      _counterService = null;
      
      _isInitialized = false;
      _currentPolicia = null;
      _onNotificationTapped = null;
      
      print('✅ [POLICE-NOTIFICATIONS] Servicio detenido exitosamente');
    } catch (e) {
      print('❌ [POLICE-NOTIFICATIONS] Error al detener servicio: $e');
    }
  }
}