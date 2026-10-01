import 'dart:typed_data';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../../../../common/state_enum.dart';
import '../../../../domain/use_cases/reportar_desaparicion_use_case.dart';
import '../../../../domain/entities/desaparecido.dart';
import 'package:path/path.dart' as path;

class ReportDesaparecidoViewModel extends ChangeNotifier {
  final ReportarDesaparicionUseCase _reportarDesaparicion;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  ReportDesaparecidoViewModel(this._reportarDesaparicion);

  String _nombres = '';
  String get nombres => _nombres;
  set nombres(String value) {
    _nombres = value;
    notifyListeners();
  }

  String _apellidos = '';
  String get apellidos => _apellidos;
  set apellidos(String value) {
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
  
  // Alias para compatibilidad con el código existente
  RequestState get state => _reportState;

  String _message = '';
  String get message => _message;

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

  // Helper para subir bytes en memoria (100% compatible con Web y Móvil)
  Future<String?> _subirImagenBytes(Uint8List bytes, String folderPath) async {
    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = _storage.ref().child('$folderPath/$fileName');
      UploadTask uploadTask = storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      print('Imagen subida a: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print("Error al subir bytes a $folderPath: $e");
      _message = "Error al subir imagen: $e";
      return null;
    }
  }

  // Método para reportar con imágenes (soporta File y Uint8List)
  Future<void> reportDesaparecidoConImagenes(
    Desaparecido desaparecido, {
    File? fotoFile,
    File? fichaFile,
    Uint8List? fotoBytes,
    Uint8List? fichaBytes,
  }) async {
    _reportState = RequestState.Loading;
    notifyListeners();

    try {
      // 1. Subir imágenes (si existen) y obtener URLs
      String? fotoUrl;
      String? fichaUrl;

      if (fotoBytes != null) {
        fotoUrl = await _subirImagenBytes(fotoBytes, 'desaparecidos/fotos');
      } else if (fotoFile != null) {
        fotoUrl = await _subirImagen(fotoFile, 'desaparecidos/fotos');
      }

      if (fichaBytes != null) {
        fichaUrl = await _subirImagenBytes(fichaBytes, 'desaparecidos/fichas');
      } else if (fichaFile != null) {
        fichaUrl = await _subirImagen(fichaFile, 'desaparecidos/fichas');
      }

      // 2. Crear el objeto Desaparecido actualizado con las URLs
      final updatedDesaparecido = desaparecido.copyWith(
        fotoUrl: fotoUrl,
        imagenFichaUrl: fichaUrl,
      );

      // 3. Guardar el objeto actualizado en Firestore
      final result = await _reportarDesaparicion.execute(updatedDesaparecido);

      result.fold(
        (failure) {
          _message = "Error al guardar el reporte: ${failure.message}";
          _reportState = RequestState.Error;
        },
        (_) {
          _message = 'Reporte guardado exitosamente.';
          _reportState = RequestState.Loaded;
        },
      );
    } catch (e) {
      _message = "Error durante el proceso: ${e.toString()}";
      _reportState = RequestState.Error;
    } finally {
      notifyListeners();
    }
  }

  // Helper para subir imagen y obtener URL
  Future<String?> _subirImagen(File imageFile, String folderPath) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return await _subirImagenBytes(bytes, folderPath);
    } catch (e) {
      try {
        String fileName =
            '${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
        Reference storageRef = _storage.ref().child('$folderPath/$fileName');
        UploadTask uploadTask = storageRef.putFile(imageFile);
        TaskSnapshot taskSnapshot = await uploadTask;
        String downloadUrl = await taskSnapshot.ref.getDownloadURL();
        print('Imagen subida a: $downloadUrl');
        return downloadUrl;
      } catch (err) {
        print("Error al subir imagen a $folderPath: $err");
        _message = "Error al subir imagen: $err";
        return null;
      }
    }
  }

  // Método para resetear el estado del formulario
  void resetState() {
    _nombres = '';
    _apellidos = '';
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
