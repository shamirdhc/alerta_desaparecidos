import 'package:dartz/dartz.dart';
import '../../domain/entities/desaparecido.dart';
import '../../domain/repositories/desaparecido_repository.dart';
import '../../common/failure.dart';

class ReportarDesaparicionUseCase {
  final DesaparecidoRepository _repository;

  ReportarDesaparicionUseCase(this._repository);

  Future<Either<Failure, void>> execute(Desaparecido desaparecido) async {
    return await _repository.reportDesaparecido(desaparecido);
  }
}
