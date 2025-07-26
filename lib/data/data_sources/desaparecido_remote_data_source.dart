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
    int? limit = 10,
    Desaparecido? lastDesaparecido,
    String? searchQuery,
    String? departamento,
  }) async {
    if (searchQuery != null && searchQuery.isNotEmpty) {
      return _getDesaparecidosConBusquedaOr(
        filter: filter,
        limit: limit,
        searchQuery: searchQuery,
        departamento: departamento,
      );
    } else {
      return _getDesaparecidosSimple(
        filter: filter,
        limit: limit,
        lastDesaparecido: lastDesaparecido,
        departamento: departamento,
      );
    }
  }

  Future<Either<Failure, List<Desaparecido>>> _getDesaparecidosConBusquedaOr({
    required MissingFilter filter,
    required int? limit,
    required String searchQuery,
    required String? departamento,
  }) async {
    try {
      final searchQueryUpper = searchQuery.toUpperCase();

      Query<Map<String, dynamic>> buildBaseQuery() {
        Query<Map<String, dynamic>> baseQuery = _desaparecidosCollection;
        switch (filter) {
          case MissingFilter.active:
            baseQuery = baseQuery.where('estado', isEqualTo: 'activo');
            break;
          case MissingFilter.all:
            break;
        }
        if (departamento != null && departamento.isNotEmpty) {
          baseQuery = baseQuery.where('departamento', isEqualTo: departamento);
        }
        return baseQuery;
      }

      Query<Map<String, dynamic>> queryNombres = buildBaseQuery()
          .orderBy('nombres')
          .where('nombres', isGreaterThanOrEqualTo: searchQueryUpper)
          .where('nombres', isLessThan: '${searchQueryUpper}z\uFFFF');

      Query<Map<String, dynamic>> queryApellidos = buildBaseQuery()
          .orderBy('apellidos')
          .where('apellidos', isGreaterThanOrEqualTo: searchQueryUpper)
          .where('apellidos', isLessThan: '${searchQueryUpper}z\uFFFF');

      final int fetchLimit = (limit ?? 10) * 2;
      queryNombres = queryNombres.limit(fetchLimit);
      queryApellidos = queryApellidos.limit(fetchLimit);

      final results = await Future.wait([
        queryNombres.get(),
        queryApellidos.get(),
      ]);

      final QuerySnapshot<Map<String, dynamic>> nombresSnapshot = results[0];
      final QuerySnapshot<Map<String, dynamic>> apellidosSnapshot = results[1];

      final Set<String> seenIds = <String>{};
      final List<Desaparecido> finalResults = [];

      for (var doc in nombresSnapshot.docs) {
        if (!seenIds.contains(doc.id)) {
          final desaparecido = Desaparecido.fromMap(doc.data(), doc.id);
          finalResults.add(desaparecido);
          seenIds.add(doc.id);
        }
      }

      for (var doc in apellidosSnapshot.docs) {
        if (!seenIds.contains(doc.id)) {
          final desaparecido = Desaparecido.fromMap(doc.data(), doc.id);
          finalResults.add(desaparecido);
          seenIds.add(doc.id);
        }
      }

      finalResults.sort((a, b) => a.nombres.compareTo(b.nombres));

      if (finalResults.length > (limit ?? 10)) {
        return Right(finalResults.sublist(0, limit ?? 10));
      }

      return Right(finalResults);
    } on FirebaseException catch (e) {
      print('Firebase Error en _getDesaparecidosConBusquedaOr: ${e.code} - ${e.message}');
      if (e.code == 'failed-precondition') {
        return Left(DatabaseFailure('Firestore requiere un índice para esta consulta. Error: ${e.message}'));
      }
      return Left(DatabaseFailure('Error de Firestore: ${e.message ?? e.code}'));
    } catch (e) {
      print('Error inesperado en _getDesaparecidosConBusquedaOr: $e');
      return Left(DatabaseFailure('Error inesperado al obtener datos: ${e.toString()}'));
    }
  }

  Future<Either<Failure, List<Desaparecido>>> _getDesaparecidosSimple({
    required MissingFilter filter,
    required int? limit,
    required Desaparecido? lastDesaparecido,
    required String? departamento,
  }) async {
    Query<Map<String, dynamic>> query = _desaparecidosCollection;

    switch (filter) {
      case MissingFilter.active:
        query = query.where('estado', isEqualTo: 'activo');
        break;
      case MissingFilter.all:
        break;
    }

    if (departamento != null && departamento.isNotEmpty) {
      query = query.where('departamento', isEqualTo: departamento);
    }

    query = query.orderBy('nombres');

    if (lastDesaparecido != null) {
      query = query.startAfter([lastDesaparecido.nombres]);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> querySnapshot = await query.get();
      final List<Desaparecido> desaparecidosList = querySnapshot.docs.map((doc) {
        return Desaparecido.fromMap(doc.data(), doc.id);
      }).toList();
      return Right(desaparecidosList);
    } on FirebaseException catch (e) {
      print('Firebase Error en _getDesaparecidosSimple: ${e.code} - ${e.message}');
      if (e.code == 'failed-precondition') {
        return Left(DatabaseFailure('Firestore requiere un índice para esta consulta. Error: ${e.message}'));
      }
      return Left(DatabaseFailure('Error de Firestore: ${e.message ?? e.code}'));
    } catch (e) {
      print('Error inesperado en _getDesaparecidosSimple: $e');
      return Left(DatabaseFailure('Error inesperado al obtener datos: ${e.toString()}'));
    }
  }

  Future<Either<Failure, String>> uploadImage(String path, Uint8List imageBytes) async {
    try {
      final Reference storageRef = _storage.ref().child(path);
      final UploadTask uploadTask = storageRef.putData(imageBytes);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return Right(downloadUrl);
    } on FirebaseException catch (e) {
      return Left(DatabaseFailure(e.message ?? 'Error desconocido al subir la imagen.'));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> reportDesaparecido(
    Desaparecido desaparecido, {
    Uint8List? fotoBytes,
    Uint8List? fichaBytes,
  }) async {
    try {
      String? fotoUrl;
      String? fichaUrl;

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

      final docRef = await _desaparecidosCollection.add({
        ...desaparecido.toMap(),
        if (fotoUrl != null) 'fotoUrl': fotoUrl,
        if (fichaUrl != null) 'imagenFichaUrl': fichaUrl,
      });

      await docRef.collection('ubicacion').doc('detalles').set({
        'departamento': desaparecido.departamento,
        'provincia': desaparecido.provincia,
        'distrito': desaparecido.distrito,
      });

      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(DatabaseFailure(e.message ?? 'Error desconocido al guardar el reporte.'));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> marcarComoEncontrado(String desaparecidoId) async {
    try {
      await _desaparecidosCollection.doc(desaparecidoId).update({
        'estado': 'encontrado',
        'fecha_encontrado': DateTime.now(),
      });
      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(DatabaseFailure(e.message ?? 'Error desconocido al marcar como encontrado.'));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  // Método para marcar caso como encontrado con detalles
  Future<Either<Failure, void>> markCaseAsFound(String caseId, String details) async {
    try {
      await _desaparecidosCollection.doc(caseId).update({
        'estado': 'encontrado',
        'fechaEncontrado': DateTime.now(),
        'encontradoDetalles': details,
        'fechaActualizacion': DateTime.now(),
      });
      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(DatabaseFailure(e.message ?? 'Error desconocido al marcar como encontrado.'));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  Future<Either<Failure, int>> getTotalCount({
    required MissingFilter filter,
    String? searchQuery,
    String? departamento,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _desaparecidosCollection;
      
      switch (filter) {
        case MissingFilter.active:
          query = query.where('estado', isEqualTo: 'activo');
          break;
        case MissingFilter.all:
          break;
      }
      
      if (departamento != null && departamento.isNotEmpty) {
        query = query.where('departamento', isEqualTo: departamento);
      }
      
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final searchQueryUpper = searchQuery.toUpperCase();
        
        final futures = await Future.wait([
          query.where('nombres', isGreaterThanOrEqualTo: searchQueryUpper)
               .where('nombres', isLessThan: '${searchQueryUpper}z\uFFFF')
               .get(),
          query.where('apellidos', isGreaterThanOrEqualTo: searchQueryUpper)
               .where('apellidos', isLessThan: '${searchQueryUpper}z\uFFFF')
               .get(),
        ]);
        
        final Set<String> uniqueIds = {};
        for (final snapshot in futures) {
          for (final doc in snapshot.docs) {
            uniqueIds.add(doc.id);
          }
        }
        
        return Right(uniqueIds.length);
      } else {
        final AggregateQuerySnapshot countSnapshot = await query.count().get();
        return Right(countSnapshot.count ?? 0);
      }
    } catch (e) {
      return Left(DatabaseFailure('Error al obtener total de registros: ${e.toString()}'));
    }
  }
}
