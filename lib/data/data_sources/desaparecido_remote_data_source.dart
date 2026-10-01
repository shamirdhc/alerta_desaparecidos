import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/desaparecido.dart';
import '../../domain/entities/historial_encontrado.dart';
import '../../common/failure.dart';
import 'package:dartz/dartz.dart';
import '../../domain/enums.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../../services/gps_location_service.dart';

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
      final cleanQuery = searchQuery.trim().toLowerCase();
      final searchTerms = cleanQuery.split(' ').where((term) => term.isNotEmpty).toList();
      if (searchTerms.isEmpty) {
        return _getDesaparecidosSimple(
          filter: filter,
          limit: limit,
          lastDesaparecido: null,
          departamento: departamento,
        );
      }

      Query<Map<String, dynamic>> query = _desaparecidosCollection;
      
      final cleanDept = departamento?.trim();
      final bool hasDeptFilter = cleanDept != null &&
          cleanDept.isNotEmpty &&
          cleanDept.toLowerCase() != 'todos' &&
          cleanDept.toLowerCase() != 'todos los departamentos';
      
      if (hasDeptFilter) {
        final variants = GpsLocationService.getDepartmentVariants(cleanDept);
        if (variants.length == 1) {
          query = query.where('departamento', isEqualTo: variants.first);
        } else if (variants.isNotEmpty) {
          query = query.where('departamento', whereIn: variants);
        }
      }
      
      if (filter == MissingFilter.found) {
        query = query.where('estado', isEqualTo: 'encontrado');
      }
      
      List<Desaparecido> allResults = [];
      
      // 1. 🚀 Búsqueda instantánea por tokens/keywords indexados en Firestore
      try {
        final firstTerm = searchTerms.first;
        final keywordQuery = query.where('keywords', arrayContains: firstTerm).limit(100);
        final keywordSnapshot = await keywordQuery.get();
        if (keywordSnapshot.docs.isNotEmpty) {
          allResults = keywordSnapshot.docs.map((doc) {
            return Desaparecido.fromMap(doc.data(), doc.id);
          }).toList();
        }
      } catch (e) {
        print('⚠️ Búsqueda por keywords no disponible o falló: $e');
      }

      // 2. Si no se encontraron por keywords (ej. registros legacy antiguos sin keywords), fallback a búsqueda por prefijo
      if (allResults.isEmpty) {
        final orFallback = await _getDesaparecidosConBusquedaOr(
          searchQuery: searchQuery,
          filter: filter,
          limit: limit,
          departamento: departamento,
        );
        orFallback.fold(
          (failure) => null,
          (list) => allResults = list,
        );
      }

      // Filtrar por estado
      if (filter == MissingFilter.active) {
        allResults = allResults.where((d) => d.estado != 'encontrado').toList();
      } else if (filter == MissingFilter.found) {
        allResults = allResults.where((d) => d.estado == 'encontrado').toList();
      }

      // 🛡️ REGLA: Ventana estricta de 8 meses (240 días)
      final DateTime limiteOchoMeses = DateTime.now().subtract(const Duration(days: 240));
      allResults = allResults.where((d) {
        final fechaRef = (filter == MissingFilter.found)
            ? (d.fechaEncontrado ?? d.fechaDesaparicion)
            : d.fechaDesaparicion;
        return fechaRef == null || fechaRef.isAfter(limiteOchoMeses);
      }).toList();

      // 🔥 BÚSQUEDA INTELIGENTE CON PUNTUACIÓN DE RELEVANCIA
      final searchResults = _performIntelligentSearch(allResults, searchQuery);
      
      // Aplicar límite
      final finalLimit = limit ?? 20;
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
          case MissingFilter.found:
            baseQuery = baseQuery.where('estado', isEqualTo: 'encontrado');
            break;
          case MissingFilter.all:
            // No aplicar filtro de estado para MissingFilter.all
            break;
        }
        final cleanDept = departamento?.trim();
        final bool hasDeptFilter = cleanDept != null &&
            cleanDept.isNotEmpty &&
            cleanDept.toLowerCase() != 'todos' &&
            cleanDept.toLowerCase() != 'todos los departamentos';
        if (hasDeptFilter) {
          final variants = GpsLocationService.getDepartmentVariants(cleanDept);
          if (variants.length == 1) {
            baseQuery = baseQuery.where('departamento', isEqualTo: variants.first);
          } else if (variants.isNotEmpty) {
            baseQuery = baseQuery.where('departamento', whereIn: variants);
          }
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

      final cleanDept = departamento?.trim();
      final bool hasDeptFilter = cleanDept != null &&
          cleanDept.isNotEmpty &&
          cleanDept.toLowerCase() != 'todos' &&
          cleanDept.toLowerCase() != 'todos los departamentos';

      // 1. Filtrado por estado directamente en Firestore
      if (filter == MissingFilter.found) {
        query = query.where('estado', isEqualTo: 'encontrado');
      } else if (filter == MissingFilter.active) {
        query = query.where('estado', isEqualTo: 'activo');
      }

      // 2. Aplicar filtro de departamento si existe
      if (hasDeptFilter) {
        final variants = GpsLocationService.getDepartmentVariants(cleanDept);
        if (variants.length == 1) {
          query = query.where('departamento', isEqualTo: variants.first);
        } else if (variants.isNotEmpty) {
          query = query.where('departamento', whereIn: variants);
        }
      }

      // 3. Ordenar por fecha de desaparición descendente y paginar con cursor
      query = query.orderBy('fecha_desaparicion', descending: true);
      if (lastDesaparecido != null && lastDesaparecido.fechaDesaparicion != null) {
        query = query.startAfter([Timestamp.fromDate(lastDesaparecido.fechaDesaparicion!)]);
      }

      // 4. Límite de documentos a solicitar
      final int fetchLimit = limit ?? 20;
      query = query.limit(fetchLimit);

      QuerySnapshot<Map<String, dynamic>> querySnapshot;
      try {
        querySnapshot = await query.get(const GetOptions(source: Source.server));
      } catch (_) {
        querySnapshot = await query.get();
      }
      
      List<Desaparecido> desaparecidosList = querySnapshot.docs.map((doc) {
        return Desaparecido.fromMap(doc.data(), doc.id);
      }).toList();

      // 5. Garantía de aislamiento por departamento (defensa estricta contra contaminación cruzada)
      if (hasDeptFilter) {
        desaparecidosList = desaparecidosList.where((d) {
          return GpsLocationService.matches(d.departamento ?? '', cleanDept);
        }).toList();
      }

      // 6. Filtrado defensivo de estado
      if (filter == MissingFilter.active) {
        desaparecidosList = desaparecidosList
            .where((desaparecido) => desaparecido.estado != 'encontrado')
            .toList();
      } else if (filter == MissingFilter.found) {
        desaparecidosList = desaparecidosList
            .where((desaparecido) => desaparecido.estado == 'encontrado')
            .toList();
      }

      // 🛡️ REGLA: Ventana estricta de 8 meses (240 días)
      final DateTime limiteOchoMeses = DateTime.now().subtract(const Duration(days: 240));
      desaparecidosList = desaparecidosList.where((d) {
        final fechaRef = (filter == MissingFilter.found)
            ? (d.fechaEncontrado ?? d.fechaDesaparicion)
            : d.fechaDesaparicion;
        return fechaRef == null || fechaRef.isAfter(limiteOchoMeses);
      }).toList();

      // 7. Deduplicación defensiva por clave de persona (nombre + departamento + fecha)
      final Map<String, Desaparecido> uniqueMap = {};
      for (final d in desaparecidosList) {
        final nom = '${d.nombres} ${d.apellidos}'.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
        final dept = (d.departamento ?? '').trim().toUpperCase();
        final fecha = d.fechaDesaparicion != null 
            ? '${d.fechaDesaparicion!.year}-${d.fechaDesaparicion!.month}-${d.fechaDesaparicion!.day}' 
            : '';
        final key = '$nom|$dept|$fecha';
        
        if (!uniqueMap.containsKey(key)) {
          uniqueMap[key] = d;
        } else {
          final existing = uniqueMap[key]!;
          final existingFoto = existing.fotoUrl ?? '';
          final newFoto = d.fotoUrl ?? '';
          if (!existingFoto.contains('firebasestorage') && newFoto.contains('firebasestorage')) {
            uniqueMap[key] = d;
          }
        }
      }
      desaparecidosList = uniqueMap.values.toList();

      // 8. Encontrados se ordenan prioritariamente por fecha de hallazgo
      if (filter == MissingFilter.found) {
        desaparecidosList.sort((a, b) {
          final dateA = a.fechaEncontrado ?? a.fechaActualizacion ?? a.fechaDesaparicion ?? DateTime(2000);
          final dateB = b.fechaEncontrado ?? b.fechaActualizacion ?? b.fechaDesaparicion ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });
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
      
      final cleanDept = departamento?.trim();
      final bool hasDeptFilter = cleanDept != null &&
          cleanDept.isNotEmpty &&
          cleanDept.toLowerCase() != 'todos' &&
          cleanDept.toLowerCase() != 'todos los departamentos';

      if (hasDeptFilter) {
        final variants = GpsLocationService.getDepartmentVariants(cleanDept);
        if (variants.length == 1) {
          query = query.where('departamento', isEqualTo: variants.first);
        } else if (variants.isNotEmpty) {
          query = query.where('departamento', whereIn: variants);
        }
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
            final data = doc.data();
            if (filter == MissingFilter.active) {
              if (data['estado'] == 'activo' || data['estado'] != 'encontrado') {
                uniqueIds.add(doc.id);
              }
            } else if (filter == MissingFilter.found) {
              if (data['estado'] == 'encontrado') {
                uniqueIds.add(doc.id);
              }
            } else {
              uniqueIds.add(doc.id);
            }
          }
        }
        
        return Right(uniqueIds.length);
      } else {
        Query<Map<String, dynamic>> countQuery = query;
        if (filter == MissingFilter.found) {
          countQuery = countQuery.where('estado', isEqualTo: 'encontrado');
        } else if (filter == MissingFilter.active) {
          countQuery = countQuery.where('estado', isEqualTo: 'activo');
        }
        try {
          final countSnapshot = await countQuery.count().get();
          return Right(countSnapshot.count ?? 0);
        } catch (e) {
          // Fallback a conteo con límite de seguridad
          final QuerySnapshot<Map<String, dynamic>> snapshot = await countQuery.limit(500).get();
          if (filter == MissingFilter.active) {
            return Right(snapshot.docs.where((d) => d.data()['estado'] != 'encontrado').length);
          }
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

  /// Obtiene los casos de Firestore para sincronización con la base de datos local SQLite:
  /// - Si modifiedSince == null, descarga todos los casos vigentes (activos y encontrados)
  /// - Si modifiedSince != null, descarga únicamente las modificaciones desde esa fecha (Delta Sync)
  Future<Either<Failure, List<Desaparecido>>> getCasesForSync({DateTime? modifiedSince}) async {
    try {
      final List<Desaparecido> allCases = [];

      if (modifiedSince != null) {
        final querySnapshot = await _desaparecidosCollection
            .where('fecha_actualizacion', isGreaterThan: Timestamp.fromDate(modifiedSince))
            .get();

        for (final doc in querySnapshot.docs) {
          allCases.add(Desaparecido.fromMap(doc.data(), doc.id));
        }
      } else {
        final activeSnapshot = await _desaparecidosCollection
            .where('estado', isEqualTo: 'activo')
            .get();

        for (final doc in activeSnapshot.docs) {
          allCases.add(Desaparecido.fromMap(doc.data(), doc.id));
        }

        final foundSnapshot = await _desaparecidosCollection
            .where('estado', isEqualTo: 'encontrado')
            .get();

        for (final doc in foundSnapshot.docs) {
          allCases.add(Desaparecido.fromMap(doc.data(), doc.id));
        }
      }

      return Right(allCases);
    } on FirebaseException catch (e) {
      return Left(DatabaseFailure(e.message ?? 'Error al sincronizar con Firestore.'));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
