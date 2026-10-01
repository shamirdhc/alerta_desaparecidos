import '../../../services/gps_location_service.dart';
import 'package:flutter/foundation.dart';
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
import '../view_models/report_desaparecido_view_model.dart';
import 'package:crop_image/crop_image.dart';
import 'package:file_picker/file_picker.dart';
import '../../../common/state_enum.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'tutorials/tutorial_main_screen.dart';
import '../../../services/gemini_extractor_service.dart';
import '../../../injection.dart' as di;
import '../../../common/constants/gemini_constants.dart';

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
class ReportScreenColors {
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
        backgroundColor: ReportScreenColors.primaryNavy,
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
                    gridCornerColor: ReportScreenColors.primaryBlue,
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
                          backgroundColor: ReportScreenColors.primaryBlue,
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
                  ? ReportScreenColors.primaryBlue
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
  Uint8List? _fotoBytes;
  Uint8List? _imagenFichaBytes;
  bool _isGuardarActivo = false;
  bool _isAiScanning = false;
  bool _dialogoCargandoAbierto = false;

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

      if (pickedFile != null) {
        try {
          // Leer bytes directamente sin depender de filesystem temporal
          final Uint8List imageData = await pickedFile.readAsBytes();

          final croppedData = await Navigator.of(context).push<Uint8List>(
            MaterialPageRoute(
              builder: (context) => ImageCropperDialog(imageData: imageData),
            ),
          );

          if (croppedData != null) {
            File? file;
            if (!kIsWeb) {
              try {
                final tempDir = await getTemporaryDirectory();
                final f = File(
                  '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg',
                );
                await f.writeAsBytes(croppedData);
                file = f;
              } catch (_) {
                // Si path_provider falla o no existe canal nativo, seguimos con bytes
              }
            }

            setState(() {
              if (isFotoPersona) {
                _fotoFile = file;
                _fotoBytes = croppedData;
                _isFotoValid = true;
              } else {
                _imagenFichaFile = file;
                _imagenFichaBytes = croppedData;
                _isImagenFichaValid = true;
              }
              _validateForm();
            });

            // Si es la Nota de Alerta, auto-ejecutar el análisis y relleno automático
            if (!isFotoPersona) {
              Future.microtask(() => _ejecutarEscaneoIa());
            }
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

            File? tempFile;
            if (!kIsWeb) {
              try {
                final tempDir = await getTemporaryDirectory();
                final tempPath = tempDir.path;
                final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
                final f = File('$tempPath/$fileName');
                await f.writeAsBytes(pngBytes);
                tempFile = f;
              } catch (_) {}
            }

            if (!mounted) return;
            setState(() {
              _imagenFichaFile = tempFile;
              _imagenFichaBytes = pngBytes;
              _isImagenFichaValid = true;
              _validateForm();
            });

            // Si es la Nota de Alerta en PDF, auto-ejecutar el análisis y relleno automático
            Future.microtask(() => _ejecutarEscaneoIa());
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
    if (!mounted) return;
    setState(() {
      departamentos = data;
    });

    if (selectedDepartamento == null && data.isNotEmpty) {
      try {
        final loc = await GpsLocationService.getSavedLocation();
        if (loc != null && mounted) {
          final match = data.firstWhere(
            (dep) => GpsLocationService.matches(dep['name'].toString(), loc.departamento),
            orElse: () => <String, dynamic>{},
          );
          if (match.isNotEmpty && match['id'] != null) {
            final depId = match['id'].toString();
            final provData = await dbHelper.getProvincias(depId);
            if (!mounted) return;
            setState(() {
              selectedDepartamento = depId;
              provincias = provData;
            });

            if (loc.provincia.isNotEmpty) {
              final provMatch = provData.firstWhere(
                (p) => GpsLocationService.matches(p['name'].toString(), loc.provincia),
                orElse: () => <String, dynamic>{},
              );
              if (provMatch.isNotEmpty && provMatch['id'] != null && mounted) {
                final provId = provMatch['id'].toString();
                final distData = await dbHelper.getDistritos(provId);
                if (mounted) {
                  setState(() {
                    selectedProvincia = provId;
                    distritos = distData;
                  });
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error auto-seleccionando departamento en reporte: $e');
      }
    }
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
    final fotoSeleccionada = _fotoBytes != null || _fotoFile != null;
    final imagenFichaSeleccionada = _imagenFichaBytes != null || _imagenFichaFile != null;
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
    if (surnames.isEmpty) {
      return 'Por favor, ingrese al menos un apellido.';
    }
    if (surnames.length > 4) {
      return 'Máximo 4 palabras permitidas en apellidos.';
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
      firstDate: DateTime(1910),
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
      firstDate: DateTime(1980),
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

  void _mostrarCamposFaltantes() {
    final List<String> faltantes = [];
    if (_fotoBytes == null && _fotoFile == null) faltantes.add('Foto de la persona');
    if (_imagenFichaBytes == null && _imagenFichaFile == null) faltantes.add('Nota de Alerta (PDF o Imagen)');
    if (_validarNombres(_nombresController.text) != null) faltantes.add('Nombres válidos');
    if (_validarApellidos(_apellidosController.text) != null) faltantes.add('Apellidos válidos');
    if (_validarDNI(_dniController.text) != null) faltantes.add('DNI (8 dígitos)');
    if (_validarTelefono(_telefonoContactoController.text) != null) faltantes.add('Teléfono (9 dígitos)');
    if (_sexo == null) faltantes.add('Sexo');
    if (_selectedFechaNacimiento == null) faltantes.add('Fecha de nacimiento');
    if (_selectedFechaDesaparicion == null) faltantes.add('Fecha de desaparición');
    if (selectedDepartamento == null) faltantes.add('Departamento');
    if (selectedProvincia == null) faltantes.add('Provincia');
    if (selectedDistrito == null) faltantes.add('Distrito');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  'Complete los campos obligatorios:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              faltantes.take(4).map((f) => '• $f').join('\n') +
                  (faltantes.length > 4 ? '\n• y ${faltantes.length - 4} campos más...' : ''),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
        fotoBytes: _fotoBytes,
        fichaBytes: _imagenFichaBytes,
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
            isFotoPersona ? 'Foto de la Persona' : 'Subir Nota de Alerta PNP',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (isFotoPersona) ...[
                _buildDialogOption(
                  icon: Icons.camera_alt_rounded,
                  title: 'Tomar Foto con Cámara',
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.camera, isFotoPersona);
                  },
                ),
                _buildDialogOption(
                  icon: Icons.photo_library_rounded,
                  title: 'Elegir de la Galería',
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.gallery, isFotoPersona);
                  },
                ),
              ] else ...[
                _buildDialogOption(
                  icon: Icons.camera_alt_rounded,
                  title: 'Tomar Foto de Nota de Alerta',
                  onTap: () {
                    Navigator.of(context).pop();
                    _handleImageSelection(ImageSource.camera, false);
                  },
                ),
                _buildDialogOption(
                  icon: Icons.photo_library_rounded,
                  title: 'Seleccionar Imagen de Galería',
                  onTap: () {
                    Navigator.of(context).pop();
                    _handleImageSelection(ImageSource.gallery, false);
                  },
                ),
                _buildDialogOption(
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'Seleccionar Archivo PDF',
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
        _viewModel = di.locator<ReportDesaparecidoViewModel>();
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
                    const SizedBox(height: 18),
                    _buildAiAutoFillBanner(),
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


  // ==========================================
  // INTELIGENCIA ARTIFICIAL: ESCANEO DE FICHA
  // ==========================================

  Widget _buildAiAutoFillBanner() {
    final bool hasFicha = _imagenFichaBytes != null || _imagenFichaFile != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1B4B), // Indigo profundo institucional
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'ESCANEO INTELIGENTE PNP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                          ),
                          child: const Text(
                            'IA ACTIVA',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasFicha
                          ? 'Nota de Alerta cargada. Pulsa el botón para extraer los datos.'
                          : 'Sube la Nota de Alerta (PDF o Foto) y la IA llenará el formulario.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(
                hasFicha ? Icons.bolt_rounded : Icons.file_upload_outlined,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                hasFicha
                    ? '✨ Auto-completar Formulario con IA'
                    : '📄 Subir Nota de Alerta y Auto-completar',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasFicha ? const Color(0xFF4F46E5) : const Color(0xFF0284C7),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
                shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.5),
              ),
              onPressed: _ejecutarEscaneoIa,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _ejecutarEscaneoIa() async {
    if (_isAiScanning) return;

    // Si no ha seleccionado la ficha, pedir seleccionarla primero
    if (_imagenFichaBytes == null && _imagenFichaFile == null) {
      await _showImageSourceSelection(false);
      if (_imagenFichaBytes == null && _imagenFichaFile == null) return;
    }

    _isAiScanning = true;

    // Verificar API Key
    final hasKey = await GeminiExtractorService.hasApiKey();
    if (!hasKey) {
      if (!mounted) {
        _isAiScanning = false;
        return;
      }
      await _mostrarDialogoApiKey();
      final stillHasKey = await GeminiExtractorService.hasApiKey();
      if (!stillHasKey) {
        _isAiScanning = false;
        return;
      }
    }

    if (!mounted) {
      _isAiScanning = false;
      return;
    }
    _mostrarDialogoCargandoIa();

    try {
      final bytes = _imagenFichaBytes ?? await _imagenFichaFile!.readAsBytes();
      final mimeType = (_imagenFichaFile?.path.toLowerCase().endsWith('.png') ?? false) ? 'image/png' : 'image/jpeg';
      
      final data = await GeminiExtractorService.extractFromImageBytes(
        bytes,
        mimeType: mimeType,
      );

      _cerrarDialogoCargandoIa();

      if (data == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron extraer datos del documento.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Si no hay foto individual de la persona, usar la imagen de la ficha
      if (_fotoBytes == null && _fotoFile == null) {
        setState(() {
          _fotoBytes = bytes;
          _fotoFile = _imagenFichaFile;
          _isFotoValid = true;
        });
      }

      // 1. Auto-completar campos de texto
      setState(() {
        if (data.nombres != null && data.nombres!.isNotEmpty) {
          _nombresController.text = data.nombres!.toUpperCase();
        }
        if (data.apellidos != null && data.apellidos!.isNotEmpty) {
          _apellidosController.text = data.apellidos!.toUpperCase();
        }
        if (data.dni != null && data.dni!.isNotEmpty) {
          _dniController.text = data.dni!;
        }
        if (data.sexo != null && data.sexo!.isNotEmpty) {
          final s = data.sexo!.toUpperCase();
          if (s.contains('FEM') || s == 'F') {
            _sexo = 'Femenino';
          } else if (s.contains('MAS') || s == 'M') {
            _sexo = 'Masculino';
          }
        }
        if (data.fechaNacimiento != null) {
          _selectedFechaNacimiento = data.fechaNacimiento;
          _fechaNacimientoController.text = DateFormat('dd/MM/yyyy').format(data.fechaNacimiento!);
        }
        if (data.fechaDesaparicion != null) {
          _selectedFechaDesaparicion = data.fechaDesaparicion;
          _fechaDesaparicionController.text = DateFormat('dd/MM/yyyy').format(data.fechaDesaparicion!);
        }
        if (data.horaDesaparicion != null && data.horaDesaparicion!.isNotEmpty) {
          try {
            final rawTime = data.horaDesaparicion!.replaceAll(RegExp(r'[^0-9:]'), '');
            final parts = rawTime.split(':');
            if (parts.length >= 2) {
              int h = int.parse(parts[0]);
              final m = int.parse(parts[1]);
              final lower = data.horaDesaparicion!.toLowerCase();
              if (lower.contains('p.m.') || lower.contains('pm')) {
                if (h < 12) h += 12;
              } else if (lower.contains('a.m.') || lower.contains('am')) {
                if (h == 12) h = 0;
              }
              _selectedHoraDesaparicion = TimeOfDay(hour: h, minute: m);
              _horaDesaparicionController.text = _selectedHoraDesaparicion!.format(context);
            }
          } catch (_) {}
        }
        if (data.resumenDetalles.isNotEmpty) {
          _detallesAdicionalesController.text = data.resumenDetalles.toUpperCase();
        }
      });

      // 2. Auto-seleccionar Ubigeo en cascada
      if (data.departamento != null && data.departamento!.isNotEmpty) {
        final cleanDep = data.departamento!.toUpperCase().trim();
        final depMatch = departamentos.firstWhere(
          (d) => d['name'].toString().toUpperCase().trim() == cleanDep ||
                 cleanDep.contains(d['name'].toString().toUpperCase().trim()) ||
                 d['name'].toString().toUpperCase().trim().contains(cleanDep),
          orElse: () => <String, dynamic>{},
        );
        if (depMatch.isNotEmpty) {
          final depId = depMatch['id'].toString();
          final provData = await dbHelper.getProvincias(depId);
          setState(() {
            selectedDepartamento = depId;
            provincias = provData;
          });

          if (data.provincia != null && data.provincia!.isNotEmpty) {
            final cleanProv = data.provincia!.toUpperCase().trim();
            final provMatch = provincias.firstWhere(
              (p) => p['name'].toString().toUpperCase().trim() == cleanProv ||
                     cleanProv.contains(p['name'].toString().toUpperCase().trim()) ||
                     p['name'].toString().toUpperCase().trim().contains(cleanProv),
              orElse: () => <String, dynamic>{},
            );
            if (provMatch.isNotEmpty) {
              final provId = provMatch['id'].toString();
              final distData = await dbHelper.getDistritos(provId);
              setState(() {
                selectedProvincia = provId;
                distritos = distData;
              });

              if (data.distrito != null && data.distrito!.isNotEmpty) {
                final cleanDist = data.distrito!.toUpperCase().trim();
                final distMatch = distritos.firstWhere(
                  (dist) => dist['name'].toString().toUpperCase().trim() == cleanDist ||
                            cleanDist.contains(dist['name'].toString().toUpperCase().trim()) ||
                            dist['name'].toString().toUpperCase().trim().contains(cleanDist),
                  orElse: () => <String, dynamic>{},
                );
                if (distMatch.isNotEmpty) {
                  setState(() {
                    selectedDistrito = distMatch['id'].toString();
                  });
                }
              }
            }
          }
        }
      }

      _validateForm();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '¡Formulario rellenado automáticamente con la Nota de Alerta!',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      _cerrarDialogoCargandoIa();
      if (!mounted) return;
      final errorMsg = e.toString()
          .replaceAll('Exception:', '')
          .replaceAll('GenerativeAIException:', '')
          .trim();
      final msgMostrar = errorMsg.isNotEmpty ? errorMsg : 'Por favor verifique la imagen e intente de nuevo.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Error al escanear con IA: $msgMostrar',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      _isAiScanning = false;
    }
  }

  void _mostrarDialogoCargandoIa() {
    _dialogoCargandoAbierto = true;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Analizando Nota de Alerta...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Extrayendo nombres, fechas, Ubigeo y rasgos policiales con Google Gemini IA...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  _dialogoCargandoAbierto = false;
                  Navigator.of(dialogContext).pop();
                },
                icon: const Icon(Icons.close, color: Colors.white54, size: 16),
                label: const Text(
                  'Cancelar / Continuar Manualmente',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      _dialogoCargandoAbierto = false;
    });
  }

  void _cerrarDialogoCargandoIa() {
    if (_dialogoCargandoAbierto && mounted) {
      _dialogoCargandoAbierto = false;
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
    }
  }

  Future<void> _mostrarDialogoApiKey() async {
    final controller = TextEditingController(text: GeminiConstants.apiKey);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: Color(0xFF8B5CF6)),
            SizedBox(width: 10),
            Text('Clave API Google Gemini', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa tu clave gratuita obtenida en aistudio.google.com con tu cuenta de Google:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Pega tu clave (AQ... o AIzaSy...)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await GeminiExtractorService.saveApiKey(controller.text.trim());
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
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
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildDateField(
                    controller: _fechaNacimientoController,
                    label: 'F. Nacimiento',
                    icon: Icons.cake,
                    onTap: () => _selectFechaNacimiento(context),
                    isValid: _isFechaNacimientoValid,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateField(
                    controller: _fechaDesaparicionController,
                    label: 'F. Desaparición',
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
          hint: 'Información relevante del caso, señas particulares, vestimenta...',
          icon: Icons.note,
          maxLines: 4,
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
                    (_fotoBytes == null && _fotoFile == null)
                        ? 'Foto de la Persona'
                        : 'Foto Seleccionada',
                icon: (_fotoBytes == null && _fotoFile == null) ? Icons.camera_alt : Icons.check_circle,
                isSelected: _isFotoValid,
                onPressed: () => _showImageSourceDialog(true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMediaButton(
                label:
                    (_imagenFichaBytes == null && _imagenFichaFile == null)
                        ? 'Ficha/Documento'
                        : 'Ficha Seleccionada',
                icon:
                    (_imagenFichaBytes == null && _imagenFichaFile == null)
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

  Widget _buildFieldLabel(String label, {bool isRequired = true, bool isValid = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isValid ? const Color(0xFF166534) : const Color(0xFF334155),
                letterSpacing: 0.1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isRequired)
            const Text(
              ' *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFFDC2626),
              ),
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFieldLabel(label, isRequired: isRequired, isValid: isValid),
        Container(
          decoration: BoxDecoration(
            color: isValid ? const Color(0xFFF0FDF4) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isValid ? const Color(0xFF22C55E) : const Color(0xFF93C5FD),
              width: isValid ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            inputFormatters: formatter,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 13.5,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 10, right: 6),
                child: Icon(
                  icon,
                  color: isValid ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                  size: 19,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: maxLines > 1 ? 14 : 12,
              ),
              isDense: true,
              errorStyle: const TextStyle(color: Colors.deepOrange, fontSize: 11),
            ),
            onChanged: (_) => _validateForm(),
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFieldLabel(label, isRequired: true, isValid: isValid),
        Container(
          decoration: BoxDecoration(
            color: isValid ? const Color(0xFFF0FDF4) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isValid ? const Color(0xFF22C55E) : const Color(0xFF93C5FD),
              width: isValid ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: DropdownButtonFormField<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            dropdownColor: Colors.white,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 8, right: 4),
                child: Icon(
                  icon,
                  color: isValid ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                  size: 19,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 38),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              isDense: true,
              errorStyle: const TextStyle(color: Colors.deepOrange, fontSize: 11),
            ),
            validator: (val) => val == null ? 'Seleccione ' : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isValid = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFieldLabel(label, isRequired: true, isValid: isValid),
        Container(
          decoration: BoxDecoration(
            color: isValid ? const Color(0xFFF0FDF4) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isValid ? const Color(0xFF22C55E) : const Color(0xFF93C5FD),
              width: isValid ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: IgnorePointer(
              child: TextFormField(
                controller: controller,
                readOnly: true,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'DD/MM/AAAA',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.normal,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 8, right: 4),
                    child: Icon(
                      icon,
                      color: isValid ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                      size: 18,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 38),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      color: isValid ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                      size: 16,
                    ),
                  ),
                  suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                  isDense: true,
                  errorStyle: const TextStyle(color: Colors.deepOrange, fontSize: 11),
                ),
                validator: (val) => (val == null || val.isEmpty) ? 'Requerido' : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ),
          ),
        ),
      ],
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
                onTap: _isLoading
                    ? null
                    : (_isGuardarActivo ? _guardarReporte : _mostrarCamposFaltantes),
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
