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

  Future<void> marcarComoEncontrado(String desaparecidoId) async {
    _marcarEncontradoState = RequestState.Loading;
    notifyListeners();

    final result = await _marcarComoEncontradoUseCase.execute(desaparecidoId);

    result.fold(
      (failure) {
        _mensajeMarcarEncontrado = failure.message;
        _marcarEncontradoState = RequestState.Error;
      },
      (success) {
        _mensajeMarcarEncontrado = 'Persona marcada como encontrada';
        _marcarEncontradoState = RequestState.Loaded;
      },
    );
    notifyListeners();
  }

  void resetState() {
    _marcarEncontradoState = RequestState.Empty;
    _mensajeMarcarEncontrado = '';
    notifyListeners();
  }
}
