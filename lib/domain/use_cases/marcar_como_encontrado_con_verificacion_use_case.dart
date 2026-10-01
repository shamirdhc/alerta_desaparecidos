import 'package:dartz/dartz.dart';
import '../entities/historial_encontrado.dart';
import '../repositories/desaparecido_repository.dart';
import '../repositories/policia_repository.dart';
import '../../common/failure.dart';

class MarcarComoEncontradoConVerificacionUseCase {
  final DesaparecidoRepository _desaparecidoRepository;
  final PoliciaRepository _policiaRepository;

  MarcarComoEncontradoConVerificacionUseCase(
    this._desaparecidoRepository,
    this._policiaRepository,
  );

  Future<Either<Failure, String>> execute(
    String desaparecidoId, {
    required DateTime fechaEncontrado,
    required String encontradoDetalles,
  }) async {
    try {
      // 1. Obtener información del policía actual
      final policia = await _policiaRepository.getCurrentPolicia();
      if (policia == null) {
        return const Left(DatabaseFailure('No se pudo obtener información del policía actual'));
      }

      // 2. Obtener información del desaparecido
      final desaparecidoResult = await _desaparecidoRepository.getDesaparecidoById(desaparecidoId);
      return desaparecidoResult.fold(
        (failure) => Left(failure),
        (desaparecido) async {
          if (desaparecido == null) {
            return const Left(DatabaseFailure('No se encontró el caso del desaparecido'));
          }

          // 3. Verificar jurisdicción (los administradores PNP tienen jurisdicción nacional)
          final departamentoDesaparecido = _normalizarDepartamento(desaparecido.departamento ?? '');
          final departamentoPolicia = _normalizarDepartamento(policia.departamento);

          if (!policia.admin &&
              departamentoDesaparecido.isNotEmpty &&
              departamentoPolicia.isNotEmpty &&
              departamentoDesaparecido != departamentoPolicia) {
            return Left(JurisdictionFailure(
              'El desaparecido está fuera de su jurisdicción. '
              'Desaparecido en: $departamentoDesaparecido, '
              'Su jurisdicción: $departamentoPolicia. '
              'Comuníquese con la central policial del aplicativo.'
            ));
          }

          // 4. Marcar como encontrado
          final marcarResult = await _desaparecidoRepository.marcarComoEncontrado(
            desaparecidoId,
            fechaEncontrado: fechaEncontrado,
            encontradoDetalles: encontradoDetalles,
          );

          return marcarResult.fold(
            (failure) => Left(failure),
            (_) async {
              // 5. Crear registro en el historial
              final historial = HistorialEncontrado(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                desaparecidoId: desaparecidoId,
                desaparecidoNombre: '${desaparecido.nombres} ${desaparecido.apellidos}',
                desaparecidoDni: desaparecido.dni ?? 'No especificado',
                policiaId: policia.uid,
                policiaNombre: '${policia.nombre} ${policia.apellido}',
                policiaRango: policia.rango,
                policiaDepartamento: policia.departamento,
                fechaAccion: fechaEncontrado,
                detallesHallazgo: encontradoDetalles,
                ubicacionHallazgo: desaparecido.departamento ?? 'No especificado',
                fechaCreacion: DateTime.now(),
              );

              // 6. Guardar historial
              final historialResult = await _desaparecidoRepository.guardarHistorialEncontrado(historial);
              
              return historialResult.fold(
                (failure) {
                  // Si falla el historial, aún consideramos exitoso el marcado
                  print('⚠️ Advertencia: No se pudo guardar el historial: ${failure.message}');
                  return const Right('Caso marcado como encontrado exitosamente');
                },
                (_) => const Right('Caso marcado como encontrado exitosamente'),
              );
            },
          );
        },
      );
    } catch (e) {
      return Left(DatabaseFailure('Error inesperado: $e'));
    }
  }

  String _normalizarDepartamento(String departamento) {
    return departamento
        .trim()
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ñ', 'N');
  }
}

// Nueva clase de falla para jurisdicción
class JurisdictionFailure extends Failure {
  const JurisdictionFailure(super.message);
}