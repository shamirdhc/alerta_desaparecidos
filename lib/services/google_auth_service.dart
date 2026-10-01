import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_service.dart';
import '../common/constants/peru_locations.dart';

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Inicia sesión con cuenta de Google (adaptado para Web y Móvil)
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // En Web, Firebase Auth maneja el flujo nativo de Google OAuth sin requerir canal de plugins
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        try {
          return await FirebaseAuth.instance.signInWithPopup(googleProvider);
        } on FirebaseAuthException catch (e) {
          final code = e.code.toLowerCase();
          final msg = (e.message ?? '').toLowerCase();
          // Si el usuario cerró la ventana emergente o canceló la selección de cuenta
          if (code.contains('popup-closed') ||
              code.contains('closed-by-user') ||
              code.contains('cancelled') ||
              code.contains('canceled') ||
              msg.contains('closed by user') ||
              msg.contains('popup has been closed') ||
              msg.contains('cancelled') ||
              msg.contains('canceled')) {
            print('ℹ️ [GOOGLE_AUTH] El usuario cerró la ventana de Google sin seleccionar cuenta.');
            return null;
          }

          // Solo si fue bloqueado activamente por el navegador, intentar redirección con salvaguarda
          if (code.contains('popup-blocked')) {
            print('⚠️ [GOOGLE_AUTH] Popup bloqueado por el navegador. Usando redirección...');
            try {
              await FirebaseAuth.instance.signInWithRedirect(googleProvider);
            } catch (redirErr) {
              print('⚠️ [GOOGLE_AUTH] Redirección no disponible o cancelada: $redirErr');
            }
            return null;
          }

          print('❌ [GOOGLE_AUTH] FirebaseAuthException en Web: ${e.code} - ${e.message}');
          rethrow;
        } catch (popupError) {
          final errorStr = popupError.toString().toLowerCase();
          if (errorStr.contains('popup-closed') ||
              errorStr.contains('closed by user') ||
              errorStr.contains('closed-by-user') ||
              errorStr.contains('cancelled') ||
              errorStr.contains('canceled') ||
              errorStr.contains('user-cancelled') ||
              errorStr.contains('dismissed') ||
              errorStr.contains('aborted')) {
            print('ℹ️ [GOOGLE_AUTH] Ventana de Google cerrada voluntariamente: $errorStr');
            return null;
          }
          print('❌ [GOOGLE_AUTH] Error no controlado en popup: $popupError');
          rethrow;
        }
      } else {
        // En Android / iOS nativo
        try {
          final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
          if (googleUser == null) {
            print('ℹ️ [GOOGLE_AUTH] Selección de cuenta cancelada por el usuario en móvil.');
            return null;
          }

          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          return await FirebaseAuth.instance.signInWithCredential(credential);
        } catch (mobileError) {
          final errStr = mobileError.toString().toLowerCase();
          if (errStr.contains('sign_in_canceled') ||
              errStr.contains('sign_in_failed') ||
              errStr.contains('canceled') ||
              errStr.contains('cancelled') ||
              errStr.contains('12501') ||
              errStr.contains('12502') ||
              errStr.contains('12500')) {
            print('ℹ️ [GOOGLE_AUTH] Autenticación cancelada por el usuario en móvil: $mobileError');
            return null;
          }
          print('❌ [GOOGLE_AUTH] Error en móvil: $mobileError');
          rethrow;
        }
      }
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('popup-closed') ||
          errStr.contains('closed by user') ||
          errStr.contains('closed-by-user') ||
          errStr.contains('cancelled') ||
          errStr.contains('canceled') ||
          errStr.contains('sign_in_canceled') ||
          errStr.contains('12501') ||
          errStr.contains('12502')) {
        print('ℹ️ [GOOGLE_AUTH] Cancelación detectada en nivel general.');
        return null;
      }
      print('❌ [GOOGLE_AUTH] Error en inicio de sesión con Google: $e');
      rethrow;
    }
  }

  /// Registra o actualiza los datos del ciudadano en Firestore
  /// Incluye nombre completo, teléfono/celular, departamento y provincia de residencia
  static Future<void> syncCitizenProfile({
    required User user,
    required String phoneNumber,
    String? fullName,
    String? departamento,
    String? provincia,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('ciudadanos').doc(user.uid);
      final docSnapshot = await docRef.get();

      final effectiveName = (fullName != null && fullName.trim().isNotEmpty)
          ? fullName.trim()
          : (user.displayName ?? 'Ciudadano');
      final namesParts = effectiveName.split(' ');
      final apellidos = namesParts.length > 1 ? namesParts.sublist(1).join(' ') : '';

      final cleanDept = (departamento ?? '').trim();
      final canonicalDept = PeruLocations.departamentos.firstWhere(
        (d) => PeruLocations.normalize(d) == PeruLocations.normalize(cleanDept),
        orElse: () => cleanDept.isNotEmpty ? cleanDept.toUpperCase() : 'LIMA',
      );
      final canonicalProv = PeruLocations.matchProvincia(canonicalDept, provincia);

      final citizenData = <String, dynamic>{
        'uid': user.uid,
        'email': user.email ?? '',
        'nombre_completo': effectiveName,
        'nombres': effectiveName,
        'apellidos': apellidos,
        'telefono': phoneNumber,
        'celular': phoneNumber,
        'departamento': canonicalDept,
        'provincia': canonicalProv,
        'foto_perfil': user.photoURL ?? '',
        'rol': 'citizen',
        'auth_provider': 'google',
        'fecha_ultimo_acceso': FieldValue.serverTimestamp(),
      };

      if (!docSnapshot.exists) {
        citizenData['fecha_registro'] = FieldValue.serverTimestamp();
        citizenData['vetado'] = false;
      }

      await docRef.set(citizenData, SetOptions(merge: true));

      try {
        await user.updateDisplayName(effectiveName);
      } catch (_) {}

      // Guardar la sesión permanente en el teléfono
      await SessionService.saveUserSession(
        userRole: 'citizen',
        userId: user.uid,
        phoneNumber: phoneNumber,
        userName: effectiveName,
        departamento: canonicalDept,
        provincia: canonicalProv,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userRole', 'citizen');
      await prefs.setBool('is_superadmin', false);
      await prefs.remove('is_superadmin');
      await prefs.setString('last_phone_number', phoneNumber);
      await prefs.setString('user_departamento', canonicalDept);
      await prefs.setString('user_department', canonicalDept);
      await prefs.setString('user_provincia', canonicalProv);

      print('✅ [GOOGLE_AUTH] Perfil de ciudadano sincronizado con éxito: $canonicalProv, $canonicalDept');
    } catch (e) {
      print('❌ [GOOGLE_AUTH] Error sincronizando perfil: $e');
      rethrow;
    }
  }

  /// Cierra sesión de Google y Firebase
  static Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      await FirebaseAuth.instance.signOut();
      await SessionService.clearUserSession();
    } catch (e) {
      print('⚠️ [GOOGLE_AUTH] Error en cierre de sesión: $e');
    }
  }
}
