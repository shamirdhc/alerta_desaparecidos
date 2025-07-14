import 'package:dartz/dartz.dart';
import '../entities/desaparecido.dart';
import '../entities/paginated_response.dart'; // ✅ Agregar import
import '../../common/failure.dart';
import '../enums.dart';

abstract class DesaparecidoRepository {
  Future<Either<Failure, void>> reportDesaparecido(Desaparecido desaparecido);

  // ✅ Cambiar el tipo de retorno
  Future<Either<Failure, PaginatedResponse<Desaparecido>>> getDesaparecidos({
    MissingFilter filter = MissingFilter.active,
    int? limit,
    Desaparecido? lastDesaparecido,
    String? searchQuery,
    String? departamento,
  });

  Future<Either<Failure, void>> marcarComoEncontrado(String desaparecidoId);
}