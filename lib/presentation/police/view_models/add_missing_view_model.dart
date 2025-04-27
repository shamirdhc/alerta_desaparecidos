// lib/presentation/police/view_models/add_missing_view_model.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart'; // Importar Firebase Storage
import 'package:flutter/material.dart';
import '../../../domain/use_cases/reportar_desaparicion_use_case.dart';
import '../../../domain/entities/desaparecido.dart';
import '../../../common/state_enum.dart';
import 'package:path/path.dart' as path; // Para obtener la extensión del archivo

class AddMissingViewModel extends ChangeNotifier {
  final ReportarDesaparicionUseCase _reportarDesaparicionUseCase;
  // Añadir FirebaseStorage (idealmente inyectado, pero lo instanciamos aquí por simplicidad)
  final FirebaseStorage _storage = FirebaseStorage.instance;

  AddMissingViewModel(this._reportarDesaparicionUseCase);

  RequestState _state = RequestState.Empty;
  RequestState get state => _state;

  String _message = '';
  String get message => _message;

  // Método existente para reportar sin manejo directo de imágenes aquí
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

  // --- MÉTODO IMPLEMENTADO ---
  Future<void> reportDesaparecidoConImagenes(Desaparecido desaparecido, File? fotoFile, File? imagenFichaFile) async {
    _state = RequestState.Loading;
    _message = 'Subiendo imágenes y guardando reporte...';
    notifyListeners();

    String? fotoUrl;
    String? imagenFichaUrl;

    try {
      // 1. Subir fotoFile si existe
      if (fotoFile != null) {
        fotoUrl = await _subirImagen(fotoFile, 'fotos_desaparecidos');
        if (fotoUrl == null) {
          throw Exception("Error al subir la foto.");
        }
      }

      // 2. Subir imagenFichaFile si existe
      if (imagenFichaFile != null) {
        imagenFichaUrl = await _subirImagen(imagenFichaFile, 'fichas_desaparecidos');
         if (imagenFichaUrl == null) {
          throw Exception("Error al subir la imagen de la ficha.");
        }
      }

      // 3. Crear el objeto Desaparecido final con las URLs
      final desaparecidoFinal = Desaparecido(
        id: desaparecido.id,
        // nombreCompleto: desaparecido.nombreCompleto, // ELIMINA O COMENTA ESTA LÍNEA
        nombres: desaparecido.nombres, // AÑADE ESTA LÍNEA
        apellidos: desaparecido.apellidos, // AÑADE ESTA LÍNEA
        sexo: desaparecido.sexo,
        dni: desaparecido.dni,
        telefonoContacto: desaparecido.telefonoContacto,
        fechaDesaparicion: desaparecido.fechaDesaparicion,
        departamento: desaparecido.departamento,
        provincia: desaparecido.provincia,
        distrito: desaparecido.distrito,
        detallesAdicionales: desaparecido.detallesAdicionales,
        fotoUrl: fotoUrl,
        imagenFichaUrl: imagenFichaUrl,
        fechaCreacion: desaparecido.fechaCreacion,
        fechaActualizacion: DateTime.now(),
        estado: desaparecido.estado,
      );

      // 4. Guardar el objeto 'desaparecidoFinal' en Firestore
      final result = await _reportarDesaparicionUseCase.execute(desaparecidoFinal);

      result.fold(
        (failure) {
          _message = "Error al guardar el reporte: ${failure.message}";
          _state = RequestState.Error;
        },
        (_) {
          _message = 'Reporte e imágenes guardados exitosamente.';
          _state = RequestState.Loaded;
        },
      );

    } catch (e) {
       _message = "Error durante el proceso: ${e.toString()}";
      _state = RequestState.Error;
    } finally {
      // 6. Notificar a los listeners del resultado final
      notifyListeners();
    }
  }

  // Helper para subir imagen y obtener URL
  Future<String?> _subirImagen(File imageFile, String folderPath) async {
    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      Reference storageRef = _storage.ref().child('$folderPath/$fileName');
      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Error al subir imagen a $folderPath: $e");
      return null; // Retorna null si hay error
    }
  }
  // --- FIN DEL MÉTODO IMPLEMENTADO ---
}
