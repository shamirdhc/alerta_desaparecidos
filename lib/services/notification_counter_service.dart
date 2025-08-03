import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationCounterService {
  static final NotificationCounterService _instance = NotificationCounterService._internal();
  factory NotificationCounterService() => _instance;
  NotificationCounterService._internal();

  ValueNotifier<int>? _unreadCount;
  bool _isDisposed = false;
  static const String _unreadCountKey = 'unread_notifications_count';
  static const String _lastReadTimestampKey = 'last_read_timestamp';

  ValueNotifier<int> get unreadCount {
    if (_isDisposed || _unreadCount == null) {
      _unreadCount = ValueNotifier<int>(0);
      _isDisposed = false;
    }
    return _unreadCount!;
  }

  // Inicializar el servicio
  Future<void> initialize() async {
    if (_isDisposed || _unreadCount == null) {
      _unreadCount = ValueNotifier<int>(0);
      _isDisposed = false;
    }
    await _loadUnreadCount();
  }

  // Cargar el conteo de notificaciones no leídas desde SharedPreferences
  Future<void> _loadUnreadCount() async {
    try {
      if (_isDisposed) return;
      
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(_unreadCountKey) ?? 0;
      
      if (!_isDisposed && _unreadCount != null) {
        _unreadCount!.value = count;
      }
    } catch (e) {
      print('❌ Error al cargar conteo de notificaciones: $e');
    }
  }

  // Incrementar el conteo de notificaciones no leídas
  Future<void> incrementUnreadCount() async {
    try {
      if (_isDisposed || _unreadCount == null) return;
      
      _unreadCount!.value++;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unreadCountKey, _unreadCount!.value);
    } catch (e) {
      print('❌ Error al incrementar conteo: $e');
    }
  }

  // Marcar todas las notificaciones como leídas
  Future<void> markAllAsRead() async {
    try {
      if (_isDisposed || _unreadCount == null) return;
      
      _unreadCount!.value = 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unreadCountKey, 0);
      await prefs.setInt(_lastReadTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('❌ Error al marcar como leídas: $e');
    }
  }

  // Obtener el timestamp de la última vez que se marcaron como leídas
  Future<DateTime?> getLastReadTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastReadTimestampKey);
      return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
    } catch (e) {
      print('❌ Error al obtener timestamp: $e');
      return null;
    }
  }

  void dispose() {
    if (!_isDisposed && _unreadCount != null) {
      _unreadCount!.dispose();
      _unreadCount = null;
      _isDisposed = true;
      print('✅ [NOTIFICATION-COUNTER] Servicio dispuesto correctamente');
    }
  }

  // Verificar si está dispuesto
  bool get isDisposed => _isDisposed;
}