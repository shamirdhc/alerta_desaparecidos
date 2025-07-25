import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SessionService {
  static const String _userRoleKey = 'userRole';
  static const String _userIdKey = 'userId';
  static const String _phoneNumberKey = 'phoneNumber';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _lastLoginKey = 'lastLogin';
  static const String _sessionValidKey = 'sessionValid';
  static const String _firebaseTokenKey = 'firebase_token';

  // Configurar persistencia de Firebase Auth
  static Future<void> initializeFirebaseAuth() async {
    try {
      // Asegurar que Firebase Auth mantenga la sesión
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      print('✅ [AUTH] Persistencia de Firebase configurada');
    } catch (e) {
      print('❌ [AUTH] Error configurando persistencia: $e');
    }
  }

  static Future<void> saveUserSession({
    required String userRole,
    required String userId,
    required String phoneNumber,
    bool biometricEnabled = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Obtener token de Firebase si está disponible
      String? firebaseToken;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          firebaseToken = await currentUser.getIdToken();
        } catch (e) {
          print('⚠️ [AUTH] No se pudo obtener token: $e');
        }
      }

      await Future.wait([
        prefs.setString(_userRoleKey, userRole),
        prefs.setString(_userIdKey, userId),
        prefs.setString(_phoneNumberKey, phoneNumber),
        prefs.setBool(_biometricEnabledKey, biometricEnabled),
        prefs.setString(_lastLoginKey, DateTime.now().toIso8601String()),
        prefs.setBool(_sessionValidKey, true),
        if (firebaseToken != null) prefs.setString(_firebaseTokenKey, firebaseToken),
      ]);
      
      print('✅ [AUTH] Sesión guardada exitosamente');
    } catch (e) {
      throw Exception('Error al guardar sesión: $e');
    }
  }

  // Verificar y sincronizar autenticación
  static Future<bool> ensureUserAuthenticated() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final session = await getUserSession();
      
      print('🔍 [AUTH] Verificando autenticación - Firebase: ${currentUser?.uid}, Sesión: ${session?['userId']}');
      
      if (currentUser != null && session != null) {
        // Usuario autenticado correctamente
        return true;
      }
      
      if (currentUser == null && session != null) {
        // Intentar re-autenticar usando el número de teléfono guardado
        print('🔄 [AUTH] Intentando re-autenticación silenciosa');
        return await _attemptSilentReauth(session);
      }
      
      return false;
    } catch (e) {
      print('❌ [AUTH] Error verificando autenticación: $e');
      return false;
    }
  }

  static Future<bool> _attemptSilentReauth(Map<String, dynamic> session) async {
    try {
      // Verificar si el token guardado aún es válido
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_firebaseTokenKey);
      
      if (savedToken != null) {
        // Intentar validar el token
        try {
          // Verificar si el usuario existe en Firestore
          final isValid = await validateUserInDatabase(
            session['userId'],
            session['userRole'],
          );
          
          if (isValid) {
            print('✅ [AUTH] Re-autenticación silenciosa exitosa');
            return true;
          }
        } catch (e) {
          print('❌ [AUTH] Token inválido: $e');
        }
      }
      
      return false;
    } catch (e) {
      print('❌ [AUTH] Error en re-autenticación silenciosa: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final userRole = prefs.getString(_userRoleKey);
      final userId = prefs.getString(_userIdKey);
      final phoneNumber = prefs.getString(_phoneNumberKey);
      final biometricEnabled = prefs.getBool(_biometricEnabledKey) ?? false;
      final lastLoginStr = prefs.getString(_lastLoginKey);
      final sessionValid = prefs.getBool(_sessionValidKey) ?? false;

      if (userRole == null ||
          userId == null ||
          phoneNumber == null ||
          !sessionValid) {
        return null;
      }

      // Verificar si la sesión no ha expirado (24 horas)
      if (lastLoginStr != null) {
        final lastLogin = DateTime.parse(lastLoginStr);
        final now = DateTime.now();
        if (now.difference(lastLogin).inHours > 24) {
          await clearUserSession();
          return null;
        }
      }

      return {
        'userRole': userRole,
        'userId': userId,
        'phoneNumber': phoneNumber,
        'biometricEnabled': biometricEnabled,
        'lastLogin': lastLoginStr,
      };
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Limpiar todas las claves relacionadas con la sesión
      final keysToRemove = [
        _userRoleKey,
        _userIdKey,
        _phoneNumberKey,
        _biometricEnabledKey,
        _lastLoginKey,
        _firebaseTokenKey,
        // Claves adicionales que podrían existir
        'user_role',
        'userRole',
        'last_phone_number',
        'biometric_enabled',
      ];

      await Future.wait([
        ...keysToRemove.map((key) => prefs.remove(key)),
        prefs.setBool(_sessionValidKey, false),
      ]);

      print('✅ [AUTH] Sesión limpiada exitosamente');
    } catch (e) {
      print('❌ [AUTH] Error al limpiar sesión: $e');
      throw Exception('Error al limpiar sesión: $e');
    }
  }

  static Future<bool> isSessionValid() async {
    try {
      final session = await getUserSession();
      return session != null;
    } catch (e) {
      return false;
    }
  }

  static Future<void> updateLastLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastLoginKey, DateTime.now().toIso8601String());
      
      // Actualizar token si es posible
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          final token = await currentUser.getIdToken(true); // Forzar refresh
          if (token != null) {
            await prefs.setString(_firebaseTokenKey, token);
          }
        } catch (e) {
          print('⚠️ [AUTH] No se pudo actualizar token: $e');
        }
      }
    } catch (e) {
      // Ignorar errores de actualización
    }
  }

  static Future<bool> validateUserInDatabase(
    String userId,
    String userRole,
  ) async {
    try {
      final collection = userRole == 'police' ? 'policias' : 'ciudadanos';
      final doc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists) {
        return false;
      }

      // Para ciudadanos, verificar que no estén vetados
      if (userRole == 'citizen') {
        final data = doc.data();
        if (data != null && data['vetado'] == true) {
          return false;
        }
      }

      return true;
    } catch (e) {
      print('❌ [AUTH] Error validando usuario en base de datos: $e');
      return false;
    }
  }
}
