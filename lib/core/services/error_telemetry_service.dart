import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Servicio centralizado de captura y telemetría de errores y diagnósticos.
/// Recoge fallos de forma segura, respetando la privacidad del usuario,
/// con throttling inteligente para evitar saturación de red o Firestore.
class ErrorTelemetryService {
  static final ErrorTelemetryService _instance = ErrorTelemetryService._internal();
  factory ErrorTelemetryService() => _instance;
  ErrorTelemetryService._internal();

  static const String _collectionName = 'errores_sistema';
  
  // Cache de huellas de error recientes para throttling (evita reportar en bucle el mismo error)
  final Map<String, int> _recentErrorFingerprints = {};
  DateTime _lastPurgeTime = DateTime.now();

  String? _appVersion;
  Map<String, dynamic>? _deviceMeta;

  /// Inicializa los datos del entorno (versión, sistema operativo, etc.)
  Future<void> init() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (_) {
      _appVersion = 'unknown';
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        _deviceMeta = {
          'platform': 'Web',
          'browser': webInfo.browserName.name,
          'userAgent': webInfo.userAgent,
          'language': webInfo.language,
          'vendor': webInfo.vendor,
        };
      } else {
        final defaultTarget = defaultTargetPlatform;
        if (defaultTarget == TargetPlatform.android) {
          final androidInfo = await deviceInfo.androidInfo;
          _deviceMeta = {
            'platform': 'Android',
            'model': androidInfo.model,
            'manufacturer': androidInfo.manufacturer,
            'versionSdk': androidInfo.version.sdkInt,
            'release': androidInfo.version.release,
          };
        } else if (defaultTarget == TargetPlatform.iOS) {
          final iosInfo = await deviceInfo.iosInfo;
          _deviceMeta = {
            'platform': 'iOS',
            'model': iosInfo.utsname.machine,
            'systemVersion': iosInfo.systemVersion,
          };
        } else {
          _deviceMeta = {
            'platform': defaultTarget.name,
          };
        }
      }
    } catch (_) {
      _deviceMeta = {'platform': kIsWeb ? 'Web' : defaultTargetPlatform.name};
    }
  }

  /// Registra un error en Firestore con metadatos completos y throttling
  Future<void> recordError({
    required dynamic exception,
    required StackTrace? stackTrace,
    String? reason,
    String? currentRoute,
    String? userRole,
    bool isFatal = false,
  }) async {
    try {
      // 1. Crear huella única del error
      final errString = exception.toString();
      final firstStackLine = stackTrace != null 
          ? stackTrace.toString().split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '')
          : '';
      final fingerprint = '${errString.hashCode}_${firstStackLine.hashCode}';

      // 2. Throttling: evitar enviar el mismo error más de 1 vez cada 3 minutos
      final now = DateTime.now();
      if (now.difference(_lastPurgeTime).inMinutes > 5) {
        _recentErrorFingerprints.clear();
        _lastPurgeTime = now;
      }

      if (_recentErrorFingerprints.containsKey(fingerprint)) {
        final lastSent = _recentErrorFingerprints[fingerprint]!;
        if (now.millisecondsSinceEpoch - lastSent < 180000) {
          // Ya enviado recientemente, ignorar para proteger cuota
          debugPrint('⚠️ [ErrorTelemetry] Error repetido suprimido por throttling: $errString');
          return;
        }
      }
      _recentErrorFingerprints[fingerprint] = now.millisecondsSinceEpoch;

      // 3. Preparar documento de error
      final stackTraceClean = stackTrace != null
          ? (stackTrace.toString().length > 2500 
              ? '${stackTrace.toString().substring(0, 2500)}\n...[truncado]'
              : stackTrace.toString())
          : null;

      final Map<String, dynamic> errorDoc = {
        'error': errString.length > 500 ? errString.substring(0, 500) : errString,
        'reason': reason ?? 'Excepción no controlada',
        'isFatal': isFatal,
        'currentRoute': currentRoute ?? 'desconocida',
        'userRole': userRole ?? 'anonimo',
        'stackTrace': stackTraceClean,
        'appVersion': _appVersion ?? 'unknown',
        'device': _deviceMeta ?? {'platform': kIsWeb ? 'Web' : 'Mobile'},
        'isWeb': kIsWeb,
        'timestamp': FieldValue.serverTimestamp(),
        'localTimestamp': now.toIso8601String(),
        'status': 'pendiente', // pendiente, revisado, corregido
      };

      // 4. Guardar en Firestore de forma asíncrona sin bloquear la app
      await FirebaseFirestore.instance
          .collection(_collectionName)
          .add(errorDoc)
          .timeout(const Duration(seconds: 4));

      debugPrint('🚨 [ErrorTelemetry] Error reportado exitosamente a $_collectionName');
    } catch (e) {
      // Nunca provocar una caída secundaria al reportar un error
      debugPrint('⚠️ [ErrorTelemetry] No se pudo enviar el reporte de error: $e');
    }
  }

  /// Retorna un resumen en texto de diagnóstico para compartir o exportar
  Future<String> generateDiagnosticSummary() async {
    final buffer = StringBuffer();
    buffer.writeln('=== DIAGNÓSTICO DEL SISTEMA ===');
    buffer.writeln('Fecha/Hora: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Versión App: ${_appVersion ?? 'desconocida'}');
    buffer.writeln('Plataforma: ${kIsWeb ? 'Web PWA' : defaultTargetPlatform.name}');
    if (_deviceMeta != null) {
      _deviceMeta!.forEach((key, val) {
        buffer.writeln('  $key: $val');
      });
    }
    buffer.writeln('===============================');
    return buffer.toString();
  }
}
