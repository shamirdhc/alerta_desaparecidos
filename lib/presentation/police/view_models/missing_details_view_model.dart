import 'package:flutter/material.dart';
import '../../../common/state_enum.dart';
import '../../../domain/use_cases/marcar_como_encontrado_use_case.dart';

class MissingDetailsViewModel extends ChangeNotifier {
  final MarcarComoEncontradoUseCase _marcarComoEncontradoUseCase;

  MissingDetailsViewModel(this._marcarComoEncontradoUseCase);

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
    _progressMessage = 'Iniciando proceso...';
    notifyListeners();

    try {
      // Paso 1: Eliminando comentarios
      _progressValue = 0.25;
      _progressMessage = 'Eliminando comentarios...';
      notifyListeners();
      
      // Paso 2: Eliminando ficha
      _progressValue = 0.5;
      _progressMessage = 'Eliminando ficha...';
      notifyListeners();
      
      // Paso 3: Cambiando estado
      _progressValue = 0.75;
      _progressMessage = 'Cambiando estado a encontrado...';
      notifyListeners();

      final result = await _marcarComoEncontradoUseCase.execute(
        desaparecidoId,
        fechaEncontrado: fechaEncontrado,
        encontradoDetalles: encontradoDetalles,
      );

      result.fold(
        (failure) {
          _mensajeMarcarEncontrado = failure.message;
          _marcarEncontradoState = RequestState.Error;
          _progressMessage = 'Error en el proceso';
        },
        (success) {
          _progressValue = 1.0;
          _progressMessage = 'Proceso completado exitosamente';
          _mensajeMarcarEncontrado = 'Persona marcada como encontrada exitosamente';
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
