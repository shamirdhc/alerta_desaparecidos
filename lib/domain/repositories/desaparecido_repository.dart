import 'package:dartz/dartz.dart';
import '../entities/desaparecido.dart';
import '../entities/paginated_response.dart';
import '../entities/historial_encontrado.dart';
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
    String? provincia,
    int? offset,
  });

  Future<Either<Failure, void>> marcarComoEncontrado(
    String desaparecidoId, {
    DateTime? fechaEncontrado,
    String? encontradoDetalles,
  });

  // Métodos adicionales necesarios
  Future<Either<Failure, List<Desaparecido>>> getAllDesaparecidos();
  
  Future<Either<Failure, void>> markCaseAsFound(String caseId, String details);

  // Nuevo método para obtener un desaparecido por ID
  Future<Either<Failure, Desaparecido?>> getDesaparecidoById(String id);

  // Nuevo método para guardar historial de encontrados
  Future<Either<Failure, void>> guardarHistorialEncontrado(HistorialEncontrado historial);

  // Método para obtener historial de encontrados
  Future<Either<Failure, List<HistorialEncontrado>>> getHistorialEncontrados({
    String? policiaId,
    String? desaparecidoId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  });
}