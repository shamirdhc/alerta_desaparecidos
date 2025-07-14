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
    int? limit = 10, // Límite por defecto
    Desaparecido? lastDesaparecido, // Para paginación (se complica con OR)
    String? searchQuery,
    String? departamento,
  }) async {
    // --- CAMBIO: Lógica de búsqueda OR ---

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // Si hay búsqueda, realizamos dos consultas y combinamos
      return _getDesaparecidosConBusquedaOr(
        filter: filter,
        limit: limit,
        searchQuery: searchQuery,
        departamento: departamento,
        // La paginación simple con startAfter se vuelve compleja aquí.
        // Una estrategia es omitirla o implementarla de forma más avanzada.
        // Por simplicidad inicial, la omitiremos en la búsqueda combinada.
      );
    } else {
      // Si no hay búsqueda, usamos la consulta simple original
      return _getDesaparecidosSimple(
        filter: filter,
        limit: limit,
        lastDesaparecido: lastDesaparecido, // Paginación SÍ aplica aquí
        departamento: departamento,
      );
    }
    // --- FIN CAMBIO ---
  }

  // --- NUEVO: Método para búsqueda combinada (OR) ---
  Future<Either<Failure, List<Desaparecido>>> _getDesaparecidosConBusquedaOr({
    required MissingFilter filter,
    required int? limit,
    required String searchQuery,
    required String? departamento,
  }) async {
    try {
      final searchQueryUpper = searchQuery.toUpperCase();

      // Construir la base de la consulta (filtros comunes)
      Query<Map<String, dynamic>> buildBaseQuery() {
        Query<Map<String, dynamic>> baseQuery = _desaparecidosCollection;
        // Aplicar filtro de estado
        switch (filter) {
          case MissingFilter.active:
            baseQuery = baseQuery.where('estado', isEqualTo: 'activo');
            break;
          case MissingFilter.found:
            baseQuery = baseQuery.where('estado', isEqualTo: 'encontrado');
            break;
          case MissingFilter.all:
            break;
        }
        // Aplicar filtro de departamento
        if (departamento != null && departamento.isNotEmpty) {
          // Asegúrate que el departamento también se compare en mayúsculas si se guarda en mayúsculas
          // O mantén la comparación como está si el departamento no se convierte a mayúsculas.
          baseQuery = baseQuery.where('departamento', isEqualTo: departamento);
        }
        return baseQuery;
      }

      // Consulta 1: Buscar por nombres (usando la query en mayúsculas)
      Query<Map<String, dynamic>> queryNombres = buildBaseQuery()
          .orderBy('nombres')
          .where('nombres', isGreaterThanOrEqualTo: searchQueryUpper)
          .where('nombres', isLessThan: '${searchQueryUpper}z\uFFFF');

      // Consulta 2: Buscar por apellidos (usando la query en mayúsculas)
      Query<Map<String, dynamic>> queryApellidos = buildBaseQuery()
          .orderBy('apellidos')
          .where('apellidos', isGreaterThanOrEqualTo: searchQueryUpper)
          .where('apellidos', isLessThan: '${searchQueryUpper}z\uFFFF');

      // Aplicar límite a ambas consultas
      final int fetchLimit = (limit ?? 10) * 2;
      queryNombres = queryNombres.limit(fetchLimit);
      queryApellidos = queryApellidos.limit(fetchLimit);

      // Ejecutar ambas consultas en paralelo
      final results = await Future.wait([
        queryNombres.get(),
        queryApellidos.get(),
      ]);

      final QuerySnapshot<Map<String, dynamic>> nombresSnapshot = results[0];
      final QuerySnapshot<Map<String, dynamic>> apellidosSnapshot = results[1];

      // Usar un Set para evitar duplicados más eficientemente
      final Set<String> seenIds = <String>{};
      final List<Desaparecido> finalResults = [];

      // Procesar resultados de nombres
      for (var doc in nombresSnapshot.docs) {
        if (!seenIds.contains(doc.id)) {
          final desaparecido = Desaparecido.fromMap(doc.data(), doc.id);
          finalResults.add(desaparecido);
          seenIds.add(doc.id);
        }
      }

      // Procesar resultados de apellidos
      for (var doc in apellidosSnapshot.docs) {
        if (!seenIds.contains(doc.id)) {
          final desaparecido = Desaparecido.fromMap(doc.data(), doc.id);
          finalResults.add(desaparecido);
          seenIds.add(doc.id);
        }
      }

      // Ordenar y limitar
      finalResults.sort((a, b) => a.nombres.compareTo(b.nombres));

      if (finalResults.length > (limit ?? 10)) {
        return Right(finalResults.sublist(0, limit ?? 10));
      }

      return Right(finalResults);
    } on FirebaseException catch (e) {
      print(
        'Firebase Error en _getDesaparecidosConBusquedaOr: ${e.code} - ${e.message}',
      );
      if (e.code == 'failed-precondition') {
        return Left(
          DatabaseFailure(
            'Firestore requiere un índice para esta consulta. Por favor, créalo siguiendo el enlace en la consola de depuración. Error: ${e.message}',
          ),
        );
      }
      return Left(
        DatabaseFailure('Error de Firestore: ${e.message ?? e.code}'),
      );
    } catch (e) {
      print('Error inesperado en _getDesaparecidosConBusquedaOr: $e');
      return Left(
        DatabaseFailure('Error inesperado al obtener datos: ${e.toString()}'),
      );
    }
  }

  // --- NUEVO: Método refactorizado para consulta simple (sin búsqueda o solo por nombre) ---
  // Este método mantiene la lógica original, incluyendo paginación simple
  Future<Either<Failure, List<Desaparecido>>> _getDesaparecidosSimple({
    required MissingFilter filter,
    required int? limit,
    required Desaparecido? lastDesaparecido,
    required String? departamento,
  }) async {
    Query<Map<String, dynamic>> query = _desaparecidosCollection;

    // 1. Aplicar filtros de estado PRIMERO
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

    // Aplicar filtro de departamento
    if (departamento != null && departamento.isNotEmpty) {
      query = query.where('departamento', isEqualTo: departamento);
    }

    // 2. Definir el ordenamiento PRINCIPAL.
    // Mantenemos el orden por 'nombres' para la paginación simple
    query = query.orderBy('nombres');

    // 3. Aplicar paginación (si existe lastDesaparecido)
    //    Debe ir DESPUÉS de todos los orderBy y where.
    if (lastDesaparecido != null) {
      // Pasar los valores de TODOS los campos definidos en orderBy, en el mismo orden.
      query = query.startAfter([lastDesaparecido.nombres]);
    }

    // 4. Aplicar límite de resultados
    if (limit != null) {
      query = query.limit(limit);
    }

    // 5. Ejecutar la consulta
    try {
      final QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await query.get();
      final List<Desaparecido> desaparecidosList =
          querySnapshot.docs.map((doc) {
            return Desaparecido.fromMap(doc.data(), doc.id);
          }).toList();
      return Right(desaparecidosList);
    } on FirebaseException catch (e) {
      print(
        'Firebase Error en _getDesaparecidosSimple: ${e.code} - ${e.message}',
      );
      if (e.code == 'failed-precondition') {
        return Left(
          DatabaseFailure(
            'Firestore requiere un índice para esta consulta. Por favor, créalo siguiendo el enlace en la consola de depuración. Error: ${e.message}',
          ),
        );
      }
      return Left(
        DatabaseFailure('Error de Firestore: ${e.message ?? e.code}'),
      );
    } catch (e) {
      print('Error inesperado en _getDesaparecidosSimple: $e');
      return Left(
        DatabaseFailure('Error inesperado al obtener datos: ${e.toString()}'),
      );
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

  // ✅ Mover este método DENTRO de la clase
  Future<Either<Failure, int>> getTotalCount({
    required MissingFilter filter,
    String? searchQuery,
    String? departamento,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _desaparecidosCollection;
      
      // Aplicar filtros igual que en getDesaparecidos pero sin límite ni paginación
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
      
      if (departamento != null && departamento.isNotEmpty) {
        query = query.where('departamento', isEqualTo: departamento);
      }
      
      // Para búsquedas, necesitamos contar manualmente porque Firestore no soporta count con OR
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final searchQueryUpper = searchQuery.toUpperCase();
        
        // Ejecutar las mismas consultas que en _getDesaparecidosConBusquedaOr pero solo contar
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
        // Para consultas simples, usar count()
        final AggregateQuerySnapshot countSnapshot = await query.count().get();
        return Right(countSnapshot.count ?? 0);
      }
    } catch (e) {
      return Left(DatabaseFailure('Error al obtener total de registros: ${e.toString()}'));
    }
  }
}
