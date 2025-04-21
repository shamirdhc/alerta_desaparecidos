import 'package:dartz/dartz.dart';
import '../entities/desaparecido.dart';
import '../repositories/desaparecido_repository.dart';
import '../../common/failure.dart';
import '../enums.dart'; // Importa el enum desde la capa de dominio

class ObtenerDesaparecidosUseCase {
  final DesaparecidoRepository _repository;

  ObtenerDesaparecidosUseCase(this._repository);

  Future<Either<Failure, List<Desaparecido>>> execute({
    MissingFilter filter = MissingFilter.active,
    int? limit,
    int? offset,
    String? searchQuery,
  }) async {
    return await _repository.getDesaparecidos(
      filter: filter,
      limit: limit,
      offset: offset,
      searchQuery: searchQuery,
    );
  }
}
