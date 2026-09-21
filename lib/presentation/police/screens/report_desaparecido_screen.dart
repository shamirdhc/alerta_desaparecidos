import 'dart:io';
import 'dart:ui' as ui;
import 'package:alerta_desaparecidos/data/data_sources/desaparecido_remote_data_source.dart';
import 'package:alerta_desaparecidos/data/repositories/desaparecido_repository_impl.dart';
import 'package:alerta_desaparecidos/domain/use_cases/reportar_desaparicion_use_case.dart';
import 'package:alerta_desaparecidos/helpers/database_helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../domain/entities/desaparecido.dart';
import '../view_models/report_desaparecido_view_model.dart';
import 'package:crop_image/crop_image.dart';
import 'package:file_picker/file_picker.dart';
import '../../../common/state_enum.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'tutorials/tutorial_main_screen.dart';

// Formatter para convertir texto a mayúsculas
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

// Paleta de colores vanguardista
class AppColors {
  static const primaryNavy = Color(0xFF1A237E); // Azul marino institucional
  static const primaryBlue = Color(0xFF3F51B5); // Azul institucional
  static const accentBlue = Color(0xFF2196F3); // Azul de acento
  static const lightBlue = Color(0xFFE3F2FD); // Azul claro
  static const successGreen = Color(0xFF4CAF50); // Verde éxito
  static const warningOrange = Color(0xFFFF9800); // Naranja advertencia
  static const errorRed = Color(0xFFF44336); // Rojo error
  static const surfaceWhite = Color(0xFFFAFAFA); // Blanco superficie
  static const textDark = Color(0xFF212121); // Texto oscuro
  static const textLight = Color(0xFF757575); // Texto claro
}

// Diálogo para recortar imágenes
class ImageCropperDialog extends StatefulWidget {
  final Uint8List imageData;

  const ImageCropperDialog({super.key, required this.imageData});

  @override
  _ImageCropperDialogState createState() => _ImageCropperDialogState();
}

class _ImageCropperDialogState extends State<ImageCropperDialog> {
  final controller = CropController();
  late Image _image;

  @override
  void initState() {
    super.initState();
    _image = Image.memory(widget.imageData);
  }

  Future<void> _cropImage() async {
    try {
      // Obtener la imagen recortada
      final ui.Image bitmap = await controller.croppedBitmap();

      // Convertir la imagen a bytes
      final ByteData? byteData = await bitmap.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw Exception('No se pudo convertir la imagen recortada');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Retornar los bytes recortados
      if (mounted) {
        Navigator.of(context).pop(pngBytes);
      }
    } catch (e) {
      print('Error al recortar la imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al recortar la imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Preparar Imagen'),
        backgroundColor: AppColors.primaryNavy,
        actions: [
          TextButton(
            onPressed: _cropImage,
            child: const Text(
              'Recortar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CropImage(
                    controller: controller,
                    image: _image,
                    gridColor: Colors.white,
                    gridCornerColor: AppColors.primaryBlue,
                    gridThickWidth: 3,
                    gridThinWidth: 1,
                    scrimColor: Colors.black.withOpacity(0.7),
                    alwaysShowThirdLines: true,
                    minimumImageSize: 50,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildRotateButton(
                        Icons.rotate_left,
                        () => controller.rotateLeft(),
                      ),
                      _buildAspectRatioButton('Original', null),
                      _buildAspectRatioButton('1:1', 1.0),
                      _buildAspectRatioButton('4:3', 4.0 / 3.0),
                      _buildAspectRatioButton('16:9', 16.0 / 9.0),
                      _buildRotateButton(
                        Icons.rotate_right,
                        () => controller.rotateRight(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _cropImage,
                        icon: const Icon(Icons.crop),
                        label: const Text('Recortar Imagen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed:
                            () => Navigator.of(context).pop(widget.imageData),
                        child: const Text(
                          'Usar sin recortar',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRotateButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: Colors.white),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.2),
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildAspectRatioButton(String label, double? ratio) {
    return InkWell(
      onTap: () {
        setState(() {
          controller.aspectRatio = ratio;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:
              controller.aspectRatio == ratio
                  ? AppColors.primaryBlue
                  : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight:
                controller.aspectRatio == ratio
                    ? FontWeight.bold
                    : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class ReportDesaparecidoScreen extends StatefulWidget {
  const ReportDesaparecidoScreen({super.key});

  @override
  State<ReportDesaparecidoScreen> createState() =>
      _ReportDesaparecidoScreenState();
}

class _ReportDesaparecidoScreenState extends State<ReportDesaparecidoScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> departamentos = [];
  List<Map<String, dynamic>> provincias = [];
  List<Map<String, dynamic>> distritos = [];

  String? selectedDepartamento;
  String? selectedProvincia;
  String? selectedDistrito;

  late ReportDesaparecidoViewModel _viewModel;
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  bool _isLoading = false;
  final DatabaseHelper dbHelper = DatabaseHelper();

  // Controllers
  final TextEditingController _nombresController = TextEditingController();
  final TextEditingController _apellidosController = TextEditingController();
  final TextEditingController _dniController = TextEditingController();
  String? _sexo;
  final TextEditingController _telefonoContactoController =
      TextEditingController();
  final TextEditingController _fechaDesaparicionController =
      TextEditingController();
  final TextEditingController _fechaNacimientoController =
      TextEditingController();
  final TextEditingController _horaDesaparicionController =
      TextEditingController();
  final TextEditingController _detallesAdicionalesController =
      TextEditingController();

  DateTime? _selectedFechaNacimiento;
  DateTime? _selectedFechaDesaparicion;
  TimeOfDay? _selectedHoraDesaparicion;

  File? _fotoFile;
  File? _imagenFichaFile;
  bool _isGuardarActivo = false;

  // Variables de validación para cada campo
  bool _isNombresValid = false;
  bool _isApellidosValid = false;
  bool _isDniValid = false;
  bool _isTelefonoValid = false;
  bool _isSexoValid = false;
  bool _isFotoValid = false;
  bool _isImagenFichaValid = false;
  bool _isFechaDesaparicionValid = false;
  bool _isFechaNacimientoValid = false;
  bool _isDepartamentoValid = false;
  bool _isProvinciaValid = false;
  bool _isDistritoValid = false;

  @override
  void initState() {
    super.initState();

    // Inicializar animaciones
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _pulseController.repeat(reverse: true);

    _loadDepartamentos();
    _setupListeners();
  }

  void _setupListeners() {
    _nombresController.addListener(_validateForm);
    _apellidosController.addListener(_validateForm);
    _dniController.addListener(_validateForm);
    _telefonoContactoController.addListener(_validateForm);
    _fechaDesaparicionController.addListener(_validateForm);
    _horaDesaparicionController.addListener(_validateForm);
    _fechaNacimientoController.addListener(_validateForm);
    _detallesAdicionalesController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _nombresController.dispose();
    _apellidosController.dispose();
    _dniController.dispose();
    _telefonoContactoController.dispose();
    _fechaDesaparicionController.dispose();
    _fechaNacimientoController.dispose();
    _horaDesaparicionController.dispose();
    _detallesAdicionalesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, bool isFotoPersona) async {
    if (!isFotoPersona) {
      _showImageSourceSelection(isFotoPersona);
      return;
    }
    _handleImageSelection(source, isFotoPersona);
  }

  Future<void> _showImageSourceSelection(bool isFotoPersona) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1565C0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                margin: const EdgeInsets.all(8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.white),
                ),
                title: const Text(
                  'Seleccionar de Galería',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleImageSelection(ImageSource.gallery, isFotoPersona);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: const Text(
                  'Tomar Foto',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleImageSelection(ImageSource.camera, isFotoPersona);
                },
              ),
              if (!isFotoPersona)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text(
                    'Seleccionar PDF',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPdfAndConvertToImage();
                  },
                ),
              const SizedBox(height: 20),
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
      setState(() => _isLoading = true);

      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: isFotoPersona ? 1000 : 1600,
        maxHeight: isFotoPersona ? 1000 : 1600,
      );

      if (pickedFile != null && pickedFile.path.isNotEmpty) {
        try {
          final compressedFile = await compressImage(File(pickedFile.path));
          final imageData = await compressedFile.readAsBytes();

          final croppedData = await Navigator.of(context).push<Uint8List>(
            MaterialPageRoute(
              builder: (context) => ImageCropperDialog(imageData: imageData),
            ),
          );

          if (croppedData != null) {
            final tempDir = await getTemporaryDirectory();
            final file = File(
              '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            await file.writeAsBytes(croppedData);

            setState(() {
              if (isFotoPersona) {
                _fotoFile = file;
                _isFotoValid = true;
              } else {
                _imagenFichaFile = file;
                _isImagenFichaValid = true;
              }
              _validateForm();
            });
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se seleccionó ninguna imagen válida.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar o recortar la imagen: $e'),
          backgroundColor: Colors.red,
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
          final page = document.pages.first;
          final pageImage = await page.render();

          if (pageImage != null) {
            final ui.Image renderedImage = await pageImage.createImage();
            final imageBytes = await renderedImage.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (imageBytes == null) {
              throw Exception('Failed to convert image to byte data');
            }
            final Uint8List pngBytes = imageBytes.buffer.asUint8List();

            final tempDir = await getTemporaryDirectory();
            final tempPath = tempDir.path;
            final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
            final tempFile = File('$tempPath/$fileName');

            await tempFile.writeAsBytes(pngBytes);

            if (!mounted) return;
            setState(() {
              _imagenFichaFile = tempFile;
              _isImagenFichaValid = true;
              _validateForm();
            });
          }
        }
      }
    } catch (e) {
      print('Error picking PDF and converting to image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
      setState(() {
        distritos = data;
        selectedDistrito = null;
      });
    }
  }

  void _validateForm() {
    final nombresValido =
        _validarNombres(_nombresController.text) == null &&
        _nombresController.text.isNotEmpty;
    final apellidosValido =
        _validarApellidos(_apellidosController.text) == null &&
        _apellidosController.text.isNotEmpty;
    final dniValido =
        _validarDNI(_dniController.text) == null &&
        _dniController.text.isNotEmpty;
    final telefonoValido =
        _validarTelefono(_telefonoContactoController.text) == null &&
        _telefonoContactoController.text.isNotEmpty;
    final fotoSeleccionada = _fotoFile != null;
    final imagenFichaSeleccionada = _imagenFichaFile != null;
    final fechaDesaparicionSeleccionada = _selectedFechaDesaparicion != null;
    final fechaNacimientoSeleccionada = _selectedFechaNacimiento != null;
    final sexoSeleccionado = _sexo != null;
    final departamentoSeleccionado = selectedDepartamento != null;
    final provinciaSeleccionada = selectedProvincia != null;
    final distritoSeleccionado = selectedDistrito != null;

    setState(() {
      _isNombresValid = nombresValido;
      _isApellidosValid = apellidosValido;
      _isDniValid = dniValido;
      _isTelefonoValid = telefonoValido;
      _isSexoValid = sexoSeleccionado;
      _isFotoValid = fotoSeleccionada;
      _isImagenFichaValid = imagenFichaSeleccionada;
      _isFechaDesaparicionValid = fechaDesaparicionSeleccionada;
      _isFechaNacimientoValid = fechaNacimientoSeleccionada;
      _isDepartamentoValid = departamentoSeleccionado;
      _isProvinciaValid = provinciaSeleccionada;
      _isDistritoValid = distritoSeleccionado;

      _isGuardarActivo =
          nombresValido &&
          apellidosValido &&
          dniValido &&
          telefonoValido &&
          sexoSeleccionado &&
          fotoSeleccionada &&
          imagenFichaSeleccionada &&
          fechaDesaparicionSeleccionada &&
          fechaNacimientoSeleccionada &&
          departamentoSeleccionado &&
          provinciaSeleccionada &&
          distritoSeleccionado;
    });
  }

  String? _validarNombres(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor, ingrese los nombres.';
    }
    final names = value.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (names.length > 3) {
      return 'Máximo 3 nombres permitidos.';
    }
    return null;
  }

  String? _validarApellidos(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor, ingrese los apellidos.';
    }
    final surnames =
        value.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (surnames.length != 2) {
      return 'Se requieren exactamente 2 apellidos.';
    }
    return null;
  }

  String? _validarDNI(String? value) {
    if (value == null || value.isEmpty) {
      return 'El DNI es obligatorio.';
    }

    final isNumeric = RegExp(r'^[0-9]+$').hasMatch(value);
    if (!isNumeric) {
      return 'El DNI solo debe contener números.';
    }

    if (value.length != 8) {
      return 'El DNI debe tener exactamente 8 dígitos.';
    }

    return null;
  }

  String? _validarTelefono(String? value) {
    if (value == null || value.isEmpty) {
      return 'El teléfono es obligatorio.';
    }

    if (value.length != 9) {
      return 'El teléfono debe tener exactamente 9 dígitos.';
    }

    return null;
  }

  Future<void> _selectFechaNacimiento(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedFechaNacimiento ??
          DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1960),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1565C0),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedFechaNacimiento) {
      setState(() {
        _selectedFechaNacimiento = picked;
        _fechaNacimientoController.text = DateFormat(
          'dd/MM/yyyy',
          'es_ES',
        ).format(picked);
        _validateForm();
      });
    }
  }

  Future<void> _selectFechaDesaparicion(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedFechaDesaparicion ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1565C0),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedFechaDesaparicion) {
      setState(() {
        _selectedFechaDesaparicion = picked;
        _fechaDesaparicionController.text = DateFormat(
          'dd/MM/yyyy',
          'es_ES',
        ).format(picked);
        _validateForm();
      });
    }
  }

  Future<void> _selectHoraDesaparicion(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedHoraDesaparicion ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedHoraDesaparicion) {
      setState(() {
        _selectedHoraDesaparicion = picked;
        _horaDesaparicionController.text = picked.format(context);
        _validateForm();
      });
    }
  }

  Future<void> _guardarReporte() async {
    if (!_formKey.currentState!.validate() || !_isGuardarActivo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, complete todos los campos requeridos y seleccione las imágenes.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
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

      // Combinar fecha y hora de desaparición
      DateTime? fechaHoraDesaparicion;
      if (_selectedFechaDesaparicion != null) {
        if (_selectedHoraDesaparicion != null) {
          fechaHoraDesaparicion = DateTime(
            _selectedFechaDesaparicion!.year,
            _selectedFechaDesaparicion!.month,
            _selectedFechaDesaparicion!.day,
            _selectedHoraDesaparicion!.hour,
            _selectedHoraDesaparicion!.minute,
          );
        } else {
          fechaHoraDesaparicion = _selectedFechaDesaparicion;
        }
      }

      final desaparecido = Desaparecido(
        nombres: _nombresController.text.trim().toUpperCase(),
        apellidos: _apellidosController.text.trim().toUpperCase(),
        sexo: _sexo?.toUpperCase(),
        dni: _dniController.text.trim(),
        telefonoContacto: _telefonoContactoController.text.trim(),
        fechaNacimiento: _selectedFechaNacimiento,
        fechaDesaparicion: fechaHoraDesaparicion,
        departamento: departamentoNombre?.toUpperCase(),
        provincia: provinciaNombre?.toUpperCase(),
        distrito: distritoNombre?.toUpperCase(),
        detallesAdicionales:
            _detallesAdicionalesController.text.trim().toUpperCase(),
        fechaCreacion: DateTime.now(),
        fechaActualizacion: DateTime.now(),
      );

      await _viewModel.reportDesaparecidoConImagenes(
        desaparecido,
        fotoFile: _fotoFile,
        fichaFile: _imagenFichaFile,
      );

      if (_viewModel.state == RequestState.Loaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_viewModel.message),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else if (_viewModel.state == RequestState.Error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${_viewModel.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: ${e.toString()}'),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red,
        ),
      );
      print('Error detallado: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showImageSourceDialog(bool isFotoPersona) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1565C0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isFotoPersona ? 'Seleccionar Fuente' : 'Seleccionar Documento PDF',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (isFotoPersona) ...[
                _buildDialogOption(
                  icon: Icons.camera_alt,
                  title: 'Cámara',
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.camera, isFotoPersona);
                  },
                ),
                _buildDialogOption(
                  icon: Icons.photo_library,
                  title: 'Galería',
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.gallery, isFotoPersona);
                  },
                ),
              ] else ...[
                _buildDialogOption(
                  icon: Icons.picture_as_pdf,
                  title: 'Seleccionar PDF',
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickPdfAndConvertToImage();
                    _validateForm();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDialogOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final desaparecidoRemoteDataSource = DesaparecidoRemoteDataSource(
          FirebaseFirestore.instance,
          FirebaseStorage.instance,
        );
        final desaparecidoRepository = DesaparecidoRepositoryImpl(
          desaparecidoRemoteDataSource,
        );
        final reportarDesaparicionUseCase = ReportarDesaparicionUseCase(
          desaparecidoRepository,
        );
        _viewModel = ReportDesaparecidoViewModel(reportarDesaparicionUseCase);
        return _viewModel;
      },
      child: Consumer<ReportDesaparecidoViewModel>(
        builder: (context, viewModel, child) {
          return PopScope(
            canPop: true,
            child: Scaffold(
              appBar: AppBar(
                title: const Text(
                  'Reportar Persona Desaparecida',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: const Color(0xFF1565C0),
                elevation: 4,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              body: Stack(
                children: [
                  _buildAnimatedForm(),
                  if (_isLoading) _buildLoadingOverlay(),
                ],
              ),
              floatingActionButton: _buildFloatingActionButton(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedForm() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildWelcomeHeader(),
                    const SizedBox(height: 30),
                    _buildPersonalInfoSection(),
                    const SizedBox(height: 25),
                    _buildLocationSection(),
                    const SizedBox(height: 25),
                    _buildMediaSection(),
                    const SizedBox(height: 30),
                    _buildSubmitButton(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2196F3), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield, color: Color(0xFF1565C0), size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sistema de Registro PNP',
            style: TextStyle(
              color: Color(0xFF1565C0),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete la información del caso de desaparición',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF1565C0).withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return _buildGlassSection(
      title: 'Información Personal',
      icon: Icons.person,
      color: const Color(0xFF2196F3),
      backgroundColor: const Color(0xFFF3F8FF),
      children: [
        _buildModernTextField(
          controller: _nombresController,
          label: 'Nombres',
          hint: 'Ingrese los nombres (máx. 3)',
          icon: Icons.badge,
          validator: _validarNombres,
          formatter: [UpperCaseTextFormatter()],
          isValid: _isNombresValid,
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          controller: _apellidosController,
          label: 'Apellidos',
          hint: 'Ingrese los dos apellidos',
          icon: Icons.person_outline,
          validator: _validarApellidos,
          formatter: [UpperCaseTextFormatter()],
          isValid: _isApellidosValid,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildModernTextField(
                controller: _dniController,
                label: 'DNI',
                hint: '8 dígitos',
                icon: Icons.credit_card,
                validator: _validarDNI,
                keyboardType: TextInputType.number,
                formatter: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                isValid: _isDniValid,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernDropdown(
                value: _sexo,
                label: 'Género',
                icon: Icons.wc,
                items: const [
                  DropdownMenuItem(
                    value: 'Masculino',
                    child: Text('Masculino'),
                  ),
                  DropdownMenuItem(value: 'Femenino', child: Text('Femenino')),
                ],
                onChanged: (value) {
                  setState(() => _sexo = value);
                  _validateForm();
                },
                isValid: _isSexoValid,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          controller: _telefonoContactoController,
          label: 'Teléfono de Contacto',
          hint: '9 dígitos',
          icon: Icons.phone,
          validator: _validarTelefono,
          keyboardType: TextInputType.phone,
          formatter: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(9),
          ],
          isValid: _isTelefonoValid,
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    controller: _fechaNacimientoController,
                    label: 'Fecha de Nacimiento',
                    icon: Icons.cake,
                    onTap: () => _selectFechaNacimiento(context),
                    isValid: _isFechaNacimientoValid,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateField(
                    controller: _fechaDesaparicionController,
                    label: 'Fecha de Desaparición',
                    icon: Icons.event_busy,
                    onTap: () => _selectFechaDesaparicion(context),
                    isValid: _isFechaDesaparicionValid,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDateField(
              controller: _horaDesaparicionController,
              label: 'Hora de Desaparición',
              icon: Icons.access_time,
              onTap: () => _selectHoraDesaparicion(context),
              isValid: _selectedHoraDesaparicion != null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return _buildGlassSection(
      title: 'Ubicación',
      icon: Icons.location_on,
      color: const Color(0xFF9C27B0),
      backgroundColor: const Color(0xFFF8F5FF),
      children: [
        _buildModernDropdown(
          value: selectedDepartamento,
          label: 'Departamento',
          icon: Icons.map,
          items:
              departamentos.map((dep) {
                return DropdownMenuItem<String>(
                  value: dep['id'],
                  child: Text(dep['name']),
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
          isValid: _isDepartamentoValid,
        ),
        if (provincias.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildModernDropdown(
            value: selectedProvincia,
            label: 'Provincia',
            icon: Icons.location_city,
            items:
                provincias.map((prov) {
                  return DropdownMenuItem<String>(
                    value: prov['id'],
                    child: Text(prov['name']),
                  );
                }).toList(),
            onChanged: (value) {
              setState(() {
                selectedProvincia = value;
                if (value != null) {
                  distritos = [];
                  selectedDistrito = null;
                  _loadDistritos(value);
                }
              });
              _validateForm();
            },
            isValid: _isProvinciaValid,
          ),
        ],
        if (distritos.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildModernDropdown(
            value: selectedDistrito,
            label: 'Distrito',
            icon: Icons.place,
            items:
                distritos.map((dist) {
                  return DropdownMenuItem<String>(
                    value: dist['id'],
                    child: Text(dist['name']),
                  );
                }).toList(),
            onChanged: (value) {
              setState(() => selectedDistrito = value);
              _validateForm();
            },
            isValid: _isDistritoValid,
          ),
        ],
        const SizedBox(height: 16),
        _buildModernTextField(
          controller: _detallesAdicionalesController,
          label: 'Detalles Adicionales',
          hint: 'Información relevante del caso...',
          icon: Icons.note,
          maxLines: 3,
          isRequired: false,
          isValid: false,
        ),
      ],
    );
  }

  Widget _buildMediaSection() {
    return _buildGlassSection(
      title: 'Archivos del Caso',
      icon: Icons.attach_file,
      color: const Color(0xFF4CAF50),
      backgroundColor: const Color(0xFFF1F8E9),
      children: [
        // Botón de ayuda para transferir archivos
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFF6B35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.help_outline,
                          color: Color(0xFFFF6B35),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '¿Necesitas ayuda para transferir archivos del PC al móvil?',
                          style: TextStyle(
                            color: Color(0xFFFF6B35),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _navigateToFileTransferTutorials,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Ver Tutorial',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Botones existentes para seleccionar archivos
        Row(
          children: [
            Expanded(
              child: _buildMediaButton(
                label:
                    _fotoFile == null
                        ? 'Foto de la Persona'
                        : 'Foto Seleccionada',
                icon: _fotoFile == null ? Icons.camera_alt : Icons.check_circle,
                isSelected: _isFotoValid,
                onPressed: () => _showImageSourceDialog(true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMediaButton(
                label:
                    _imagenFichaFile == null
                        ? 'Ficha/Documento'
                        : 'Ficha Seleccionada',
                icon:
                    _imagenFichaFile == null
                        ? Icons.description
                        : Icons.check_circle,
                isSelected: _isImagenFichaValid,
                onPressed: () => _showImageSourceDialog(false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlassSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    List<TextInputFormatter>? formatter,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isRequired = true,
    bool isValid = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:
            isValid
                ? Colors.green.withOpacity(0.1)
                : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid ? Colors.green : const Color(0xFF2196F3),
          width: isValid ? 2 : 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        inputFormatters: formatter,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(
          color: isValid ? Colors.green : const Color(0xFF1565C0),
        ),
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          hintText: hint,
          labelStyle: TextStyle(
            color: isValid ? Colors.green : const Color(0xFF1565C0),
          ),
          hintStyle: TextStyle(color: const Color(0xFF1565C0).withOpacity(0.5)),
          prefixIcon: Icon(
            icon,
            color: isValid ? Colors.green : const Color(0xFF2196F3),
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          errorStyle: const TextStyle(color: Colors.orange),
        ),
        onChanged: (_) => _validateForm(),
        autovalidateMode: AutovalidateMode.onUserInteraction,
      ),
    );
  }

  Widget _buildModernDropdown<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    bool isValid = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:
            isValid
                ? Colors.green.withOpacity(0.1)
                : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid ? Colors.green : const Color(0xFF2196F3),
          width: isValid ? 2 : 1,
        ),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        style: TextStyle(
          color: isValid ? Colors.green : const Color(0xFF1565C0),
        ),
        dropdownColor: Colors.white,
        decoration: InputDecoration(
          labelText: '$label *',
          labelStyle: TextStyle(
            color: isValid ? Colors.green : const Color(0xFF1565C0),
          ),
          prefixIcon: Icon(
            icon,
            color: isValid ? Colors.green : const Color(0xFF2196F3),
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        validator: (value) => value == null ? 'Seleccione $label' : null,
        autovalidateMode: AutovalidateMode.onUserInteraction,
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isValid = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:
            isValid
                ? Colors.green.withOpacity(0.1)
                : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid ? Colors.green : const Color(0xFF2196F3),
          width: isValid ? 2 : 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        style: TextStyle(
          color: isValid ? Colors.green : const Color(0xFF1565C0),
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: '$label *',
          labelStyle: TextStyle(
            color: isValid ? Colors.green : const Color(0xFF1565C0),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon,
            color: isValid ? Colors.green : const Color(0xFF2196F3),
            size: 20,
          ),
          suffixIcon: Icon(
            Icons.calendar_today,
            color:
                isValid
                    ? Colors.green
                    : const Color(0xFF2196F3).withOpacity(0.5),
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          isDense: false,
        ),
        validator:
            (value) => value?.isEmpty ?? true ? 'Seleccione $label' : null,
        autovalidateMode: AutovalidateMode.onUserInteraction,
      ),
    );
  }

  Widget _buildMediaButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isSelected ? 1.0 : _pulseAnimation.value,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    isSelected
                        ? [Colors.green, Colors.green.withOpacity(0.8)]
                        : [
                          const Color(0xFF2196F3).withOpacity(0.1),
                          const Color(0xFF2196F3).withOpacity(0.05),
                        ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.green : const Color(0xFF2196F3),
                width: 2,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color:
                          isSelected ? Colors.white : const Color(0xFF1565C0),
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            isSelected ? Colors.white : const Color(0xFF1565C0),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isGuardarActivo ? _pulseAnimation.value : 1.0,
          child: Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    _isGuardarActivo && !_isLoading
                        ? [Colors.green, Colors.green.withOpacity(0.8)]
                        : [
                          Colors.grey.withOpacity(0.3),
                          Colors.grey.withOpacity(0.2),
                        ],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow:
                  _isGuardarActivo
                      ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ]
                      : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isGuardarActivo && !_isLoading ? _guardarReporte : null,
                borderRadius: BorderRadius.circular(15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isLoading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      const Icon(Icons.save, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _isLoading ? 'Guardando Caso...' : 'Registrar Caso',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingActionButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: FloatingActionButton.extended(
            onPressed: () {
              Scrollable.ensureVisible(
                _formKey.currentContext!,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            },
            backgroundColor: const Color(0xFF2196F3),
            icon: const Icon(
              Icons.keyboard_arrow_up,
              color: Colors.white,
              size: 16,
            ),
            label: const Text(
              'Inicio',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              SizedBox(height: 20),
              Text(
                'Procesando caso...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToFileTransferTutorials() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TutorialMainScreen()),
    );
  }
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
    keepExif: false,
  );

  if (result == null) {
    throw Exception('Failed to compress image');
  }
  return File(result.path);
}
