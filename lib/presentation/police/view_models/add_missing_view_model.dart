// lib/presentation/police/view_models/add_missing_view_model.dart
import 'package:flutter/material.dart';
import '../../../domain/use_cases/reportar_desaparicion_use_case.dart';
import '../../../domain/entities/desaparecido.dart';
import '../../../common/state_enum.dart';

class AddMissingViewModel extends ChangeNotifier {
  final ReportarDesaparicionUseCase _reportarDesaparicionUseCase;

  AddMissingViewModel(this._reportarDesaparicionUseCase);

  RequestState _state = RequestState.Empty;
  RequestState get state => _state;

  String _message = '';
  String get message => _message;

  Future<void> reportDesaparecido(Desaparecido desaparecido) async {
    _state = RequestState.Loading;
    notifyListeners();
    final result = await _reportarDesaparicionUseCase.execute(desaparecido);
    result.fold(
      (failure) {
        _message = failure.message;
        _state = RequestState.Error;
      },
      (_) {
        _message = 'Reporte guardado exitosamente.';
        _state = RequestState.Loaded;
      },
    );
    notifyListeners();
  }

  void resetState() {
    _state = RequestState.Empty;
    _message = '';
    notifyListeners();
  }
}
