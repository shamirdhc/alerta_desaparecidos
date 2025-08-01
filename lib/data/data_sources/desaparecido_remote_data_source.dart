import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/desaparecido.dart';
import '../../domain/entities/historial_encontrado.dart';
import '../../common/failure.dart';
import 'package:dartz/dartz.dart';
import '../../domain/enums.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class DesaparecidoRemoteDataSource {
  final CollectionReference<Map<String, dynamic>> _desaparecidosCollection;
  final CollectionReference<Map<String, dynamic>> _historialEncontradoCollection;
  final FirebaseStorage _storage;

  DesaparecidoRemoteDataSource(FirebaseFirestore firestore, this._storage)
    : _desaparecidosCollection = firestore.collection('desaparecidos'),
      _historialEncontradoCollection = firestore.collection('historial_encontrados');

  Future<Either<Failure, List<Desaparecido>>> getDesaparecidos({
    MissingFilter filter = MissingFilter.active,
    int? limit = 10,
    Desaparecido? lastDesaparecido,
    String? searchQuery,
    String? departamento,
  }) async {
    if (searchQuery != null && searchQuery.isNotEmpty) {
      return _getDesaparecidosConBusquedaInteligente(
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

  // 🚀 NUEVA IMPLEMENTACIÓN: Búsqueda inteligente completa
  Future<Either<Failure, List<Desaparecido>>> _getDesaparecidosConBusquedaInteligente({
    required String searchQuery,
    required MissingFilter filter,
    required int? limit,
    required String? departamento,
  }) async {
    try {
      // Obtener todos los registros para búsqueda en memoria
      Query<Map<String, dynamic>> query = _desaparecidosCollection;
      
      if (departamento != null && departamento.isNotEmpty && departamento != 'Todos los departamentos') {
        query = query.where('departamento', isEqualTo: departamento);
      }
      
      // Obtener más registros para búsqueda completa
      query = query.limit(500);
      
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      
      List<Desaparecido> allResults = snapshot.docs.map((doc) {
        return Desaparecido.fromMap(doc.data(), doc.id);
      }).toList();

      // Filtrar por estado
      if (filter == MissingFilter.active) {
        allResults = allResults.where((d) => d.estado != 'encontrado').toList();
      }

      // 🔥 BÚSQUEDA INTELIGENTE CON PUNTUACIÓN
      final searchResults = _performIntelligentSearch(allResults, searchQuery);
      
      // Aplicar límite
      final finalLimit = limit ?? 10;
      if (searchResults.length > finalLimit) {
        return Right(searchResults.take(finalLimit).toList());
      }
      
      return Right(searchResults);
    } catch (e) {
      print('Error en búsqueda inteligente: $e');
      // Fallback a búsqueda simple
      return _getDesaparecidosConBusquedaOr(
        searchQuery: searchQuery,
        filter: filter,
        limit: limit,
        departamento: departamento,
      );
    }
  }

  // 🧠 ALGORITMO DE BÚSQUEDA INTELIGENTE
  List<Desaparecido> _performIntelligentSearch(List<Desaparecido> allData, String searchQuery) {
    if (searchQuery.trim().isEmpty) return allData;
    
    final query = searchQuery.trim().toLowerCase();
    final searchTerms = query.split(' ').where((term) => term.isNotEmpty).toList();
    
    // Lista de resultados con puntuación
    final List<MapEntry<Desaparecido, double>> scoredResults = [];
    
    for (final person in allData) {
      final score = _calculateSearchScore(person, query, searchTerms);
      if (score > 0) {
        scoredResults.add(MapEntry(person, score));
      }
    }
    
    // Ordenar por puntuación (mayor a menor)
    scoredResults.sort((a, b) => b.value.compareTo(a.value));
    
    return scoredResults.map((entry) => entry.key).toList();
  }

  // 🎯 CÁLCULO DE PUNTUACIÓN DE RELEVANCIA
  double _calculateSearchScore(Desaparecido person, String fullQuery, List<String> searchTerms) {
    double score = 0.0;
    
    final nombres = person.nombres.toLowerCase();
    final apellidos = person.apellidos.toLowerCase();
    final dni = person.dni?.toLowerCase() ?? '';
    final fullName = '$nombres $apellidos';
    
    // 🔥 BÚSQUEDA POR DNI (máxima prioridad)
    if (dni.isNotEmpty && dni.contains(fullQuery)) {
      score += 100.0;
      if (dni == fullQuery) score += 50.0; // DNI exacto
    }
    
    // 🔥 COINCIDENCIA EXACTA DEL NOMBRE COMPLETO
    if (fullName == fullQuery) {
      score += 90.0;
    }
    
    // 🔥 COINCIDENCIA EXACTA DE NOMBRES O APELLIDOS
    if (nombres == fullQuery || apellidos == fullQuery) {
      score += 80.0;
    }
    
    // 🔥 BÚSQUEDA POR TÉRMINOS INDIVIDUALES
    for (final term in searchTerms) {
      // Nombres
      if (nombres.contains(term)) {
        score += 30.0;
        if (nombres.startsWith(term)) score += 20.0; // Bonus por inicio
      }
      
      // Apellidos (incluyendo segundo apellido)
      if (apellidos.contains(term)) {
        score += 30.0;
        if (apellidos.startsWith(term)) score += 20.0; // Bonus por inicio
      }
      
      // Palabras individuales en nombres
      final nombreWords = nombres.split(' ');
      for (final word in nombreWords) {
        if (word.startsWith(term)) score += 25.0;
        if (word == term) score += 35.0;
      }
      
      // Palabras individuales en apellidos
      final apellidoWords = apellidos.split(' ');
      for (final word in apellidoWords) {
        if (word.startsWith(term)) score += 25.0;
        if (word == term) score += 35.0;
      }
    }
    
    // 🔥 BÚSQUEDA FUZZY (tolerancia a errores)
    for (final term in searchTerms) {
      if (term.length >= 3) {
        if (_isSimilar(nombres, term) || _isSimilar(apellidos, term)) {
          score += 10.0;
        }
      }
    }
    
    return score;
  }

  // 🔍 SIMILITUD FUZZY SIMPLE
  bool _isSimilar(String text, String term) {
    if (text.length < term.length) return false;
    
    int matches = 0;
    for (int i = 0; i < term.length; i++) {
      if (i < text.length && text[i] == term[i]) {
        matches++;
      }
    }
    
    // Al menos 70% de coincidencia
    return (matches / term.length) >= 0.7;
  }

  // 🔄 MÉTODO ORIGINAL: Búsqueda básica por prefijos (fallback)
  Future<Either<Failure, List<Desaparecido>>> _getDesaparecidosConBusquedaOr({
    required String searchQuery,
    required MissingFilter filter,
    required int? limit,
    required String? departamento,
  }) async {
    try {
      final searchQueryUpper = searchQuery.toUpperCase();

      Query<Map<String, dynamic>> buildBaseQuery() {
        Query<Map<String, dynamic>> baseQuery = _desaparecidosCollection;
        switch (filter) {
          case MissingFilter.active:
            baseQuery = baseQuery.where('estado', isNotEqualTo: 'encontrado');
            break;
          case MissingFilter.all:
            // No aplicar filtro de estado para MissingFilter.all
            break;
        }
        if (departamento != null && departamento.isNotEmpty && departamento != 'Todos los departamentos') {
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

  // ✅ MÉTODO ORIGINAL RESTAURADO: Sin búsqueda, solo paginación
  Future<Either<Failure, List<Desaparecido>>> _getDesaparecidosSimple({
    required MissingFilter filter,
    required int? limit,
    required Desaparecido? lastDesaparecido,
    required String? departamento,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _desaparecidosCollection;

      // Aplicar filtro de departamento primero si existe
      if (departamento != null && departamento.isNotEmpty && departamento != 'Todos los departamentos') {
        query = query.where('departamento', isEqualTo: departamento);
      }

      // Para evitar el error de índice, simplificamos la consulta
      switch (filter) {
        case MissingFilter.active:
          // En lugar de usar isNotEqualTo que requiere índice compuesto,
          // obtenemos todos y filtramos en memoria
          break;
        case MissingFilter.all:
          // No aplicar filtro de estado para MissingFilter.all
          break;
      }

      // Ordenar por nombres
      query = query.orderBy('nombres');

      if (lastDesaparecido != null) {
        query = query.startAfter([lastDesaparecido.nombres]);
      }

      // Aumentamos el límite para compensar el filtrado en memoria
      int fetchLimit = limit != null ? (limit * 2) : 50;
      query = query.limit(fetchLimit);

      final QuerySnapshot<Map<String, dynamic>> querySnapshot = await query.get();
      
      List<Desaparecido> desaparecidosList = querySnapshot.docs.map((doc) {
        return Desaparecido.fromMap(doc.data(), doc.id);
      }).toList();

      // Filtrar en memoria para MissingFilter.active
      if (filter == MissingFilter.active) {
        desaparecidosList = desaparecidosList
            .where((desaparecido) => desaparecido.estado != 'encontrado')
            .toList();
      }

      // Aplicar límite final si se especificó
      if (limit != null && desaparecidosList.length > limit) {
        desaparecidosList = desaparecidosList.take(limit).toList();
      }

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

  // Método para reportar un nuevo caso de desaparecido
  Future<Either<Failure, void>> reportDesaparecido(Desaparecido desaparecido) async {
    try {
      final Map<String, dynamic> data = desaparecido.toMap();
      data['fechaReporte'] = DateTime.now();
      data['fechaActualizacion'] = DateTime.now();
      
      await _desaparecidosCollection.add(data);
      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(DatabaseFailure(e.message ?? 'Error desconocido al reportar desaparecido.'));
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
        'encontradoDetalles': details.toUpperCase(),
        'fechaActualizacion': DateTime.now(),
      });
      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(DatabaseFailure(e.message ?? 'Error desconocido al marcar como encontrado.'));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  // Método para marcar como encontrado con parámetros opcionales
  Future<Either<Failure, void>> marcarComoEncontrado(
    String desaparecidoId, {
    DateTime? fechaEncontrado,
    String? encontradoDetalles,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'estado': 'encontrado',
        'fechaEncontrado': fechaEncontrado ?? DateTime.now(),
        'fechaActualizacion': DateTime.now(),
      };
      
      if (encontradoDetalles != null) {
        updateData['encontradoDetalles'] = encontradoDetalles.toUpperCase();
      }
      
      await _desaparecidosCollection.doc(desaparecidoId).update(updateData);
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
      
      // Aplicar filtro de departamento primero si existe
      if (departamento != null && departamento.isNotEmpty && departamento != 'Todos los departamentos') {
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
            // Filtrar por estado en memoria si es necesario
            if (filter == MissingFilter.active) {
              final data = doc.data();
              if (data['estado'] != 'encontrado') {
                uniqueIds.add(doc.id);
              }
            } else {
              uniqueIds.add(doc.id);
            }
          }
        }
        
        return Right(uniqueIds.length);
      } else {
        // Para consultas simples sin búsqueda, obtenemos todos y contamos en memoria
        final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
        
        if (filter == MissingFilter.active) {
          int count = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (data['estado'] != 'encontrado') {
              count++;
            }
          }
          return Right(count);
        } else {
          return Right(snapshot.docs.length);
        }
      }
    } catch (e) {
      print('Error en getTotalCount: $e');
      return Left(DatabaseFailure('Error al obtener total de registros: ${e.toString()}'));
    }
  }

  // Nuevo método para obtener un desaparecido por ID
  Future<Either<Failure, Desaparecido?>> getDesaparecidoById(String id) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = 
          await _desaparecidosCollection.doc(id).get();
      
      if (doc.exists && doc.data() != null) {
        return Right(Desaparecido.fromMap(doc.data()!, doc.id));
      } else {
        return const Right(null);
      }
    } on FirebaseException catch (e) {
      return Left(DatabaseFailure(e.message ?? 'Error al obtener desaparecido por ID.'));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  // Nuevo método para guardar historial de encontrado
  Future<Either<Failure, void>> guardarHistorialEncontrado(HistorialEncontrado historial) async {
    try {
      await _historialEncontradoCollection.add(historial.toMap());
      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(DatabaseFailure(e.message ?? 'Error al guardar historial de encontrado.'));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  // Nuevo método para obtener historial de encontrados
  Future<Either<Failure, List<HistorialEncontrado>>> getHistorialEncontrados({
    String? policiaId,
    String? desaparecidoId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _historialEncontradoCollection;
      
      // Aplicar filtros
      if (policiaId != null) {
        query = query.where('policiaId', isEqualTo: policiaId);
      }
      
      if (desaparecidoId != null) {
        query = query.where('desaparecidoId', isEqualTo: desaparecidoId);
      }
      
      if (fechaInicio != null) {
        query = query.where('fechaCreacion', isGreaterThanOrEqualTo: fechaInicio);
      }
      
      if (fechaFin != null) {
        query = query.where('fechaCreacion', isLessThanOrEqualTo: fechaFin);
      }
      
      // Ordenar por fecha de creación descendente
      query = query.orderBy('fechaCreacion', descending: true);
      
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      
      final List<HistorialEncontrado> historialList = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Agregar el ID del documento al mapa
        return HistorialEncontrado.fromMap(data);
      }).toList();
      
      return Right(historialList);
    } on FirebaseException catch (e) {
      return Left(DatabaseFailure(e.message ?? 'Error al obtener historial de encontrados.'));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
