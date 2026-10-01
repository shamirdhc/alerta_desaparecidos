import 'package:flutter/material.dart';
import '../../../common/state_enum.dart';
import '../../../domain/use_cases/marcar_como_encontrado_con_verificacion_use_case.dart';

class MissingDetailsViewModel extends ChangeNotifier {
  final MarcarComoEncontradoConVerificacionUseCase _marcarComoEncontradoConVerificacionUseCase;

  MissingDetailsViewModel(this._marcarComoEncontradoConVerificacionUseCase);

  RequestState _marcarEncontradoState = RequestState.Empty;
  RequestState get marcarEncontradoState => _marcarEncontradoState;

  String _mensajeMarcarEncontrado = '';
  String get mensajeMarcarEncontrado => _mensajeMarcarEncontrado;

  String _progressMessage = '';
  String get progressMessage => _progressMessage;

  double _progressValue = 0.0;
  double get progressValue => _progressValue;

  Future<void> marcarComoEncontrado(
    String desaparecidoId, {
    DateTime? fechaEncontrado,
    String? encontradoDetalles,
  }) async {
    _marcarEncontradoState = RequestState.Loading;
    _progressValue = 0.0;
    _progressMessage = 'Verificando jurisdicción y permisos PNP...';
    notifyListeners();

    try {
      _progressValue = 0.3;
      _progressMessage = 'Registrando auditoría en historial policial...';
      notifyListeners();

      final result = await _marcarComoEncontradoConVerificacionUseCase.execute(
        desaparecidoId,
        fechaEncontrado: fechaEncontrado ?? DateTime.now(),
        encontradoDetalles: (encontradoDetalles != null && encontradoDetalles.trim().isNotEmpty)
            ? encontradoDetalles
            : 'Caso resuelto y persona localizada por personal policial PNP.',
      );

      _progressValue = 0.7;
      _progressMessage = 'Actualizando estado del caso...';
      notifyListeners();

      result.fold(
        (failure) {
          _mensajeMarcarEncontrado = failure.message;
          _marcarEncontradoState = RequestState.Error;
          _progressMessage = failure.message;
        },
        (success) {
          _progressValue = 1.0;
          _progressMessage = 'Proceso completado exitosamente';
          _mensajeMarcarEncontrado = success;
          _marcarEncontradoState = RequestState.Loaded;
        },
      );
    } catch (e) {
      _mensajeMarcarEncontrado = 'Error inesperado: $e';
      _marcarEncontradoState = RequestState.Error;
      _progressMessage = 'Error en el proceso';
    }
    
    notifyListeners();
  }

  void resetState() {
    _marcarEncontradoState = RequestState.Empty;
    _mensajeMarcarEncontrado = '';
    _progressMessage = '';
    _progressValue = 0.0;
    notifyListeners();
  }
}
