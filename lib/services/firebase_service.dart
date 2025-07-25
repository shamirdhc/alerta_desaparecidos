import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const int _timeoutSeconds = 60;
  static const int _maxRetries = 3;

  // Variable para rastrear verificaciones activas
  String? _currentVerificationId;

  /// Verifica un número de teléfono con manejo mejorado de timeouts y reintentos
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
    int retryCount = 0,
  }) async {
    try {
      // Cancelar verificación anterior si existe
      if (_currentVerificationId != null) {
        print('🔄 [AUTH] Cancelando verificación SMS anterior');
        _currentVerificationId = null;
      }

      print('📱 [AUTH] Iniciando verificación de teléfono: $phoneNumber (intento ${retryCount + 1})');

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: _timeoutSeconds),
        verificationCompleted: (PhoneAuthCredential credential) {
          print('✅ [AUTH] Verificación automática completada');
          _currentVerificationId = null;
          verificationCompleted(credential);
        },
        verificationFailed: (FirebaseAuthException e) async {
          print('❌ [AUTH] Error en verificación: ${e.code} - ${e.message}');
          
          // Implementar lógica de reintentos para errores de red
          if (_shouldRetry(e) && retryCount < _maxRetries) {
            final delaySeconds = (retryCount + 1) * 2;
            print('🔄 [AUTH] Reintentando en $delaySeconds segundos...');
            await Future.delayed(Duration(seconds: delaySeconds));
            
            return verifyPhoneNumber(
              phoneNumber: phoneNumber,
              verificationCompleted: verificationCompleted,
              verificationFailed: verificationFailed,
              codeSent: codeSent,
              codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
              retryCount: retryCount + 1,
            );
          }
          
          _currentVerificationId = null;
          verificationFailed(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          print('📨 [AUTH] Código SMS enviado - ID: $verificationId');
          _currentVerificationId = verificationId;
          codeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('⏰ [AUTH] Timeout de auto-recuperación - ID: $verificationId');
          
          // Verificar si el usuario ya está autenticado antes de proceder
          final currentUser = _auth.currentUser;
          if (currentUser != null) {
            print('🔍 [AUTH] Usuario ya autenticado, ignorando timeout de SMS');
            _currentVerificationId = null;
            return;
          }
          
          // Solo proceder si no hay usuario autenticado
          _currentVerificationId = verificationId;
          codeAutoRetrievalTimeout(verificationId);
        },
      );
    } catch (e) {
      print('❌ [AUTH] Error general en verificación: $e');
      
      // Manejar errores generales con reintentos
      if (retryCount < _maxRetries) {
        final delaySeconds = (retryCount + 1) * 2;
        print('🔄 [AUTH] Reintentando verificación en $delaySeconds segundos...');
        await Future.delayed(Duration(seconds: delaySeconds));
        
        return verifyPhoneNumber(
          phoneNumber: phoneNumber,
          verificationCompleted: verificationCompleted,
          verificationFailed: verificationFailed,
          codeSent: codeSent,
          codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
          retryCount: retryCount + 1,
        );
      }
      
      _currentVerificationId = null;
      verificationFailed(FirebaseAuthException(
        code: 'network-error',
        message: 'Error de conexión. Verifica tu internet e inténtalo de nuevo.',
      ));
    }
  }

  /// Determina si un error debe ser reintentado
  bool _shouldRetry(FirebaseAuthException e) {
    final retryableCodes = [
      'network-request-failed',
      'too-many-requests',
      'timeout',
      'unavailable',
    ];
    
    final retryableMessages = [
      'network',
      'timeout',
      'Unable to resolve host',
      'Connection timed out',
      'No address associated with hostname',
    ];
    
    // Verificar códigos de error
    if (retryableCodes.contains(e.code)) {
      return true;
    }
    
    // Verificar mensajes de error
    final message = e.message?.toLowerCase() ?? '';
    return retryableMessages.any((msg) => message.contains(msg));
  }

  /// Inicia sesión con credenciales de teléfono
  Future<UserCredential> signInWithCredential(PhoneAuthCredential credential) async {
    try {
      print('🔐 [AUTH] Iniciando sesión con credencial');
      
      final result = await _auth.signInWithCredential(credential).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw FirebaseAuthException(
            code: 'timeout',
            message: 'La verificación tardó demasiado. Inténtalo de nuevo.',
          );
        },
      );
      
      print('✅ [AUTH] Sesión iniciada exitosamente - UID: ${result.user?.uid}');
      _currentVerificationId = null;
      
      return result;
    } catch (e) {
      print('❌ [AUTH] Error al iniciar sesión: $e');
      _currentVerificationId = null;
      rethrow;
    }
  }

  /// Limpia la verificación activa
  void clearActiveVerification() {
    print('🧹 [AUTH] Limpiando verificación activa');
    _currentVerificationId = null;
  }

  /// Obtiene el ID de verificación actual
  String? get currentVerificationId => _currentVerificationId;

  /// Verifica si hay una verificación activa
  bool get hasActiveVerification => _currentVerificationId != null;

  /// Cierra sesión del usuario actual
  Future<void> signOut() async {
    try {
      print('🚪 [AUTH] Cerrando sesión');
      clearActiveVerification();
      await _auth.signOut();
      print('✅ [AUTH] Sesión cerrada exitosamente');
    } catch (e) {
      print('❌ [AUTH] Error al cerrar sesión: $e');
      rethrow;
    }
  }

  /// Obtiene el usuario actual
  User? get currentUser => _auth.currentUser;

  /// Stream de cambios de estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Reenvía el código SMS
  Future<void> resendCode({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
    int? resendToken,
  }) async {
    print('🔄 [AUTH] Reenviando código SMS');
    
    await verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }
}