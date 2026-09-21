import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_service.dart';

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Inicia sesión con cuenta de Google y vincula con Firebase Auth
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. Lanzar flujo de autenticación de Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // El usuario canceló la selección de cuenta
        return null;
      }

      // 2. Obtener tokens de autenticación
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Crear credencial de Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Iniciar sesión en Firebase
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      return userCredential;
    } catch (e) {
      print('❌ [GOOGLE_AUTH] Error en inicio de sesión con Google: $e');
      rethrow;
    }
  }

  /// Registra o actualiza los datos del ciudadano en Firestore
  static Future<void> syncCitizenProfile({
    required User user,
    required String phoneNumber,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('ciudadanos').doc(user.uid);
      final docSnapshot = await docRef.get();

      final displayName = user.displayName ?? 'Ciudadano';
      final namesParts = displayName.split(' ');
      final nombres = namesParts.isNotEmpty ? namesParts.first : displayName;
      final apellidos = namesParts.length > 1 ? namesParts.sublist(1).join(' ') : '';

      final citizenData = {
        'uid': user.uid,
        'email': user.email ?? '',
        'nombres': nombres,
        'apellidos': apellidos,
        'telefono': phoneNumber,
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

      // Guardar la sesión permanente en el teléfono
      await SessionService.saveUserSession(
        userRole: 'citizen',
        userId: user.uid,
        phoneNumber: phoneNumber,
        userName: displayName,
      );

      print('✅ [GOOGLE_AUTH] Perfil de ciudadano sincronizado con éxito');
    } catch (e) {
      print('❌ [GOOGLE_AUTH] Error sincronizando perfil: $e');
      rethrow;
    }
  }

  /// Cierra sesión de Google y Firebase
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
      await SessionService.clearUserSession();
    } catch (e) {
      print('⚠️ [GOOGLE_AUTH] Error en cierre de sesión: $e');
    }
  }
}
