import 'package:dartz/dartz.dart';
import '../../domain/entities/desaparecido.dart';
import '../../domain/entities/paginated_response.dart'; // ✅ Agregar import
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
  // ✅ Cambiar el tipo de retorno
  Future<Either<Failure, PaginatedResponse<Desaparecido>>> getDesaparecidos({
    MissingFilter filter = MissingFilter.active,
    int? limit,
    Desaparecido? lastDesaparecido,
    String? searchQuery,
    String? departamento,
  }) async {
    // ✅ Obtener datos y total por separado
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
        // ✅ Obtener el total de registros
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
}