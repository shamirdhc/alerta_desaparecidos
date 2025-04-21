import 'package:dartz/dartz.dart';
import '../repositories/desaparecido_repository.dart';
import '../../common/failure.dart';

class MarcarComoEncontradoUseCase {
  final DesaparecidoRepository _repository;

  MarcarComoEncontradoUseCase(this._repository);

  Future<Either<Failure, void>> execute(String desaparecidoId) async {
    return await _repository.marcarComoEncontrado(desaparecidoId);
  }
}
