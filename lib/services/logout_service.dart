// Servicio de logout para POLICÍA (mantiene el comportamiento actual)
class PoliceLogoutService {
  static bool _isManualLogout = false;
  static DateTime? _lastResetTime;
  
  static void markManualLogout() {
    print('👮 [POLICE-LOGOUT] ========== MARCANDO LOGOUT MANUAL ==========');
    print('👮 [POLICE-LOGOUT] Estado anterior: $_isManualLogout');
    print('👮 [POLICE-LOGOUT] Timestamp: ${DateTime.now()}');
    
    _isManualLogout = true;
    
    print('👮 [POLICE-LOGOUT] Estado nuevo: $_isManualLogout');
    print('👮 [POLICE-LOGOUT] ✅ Logout manual marcado exitosamente');
    
    // Stack trace para ver desde dónde se llama
    final stackTrace = StackTrace.current;
    final lines = stackTrace.toString().split('\n');
    print('👮 [POLICE-LOGOUT] Llamado desde:');
    for (int i = 1; i < lines.length && i < 4; i++) {
      print('👮 [POLICE-LOGOUT]   ${i}: ${lines[i].trim()}');
    }
    print('👮 [POLICE-LOGOUT] ========================================');
  }
  
  static bool isManualLogout() {
    final result = _isManualLogout;
    print('🔍 [POLICE-LOGOUT] Consultando estado: $result');
    return result;
  }
  
  static void resetLogoutFlag() {
    print('👮 [POLICE-LOGOUT] ========== RESETEANDO FLAG ==========');
    print('👮 [POLICE-LOGOUT] Estado anterior: $_isManualLogout');
    print('👮 [POLICE-LOGOUT] Timestamp: ${DateTime.now()}');
    
    _isManualLogout = false;
    _lastResetTime = DateTime.now();
    
    print('👮 [POLICE-LOGOUT] Estado nuevo: $_isManualLogout');
    print('👮 [POLICE-LOGOUT] Último reseteo: $_lastResetTime');
    print('👮 [POLICE-LOGOUT] ✅ Flag reseteado exitosamente');
    
    // Stack trace detallado para debug
    final stackTrace = StackTrace.current;
    final lines = stackTrace.toString().split('\n');
    print('👮 [POLICE-LOGOUT] STACK TRACE COMPLETO:');
    for (int i = 1; i < lines.length && i < 8; i++) {
      print('👮 [POLICE-LOGOUT]   ${i}: ${lines[i].trim()}');
    }
    print('👮 [POLICE-LOGOUT] =====================================');
  }
  
  static bool wasRecentlyReset({int secondsThreshold = 60}) {
    if (_lastResetTime == null) return false;
    
    final now = DateTime.now();
    final difference = now.difference(_lastResetTime!).inSeconds;
    final wasRecent = difference <= secondsThreshold;
    
    print('🔍 [POLICE-LOGOUT] Verificando reseteo reciente:');
    print('🔍 [POLICE-LOGOUT] Último reseteo: $_lastResetTime');
    print('🔍 [POLICE-LOGOUT] Tiempo actual: $now');
    print('🔍 [POLICE-LOGOUT] Diferencia: ${difference}s');
    print('🔍 [POLICE-LOGOUT] ¿Fue reciente? $wasRecent (umbral: ${secondsThreshold}s)');
    
    return wasRecent;
  }
}

// Servicio de logout para CIUDADANO (completamente separado)
class CitizenLogoutService {
  static bool _isManualLogout = false;
  static DateTime? _lastResetTime;
  
  static void markManualLogout() {
    print('👤 [CITIZEN-LOGOUT] ========== MARCANDO LOGOUT MANUAL ==========');
    print('👤 [CITIZEN-LOGOUT] Estado anterior: $_isManualLogout');
    print('👤 [CITIZEN-LOGOUT] Timestamp: ${DateTime.now()}');
    
    _isManualLogout = true;
    
    print('👤 [CITIZEN-LOGOUT] Estado nuevo: $_isManualLogout');
    print('👤 [CITIZEN-LOGOUT] ✅ Logout manual marcado exitosamente');
    
    // Stack trace para ver desde dónde se llama
    final stackTrace = StackTrace.current;
    final lines = stackTrace.toString().split('\n');
    print('👤 [CITIZEN-LOGOUT] Llamado desde:');
    for (int i = 1; i < lines.length && i < 4; i++) {
      print('👤 [CITIZEN-LOGOUT]   ${i}: ${lines[i].trim()}');
    }
    print('👤 [CITIZEN-LOGOUT] ========================================');
  }
  
  static bool isManualLogout() {
    final result = _isManualLogout;
    print('🔍 [CITIZEN-LOGOUT] Consultando estado: $result');
    return result;
  }
  
  static void resetLogoutFlag() {
    print('👤 [CITIZEN-LOGOUT] ========== RESETEANDO FLAG ==========');
    print('👤 [CITIZEN-LOGOUT] Estado anterior: $_isManualLogout');
    print('👤 [CITIZEN-LOGOUT] Timestamp: ${DateTime.now()}');
    
    _isManualLogout = false;
    _lastResetTime = DateTime.now();
    
    print('👤 [CITIZEN-LOGOUT] Estado nuevo: $_isManualLogout');
    print('👤 [CITIZEN-LOGOUT] Último reseteo: $_lastResetTime');
    print('👤 [CITIZEN-LOGOUT] ✅ Flag reseteado exitosamente');
    
    // Stack trace detallado para debug
    final stackTrace = StackTrace.current;
    final lines = stackTrace.toString().split('\n');
    print('👤 [CITIZEN-LOGOUT] STACK TRACE COMPLETO:');
    for (int i = 1; i < lines.length && i < 8; i++) {
      print('👤 [CITIZEN-LOGOUT]   ${i}: ${lines[i].trim()}');
    }
    print('👤 [CITIZEN-LOGOUT] =====================================');
  }
  
  static bool wasRecentlyReset({int secondsThreshold = 60}) {
    if (_lastResetTime == null) return false;
    
    final now = DateTime.now();
    final difference = now.difference(_lastResetTime!).inSeconds;
    final wasRecent = difference <= secondsThreshold;
    
    print('🔍 [CITIZEN-LOGOUT] Verificando reseteo reciente:');
    print('🔍 [CITIZEN-LOGOUT] Último reseteo: $_lastResetTime');
    print('🔍 [CITIZEN-LOGOUT] Tiempo actual: $now');
    print('🔍 [CITIZEN-LOGOUT] Diferencia: ${difference}s');
    print('🔍 [CITIZEN-LOGOUT] ¿Fue reciente? $wasRecent (umbral: ${secondsThreshold}s)');
    
    return wasRecent;
  }
}

// Mantener compatibilidad hacia atrás (alias para policía)
class LogoutService extends PoliceLogoutService {}