import 'package:dartz/dartz.dart';
import '../../domain/entities/desaparecido.dart';
import '../../domain/entities/paginated_response.dart';
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
      String desaparecidoId,
      ) async {
    return await remoteDataSource.marcarComoEncontrado(desaparecidoId);
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
}