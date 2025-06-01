import 'dart:io';
import 'dart:ui' as ui;
import 'package:alerta_desaparecidos/helpers/database_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../domain/entities/desaparecido.dart';
import '../view_models/add_missing_view_model.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart'; // Importar file_picker
import '../../../common/state_enum.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

// --- MOVER LA CLASE AQUÍ ---
// --- NUEVA CLASE: Formateador a Mayúsculas ---
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
// --- FIN NUEVA CLASE ---

class AddMissingScreen extends StatefulWidget {
  const AddMissingScreen({super.key});

  @override
  State<AddMissingScreen> createState() => _AddMissingScreenState();
}

class _AddMissingScreenState extends State<AddMissingScreen> {
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> departamentos = [];
  List<Map<String, dynamic>> provincias = [];
  List<Map<String, dynamic>> distritos = [];

  // --- AÑADE ESTAS LÍNEAS ---
  String? selectedDepartamento;
  String? selectedProvincia;
  String? selectedDistrito;

  late AddMissingViewModel _viewModel; // Declaración

  bool _isLoading = false; // Estado de carga inicializado como falso

  final DatabaseHelper dbHelper = DatabaseHelper();

  // final TextEditingController _nombreCompletoController = TextEditingController(); // ELIMINA O COMENTA ESTA LÍNEA
  final TextEditingController _nombresController =
      TextEditingController(); // AÑADE ESTA LÍNEA
  final TextEditingController _apellidosController =
      TextEditingController(); // AÑADE ESTA LÍNEA
  final TextEditingController _dniController = TextEditingController();
  String? _sexo;
  final TextEditingController _telefonoContactoController =
      TextEditingController();
  final TextEditingController _fechaDesaparicionController =
      TextEditingController();
  final TextEditingController _fechaNacimientoController =
      TextEditingController(); // <<< NUEVO
  final TextEditingController _detallesAdicionalesController =
      TextEditingController();

  // --- AÑADE ESTAS LÍNEAS ---
  DateTime? _selectedFechaNacimiento;
  DateTime? _selectedFechaDesaparicion;
  // --- FIN ---

  File? _fotoFile;
  File? _imagenFichaFile;
  bool _isGuardarActivo = false;

  @override
  void initState() {
    super.initState(); // Muy importante llamar a super.initState() primero
    // Inicialización del ViewModel
    _viewModel = Provider.of<AddMissingViewModel>(context, listen: false);
    _loadDepartamentos(); // Cargar datos iniciales
    _nombresController.addListener(_validateForm); // AÑADE ESTA LÍNEA
    _apellidosController.addListener(_validateForm); // AÑADE ESTA LÍNEA
    _dniController.addListener(_validateForm);
    _telefonoContactoController.addListener(_validateForm);
    _fechaDesaparicionController.addListener(_validateForm);
    _fechaNacimientoController.addListener(
      _validateForm,
    ); // <<< NUEVO (Añadir listener)
    _detallesAdicionalesController.addListener(_validateForm);
    // Asegúrate de que los listeners para los dropdowns también llamen a _validateForm
  }

  Future<void> _pickImage(ImageSource source, bool isFotoPersona) async {
    if (!isFotoPersona) {
      // Si no es para la foto de la persona, ofrecer selección de PDF
      _showImageSourceSelection(isFotoPersona);
      return;
    }
    _handleImageSelection(source, isFotoPersona);
  }

  Future<void> _showImageSourceSelection(bool isFotoPersona) async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Seleccionar de Galería'),
                onTap: () {
                  Navigator.pop(context);
                  _handleImageSelection(ImageSource.gallery, isFotoPersona);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar Foto'),
                onTap: () {
                  Navigator.pop(context);
                  _handleImageSelection(ImageSource.camera, isFotoPersona);
                },
              ),
              if (!isFotoPersona) // Opción para PDF solo para imagen ficha
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('Seleccionar PDF'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPdfAndConvertToImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleImageSelection(
    ImageSource source,
    bool isFotoPersona,
  ) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70, // Calidad reducida al 70%
        maxWidth: isFotoPersona ? 1000 : 1600, // Diferentes tamaños según tipo
        maxHeight: isFotoPersona ? 1000 : 1600,
      );

      if (pickedFile != null && pickedFile.path.isNotEmpty) {
        setState(() => _isLoading = true); // Mostrar loader

        try {
          final compressedFile = await compressImage(File(pickedFile.path));
          final croppedFile = await ImageCropper().cropImage(
            sourcePath: compressedFile.path,
            compressQuality: 60,
            compressFormat: ImageCompressFormat.jpg,
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: 'Recortar Imagen',
                toolbarColor: Theme.of(context).primaryColor,
                toolbarWidgetColor: Colors.white,
                initAspectRatio: CropAspectRatioPreset.original,
                lockAspectRatio: false,
                aspectRatioPresets: [
                  CropAspectRatioPreset.square,
                  CropAspectRatioPreset.ratio3x2,
                  CropAspectRatioPreset.original,
                  CropAspectRatioPreset.ratio4x3,
                  CropAspectRatioPreset.ratio16x9,
                ],
              ),
              IOSUiSettings(
                title: 'Recortar Imagen',
                aspectRatioPresets: [
                  CropAspectRatioPreset.square,
                  CropAspectRatioPreset.ratio3x2,
                  CropAspectRatioPreset.original,
                  CropAspectRatioPreset.ratio4x3,
                  CropAspectRatioPreset.ratio16x9,
                ],
              ),
              WebUiSettings(context: context),
            ],
          );
          if (croppedFile != null) {
            setState(() {
              if (isFotoPersona) {
                _fotoFile = File(croppedFile.path);
              } else {
                _imagenFichaFile = File(croppedFile.path);
              }
            });
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      } else if (mounted) {
        // Si no se seleccionó ninguna imagen válida
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se seleccionó ninguna imagen válida.'),
          ),
        );
      }
    } catch (e) {
      // Manejo de errores inesperados y detallados
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar o recortar la imagen: $e'),
        ),
      );
      print('Error al seleccionar o recortar la imagen: $e');
    }
  }

  Future<void> _pickPdfAndConvertToImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        final document = await PdfDocument.openFile(file.path);

        if (document.pages.isNotEmpty) {
          final page = document.pages.first; // Acceder a la primera página
          final pageImage = await page.render(); // Renderizar la página

          if (pageImage != null) {
            // Obtener los bytes de la imagen renderizada
            final ui.Image renderedImage =
                await pageImage
                    .createImage(); // Await the creation of the image
            final imageBytes = await renderedImage.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (imageBytes == null) {
              throw Exception('Failed to convert image to byte data');
            }
            final Uint8List pngBytes = imageBytes.buffer.asUint8List();

            // Create a temporary file to save the image
            final tempDir = await getTemporaryDirectory();
            final tempPath = tempDir.path;
            final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
            final tempFile = File('$tempPath/$fileName');

            await tempFile.writeAsBytes(pngBytes);

            setState(() {
              _imagenFichaFile = tempFile;
            });
          }
        }
        // En pdfrx, no hay un método close explícito para el documento.
        // La gestión de recursos se maneja internamente o por el recolector de basura.
      }
    } catch (e) {
      print('Error picking PDF and converting to image: $e');
      // Handle error, e.g., show a SnackBar
    }
  }

  void _loadDepartamentos() async {
    final data = await dbHelper.getDepartamentos();
    setState(() {
      departamentos = data;
    });
  }

  void _loadProvincias(String departamentoId) async {
    final data = await dbHelper.getProvincias(departamentoId);
    if (mounted) {
      // <-- Añadir esta verificación
      setState(() {
        provincias = data;
        distritos = [];
        selectedProvincia = null;
        selectedDistrito = null;
      });
    }
  }

  void _loadDistritos(String provinciaId) async {
    final data = await dbHelper.getDistritos(provinciaId);
    if (mounted) {
      // <-- Añadir esta verificación
      setState(() {
        distritos = data;
        selectedDistrito = null;
      });
    }
  }

  // --- ACTUALIZA ESTA FUNCIÓN ---
  void _validateForm() {
    final nombresValido = _validarNombres(_nombresController.text) == null;
    final apellidosValido =
        _validarApellidos(_apellidosController.text) == null;
    final dniValido = _validarDNI(_dniController.text) == null;
    final telefonoValido =
        _validarTelefono(_telefonoContactoController.text) == null;
    final fotoSeleccionada = _fotoFile != null;
    final imagenFichaSeleccionada = _imagenFichaFile != null;
    // --- CAMBIO EN VALIDACIÓN DE FECHAS ---
    final fechaDesaparicionSeleccionada = _selectedFechaDesaparicion != null;
    final fechaNacimientoSeleccionada = _selectedFechaNacimiento != null;
    // --- FIN CAMBIO ---
    final sexoSeleccionado = _sexo != null;

    setState(() {
      _isGuardarActivo =
          nombresValido &&
          apellidosValido &&
          dniValido &&
          telefonoValido &&
          sexoSeleccionado &&
          fotoSeleccionada &&
          imagenFichaSeleccionada &&
          fechaDesaparicionSeleccionada && // Usa la nueva validación
          fechaNacimientoSeleccionada && // Usa la nueva validación
          selectedDepartamento != null &&
          selectedProvincia != null &&
          selectedDistrito != null;
    });
  }
  // --- FIN ACTUALIZACIÓN _validateForm ---

  // --- AÑADE ESTAS FUNCIONES ---
  String? _validarNombres(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor, ingrese los nombres.';
    }
    // Dividir por espacios y filtrar vacíos
    final names = value.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (names.length > 3) {
      return 'Máximo 3 nombres permitidos.';
    }
    return null; // Válido
  }

  String? _validarApellidos(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor, ingrese los apellidos.';
    }
    // Dividir por espacios y filtrar vacíos
    final surnames =
        value.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (surnames.length != 2) {
      return 'Se requieren exactamente 2 apellidos.';
    }
    return null; // Válido
  }

  String? _validarDNI(String? value) {
    if (value == null || value.isEmpty) {
      return 'El DNI es obligatorio.';
    }

    // Verificar que el DNI contiene solo números
    final isNumeric = RegExp(r'^[0-9]+$').hasMatch(value);
    if (!isNumeric) {
      return 'El DNI solo debe contener números.';
    }

    // Verificar longitud exacta de 8 dígitos
    if (value.length != 8) {
      return 'El DNI debe tener exactamente 8 dígitos.';
    }

    return null; // Validación exitosa
  }

  String? _validarTelefono(String? value) {
    if (value == null || value.isEmpty) {
      return 'El teléfono es obligatorio.';
    }

    if (value.length != 9) {
      return 'El teléfono debe tener exactamente 9 dígitos.';
    }

    return null; // Validación exitosa
  }

  // <<< INICIO NUEVA FUNCIÓN >>>
  Future<void> _selectFechaNacimiento(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedFechaNacimiento ??
          DateTime.now().subtract(
            const Duration(days: 365 * 18),
          ), // Sugerir 18 años atrás
      firstDate: DateTime(1960), // Fecha mínima razonable
      lastDate: DateTime.now(), // No puede nacer en el futuro
      locale: const Locale('es', 'ES'),
    );
    if (picked != null && picked != _selectedFechaNacimiento) {
      setState(() {
        _selectedFechaNacimiento = picked;
        // Usar el formato que prefieras, ej: 'dd/MM/yyyy' o 'yyyy-MM-dd'
        _fechaNacimientoController.text = DateFormat(
          'dd/MM/yyyy',
          'es_ES',
        ).format(picked);
        _validateForm(); // Revalidar el formulario
      });
    }
  }
  // <<< FIN NUEVA FUNCIÓN >>>

  // --- AÑADE ESTA FUNCIÓN ---
  Future<void> _selectFechaDesaparicion(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedFechaDesaparicion ??
          DateTime.now(), // Fecha inicial sugerida: hoy
      firstDate: DateTime(2000), // Fecha mínima razonable
      lastDate: DateTime.now(), // No puede ser en el futuro
      locale: const Locale('es', 'ES'),
    );
    if (picked != null && picked != _selectedFechaDesaparicion) {
      setState(() {
        _selectedFechaDesaparicion = picked;
        _fechaDesaparicionController.text = DateFormat(
          'dd/MM/yyyy',
          'es_ES',
        ).format(picked);
        _validateForm(); // Revalidar el formulario
      });
    }
  }
  // --- FIN ---

  // Elimina o comenta la función _selectDate si ya no la usas
  // Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
  //    // ... tu lógica existente para seleccionar fecha ...
  // }

  Future<void> _guardarReporte() async {
    if (!_formKey.currentState!.validate() || !_isGuardarActivo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, complete todos los campos requeridos y seleccione las imágenes.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true; // Mostrar indicador de carga
    });

    try {
      // Crear el objeto Desaparecido (similar a como lo haces ahora)
      // Asegúrate de obtener los nombres de dep/prov/dist correctamente
      final departamentoNombre =
          selectedDepartamento != null
              ? departamentos.firstWhere(
                (dep) => dep['id'] == selectedDepartamento,
              )['name']
              : null;
      final provinciaNombre =
          selectedProvincia != null
              ? provincias.firstWhere(
                (prov) => prov['id'] == selectedProvincia,
              )['name']
              : null;
      final distritoNombre =
          selectedDistrito != null
              ? distritos.firstWhere(
                (dist) => dist['id'] == selectedDistrito,
              )['name']
              : null;

      final desaparecido = Desaparecido(
        nombres: _nombresController.text.trim().toUpperCase(),
        apellidos: _apellidosController.text.trim().toUpperCase(),
        sexo: _sexo?.toUpperCase(),
        dni: _dniController.text.trim(), // DNI usualmente no va en mayúsculas
        telefonoContacto: _telefonoContactoController.text.trim(),
        fechaNacimiento: _selectedFechaNacimiento,
        fechaDesaparicion: _selectedFechaDesaparicion,
        departamento: departamentoNombre?.toUpperCase(),
        provincia: provinciaNombre?.toUpperCase(),
        distrito: distritoNombre?.toUpperCase(),
        detallesAdicionales:
            _detallesAdicionalesController.text
                .trim()
                .toUpperCase(), // <-- Cambio aquí
        fechaCreacion: DateTime.now(),
        fechaActualizacion: DateTime.now(),
      );

      // --- CAMBIO AQUÍ: Usa argumentos nombrados para los archivos ---
      await _viewModel.reportDesaparecidoConImagenes(
        desaparecido, // Primer argumento posicional
        fotoFile: _fotoFile, // Argumento nombrado
        fichaFile: _imagenFichaFile, // Argumento nombrado
      );
      // --- FIN CAMBIO ---

      // Escuchar el estado del ViewModel para saber si fue exitoso
      // (Esto requiere que el ViewModel exponga su estado, por ejemplo, con ChangeNotifier)
      if (_viewModel.state == RequestState.Loaded) {
        // Verifica el estado del ViewModel
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_viewModel.message),
          ), // Muestra mensaje del ViewModel
        );
        // --- INICIO: Navegar atrás con resultado ---
        Navigator.pop(context, true); // Devuelve true para indicar éxito
        // --- FIN: Navegar atrás con resultado ---
      } else if (_viewModel.state == RequestState.Error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${_viewModel.message}'),
          ), // Muestra mensaje de error del ViewModel
        );
      }
      // Si el ViewModel indica éxito:
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte guardado exitosamente.')),
      );
      // Opcional: Navegar a otra pantalla o limpiar el formulario
      // Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: ${e.toString()}'),
          duration: Duration(seconds: 5), // Más tiempo para leer el error
        ),
      );
      print('Error detallado: $e'); // Para ver el error completo en la consola
    } finally {
      if (mounted) {
        // Verifica si el widget sigue montado
        setState(() {
          _isLoading = false; // Ocultar indicador de carga
        });
      }
    }
  }

  // Modifica _showImageSourceDialog para pasar el parámetro
  void _showImageSourceDialog(bool isFotoPersona) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleccionar Fuente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (isFotoPersona) // Mostrar Cámara solo si es para la foto de la persona
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Cámara'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.camera, isFotoPersona);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery, isFotoPersona);
                },
              ),
              if (!isFotoPersona) // Mostrar PDF solo si NO es para la foto de la persona (es para la ficha)
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('PDF'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    // _pickPdfAndConvertToImage ahora devuelve File? y se maneja aquí
                    // No es necesario llamar a _pickImage para PDF, se maneja directamente
                    // con _imagenFichaFile.
                    // La lógica de _pickPdfAndConvertToImage ya actualiza _imagenFichaFile
                    // y llama a setState.
                    await _pickPdfAndConvertToImage();
                    _validateForm(); // Asegúrate de validar el formulario después de la selección
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reemplazar WillPopScope con PopScope
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(title: const Text('Reportar Desaparecido')),
        body: Container( // <--- ENVOLVER CON CONTAINER
          width: double.infinity, // Asegurar que ocupe todo el ancho
          height: double.infinity, // Asegurar que ocupe todo el alto
          decoration: const BoxDecoration( // <--- AÑADIR DECORATION
            gradient: LinearGradient(
              colors: [
                Color(0xFFADD8E6), // Azul Suave
                Color(0xFF90EE90), // Verde Esperanza
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // --- CAMPO NOMBRES (Ya tiene autovalidateMode) ---
                    TextFormField(
                      controller: _nombresController,
                      decoration: InputDecoration(
                        labelText: 'Nombres *',
                        hintText: 'Ingrese los nombres (máx. 3)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0), // Consistencia en radio
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2.0,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14.0,
                          horizontal: 12.0,
                        ),
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: Colors.grey.shade600,
                        ),
                        fillColor: Colors.white.withOpacity(0.7), // <--- AÑADIR FILLCOLOR
                        filled: true, // <--- AÑADIR FILLED
                        errorStyle: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                      validator: _validarNombres,
                      inputFormatters: [UpperCaseTextFormatter()],
                      onChanged: (_) => _validateForm(),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 16.0),

                    // --- CAMPO APELLIDOS (Ya tiene autovalidateMode) ---
                    TextFormField(
                      controller: _apellidosController,
                      decoration: InputDecoration(
                        labelText: 'Apellidos *',
                        hintText: 'Ingrese los dos apellidos',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2.0,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14.0,
                          horizontal: 12.0,
                        ),
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: Colors.grey.shade600,
                        ),
                        errorStyle: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                      validator: _validarApellidos,
                      inputFormatters: [UpperCaseTextFormatter()],
                      onChanged: (_) => _validateForm(),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 16.0),

                    // --- CAMPO DNI ---
                    TextFormField(
                      controller: _dniController,
                      decoration: InputDecoration(
                        labelText: 'DNI (8 dígitos)*',
                        hintText: 'Ingrese su DNI',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2.0,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14.0,
                          horizontal: 12.0,
                        ),
                        prefixIcon: Icon(
                          Icons.badge_outlined,
                          color: Colors.grey.shade600,
                        ),
                        errorStyle: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      validator: _validarDNI, // Usa tu función de validación
                      onChanged: (value) {
                        // _formKey.currentState?.validate(); // Puedes quitar esta línea si quieres
                        _validateForm(); // <-- AÑADE O REEMPLAZA CON ESTA LÍNEA
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),

                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _telefonoContactoController,
                      decoration: InputDecoration(
                        labelText: 'Teléfono Contacto (9 dígitos)*',
                        hintText: 'Ingrese el teléfono de contacto',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
                        prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey.shade600),
                        // fillColor: Colors.grey.shade50, // Ejemplo de fillColor
                        // filled: true,                 // Necesario si se usa fillColor
                        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
                      validator: _validarTelefono,
                      onChanged: (value) {
                        // setState(() { // No es necesario setState aquí si solo validas con _validateForm
                        //   _validateForm(); 
                        // });
                        _validateForm(); // Llamar a _validateForm para actualizar el estado del botón guardar
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 16.0),
                    // --- CAMPO SEXO/GÉNERO ---
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Género *',
                        hintText: 'Seleccione el género',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0), // Aumentado vertical a 16.0
                        prefixIcon: Icon(Icons.wc_outlined, color: Colors.grey.shade600),
                        fillColor: Colors.white.withOpacity(0.7),
                        filled: true,
                        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      value: _sexo,
                      items: const [
                        DropdownMenuItem(
                          value: 'Masculino',
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0), // Aumentado vertical a 12.0
                            child: Text('Masculino', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Femenino',
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0), // Aumentado vertical a 12.0
                            child: Text('Femenino', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, seleccione el género.';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          _sexo = value;
                        });
                        _validateForm();
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 16.0),

                    // --- CAMPO FECHA NACIMIENTO ---
                    TextFormField(
                      controller: _fechaNacimientoController,
                      decoration: InputDecoration(
                        labelText: 'Fecha Nacimiento *',
                        hintText: 'Seleccione la fecha',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
                        prefixIcon: Icon(Icons.calendar_month_outlined, color: Colors.grey.shade600),
                        suffixIcon: Icon(Icons.calendar_today, color: Colors.grey.shade600),
                        // fillColor: Colors.grey.shade50,
                        // filled: true,
                        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      readOnly: true,
                      onTap: () {
                        FocusScope.of(context).requestFocus(FocusNode());
                        _selectFechaNacimiento(context);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, seleccione la fecha de nacimiento.';
                        }
                        // ... otras validaciones si las tienes ...
                        return null;
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 16.0),

                    // --- CAMPO FECHA DESAPARICIÓN ---
                    TextFormField(
                      controller: _fechaDesaparicionController,
                      decoration: InputDecoration(
                        labelText: 'Fecha Desaparición *',
                        hintText: 'Seleccione la fecha',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
                        prefixIcon: Icon(Icons.calendar_month_outlined, color: Colors.grey.shade600),
                        suffixIcon: Icon(Icons.calendar_today, color: Colors.grey.shade600),
                        // fillColor: Colors.grey.shade50,
                        // filled: true,
                        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      readOnly: true,
                      onTap: () {
                        FocusScope.of(context).requestFocus(FocusNode());
                        _selectFechaDesaparicion(context);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, seleccione la fecha de desaparición.';
                        }
                        // ... otras validaciones si las tienes ...
                        return null;
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 16.0),
                    // Dropdown para Departamentos
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Departamento *',
                        hintText: 'Seleccione departamento',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0), // Aumentado vertical a 16.0
                        prefixIcon: Icon(Icons.location_city_outlined, color: Colors.grey.shade600),
                        fillColor: Colors.white.withOpacity(0.7),
                        filled: true,
                        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      value: selectedDepartamento,
                      items:
                          departamentos.map((departamento) {
                            return DropdownMenuItem<String>(
                              value: departamento['id'],
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0), // Aumentado vertical a 12.0
                                child: Text(
                                  departamento['name'],
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedDepartamento = value;
                          _loadProvincias(value!); 
                          selectedProvincia = null; 
                          distritos = []; 
                          selectedDistrito = null; 
                        });
                        _validateForm();
                      },
                      validator: (value) =>
                          value == null ? 'Seleccione un departamento' : null,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 16.0), // Añadido para consistencia

                    // Aplica el mismo estilo a los otros DropdownButtonFormField (provincia y distrito)
                    if (provincias.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Provincia *',
                          hintText: 'Seleccione provincia',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide(color: Colors.red, width: 2.0),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide(color: Colors.red, width: 2.0),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0), // Aumentado vertical a 16.0
                          prefixIcon: Icon(Icons.map_outlined, color: Colors.grey.shade600),
                          fillColor: Colors.white.withOpacity(0.7),
                          filled: true,
                          errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                        value: selectedProvincia,
                        items:
                            provincias.map((prov) {
                              return DropdownMenuItem<String>(
                                value: prov['id'] ?? '',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0), // Aumentado vertical a 12.0
                                  child: Text(prov['name'] ?? 'Sin nombre', style: TextStyle(fontSize: 16)),
                                ),
                              );
                            }).toList(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, seleccione una provincia.';
                          }
                          return null;
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        onChanged: (value) {
                          String? previousSelection = selectedProvincia;
                          setState(() {
                            selectedProvincia = value;
                            if (value != previousSelection) {
                              distritos = [];
                              selectedDistrito = null;
                            }
                          });
                          if (value != null &&
                              value.isNotEmpty &&
                              value != previousSelection) {
                            _loadDistritos(value);
                          }
                          _validateForm();
                        },
                      ),
                      const SizedBox(height: 16.0),
                    ],

                    // Dropdown para Distritos
                    if (distritos.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Distrito *',
                          hintText: 'Seleccione distrito',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide(color: Colors.red, width: 2.0),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide(color: Colors.red, width: 2.0),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0), // Aumentado vertical a 16.0
                          prefixIcon: Icon(Icons.location_on_outlined, color: Colors.grey.shade600),
                          fillColor: Colors.white.withOpacity(0.7),
                          filled: true,
                          errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                        value: selectedDistrito,
                        items:
                            distritos.map((dist) {
                              return DropdownMenuItem<String>(
                                value: dist['id'] ?? '',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0), // Aumentado vertical a 12.0
                                  child: Text(dist['name'] ?? 'Sin nombre', style: TextStyle(fontSize: 16)),
                                ),
                              );
                            }).toList(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, seleccione un distrito.';
                          }
                          return null;
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        onChanged: (value) {
                          setState(() {
                            selectedDistrito = value;
                          });
                          _validateForm();
                        },
                      ),
                      const SizedBox(height: 16.0),
                    ],
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _detallesAdicionalesController,
                      decoration: InputDecoration(
                        labelText: 'Detalles Adicionales (Opcional)',
                        hintText: 'Ingrese cualquier detalle relevante...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
                        prefixIcon: Icon(Icons.notes_outlined, color: Colors.grey.shade600),
                        // fillColor: Colors.grey.shade50,
                        // filled: true,
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        // No requiere validación en tiempo real para campos opcionales generalmente
                        // Pero si necesitas actualizar el estado del botón guardar, llama a _validateForm()
                        _validateForm(); 
                      },
                    ),
                    const SizedBox(height: 16.0),
                    // --- BOTÓN PARA FOTO DE LA PERSONA ---
                    SizedBox(
                      width: double.infinity, // Para que ocupe todo el ancho disponible
                      child: ElevatedButton.icon(
                        onPressed: () => _showImageSourceDialog(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFADD8E6), // Azul suave como color base
                          foregroundColor: Colors.white, // Texto e icono blancos para buen contraste
                          padding: const EdgeInsets.symmetric(
                            vertical: 14.0, // Aumentar padding vertical
                            horizontal: 16.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0), // Bordes redondeados consistentes
                          ),
                          elevation: 5, // Sutil elevación, consistente
                        ),
                        icon: Icon(_fotoFile == null ? Icons.add_a_photo_outlined : Icons.check_circle_outline, color: Colors.white),
                        label: Text(
                          _fotoFile == null
                              ? 'Seleccionar Foto *'
                              : 'Foto Seleccionada',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- BOTÓN PARA FICHA DE DESAPARICIÓN ---
                    SizedBox(
                      width: double.infinity, // Para que ocupe todo el ancho disponible
                      child: ElevatedButton.icon(
                        onPressed: () => _showImageSourceDialog(false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFADD8E6), // Azul suave como color base
                          foregroundColor: Colors.white, // Texto e icono blancos para buen contraste
                          padding: const EdgeInsets.symmetric(
                            vertical: 14.0,
                            horizontal: 16.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          elevation: 5, // Sutil elevación, consistente
                        ),
                        icon: Icon(_imagenFichaFile == null ? Icons.attach_file_outlined : Icons.check_circle_outline, color: Colors.white),
                        label: Text(
                          _imagenFichaFile == null
                              ? 'Seleccionar Ficha *'
                              : 'Ficha Seleccionada',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0), // Un poco más de espacio antes del botón de guardar
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isGuardarActivo && !_isLoading
                                  ? _guardarReporte
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isGuardarActivo && !_isLoading
                                ? const Color(0xFF90EE90) // Verde esperanza para el botón activo
                                : Colors.grey.shade400, // Gris para deshabilitado
                            foregroundColor: Colors.white, // Texto blanco para mejor contraste
                            padding: const EdgeInsets.symmetric(vertical: 16.0), // Padding generoso
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            elevation: _isGuardarActivo && !_isLoading ? 5 : 2,
                          ),
                          icon: _isLoading
                              ? Container(
                                  width: 24,
                                  height: 24,
                                  padding: const EdgeInsets.all(2.0),
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Icon(Icons.save_alt_outlined, color: Colors.white),
                          label: Text(
                            _isLoading
                                ? 'Guardando...'
                                : 'Guardar Reporte',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Superposición del Indicador de Carga
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5), // Fondo semitransparente
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    )
    );
  }

  // --- FIN ACTUALIZACIÓN MÉTODO PARA GUARDAR ---
}

Future<File> compressImage(File file) async {
  final tempDir = await getTemporaryDirectory();
  final path = tempDir.path;
  final targetPath = '$path/${DateTime.now().millisecondsSinceEpoch}.jpg';
  final result = await FlutterImageCompress.compressAndGetFile(
    file.absolute.path,
    targetPath,
    quality: 60,
    minWidth: 800,
    minHeight: 800,
    rotate: 0,
    keepExif: false, // Desactiva EXIF para reducir tamaño
  );

  if (result == null) {
    throw Exception('Failed to compress image');
  }
  return File(result.path);
}
