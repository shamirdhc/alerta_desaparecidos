import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Servicio silencioso de métricas, telemetría de adopción, instalaciones y uso de módulos.
/// Diseñado para operar en segundo plano sin interrumpir ni bloquear la experiencia del usuario.
class AnalyticsTelemetryService {
  static final AnalyticsTelemetryService _instance = AnalyticsTelemetryService._internal();
  factory AnalyticsTelemetryService() => _instance;
  AnalyticsTelemetryService._internal();

  static const String _installationsCollection = 'instalaciones_dispositivos';
  static const String _metricsCollection = 'metricas_resumen';
  static const String _eventsCollection = 'eventos_actividad';

  String? _instanceId;
  String? _appVersion;
  String? _platformName;
  String? _deviceModel;
  bool _initialized = false;

  /// Inicializa la telemetría al arranque del app
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Obtener o generar identificador anónimo único de instalación
      _instanceId = prefs.getString('telemetry_instance_id');
      final bool isFirstLaunch = _instanceId == null;
      if (isFirstLaunch) {
        _instanceId = 'inst_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
        await prefs.setString('telemetry_instance_id', _instanceId!);
        await prefs.setString('telemetry_first_launch', DateTime.now().toIso8601String());
      }

      // 2. Info de la versión
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      } catch (_) {
        _appVersion = '1.0.0';
      }

      // 3. Info del dispositivo
      final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        _platformName = 'Web';
        try {
          final web = await deviceInfo.webBrowserInfo;
          _deviceModel = '${web.browserName.name} (${web.platform ?? 'Web'})';
        } catch (_) {
          _deviceModel = 'Navegador Web';
        }
      } else {
        _platformName = defaultTargetPlatform.name;
        if (defaultTargetPlatform == TargetPlatform.android) {
          try {
            final android = await deviceInfo.androidInfo;
            _deviceModel = '${android.manufacturer} ${android.model} (Android ${android.version.release})';
          } catch (_) {
            _deviceModel = 'Dispositivo Android';
          }
        } else {
          _deviceModel = _platformName;
        }
      }

      _initialized = true;

      // 4. Registrar o actualizar sesión silenciosa
      _recordSessionHeartbeat(isFirstLaunch, prefs);
    } catch (e) {
      debugPrint('⚠️ [AnalyticsTelemetry] Error en init: $e');
    }
  }

  /// Registra apertura de sesión e instalación inicial
  Future<void> _recordSessionHeartbeat(bool isFirstLaunch, SharedPreferences prefs) async {
    try {
      final now = DateTime.now();
      final String monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final String dayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Recuperar departamento/provincia aproximada si ya fue guardada en el dispositivo
      final String depto = prefs.getString('user_departamento') ?? 
                           prefs.getString('last_known_region') ?? 
                           'NO_ESPECIFICADO';

      final userRole = prefs.getString('userRole') ?? 'espectador';

      // 1. Registro del dispositivo (documento individual por instalación)
      final deviceDocRef = FirebaseFirestore.instance.collection(_installationsCollection).doc(_instanceId);
      
      if (isFirstLaunch) {
        await deviceDocRef.set({
          'instance_id': _instanceId,
          'platform': _platformName,
          'device_model': _deviceModel,
          'app_version': _appVersion,
          'departamento': depto,
          'first_open': FieldValue.serverTimestamp(),
          'last_open': FieldValue.serverTimestamp(),
          'total_sessions': 1,
          'role': userRole,
        }, SetOptions(merge: true));

        // Incrementar contador global de nuevas instalaciones
        _incrementGlobalCounter('instalaciones_totales', 1);
        _incrementPeriodCounter(monthKey, 'nuevas_instalaciones', 1);
        if (depto != 'NO_ESPECIFICADO') {
          _incrementRegionCounter(monthKey, depto, 1);
        }
      } else {
        await deviceDocRef.set({
          'last_open': FieldValue.serverTimestamp(),
          'total_sessions': FieldValue.increment(1),
          'app_version': _appVersion,
          'role': userRole,
          if (depto != 'NO_ESPECIFICADO') 'departamento': depto,
        }, SetOptions(merge: true));
      }

      // Incrementar sesiones activas del día y del mes
      _incrementPeriodCounter(monthKey, 'total_sesiones', 1);
      _incrementPeriodCounter(monthKey, 'sesiones_$dayKey', 1);
    } catch (e) {
      debugPrint('⚠️ [AnalyticsTelemetry] Error en _recordSessionHeartbeat: $e');
    }
  }

  /// Registra el uso de un módulo específico (Ruta Segura, Mi Familia, Central Auxilio, etc.)
  Future<void> logModuleUsage(String moduleName, {Map<String, dynamic>? extraDetails}) async {
    try {
      final now = DateTime.now();
      final String monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      // Incrementar contador acumulado en el resumen del mes
      await FirebaseFirestore.instance.collection(_metricsCollection).doc(monthKey).set({
        'modulos': {
          moduleName: FieldValue.increment(1),
        },
        'ultimo_evento': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Guardar evento reciente en log rotativo
      await FirebaseFirestore.instance.collection(_eventsCollection).add({
        'module': moduleName,
        'instance_id': _instanceId ?? 'anon',
        'platform': _platformName ?? 'unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'details': extraDetails ?? {},
      });
    } catch (e) {
      debugPrint('⚠️ [AnalyticsTelemetry] Error en logModuleUsage: $e');
    }
  }

  /// Actualiza la región detectada del dispositivo (cuando el usuario usa GPS o selecciona zona)
  Future<void> updateRegion(String departamento) async {
    if (_instanceId == null || departamento.trim().isEmpty) return;
    try {
      final deptoClean = departamento.trim().toUpperCase();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_known_region', deptoClean);

      await FirebaseFirestore.instance.collection(_installationsCollection).doc(_instanceId).set({
        'departamento': deptoClean,
        'region_actualizada': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final now = DateTime.now();
      final String monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      _incrementRegionCounter(monthKey, deptoClean, 1);
    } catch (_) {}
  }

  void _incrementGlobalCounter(String field, int delta) {
    try {
      FirebaseFirestore.instance.collection(_metricsCollection).doc('resumen_historico').set({
        field: FieldValue.increment(delta),
        'actualizado': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _incrementPeriodCounter(String monthKey, String field, int delta) {
    try {
      FirebaseFirestore.instance.collection(_metricsCollection).doc(monthKey).set({
        field: FieldValue.increment(delta),
        'actualizado': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _incrementRegionCounter(String monthKey, String region, int delta) {
    try {
      FirebaseFirestore.instance.collection(_metricsCollection).doc(monthKey).set({
        'regiones': {
          region: FieldValue.increment(delta),
        },
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
