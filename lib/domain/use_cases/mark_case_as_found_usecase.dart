import 'package:dartz/dartz.dart';
import '../../common/failure.dart';
import '../repositories/desaparecido_repository.dart';

class MarkCaseAsFoundUseCase {
  final DesaparecidoRepository repository;

  MarkCaseAsFoundUseCase(this.repository);

  Future<Either<Failure, void>> execute(String caseId, String details) async {
    return await repository.markCaseAsFound(caseId, details);
  }
}