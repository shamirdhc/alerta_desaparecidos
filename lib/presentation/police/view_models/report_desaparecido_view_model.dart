import 'package:flutter/material.dart';
import '../../../../common/state_enum.dart';
import '../../../../domain/use_cases/reportar_desaparicion_use_case.dart';
import '../../../../domain/entities/desaparecido.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportDesaparecidoViewModel extends ChangeNotifier {
  final ReportarDesaparicionUseCase _reportarDesaparicion;

  ReportDesaparecidoViewModel(this._reportarDesaparicion);

  // Estado de los campos del formulario
  String _nombreCompleto = '';
  String get nombreCompleto => _nombreCompleto;
  set nombreCompleto(String value) {
    _nombreCompleto = value;
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

  GeoPoint? _ubicacionDesaparicion;
  GeoPoint? get ubicacionDesaparicion => _ubicacionDesaparicion;
  set ubicacionDesaparicion(GeoPoint? value) {
    _ubicacionDesaparicion = value;
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
  Desaparecido _buildDesaparecido() {
    return Desaparecido(
      nombreCompleto: _nombreCompleto,
      dni: _dni,
      telefonoContacto: _telefonoContacto,
      ubicacionDesaparicion: _ubicacionDesaparicion,
      fechaDesaparicion: _fechaDesaparicion,
      sexo: _sexo,
      detallesAdicionales: _detallesAdicionales,
      fotoUrl: _fotoUrl,
      imagenFichaUrl: _imagenFichaUrl,
      fechaCreacion: DateTime.now(),
      fechaActualizacion: DateTime.now(),
    );
  }

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
    _nombreCompleto = '';
    _dni = null;
    _telefonoContacto = null;
    _ubicacionDesaparicion = null;
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
