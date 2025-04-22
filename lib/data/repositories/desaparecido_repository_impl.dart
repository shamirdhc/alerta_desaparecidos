import 'package:dartz/dartz.dart';
import '../../domain/entities/desaparecido.dart';
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
  Future<Either<Failure, List<Desaparecido>>> getDesaparecidos({
    MissingFilter filter = MissingFilter.active,
    int? limit,
    Desaparecido? lastDesaparecido, // Cambiado de `offset` a `lastDesaparecido`
    String? searchQuery,
  }) async {
    return await remoteDataSource.getDesaparecidos(
      filter: filter,
      limit: limit,
      lastDesaparecido: lastDesaparecido, // Se pasa el nuevo parámetro
      searchQuery: searchQuery,
    );
  }

  @override
  Future<Either<Failure, void>> marcarComoEncontrado(
      String desaparecidoId,
      ) async {
    return await remoteDataSource.marcarComoEncontrado(desaparecidoId);
  }

// TODO: Definir otros métodos del repositorio (si los hay)
}