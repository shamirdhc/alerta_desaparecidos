import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/policia.dart';

abstract class PoliciaRemoteDataSource {
  Future<List<Policia>> getAllPolicias();
  Future<Policia?> getPoliciaById(String uid);
  Future<Policia?> getCurrentPolicia();
  Future<bool> isCurrentUserAdmin();
  Future<void> createPolicia(Policia policia);
  Future<void> updatePolicia(Policia policia);
  Future<void> deletePolicia(String uid);
  Future<bool> phoneNumberExists(String phoneNumber, {String? excludeUid});
  Future<bool> cipNumberExists(String cipNumber, {String? excludeUid});
}

class PoliciaRemoteDataSourceImpl implements PoliciaRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  PoliciaRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<List<Policia>> getAllPolicias() async {
    try {
      final querySnapshot = await _firestore
          .collection('policias')
          .orderBy('fecha_registro', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Policia.fromMap({...doc.data(), 'uid': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener policías: $e');
    }
  }

  @override
  Future<Policia?> getPoliciaById(String uid) async {
    try {
      final doc = await _firestore.collection('policias').doc(uid).get();
      
      if (doc.exists) {
        return Policia.fromMap({...doc.data()!, 'uid': doc.id});
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener policía: $e');
    }
  }

  @override
  Future<Policia?> getCurrentPolicia() async {
    try {
      final user = _auth.currentUser;
      print('🔍 [DEBUG] Usuario actual: ${user?.uid}');
      print('🔍 [DEBUG] Teléfono del usuario: ${user?.phoneNumber}');
      print('🔍 [DEBUG] Email del usuario: ${user?.email}');
      
      if (user == null) {
        print('❌ [DEBUG] No hay usuario autenticado');
        return null;
      }

      final email = (user.email ?? '').trim().toLowerCase();

      // 0. Superadmin exclusivo por correo
      if (email == 'shamirdhc2022@gmail.com') {
        print('⭐ [SUPERADMIN] Acceso otorgado a Superadmin: $email');
        // Buscar documento en policias si existe
        final directDoc = await _firestore.collection('policias').doc(user.uid).get();
        if (directDoc.exists && directDoc.data() != null) {
          final data = directDoc.data()!;
          return Policia.fromMap({
            ...data,
            'uid': user.uid,
            'email': email,
            'admin': true,
            'rol': 'superadmin',
            'rango': data['rango'] ?? 'SUPERADMIN PNP',
            'tipo_unidad': 'DEPITPTIM',
          });
        }
        return Policia(
          uid: user.uid,
          nombre: 'SHAMIR DEYVIS',
          apellido: 'HUERTA CCARHUAS',
          telefono: user.phoneNumber ?? '+51948269740',
          departamento: 'APURÍMAC',
          unidad: 'DEPITPTIM PNP ANDAHUAYLAS',
          rango: 'SUPERADMIN PNP',
          numeroCip: '32094511',
          rol: 'superadmin',
          admin: true,
          fechaRegistro: DateTime.now(),
          tipoUnidad: 'DEPITPTIM',
        );
      }

      // 1. Intentar obtener directamente por user.uid
      final directDoc = await _firestore.collection('policias').doc(user.uid).get();
      if (directDoc.exists && directDoc.data() != null) {
        final data = directDoc.data()!;
        print('🔍 [DEBUG] Policía encontrado directamente por UID: ${data['nombre']}');
        return Policia.fromMap({...data, 'uid': directDoc.id});
      }

      // 2. Fallback: buscar por email en la colección policias
      if (email.isNotEmpty) {
        final emailQuery = await _firestore
            .collection('policias')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (emailQuery.docs.isNotEmpty) {
          final doc = emailQuery.docs.first;
          final data = doc.data();
          print('🔍 [DEBUG] Policía encontrado por email: ${data['nombre']}');
          return Policia.fromMap({...data, 'uid': doc.id});
        }
      }

      // 3. Fallback: buscar por número de teléfono
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        final querySnapshot = await _firestore
            .collection('policias')
            .where('telefono', isEqualTo: user.phoneNumber)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final doc = querySnapshot.docs.first;
          final data = doc.data();
          print('🔍 [DEBUG] Policía encontrado por teléfono: ${data['nombre']}');

          // Sincronizar documento bajo doc(user.uid) para cumplir firestore.rules
          try {
            await _firestore
                .collection('policias')
                .doc(user.uid)
                .set(data, SetOptions(merge: true));
            print('✅ [DEBUG] Sincronizado documento policial bajo UID: ${user.uid}');
          } catch (syncError) {
            print('⚠️ [DEBUG] No se pudo duplicar bajo UID (continuando): $syncError');
          }

          final policia = Policia.fromMap({...data, 'uid': user.uid});
          return policia;
        }
      }
      
      print('❌ [DEBUG] No se encontró policía con teléfono: ${user.phoneNumber}');
      return null;
    } catch (e) {
      print('❌ [DEBUG] Error al obtener policía actual: $e');
      throw Exception('Error al obtener policía actual: $e');
    }
  }

  @override
  Future<bool> isCurrentUserAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user != null && (user.email ?? '').trim().toLowerCase() == 'shamirdhc2022@gmail.com') {
        print('⭐ [SUPERADMIN] isCurrentUserAdmin otorgado para shamirdhc2022@gmail.com');
        return true;
      }
      print('🔍 [DEBUG] Verificando si el usuario actual es admin...');
      final policia = await getCurrentPolicia();
      final isAdmin = policia?.admin ?? false;
      print('🔍 [DEBUG] Resultado isCurrentUserAdmin: $isAdmin');
      print('🔍 [DEBUG] Policía encontrado: ${policia?.toString()}');
      return isAdmin;
    } catch (e) {
      print('❌ [DEBUG] Error en isCurrentUserAdmin: $e');
      return false;
    }
  }

  @override
  Future<void> createPolicia(Policia policia) async {
    try {
      final data = policia.toMap();
      
      if (policia.uid.isNotEmpty) {
        await _firestore.collection('policias').doc(policia.uid).set(data);
      } else {
        data.remove('uid');
        await _firestore.collection('policias').add(data);
      }
    } catch (e) {
      throw Exception('Error al crear policía: $e');
    }
  }

  @override
  Future<void> updatePolicia(Policia policia) async {
    try {
      final data = policia.toMap();
      data.remove('uid'); // Remover uid para la actualización
      
      await _firestore.collection('policias').doc(policia.uid).update(data);
    } catch (e) {
      throw Exception('Error al actualizar policía: $e');
    }
  }

  @override
  Future<void> deletePolicia(String uid) async {
    try {
      await _firestore.collection('policias').doc(uid).delete();
    } catch (e) {
      throw Exception('Error al eliminar policía: $e');
    }
  }

  @override
  Future<bool> phoneNumberExists(String phoneNumber, {String? excludeUid}) async {
    try {
      Query query = _firestore
          .collection('policias')
          .where('telefono', isEqualTo: phoneNumber);

      final querySnapshot = await query.get();
      
      if (excludeUid != null) {
        return querySnapshot.docs.any((doc) => doc.id != excludeUid);
      }
      
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Error al verificar teléfono: $e');
    }
  }

  @override
  Future<bool> cipNumberExists(String cipNumber, {String? excludeUid}) async {
    try {
      Query query = _firestore
          .collection('policias')
          .where('numero_cip', isEqualTo: cipNumber.toUpperCase());

      final querySnapshot = await query.get();
      
      if (excludeUid != null) {
        return querySnapshot.docs.any((doc) => doc.id != excludeUid);
      }
      
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Error al verificar CIP: $e');
    }
  }
}