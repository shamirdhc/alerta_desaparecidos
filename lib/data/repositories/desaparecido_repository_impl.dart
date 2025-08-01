import 'package:dartz/dartz.dart';
import '../../domain/entities/desaparecido.dart';
import '../../domain/entities/paginated_response.dart';
import '../../domain/entities/historial_encontrado.dart';
import '../../domain/repositories/desaparecido_repository.dart';
import '../data_sources/desaparecido_remote_data_source.dart';
import '../../common/failure.dart';
import '../../domain/enums.dart';

class DesaparecidoRepositoryImpl implements DesaparecidoRepository {
  final DesaparecidoRemoteDataSource remoteDataSource;

  DesaparecidoRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, void>> reportDesaparecido(
      Desaparecido desaparecido,
      ) async {
    return await remoteDataSource.reportDesaparecido(desaparecido);
  }

  @override
  Future<Either<Failure, PaginatedResponse<Desaparecido>>> getDesaparecidos({
    MissingFilter filter = MissingFilter.active,
    int? limit,
    Desaparecido? lastDesaparecido,
    String? searchQuery,
    String? departamento,
  }) async {
    final dataResult = await remoteDataSource.getDesaparecidos(
      filter: filter,
      limit: limit,
      lastDesaparecido: lastDesaparecido,
      searchQuery: searchQuery,
      departamento: departamento,
    );
    
    return dataResult.fold(
      (failure) => Left(failure),
      (data) async {
        final totalResult = await remoteDataSource.getTotalCount(
          filter: filter,
          searchQuery: searchQuery,
          departamento: departamento,
        );
        
        return totalResult.fold(
          (failure) => Left(failure),
          (totalCount) => Right(PaginatedResponse(
            data: data,
            totalCount: totalCount,
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
      return await remoteDataSource.marcarComoEncontrado(
        desaparecidoId,
        fechaEncontrado: fechaEncontrado,
        encontradoDetalles: encontradoDetalles,
      );
    }

  @override
  Future<Either<Failure, List<Desaparecido>>> getAllDesaparecidos() async {
    try {
      // Obtener todos los casos sin paginación
      final result = await remoteDataSource.getDesaparecidos(
        filter: MissingFilter.all,
        limit: null, // Sin límite para obtener todos
      );
      
      return result;
    } catch (e) {
      return Left(ServerFailure('Error al obtener todos los casos: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> markCaseAsFound(String caseId, String details) async {
    try {
      return await remoteDataSource.markCaseAsFound(caseId, details);
    } catch (e) {
      return Left(ServerFailure('Error al marcar caso como encontrado: $e'));
    }
  }

  @override
  Future<Either<Failure, Desaparecido?>> getDesaparecidoById(String id) async {
    try {
      return await remoteDataSource.getDesaparecidoById(id);
    } catch (e) {
      return Left(ServerFailure('Error al obtener desaparecido: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> guardarHistorialEncontrado(HistorialEncontrado historial) async {
    try {
      return await remoteDataSource.guardarHistorialEncontrado(historial);
    } catch (e) {
      return Left(ServerFailure('Error al guardar historial: $e'));
    }
  }

  @override
  Future<Either<Failure, List<HistorialEncontrado>>> getHistorialEncontrados({
    String? policiaId,
    String? desaparecidoId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      return await remoteDataSource.getHistorialEncontrados(
        policiaId: policiaId,
        desaparecidoId: desaparecidoId,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
      );
    } catch (e) {
      return Left(ServerFailure('Error al obtener historial: $e'));
    }
  }
}