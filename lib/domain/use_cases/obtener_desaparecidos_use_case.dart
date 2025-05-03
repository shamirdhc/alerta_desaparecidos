import 'package:dartz/dartz.dart';
import '../../common/failure.dart';
import '../entities/desaparecido.dart';
import '../repositories/desaparecido_repository.dart';
import '../enums.dart'; // Asegúrate de importar MissingFilter

class ObtenerDesaparecidosUseCase {
  final DesaparecidoRepository repository;

  ObtenerDesaparecidosUseCase(this.repository);

  // --- Modifica la firma del método execute ---
  Future<Either<Failure, List<Desaparecido>>> execute({
    required int limit,
    Desaparecido? lastDesaparecido,
    String? searchQuery,
    required MissingFilter filter,
    String? departamento, // <-- Añade el parámetro departamento aquí (opcional)
  }) {
    // --- Pasa el filtro y departamento al repositorio ---
    return repository.getDesaparecidos(
      limit: limit,
      lastDesaparecido: lastDesaparecido,
      searchQuery: searchQuery,
      filter: filter,
      departamento: departamento, // <-- Pasa el departamento al método del repositorio
    );
  }
}