import 'package:flutter/material.dart';
import '../../../../common/state_enum.dart';
import '../../../../domain/use_cases/reportar_desaparicion_use_case.dart';
import '../../../../domain/entities/desaparecido.dart';

class ReportDesaparecidoViewModel extends ChangeNotifier {
  final ReportarDesaparicionUseCase _reportarDesaparicion;

  ReportDesaparecidoViewModel(this._reportarDesaparicion);

  String _nombres = ''; // AÑADE ESTA LÍNEA
  String get nombres => _nombres; // AÑADE ESTA LÍNEA
  set nombres(String value) {
    // AÑADE ESTE SETTER
    _nombres = value;
    notifyListeners();
  }

  String _apellidos = ''; // AÑADE ESTA LÍNEA
  String get apellidos => _apellidos; // AÑADE ESTA LÍNEA
  set apellidos(String value) {
    // AÑADE ESTE SETTER
    _apellidos = value;
    notifyListeners();
  }

  String? _dni;
  String? get dni => _dni;
  set dni(String? value) {
    _dni = value;
    notifyListeners();
  }

  String? _telefonoContacto;
  String? get telefonoContacto => _telefonoContacto;
  set telefonoContacto(String? value) {
    _telefonoContacto = value;
    notifyListeners();
  }

  // Variables relacionadas con Ubigeo dinámico
  String? _departamento;
  String? get departamento => _departamento;
  set departamento(String? value) {
    _departamento = value;
    notifyListeners();
  }

  String? _provincia;
  String? get provincia => _provincia;
  set provincia(String? value) {
    _provincia = value;
    notifyListeners();
  }

  String? _distrito;
  String? get distrito => _distrito;
  set distrito(String? value) {
    _distrito = value;
    notifyListeners();
  }

  DateTime? _fechaDesaparicion;
  DateTime? get fechaDesaparicion => _fechaDesaparicion;
  set fechaDesaparicion(DateTime? value) {
    _fechaDesaparicion = value;
    notifyListeners();
  }

  String? _sexo;
  String? get sexo => _sexo;
  set sexo(String? value) {
    _sexo = value;
    notifyListeners();
  }

  String? _detallesAdicionales;
  String? get detallesAdicionales => _detallesAdicionales;
  set detallesAdicionales(String? value) {
    _detallesAdicionales = value;
    notifyListeners();
  }

  String? _fotoUrl;
  String? get fotoUrl => _fotoUrl;
  set fotoUrl(String? value) {
    _fotoUrl = value;
    notifyListeners();
  }

  String? _imagenFichaUrl;
  String? get imagenFichaUrl => _imagenFichaUrl;
  set imagenFichaUrl(String? value) {
    _imagenFichaUrl = value;
    notifyListeners();
  }

  // Estado de la operación de guardado
  RequestState _reportState = RequestState.Empty;
  RequestState get reportState => _reportState;

  String _message = '';
  String get message => _message;

  // Método para construir la entidad Desaparecido

  // Método para guardar el reporte
  Future<void> reportDesaparecido(Desaparecido desaparecido) async {
    _reportState = RequestState.Loading;
    notifyListeners();

    final result = await _reportarDesaparicion.execute(desaparecido);

    result.fold(
      (failure) {
        _message = failure.message;
        _reportState = RequestState.Error;
      },
      (success) {
        _message = 'Reporte guardado exitosamente';
        _reportState = RequestState.Loaded;
      },
    );
    notifyListeners();
  }

  // Método para resetear el estado del formulario
  void resetState() {
    // _nombreCompleto = ''; // ELIMINA O COMENTA ESTA LÍNEA
    _nombres = ''; // AÑADE ESTA LÍNEA
    _apellidos = ''; // AÑADE ESTA LÍNEA
    _dni = null;
    _telefonoContacto = null;
    _departamento = null;
    _provincia = null;
    _distrito = null;
    _fechaDesaparicion = null;
    _sexo = null;
    _detallesAdicionales = null;
    _fotoUrl = null;
    _imagenFichaUrl = null;
    _reportState = RequestState.Empty;
    _message = '';
    notifyListeners();
  }
}
