import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/desaparecido.dart';
import '../../common/failure.dart';
import 'package:dartz/dartz.dart';
import '../../domain/enums.dart';

class DesaparecidoRemoteDataSource {
  final FirebaseFirestore _firestore;
  final CollectionReference<Map<String, dynamic>> _desaparecidosCollection;

  DesaparecidoRemoteDataSource(this._firestore)
      : _desaparecidosCollection = _firestore.collection('desaparecidos');

  Future<Either<Failure, void>> reportDesaparecido(
      Desaparecido desaparecido,
      ) async {
    try {
      await _desaparecidosCollection.add(desaparecido.toMap());
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
      query = query
          .orderBy('nombre') // Necesario para realizar búsquedas
          .where('nombre', isGreaterThanOrEqualTo: searchQuery)
          .where(
        'nombre',
        isLessThan: '${searchQuery}z\uFFFF', // Prefijo para búsqueda
      );
    }

    // Paginación (si hay un último desaparecido conocido)
    if (lastDesaparecido != null) {
      query = query.startAfter([lastDesaparecido.nombreCompleto]);
    } else {
      query = query.orderBy('nombre'); // Orden inicial
    }

    // Límite de resultados
    if (limit != null) {
      query = query.limit(limit);
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> querySnapshot = await query.get();
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