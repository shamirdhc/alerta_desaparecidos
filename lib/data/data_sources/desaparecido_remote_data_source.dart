import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/desaparecido.dart';
import '../../domain/entities/historial_encontrado.dart';
import '../../common/failure.dart';
import 'package:dartz/dartz.dart';
import '../../domain/enums.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../../services/gps_location_service.dart';
import '../../common/constants/peru_locations.dart';

class DesaparecidoRemoteDataSource {
  final CollectionReference<Map<String, dynamic>> _desaparecidosCollection;
  final CollectionReference<Map<String, dynamic>> _historialEncontradoCollection;
  final FirebaseStorage _storage;

  /// Intervalo mínimo (30 min) antes de forzar nuevas consultas al servidor
  /// para proteger el límite de 50,000 lecturas diarias del Plan Gratuito (Spark).
  static const int _kDeltaSyncCooldownMs = 30 * 60 * 1000;

  /// Mapa de cursores DocumentSnapshot reales por ID para garantizar paginación
  /// exacta sin saltar registros que comparten la misma fecha/hora de desaparición.
  final Map<String, DocumentSnapshot<Map<String, dynamic>>> _cursorSnapshots = {};

  bool _lastQueryHadMore = true;
  bool get lastQueryHadMore => _lastQueryHadMore;

  DesaparecidoRemoteDataSource(FirebaseFirestore firestore, this._storage)
    : _desaparecidosCollection = firestore.collection('desaparecidos'),
      _historialEncontradoCollection = firestore.collection('historial_encontrados');

  Future<Either<Failure, List<Desaparecido>>> getDesaparecidos({
    MissingFilter filter = MissingFilter.active,
    int? limit = 10,
    Desaparecido? lastDesaparecido,
    String? searchQuery,
    String? departamento,
    String? provincia,
  }) async {
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      return _getDesaparecidosConBusquedaInteligente(
        filter: filter,
        limit: limit,
        searchQuery: searchQuery,
        departamento: departamento,
        provincia: provincia,
      );
    } else {
      return _getDesaparecidosSimple(
        filter: filter,
        limit: limit,
        lastDesaparecido: lastDesaparecido,
        departamento: departamento,
        provincia: provincia,
      );
    }
  }

  // 🚀 Búsqueda inteligente completa con soporte de Departamento y Provincia
  Future<Either<Failure, List<Desaparecido>>> _getDesaparecidosConBusquedaInteligente({
    required String searchQuery,
    required MissingFilter filter,
    required int? limit,
    required String? departamento,
    String? provincia,
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
          provincia: provincia,
        );
      }

      Query<Map<String, dynamic>> query = _desaparecidosCollection;

      final cleanDept = departamento?.trim();
      final bool hasDeptFilter = cleanDept != null &&
          cleanDept.isNotEmpty &&
          cleanDept.toLowerCase() != 'todos' &&
          cleanDept.toLowerCase() != 'todos los departamentos';

      final cleanProv = provincia?.trim();
      final bool hasProvFilter = cleanProv != null &&
          cleanProv.isNotEmpty &&
          cleanProv.toLowerCase() != 'todas' &&
          cleanProv.toLowerCase() != 'todas las provincias';

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
        final firstTerm = searchTerms.first
            .replaceAll('á', 'a')
            .replaceAll('é', 'e')
            .replaceAll('í', 'i')
            .replaceAll('ó', 'o')
            .replaceAll('ú', 'u')
            .replaceAll('ñ', 'n');
        final keywordQuery = query.where('keywords', arrayContains: firstTerm).limit(120);
        final keywordSnapshot = await keywordQuery.get();
        if (keywordSnapshot.docs.isNotEmpty) {
          allResults = keywordSnapshot.docs.map((doc) {
            return Desaparecido.fromMap(doc.data(), doc.id);
          }).toList();
        }
      } catch (e) {
        print('⚠️ Búsqueda por keywords no disponible o falló: $e');
      }

      // 2. Fallback a búsqueda por prefijo si no hubo resultados por keywords
      if (allResults.isEmpty) {
        final orFallback = await _getDesaparecidosConBusquedaOr(
          searchQuery: searchQuery,
          filter: filter,
          limit: limit,
          departamento: departamento,
          provincia: provincia,
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

      // Garantía estricta de departamento y provincia
      if (hasDeptFilter) {
        allResults = allResults.where((d) {
          return PeruLocations.matchesDepartment(
            caseDept: d.departamento,
            targetDept: cleanDept,
            caseProv: d.provincia,
            caseDist: d.distrito,
          );
        }).toList();
      }

      if (hasProvFilter) {
        allResults = allResults.where((d) {
          return PeruLocations.matchesProvince(
            caseProv: d.provincia,
            caseDist: d.distrito,
            caseDetalles: d.detallesAdicionales,
            targetProv: cleanProv,
          );
        }).toList();
      }

      // Deduplicación por ID, DNI y clave
      final Set<String> seenSearchIds = <String>{};
      final Set<String> seenSearchDnis = <String>{};
      final Set<String> seenSearchKeys = <String>{};
      final List<Desaparecido> uniqueSearchResults = [];
      for (final d in allResults) {
        final id = d.id?.trim();
        final dni = d.dni?.trim();
        final normName = PeruLocations.normalize('${d.nombres} ${d.apellidos}');
        final normDept = PeruLocations.normalize(d.departamento ?? '');
        final key = '$normName|$normDept';

        if (id != null && id.isNotEmpty && !seenSearchIds.add(id)) continue;
        if (dni != null && dni.isNotEmpty && dni.length >= 8 && !seenSearchDnis.add(dni)) continue;
        if (normName.isNotEmpty && !seenSearchKeys.add(key)) continue;

        uniqueSearchResults.add(d);
      }
      allResults = uniqueSearchResults;

      // 🔥 BÚSQUEDA INTELIGENTE CON PUNTUACIÓN DE RELEVANCIA
      final searchResults = _performIntelligentSearch(allResults, searchQuery);
      _lastQueryHadMore = false;

      final finalLimit = limit ?? 30;
      if (searchResults.length > finalLimit) {
        return Right(searchResults.take(finalLimit).toList());
      }

      return Right(searchResults);
    } catch (e) {
      print('Error en búsqueda inteligente: $e');
      return _getDesaparecidosConBusquedaOr(
        searchQuery: searchQuery,
        filter: filter,
        limit: limit,
        departamento: departamento,
        provincia: provincia,
      );
    }
  }

  List<Desaparecido> _performIntelligentSearch(List<Desaparecido> allData, String searchQuery) {
    if (searchQuery.trim().isEmpty) return allData;

    final query = searchQuery.trim().toLowerCase();
    final searchTerms = query.split(' ').where((term) => term.isNotEmpty).toList();

    final List<MapEntry<Desaparecido, double>> scoredResults = [];

    for (final person in allData) {
      final score = _calculateSearchScore(person, query, searchTerms);
      if (score > 0) {
        scoredResults.add(MapEntry(person, score));
      }
    }

    scoredResults.sort((a, b) => b.value.compareTo(a.value));

    return scoredResults.map((entry) => entry.key).toList();
  }

  double _calculateSearchScore(Desaparecido person, String fullQuery, List<String> searchTerms) {
    double score = 0.0;

    final nombres = person.nombres.toLowerCase();
    final apellidos = person.apellidos.toLowerCase();
    final dni = person.dni?.toLowerCase() ?? '';
    final fullName = '$nombres $apellidos';

    if (dni.isNotEmpty && dni.contains(fullQuery)) {
      score += 100.0;
      if (dni == fullQuery) score += 50.0;
    }

    if (fullName == fullQuery) {
      score += 90.0;
    }

    if (nombres == fullQuery || apellidos == fullQuery) {
      score += 80.0;
    }

    for (final term in searchTerms) {
      if (nombres.contains(term)) {
        score += 30.0;
        if (nombres.startsWith(term)) score += 20.0;
      }

      if (apellidos.contains(term)) {
        score += 30.0;
        if (apellidos.startsWith(term)) score += 20.0;
      }

      final nombreWords = nombres.split(' ');
      for (final word in nombreWords) {
        if (word.startsWith(term)) score += 25.0;
        if (word == term) score += 35.0;
      }

      final apellidoWords = apellidos.split(' ');
      for (final word in apellidoWords) {
        if (word.startsWith(term)) score += 25.0;
        if (word == term) score += 35.0;
      }
    }

    for (final term in searchTerms) {
      if (term.length >= 3) {
        if (_isSimilar(nombres, term) || _isSimilar(apellidos, term)) {
          score += 10.0;
        }
      }
    }

    return score;
  }

  bool _isSimilar(String text, String term) {
    if (text.length < term.length) return false;

    int matches = 0;
    for (int i = 0; i < term.length; i++) {
      if (i < text.length && text[i] == term[i]) {
        matches++;
      }
    }

    return (matches / term.length) >= 0.7;
  }

  Future<Either<Failure, List<Desaparecido>>> _getDesaparecidosConBusquedaOr({
    required String searchQuery,
    required MissingFilter filter,
    required int? limit,
    required String? departamento,
    String? provincia,
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

      final int fetchLimit = (limit ?? 15) * 2;
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

      final cleanProv = provincia?.trim();
      final bool hasProvFilter = cleanProv != null &&
          cleanProv.isNotEmpty &&
          cleanProv.toLowerCase() != 'todas' &&
          cleanProv.toLowerCase() != 'todas las provincias';

      List<Desaparecido> filtered = finalResults;
      if (hasProvFilter) {
        filtered = filtered.where((d) {
          return PeruLocations.matchesProvince(
            caseProv: d.provincia,
            caseDist: d.distrito,
            caseDetalles: d.detallesAdicionales,
            targetProv: cleanProv,
          );
        }).toList();
      }

      filtered.sort((a, b) => a.nombres.compareTo(b.nombres));
      _lastQueryHadMore = false;

      if (filtered.length > (limit ?? 20)) {
        return Right(filtered.sublist(0, limit ?? 20));
      }

      return Right(filtered);
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

  // ✅ PAGINACIÓN ROBUSTA CON DOCUMENT SNAPSHOT CURSOR Y SOPORTE DE PROVINCIA / 8 MESES
  Future<Either<Failure, List<Desaparecido>>> _getDesaparecidosSimple({
    required MissingFilter filter,
    required int? limit,
    required Desaparecido? lastDesaparecido,
    required String? departamento,
    String? provincia,
  }) async {
    try {
      if (lastDesaparecido == null) {
        _cursorSnapshots.clear();
      }

      Query<Map<String, dynamic>> query = _desaparecidosCollection;

      final cleanDept = departamento?.trim();
      final bool hasDeptFilter = cleanDept != null &&
          cleanDept.isNotEmpty &&
          cleanDept.toLowerCase() != 'todos' &&
          cleanDept.toLowerCase() != 'todos los departamentos';

      final cleanProv = provincia?.trim();
      final bool hasProvFilter = cleanProv != null &&
          cleanProv.isNotEmpty &&
          cleanProv.toLowerCase() != 'todas' &&
          cleanProv.toLowerCase() != 'todas las provincias';

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

      // 3. Ordenar por fecha de desaparición descendente y paginar con DocumentSnapshot real
      // Esto evita el bug de saltar casos que comparten la misma fecha/hora de desaparición.
      query = query.orderBy('fecha_desaparicion', descending: true);
      if (lastDesaparecido != null) {
        final String? lastId = lastDesaparecido.id;
        if (lastId != null && _cursorSnapshots.containsKey(lastId)) {
          query = query.startAfterDocument(_cursorSnapshots[lastId]!);
        } else if (lastDesaparecido.fechaDesaparicion != null) {
          query = query.startAfter([Timestamp.fromDate(lastDesaparecido.fechaDesaparicion!)]);
        }
      }

      // 4. Límite de documentos a solicitar:
      // Si hay filtro de provincia dentro de un departamento, ampliamos el lote de lectura
      // para encontrar todos los casos de esa provincia en los últimos 8 meses sin dejar la lista vacía.
      // Además sumamos un pequeño margen (+8) para que la deduplicación en memoria nunca corte la página 1.
      final int requestedLimit = limit ?? 30;
      final int rawFetchLimit = hasProvFilter
          ? 160
          : (requestedLimit + 8);
      if (limit != null) {
        query = query.limit(rawFetchLimit);
      }

      // 4.1 Estrategia Cache-First + Delta Sync (Optimizado para Plan Spark de Firebase):
      QuerySnapshot<Map<String, dynamic>> querySnapshot;
      try {
        final prefs = await SharedPreferences.getInstance();
        final cacheKey = 'last_delta_sync_${filter.name}_${cleanDept ?? "ALL"}_${cleanProv ?? "ALL"}';
        final lastSyncMs = prefs.getInt(cacheKey) ?? 0;
        final nowMs = DateTime.now().millisecondsSinceEpoch;

        if (lastDesaparecido == null && lastSyncMs > 0 && (nowMs - lastSyncMs) < _kDeltaSyncCooldownMs) {
          try {
            final cachedSnapshot = await query.get(const GetOptions(source: Source.cache));
            if (cachedSnapshot.docs.isNotEmpty) {
              querySnapshot = cachedSnapshot;
            } else {
              querySnapshot = await query.get(const GetOptions(source: Source.serverAndCache));
              await prefs.setInt(cacheKey, nowMs);
            }
          } catch (_) {
            querySnapshot = await query.get(const GetOptions(source: Source.serverAndCache));
            await prefs.setInt(cacheKey, nowMs);
          }
        } else {
          try {
            querySnapshot = await query.get(const GetOptions(source: Source.serverAndCache));
          } catch (_) {
            querySnapshot = await query.get();
          }
          if (lastDesaparecido == null) {
            await prefs.setInt(cacheKey, nowMs);
          }
        }
      } catch (_) {
        querySnapshot = await query.get();
      }

      // Registrar snapshots reales para paginación exacta por cursor
      for (final doc in querySnapshot.docs) {
        _cursorSnapshots[doc.id] = doc;
      }

      final DateTime limiteOchoMeses = DateTime.now().subtract(const Duration(days: 240));

      // Evaluar si el documento más antiguo del lote ya superó los 8 meses (para cortar lecturas innecesarias)
      bool reachedEightMonthCutoff = false;
      if (querySnapshot.docs.isNotEmpty && filter == MissingFilter.active) {
        final lastRawDoc = Desaparecido.fromMap(
          querySnapshot.docs.last.data(),
          querySnapshot.docs.last.id,
        );
        if (lastRawDoc.fechaDesaparicion != null &&
            lastRawDoc.fechaDesaparicion!.isBefore(limiteOchoMeses)) {
          reachedEightMonthCutoff = true;
        }
      }

      _lastQueryHadMore = limit != null &&
          querySnapshot.docs.length >= rawFetchLimit &&
          !reachedEightMonthCutoff;

      List<Desaparecido> desaparecidosList = querySnapshot.docs.map((doc) {
        return Desaparecido.fromMap(doc.data(), doc.id);
      }).toList();

      // 5. Garantía de aislamiento por departamento y provincia
      if (hasDeptFilter) {
        desaparecidosList = desaparecidosList.where((d) {
          return PeruLocations.matchesDepartment(
            caseDept: d.departamento,
            targetDept: cleanDept,
            caseProv: d.provincia,
            caseDist: d.distrito,
          );
        }).toList();
      }

      if (hasProvFilter) {
        desaparecidosList = desaparecidosList.where((d) {
          return PeruLocations.matchesProvince(
            caseProv: d.provincia,
            caseDist: d.distrito,
            caseDetalles: d.detallesAdicionales,
            targetProv: cleanProv,
          );
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
      desaparecidosList = desaparecidosList.where((d) {
        final fechaRef = (filter == MissingFilter.found)
            ? (d.fechaEncontrado ?? d.fechaDesaparicion)
            : d.fechaDesaparicion;
        return fechaRef == null || fechaRef.isAfter(limiteOchoMeses);
      }).toList();

      // 7. Deduplicación defensiva por ID, DNI y clave de persona
      final Set<String> seenIds = <String>{};
      final Set<String> seenDnis = <String>{};
      final Set<String> seenKeys = <String>{};
      final List<Desaparecido> uniqueList = [];

      for (final d in desaparecidosList) {
        final id = d.id?.trim();
        final dni = d.dni?.trim();
        final normName = PeruLocations.normalize('${d.nombres} ${d.apellidos}');
        final normDept = PeruLocations.normalize(d.departamento ?? '');
        final key = '$normName|$normDept';

        if (id != null && id.isNotEmpty && !seenIds.add(id)) continue;
        if (dni != null && dni.isNotEmpty && dni.length >= 8 && !seenDnis.add(dni)) continue;
        if (normName.isNotEmpty && !seenKeys.add(key)) continue;

        uniqueList.add(d);
      }
      desaparecidosList = uniqueList;

      // Si el último elemento filtrado fue recortado respecto al último documento crudo del lote,
      // asociar su ID con el último DocumentSnapshot real del lote para no releer documentos descartados.
      if (desaparecidosList.isNotEmpty &&
          querySnapshot.docs.isNotEmpty &&
          desaparecidosList.last.id != null) {
        _cursorSnapshots[desaparecidosList.last.id!] = querySnapshot.docs.last;
      }

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
    String? provincia,
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

  Future<Either<Failure, List<HistorialEncontrado>>> getHistorialEncontrados({
    String? policiaId,
    String? desaparecidoId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _historialEncontradoCollection;

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

      query = query.orderBy('fechaCreacion', descending: true);

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

      final List<HistorialEncontrado> historialList = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return HistorialEncontrado.fromMap(data);
      }).toList();

      return Right(historialList);
    } on FirebaseException catch (e) {
      return Left(DatabaseFailure(e.message ?? 'Error al obtener historial de encontrados.'));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

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
