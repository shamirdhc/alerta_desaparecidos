import 'package:flutter/foundation.dart';
import 'package:dartz/dartz.dart';
import '../../domain/entities/desaparecido.dart';
import '../../domain/entities/paginated_response.dart';
import '../../domain/entities/historial_encontrado.dart';
import '../../domain/repositories/desaparecido_repository.dart';
import '../data_sources/desaparecido_remote_data_source.dart';
import '../data_sources/desaparecido_local_data_source.dart';
import '../../common/failure.dart';
import '../../domain/enums.dart';

class DesaparecidoRepositoryImpl implements DesaparecidoRepository {
  final DesaparecidoRemoteDataSource remoteDataSource;
  final DesaparecidoLocalDataSource localDataSource;

  bool _isDeltaSyncing = false;

  DesaparecidoRepositoryImpl(this.remoteDataSource, this.localDataSource);

  @override
  Future<Either<Failure, void>> reportDesaparecido(
    Desaparecido desaparecido,
  ) async {
    final result = await remoteDataSource.reportDesaparecido(desaparecido);
    result.fold(
      (failure) => null,
      (_) async {
        if (!kIsWeb) {
          await localDataSource.saveDesaparecidosBatch([desaparecido]);
        }
      },
    );
    return result;
  }

  @override
  Future<Either<Failure, PaginatedResponse<Desaparecido>>> getDesaparecidos({
    MissingFilter filter = MissingFilter.active,
    int? limit,
    Desaparecido? lastDesaparecido,
    String? searchQuery,
    String? departamento,
    String? provincia,
    int? offset,
  }) async {
    // Si estamos en Web, recurrimos al origen remoto directamente
    if (kIsWeb) {
      return _getDesaparecidosFromRemote(
        filter: filter,
        limit: limit,
        lastDesaparecido: lastDesaparecido,
        searchQuery: searchQuery,
        departamento: departamento,
        provincia: provincia,
      );
    }

    try {
      final localCount = await localDataSource.getLocalCount();

      // Carga inicial si la base de datos SQLite está vacía
      if (localCount == 0) {
        debugPrint('🚀 [LOCAL-DB] Base de datos local vacía. Realizando sincronización inicial con Firebase...');
        final syncResult = await remoteDataSource.getCasesForSync();
        await syncResult.fold(
          (failure) async {
            debugPrint('⚠️ [LOCAL-DB] Error en sincronización inicial remota: ${failure.message}');
          },
          (cases) async {
            debugPrint('📥 [LOCAL-DB] Guardando ${cases.length} casos iniciales en SQLite...');
            await localDataSource.saveDesaparecidosBatch(cases);
            await localDataSource.setLastSyncTime(DateTime.now());
            debugPrint('✅ [LOCAL-DB] Sincronización inicial en SQLite completada.');
          },
        );
      } else {
        // Disparar sincronización delta en segundo plano si han pasado más de 30 minutos
        _triggerBackgroundDeltaSync();
      }

      final int fetchLimit = limit ?? 30;
      final int fetchOffset = offset ?? 0;

      // Consultar la base de datos local SQLite (Ultra-rápido, 0 lecturas a Firebase)
      final localData = await localDataSource.getDesaparecidos(
        filter: filter,
        departamento: departamento,
        provincia: provincia,
        searchQuery: searchQuery,
        limit: fetchLimit,
        offset: fetchOffset,
      );

      final totalCount = await localDataSource.getTotalCount(
        filter: filter,
        departamento: departamento,
        provincia: provincia,
        searchQuery: searchQuery,
      );

      final bool hasMore = (fetchOffset + localData.length) < totalCount && localData.isNotEmpty;

      return Right(PaginatedResponse(
        data: localData,
        totalCount: totalCount,
        hasMore: hasMore,
      ));
    } catch (e) {
      debugPrint('⚠️ [LOCAL-DB] Excepción en SQLite local, fallback a Firebase: $e');
      return _getDesaparecidosFromRemote(
        filter: filter,
        limit: limit,
        lastDesaparecido: lastDesaparecido,
        searchQuery: searchQuery,
        departamento: departamento,
        provincia: provincia,
      );
    }
  }

  void _triggerBackgroundDeltaSync() {
    if (_isDeltaSyncing) return;
    _isDeltaSyncing = true;

    Future.microtask(() async {
      try {
        final lastSync = await localDataSource.getLastSyncTime();
        final now = DateTime.now();

        // Sincronizar solo si pasaron al menos 30 minutos desde la última comprobación
        if (lastSync == null || now.difference(lastSync).inMinutes >= 30) {
          debugPrint('🔄 [DELTA-SYNC] Verificando modificaciones en Firestore desde $lastSync...');
          final syncResult = await remoteDataSource.getCasesForSync(modifiedSince: lastSync);
          await syncResult.fold(
            (failure) async {
              debugPrint('⚠️ [DELTA-SYNC] Error en verificación delta: ${failure.message}');
            },
            (newCases) async {
              if (newCases.isNotEmpty) {
                debugPrint('📥 [DELTA-SYNC] Actualizando ${newCases.length} casos modificados en SQLite...');
                await localDataSource.saveDesaparecidosBatch(newCases);
              } else {
                debugPrint('✨ [DELTA-SYNC] No hubo cambios en Firebase. Base de datos local al día.');
              }
              await localDataSource.purgeExpiredCases();
              await localDataSource.setLastSyncTime(now);
            },
          );
        }
      } catch (e) {
        debugPrint('⚠️ [DELTA-SYNC] Error en tarea en segundo plano: $e');
      } finally {
        _isDeltaSyncing = false;
      }
    });
  }

  Future<Either<Failure, PaginatedResponse<Desaparecido>>> _getDesaparecidosFromRemote({
    required MissingFilter filter,
    int? limit,
    Desaparecido? lastDesaparecido,
    String? searchQuery,
    String? departamento,
    String? provincia,
  }) async {
    final dataResult = await remoteDataSource.getDesaparecidos(
      filter: filter,
      limit: limit,
      lastDesaparecido: lastDesaparecido,
      searchQuery: searchQuery,
      departamento: departamento,
      provincia: provincia,
    );

    return dataResult.fold(
      (failure) => Left(failure),
      (data) async {
        final totalResult = await remoteDataSource.getTotalCount(
          filter: filter,
          searchQuery: searchQuery,
          departamento: departamento,
          provincia: provincia,
        );

        final bool hasMore = remoteDataSource.lastQueryHadMore;

        return totalResult.fold(
          (failure) => Left(failure),
          (totalCount) => Right(PaginatedResponse(
            data: data,
            totalCount: totalCount,
            hasMore: hasMore,
          )),
        );
      },
    );
  }

  @override
  Future<Either<Failure, void>> marcarComoEncontrado(
    String desaparecidoId, {
    DateTime? fechaEncontrado,
    String? encontradoDetalles,
  }) async {
    final result = await remoteDataSource.marcarComoEncontrado(
      desaparecidoId,
      fechaEncontrado: fechaEncontrado,
      encontradoDetalles: encontradoDetalles,
    );
    result.fold(
      (failure) => null,
      (_) async {
        if (!kIsWeb) {
          await localDataSource.markAsFoundLocal(
            desaparecidoId,
            fechaEncontrado ?? DateTime.now(),
            encontradoDetalles ?? 'LOCALIZADO',
          );
        }
      },
    );
    return result;
  }

  @override
  Future<Either<Failure, List<Desaparecido>>> getAllDesaparecidos() async {
    if (!kIsWeb) {
      try {
        final local = await localDataSource.getDesaparecidos(
          filter: MissingFilter.all,
          limit: 2000,
          offset: 0,
        );
        if (local.isNotEmpty) {
          return Right(local);
        }
      } catch (_) {}
    }
    return await remoteDataSource.getDesaparecidos(
      filter: MissingFilter.all,
      limit: null,
    );
  }

  @override
  Future<Either<Failure, void>> markCaseAsFound(String caseId, String details) async {
    final result = await remoteDataSource.markCaseAsFound(caseId, details);
    result.fold(
      (failure) => null,
      (_) async {
        if (!kIsWeb) {
          await localDataSource.markAsFoundLocal(caseId, DateTime.now(), details);
        }
      },
    );
    return result;
  }

  @override
  Future<Either<Failure, Desaparecido?>> getDesaparecidoById(String id) async {
    return await remoteDataSource.getDesaparecidoById(id);
  }

  @override
  Future<Either<Failure, void>> guardarHistorialEncontrado(HistorialEncontrado historial) async {
    return await remoteDataSource.guardarHistorialEncontrado(historial);
  }

  @override
  Future<Either<Failure, List<HistorialEncontrado>>> getHistorialEncontrados({
    String? policiaId,
    String? desaparecidoId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    return await remoteDataSource.getHistorialEncontrados(
      policiaId: policiaId,
      desaparecidoId: desaparecidoId,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
    );
  }
}