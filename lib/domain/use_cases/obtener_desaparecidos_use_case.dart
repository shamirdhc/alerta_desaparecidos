import 'package:dartz/dartz.dart';
import '../../common/failure.dart';
import '../entities/desaparecido.dart';
import '../entities/paginated_response.dart'; // ✅ Agregar import
import '../repositories/desaparecido_repository.dart';
import '../enums.dart';

class ObtenerDesaparecidosUseCase {
  final DesaparecidoRepository repository;

  ObtenerDesaparecidosUseCase(this.repository);

  // ✅ Cambiar el tipo de retorno
  Future<Either<Failure, PaginatedResponse<Desaparecido>>> execute({
    required int limit,
    Desaparecido? lastDesaparecido,
    String? searchQuery,
    required MissingFilter filter,
    String? departamento,
    String? provincia,
    int? offset,
  }) {
    return repository.getDesaparecidos(
      limit: limit,
      lastDesaparecido: lastDesaparecido,
      searchQuery: searchQuery,
      filter: filter,
      departamento: departamento,
      provincia: provincia,
      offset: offset,
    );
  }
}