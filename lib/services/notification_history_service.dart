import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/entities/desaparecido.dart';

class NotificationHistoryItem {
  final String id;
  final String desaparecidoId;
  final String desaparecidoNombre;
  final String title;
  final String body;
  final DateTime timestamp;
  final String departamento;
  final bool isRead;
  final String commentId;

  NotificationHistoryItem({
    required this.id,
    required this.desaparecidoId,
    required this.desaparecidoNombre,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.departamento,
    this.isRead = false,
    required this.commentId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'desaparecidoId': desaparecidoId,
      'desaparecidoNombre': desaparecidoNombre,
      'title': title,
      'body': body,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'departamento': departamento,
      'isRead': isRead,
      'commentId': commentId,
    };
  }

  factory NotificationHistoryItem.fromMap(Map<String, dynamic> map) {
    return NotificationHistoryItem(
      id: map['id'] ?? '',
      desaparecidoId: map['desaparecidoId'] ?? '',
      desaparecidoNombre: map['desaparecidoNombre'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      departamento: map['departamento'] ?? '',
      isRead: map['isRead'] ?? false,
      commentId: map['commentId'] ?? '',
    );
  }

  NotificationHistoryItem copyWith({
    String? id,
    String? desaparecidoId,
    String? desaparecidoNombre,
    String? title,
    String? body,
    DateTime? timestamp,
    String? departamento,
    bool? isRead,
    String? commentId,
  }) {
    return NotificationHistoryItem(
      id: id ?? this.id,
      desaparecidoId: desaparecidoId ?? this.desaparecidoId,
      desaparecidoNombre: desaparecidoNombre ?? this.desaparecidoNombre,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      departamento: departamento ?? this.departamento,
      isRead: isRead ?? this.isRead,
      commentId: commentId ?? this.commentId,
    );
  }
}

class NotificationHistoryService {
  static final NotificationHistoryService _instance = NotificationHistoryService._internal();
  factory NotificationHistoryService() => _instance;
  NotificationHistoryService._internal();

  static const String _historyKey = 'notification_history';
  static const int _maxHistoryItems = 100; // Máximo 100 notificaciones en historial
  
  ValueNotifier<List<NotificationHistoryItem>> _historyNotifier = ValueNotifier([]);
  bool _isInitialized = false;

  ValueNotifier<List<NotificationHistoryItem>> get historyNotifier => _historyNotifier;
  List<NotificationHistoryItem> get history => _historyNotifier.value;

  // Inicializar el servicio
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _loadHistory();
      _isInitialized = true;
      print('✅ [NOTIFICATION-HISTORY] Servicio inicializado correctamente');
    } catch (e) {
      print('❌ [NOTIFICATION-HISTORY] Error al inicializar: $e');
    }
  }

  // Cargar historial desde SharedPreferences
  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);
      
      if (historyJson != null) {
        final List<dynamic> historyList = json.decode(historyJson);
        final List<NotificationHistoryItem> items = historyList
            .map((item) => NotificationHistoryItem.fromMap(item))
            .toList();
        
        // Ordenar por fecha descendente (más recientes primero)
        items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        _historyNotifier.value = items;
        print('📚 [NOTIFICATION-HISTORY] Cargadas ${items.length} notificaciones del historial');
      }
    } catch (e) {
      print('❌ [NOTIFICATION-HISTORY] Error al cargar historial: $e');
      _historyNotifier.value = [];
    }
  }

  // Guardar historial en SharedPreferences
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = _historyNotifier.value.map((item) => item.toMap()).toList();
      final historyJson = json.encode(historyList);
      
      await prefs.setString(_historyKey, historyJson);
      print('💾 [NOTIFICATION-HISTORY] Historial guardado correctamente');
    } catch (e) {
      print('❌ [NOTIFICATION-HISTORY] Error al guardar historial: $e');
    }
  }

  // Agregar nueva notificación al historial
  Future<void> addNotification({
    required String desaparecidoId,
    required String desaparecidoNombre,
    required String title,
    required String body,
    required String departamento,
    required String commentId,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final notification = NotificationHistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        desaparecidoId: desaparecidoId,
        desaparecidoNombre: desaparecidoNombre,
        title: title,
        body: body,
        timestamp: DateTime.now(),
        departamento: departamento,
        isRead: false,
        commentId: commentId,
      );

      final currentHistory = List<NotificationHistoryItem>.from(_historyNotifier.value);
      
      // Agregar al inicio de la lista
      currentHistory.insert(0, notification);
      
      // Mantener solo las últimas _maxHistoryItems notificaciones
      if (currentHistory.length > _maxHistoryItems) {
        currentHistory.removeRange(_maxHistoryItems, currentHistory.length);
      }
      
      _historyNotifier.value = currentHistory;
      await _saveHistory();
      
      print('📝 [NOTIFICATION-HISTORY] Nueva notificación agregada: $title');
    } catch (e) {
      print('❌ [NOTIFICATION-HISTORY] Error al agregar notificación: $e');
    }
  }

  // Marcar notificación como leída
  Future<void> markAsRead(String notificationId) async {
    try {
      final currentHistory = List<NotificationHistoryItem>.from(_historyNotifier.value);
      final index = currentHistory.indexWhere((item) => item.id == notificationId);
      
      if (index != -1) {
        currentHistory[index] = currentHistory[index].copyWith(isRead: true);
        _historyNotifier.value = currentHistory;
        await _saveHistory();
        print('✅ [NOTIFICATION-HISTORY] Notificación marcada como leída: $notificationId');
      }
    } catch (e) {
      print('❌ [NOTIFICATION-HISTORY] Error al marcar como leída: $e');
    }
  }

  // Marcar todas las notificaciones como leídas
  Future<void> markAllAsRead() async {
    try {
      final currentHistory = _historyNotifier.value
          .map((item) => item.copyWith(isRead: true))
          .toList();
      
      _historyNotifier.value = currentHistory;
      await _saveHistory();
      print('✅ [NOTIFICATION-HISTORY] Todas las notificaciones marcadas como leídas');
    } catch (e) {
      print('❌ [NOTIFICATION-HISTORY] Error al marcar todas como leídas: $e');
    }
  }

  // Obtener notificaciones por departamento
  List<NotificationHistoryItem> getNotificationsByDepartment(String departamento) {
    return _historyNotifier.value
        .where((item) => item.departamento.toUpperCase() == departamento.toUpperCase())
        .toList();
  }

  // Obtener notificaciones no leídas
  List<NotificationHistoryItem> getUnreadNotifications() {
    return _historyNotifier.value.where((item) => !item.isRead).toList();
  }

  // Obtener notificaciones por fecha
  List<NotificationHistoryItem> getNotificationsByDate(DateTime date) {
    return _historyNotifier.value.where((item) {
      return item.timestamp.year == date.year &&
             item.timestamp.month == date.month &&
             item.timestamp.day == date.day;
    }).toList();
  }

  // Obtener notificaciones agrupadas por fecha
  Map<String, List<NotificationHistoryItem>> getNotificationsGroupedByDate() {
    final Map<String, List<NotificationHistoryItem>> grouped = {};
    
    for (final notification in _historyNotifier.value) {
      final dateKey = _formatDateKey(notification.timestamp);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(notification);
    }
    
    return grouped;
  }

  // Formatear fecha como clave
  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final notificationDate = DateTime(date.year, date.month, date.day);
    
    if (notificationDate == today) {
      return 'Hoy';
    } else if (notificationDate == yesterday) {
      return 'Ayer';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Limpiar historial
  Future<void> clearHistory() async {
    try {
      _historyNotifier.value = [];
      await _saveHistory();
      print('🗑️ [NOTIFICATION-HISTORY] Historial limpiado');
    } catch (e) {
      print('❌ [NOTIFICATION-HISTORY] Error al limpiar historial: $e');
    }
  }

  // Verificar si una notificación existe
  bool notificationExists(String desaparecidoId, String commentId) {
    return _historyNotifier.value.any((item) => 
        item.desaparecidoId == desaparecidoId && item.commentId == commentId);
  }

  // Obtener datos del desaparecido desde Firestore
  Future<Desaparecido?> getDesaparecidoData(String desaparecidoId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('desaparecidos')
          .doc(desaparecidoId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return Desaparecido.fromMap(data, doc.id);
      }
      return null;
    } catch (e) {
      print('❌ [NOTIFICATION-HISTORY] Error al obtener datos del desaparecido: $e');
      return null;
    }
  }

  void dispose() {
    _historyNotifier.dispose();
    _isInitialized = false;
    print('✅ [NOTIFICATION-HISTORY] Servicio dispuesto correctamente');
  }
}