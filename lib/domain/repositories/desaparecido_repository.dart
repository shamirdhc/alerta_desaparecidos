import 'package:dartz/dartz.dart';
import '../entities/desaparecido.dart';
import '../../common/failure.dart';
import '../enums.dart'; // Importa el enum desde la capa de dominio

abstract class DesaparecidoRepository {
  Future<Either<Failure, void>> reportDesaparecido(Desaparecido desaparecido);
  Future<Either<Failure, List<Desaparecido>>> getDesaparecidos({
    MissingFilter filter = MissingFilter.active,
    int? limit,
    int? offset,
    String? searchQuery,
  });
  Future<Either<Failure, void>> marcarComoEncontrado(String desaparecidoId);
  // TODO: Definir otros métodos del repositorio
}
