// lib/presentation/police/view_models/add_missing_view_model.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart'; // Importar Firebase Storage
import 'package:flutter/material.dart';
import '../../../domain/use_cases/reportar_desaparicion_use_case.dart';
import '../../../domain/entities/desaparecido.dart';
import '../../../common/state_enum.dart';
import 'package:path/path.dart'
    as path; // Para obtener la extensión del archivo

class AddMissingViewModel extends ChangeNotifier {
  final ReportarDesaparicionUseCase _reportarDesaparicionUseCase;
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
  Future<void> guardarDatosYReportar(/* parámetros con datos de entrada */
    String nombresInput,
    String apellidosInput,
    String detallesInput,
    // otros parámetros...
    File? fotoFile,
    File? fichaFile,
  ) async {
    // ... validaciones ...

    // Convertir a mayúsculas ANTES de crear el objeto Desaparecido
    final nombresUpper = nombresInput.toUpperCase();
    final apellidosUpper = apellidosInput.toUpperCase();
    final detallesUpper = detallesInput.toUpperCase();

    final desaparecido = Desaparecido(
      // id se genera usualmente después o se pasa null
      nombres: nombresUpper, // Usar valor en mayúsculas
      apellidos: apellidosUpper, // Usar valor en mayúsculas
      detallesAdicionales: detallesUpper, // Usar valor en mayúsculas
      // ... otros campos ...
      fechaCreacion: DateTime.now(),
      estado: 'activo', // Estado inicial
    );

    // Llamar al método que sube imágenes y guarda, pasando el objeto ya modificado
    await reportDesaparecidoConImagenes(
      desaparecido,
      fotoFile: fotoFile,
      fichaFile: fichaFile,
    );
  }


  // Modificar reportDesaparecidoConImagenes para aceptar el objeto Desaparecido
  Future<void> reportDesaparecidoConImagenes(
    Desaparecido desaparecido, { // Recibe el objeto ya construido
    File? fotoFile,
    File? fichaFile,
  }) async {
    _state = RequestState.Loading;
    notifyListeners();

    try {
      // 1. Subir imágenes (si existen) y obtener URLs
      String? fotoUrl;
      String? fichaUrl;

      // --- INICIO CAMBIOS ---
      // Usar el helper _subirImagen para subir los archivos si existen
      if (fotoFile != null) {
        // Usar un path que no dependa del ID final, por ejemplo, con timestamp
        fotoUrl = await _subirImagen(
          fotoFile,
          'desaparecidos/fotos', // Carpeta base para fotos
        );
      }
      if (fichaFile != null) {
        fichaUrl = await _subirImagen(
          fichaFile,
          'desaparecidos/fichas', // Carpeta base para fichas
        );
      }

      // 2. Crear el objeto Desaparecido actualizado con las URLs
      //    Asegúrate de que tu clase Desaparecido tenga un método copyWith.
      //    Si no lo tiene, créalo o instancia un nuevo objeto manualmente.
      final updatedDesaparecido = desaparecido.copyWith(
        fotoUrl: fotoUrl, // Asigna la URL de la foto (puede ser null)
        imagenFichaUrl: fichaUrl, // Asigna la URL de la ficha (puede ser null)
      );


      // 3. Guardar el objeto 'updatedDesaparecido' en Firestore usando el UseCase
      final result = await _reportarDesaparicionUseCase.execute(
        updatedDesaparecido, // Pasar el objeto ACTUALIZADO
      );
      // --- FIN CAMBIOS ---

      result.fold(
        (failure) {
          _message = "Error al guardar el reporte: ${failure.message}";
          _state = RequestState.Error;
        },
        (_) {
          _message = 'Reporte guardado exitosamente.'; // Mensaje ajustado
          _state = RequestState.Loaded;
        },
      );
    } catch (e) {
      _message = "Error durante el proceso: ${e.toString()}";
      _state = RequestState.Error;
    } finally {
      notifyListeners();
    }
  }

  // Helper para subir imagen y obtener URL
  Future<String?> _subirImagen(File imageFile, String folderPath) async {
    try {
      // Crear un nombre de archivo único usando timestamp y extensión original
      String fileName =
          '${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      Reference storageRef = _storage.ref().child('$folderPath/$fileName'); // Path completo en Storage
      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      print('Imagen subida a: $downloadUrl'); // Log para verificar
      return downloadUrl;
    } catch (e) {
      print("Error al subir imagen a $folderPath: $e");
      _message = "Error al subir imagen: $e"; // Actualizar mensaje de error
      // Considera si quieres cambiar el estado a Error aquí también
      // _state = RequestState.Error;
      // notifyListeners();
      return null; // Retorna null si hay error
    }
  }
}
