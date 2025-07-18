import 'package:dartz/dartz.dart';
import '../../common/failure.dart';
import '../entities/desaparecido.dart';
import '../repositories/desaparecido_repository.dart';

class GetMissingCasesUseCase {
  final DesaparecidoRepository repository;

  GetMissingCasesUseCase(this.repository);

  Future<Either<Failure, List<Desaparecido>>> execute() async {
    return await repository.getAllDesaparecidos();
  }
}