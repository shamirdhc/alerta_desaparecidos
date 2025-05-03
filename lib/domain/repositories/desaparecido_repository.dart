import 'package:dartz/dartz.dart';
import '../entities/desaparecido.dart';
import '../../common/failure.dart'; // Ajusta la ruta si es necesario
import '../enums.dart'; // Ajusta la ruta si es necesario

abstract class DesaparecidoRepository {
  Future<Either<Failure, void>> reportDesaparecido(Desaparecido desaparecido);

  Future<Either<Failure, List<Desaparecido>>> getDesaparecidos({
    MissingFilter filter = MissingFilter.active,
    int? limit,
    Desaparecido? lastDesaparecido,
    String? searchQuery,
    String? departamento, // <-- CAMBIO: Añadir parámetro departamento
  });

  Future<Either<Failure, void>> marcarComoEncontrado(String desaparecidoId);

// TODO: Definir otros métodos del repositorio
}