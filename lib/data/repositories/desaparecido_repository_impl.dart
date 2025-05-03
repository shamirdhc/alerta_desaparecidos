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
    Desaparecido? lastDesaparecido,
    String? searchQuery,
    String? departamento, // <-- CAMBIO: Aceptar parámetro departamento
  }) async {
    // Pasa todos los parámetros al DataSource
    return await remoteDataSource.getDesaparecidos(
      filter: filter,
      limit: limit,
      lastDesaparecido: lastDesaparecido,
      searchQuery: searchQuery,
      departamento: departamento, // <-- CAMBIO: Pasar departamento al DataSource
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