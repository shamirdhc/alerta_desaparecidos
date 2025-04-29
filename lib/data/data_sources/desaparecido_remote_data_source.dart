import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/desaparecido.dart';
import '../../common/failure.dart';
import 'package:dartz/dartz.dart';
import '../../domain/enums.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class DesaparecidoRemoteDataSource {
  final CollectionReference<Map<String, dynamic>> _desaparecidosCollection;
  final FirebaseStorage _storage;

  DesaparecidoRemoteDataSource(FirebaseFirestore firestore, this._storage)
    : _desaparecidosCollection = firestore.collection('desaparecidos');

  Future<Either<Failure, List<Desaparecido>>> getDesaparecidos({
    MissingFilter filter = MissingFilter.active,
    int? limit,
    Desaparecido? lastDesaparecido, // Para paginación
    String? searchQuery,
  }) async {
    Query<Map<String, dynamic>> query = _desaparecidosCollection;

    // Filtrar por estado
    switch (filter) {
      case MissingFilter.active:
        query = query.where('estado', isEqualTo: 'activo');
        break;
      case MissingFilter.found:
        query = query.where('estado', isEqualTo: 'encontrado');
        break;
      case MissingFilter.all:
        break;
    }

    // Simplificación de búsqueda por nombre
    if (searchQuery != null && searchQuery.isNotEmpty) {
      // Asumiendo que el campo en Firestore se llama 'nombres'
      query = query
          .orderBy(
            'nombres',
          ) // Asegúrate que el campo de ordenamiento sea 'nombres'
          .where('nombres', isGreaterThanOrEqualTo: searchQuery)
          .where('nombres', isLessThan: '${searchQuery}z\uFFFF');
    }

    // Paginación (si hay un último desaparecido conocido)
    if (lastDesaparecido != null) {
      // Usa el campo por el que estás ordenando para la paginación
      // query = query.startAfter([lastDesaparecido.nombreCompleto]); // LÍNEA ANTERIOR
      query = query.startAfter([
        lastDesaparecido.nombres,
      ]); // LÍNEA CORREGIDA (asumiendo que ordenas por 'nombres')
    } else if (searchQuery == null || searchQuery.isEmpty) {
      // Solo ordena por nombre si no hay búsqueda, para evitar conflictos con el where
      query = query.orderBy('nombres'); // Orden inicial si no hay búsqueda
    }
    // Si hay búsqueda, el orderBy ya se aplicó antes.

    // Límite de resultados
    if (limit != null) {
      query = query.limit(limit);
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await query.get();
      final List<Desaparecido> desaparecidosList =
          querySnapshot.docs.map((doc) {
            return Desaparecido.fromMap(doc.data(), doc.id);
          }).toList();
      return Right(desaparecidosList);
    } on FirebaseException catch (e) {
      return Left(
        DatabaseFailure(
          e.message ??
              'Error desconocido al obtener la lista de desaparecidos.',
        ),
      );
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  Future<Either<Failure, String>> uploadImage(
    String path,
    Uint8List imageBytes,
  ) async {
    try {
      final Reference storageRef = _storage.ref().child(path);
      final UploadTask uploadTask = storageRef.putData(imageBytes);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return Right(downloadUrl);
    } on FirebaseException catch (e) {
      return Left(
        DatabaseFailure(e.message ?? 'Error desconocido al subir la imagen.'),
      );
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  // ... existing code ...

  Future<Either<Failure, void>> reportDesaparecido(
    Desaparecido desaparecido, {
    Uint8List? fotoBytes,
    Uint8List? fichaBytes,
  }) async {
    try {
      String? fotoUrl;
      String? fichaUrl;

      // Subir imágenes si existen
      if (fotoBytes != null) {
        final fotoResult = await uploadImage(
          'desaparecidos/${desaparecido.id}/foto.jpg',
          fotoBytes,
        );
        fotoResult.fold((l) => throw l, (r) => fotoUrl = r);
      }

      if (fichaBytes != null) {
        final fichaResult = await uploadImage(
          'desaparecidos/${desaparecido.id}/ficha.jpg',
          fichaBytes,
        );
        fichaResult.fold((l) => throw l, (r) => fichaUrl = r);
      }

      // Agrega el documento principal con URLs de imágenes si existen
      final docRef = await _desaparecidosCollection.add({
        ...desaparecido.toMap(),
        if (fotoUrl != null) 'fotoUrl': fotoUrl,
        if (fichaUrl != null) 'imagenFichaUrl': fichaUrl,
      });

      // Agrega la subcolección "ubicacion"
      await docRef.collection('ubicacion').doc('detalles').set({
        'departamento': desaparecido.departamento,
        'provincia': desaparecido.provincia,
        'distrito': desaparecido.distrito,
      });

      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(
        DatabaseFailure(
          e.message ?? 'Error desconocido al guardar el reporte.',
        ),
      );
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  // ... existing code ...

  Future<Either<Failure, void>> marcarComoEncontrado(
    String desaparecidoId,
  ) async {
    try {
      await _desaparecidosCollection.doc(desaparecidoId).update({
        'estado': 'encontrado',
        'fecha_encontrado': DateTime.now(),
      });
      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(
        DatabaseFailure(
          e.message ?? 'Error desconocido al marcar como encontrado.',
        ),
      );
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  // Otros métodos (si los hay)
}
