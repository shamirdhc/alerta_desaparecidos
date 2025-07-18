import 'package:dartz/dartz.dart';
import '../entities/desaparecido.dart';
import '../entities/paginated_response.dart';
import '../../common/failure.dart';
import '../enums.dart';

abstract class DesaparecidoRepository {
  Future<Either<Failure, void>> reportDesaparecido(Desaparecido desaparecido);

  Future<Either<Failure, PaginatedResponse<Desaparecido>>> getDesaparecidos({
    MissingFilter filter = MissingFilter.active,
    int? limit,
    Desaparecido? lastDesaparecido,
    String? searchQuery,
    String? departamento,
  });

  Future<Either<Failure, void>> marcarComoEncontrado(String desaparecidoId);

  // Métodos adicionales necesarios
  Future<Either<Failure, List<Desaparecido>>> getAllDesaparecidos();
  
  Future<Either<Failure, void>> markCaseAsFound(String caseId, String details);
}