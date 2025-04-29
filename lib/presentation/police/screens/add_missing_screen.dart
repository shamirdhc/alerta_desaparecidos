import 'dart:io';
import 'package:alerta_desaparecidos/helpers/database_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../domain/entities/desaparecido.dart';
import '../view_models/add_missing_view_model.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../common/state_enum.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

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
  final TextEditingController _detallesAdicionalesController =
      TextEditingController();
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
    // Asegúrate de que los listeners para los dropdowns también llamen a _validateForm
  }

  Future<void> _pickImage(ImageSource source, bool isFotoPersona) async {
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
  // ... existing code ...
  void _validateForm() {
    final nombresValido = _validarNombres(_nombresController.text) == null;
    final apellidosValido =
        _validarApellidos(_apellidosController.text) == null;
    final dniValido = _validarDNI(_dniController.text) == null;
    final telefonoValido =
        _validarTelefono(_telefonoContactoController.text) == null;
    final fotoSeleccionada = _fotoFile != null;
    final imagenFichaSeleccionada = _imagenFichaFile != null;
    final fechaSeleccionada = _fechaDesaparicionController.text.isNotEmpty;
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
          fechaSeleccionada &&
          selectedDepartamento != null &&
          selectedProvincia != null &&
          selectedDistrito != null;
    });
  }
  // ... existing code ...
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

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'), // Cambia el idioma a español
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd', 'es_ES').format(picked);
        _validateForm(); // Valida el formulario después de seleccionar la fecha
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
        nombres: _nombresController.text.trim(),
        apellidos: _apellidosController.text.trim(),
        sexo: _sexo,
        dni:
            _dniController.text.trim().isEmpty
                ? null
                : _dniController.text.trim(),
        telefonoContacto:
            _telefonoContactoController.text.trim().isEmpty
                ? null
                : _telefonoContactoController.text.trim(),
        fechaDesaparicion:
            _fechaDesaparicionController.text.isNotEmpty
                ? DateFormat(
                  'yyyy-MM-dd',
                ).parse(_fechaDesaparicionController.text)
                : null,
        departamento: departamentoNombre,
        provincia: provinciaNombre,
        distrito: distritoNombre,
        detallesAdicionales:
            _detallesAdicionalesController.text.trim().isEmpty
                ? null
                : _detallesAdicionalesController.text.trim(),
        fechaCreacion: DateTime.now(),
        fechaActualizacion: DateTime.now(),
        // No pases fotoUrl ni imagenFichaUrl aquí si el ViewModel los va a generar
      );

      // Llamar al ViewModel para guardar y subir imágenes
      await _viewModel.reportDesaparecidoConImagenes(
        desaparecido,
        _fotoFile,
        _imagenFichaFile,
      );
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
          title: const Text('Seleccionar Fuente de Imagen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Cámara'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(
                    ImageSource.camera,
                    isFotoPersona,
                  ); // Pasa el parámetro
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(
                    ImageSource.gallery,
                    isFotoPersona,
                  ); // Pasa el parámetro
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
        body: Stack(
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
                      decoration: const InputDecoration(
                        labelText: 'Nombres *',
                        hintText: 'Ingrese los nombres (máx. 3)',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validarNombres,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => _validateForm(),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 16.0),

                    // --- CAMPO APELLIDOS (Ya tiene autovalidateMode) ---
                    TextFormField(
                      controller: _apellidosController,
                      decoration: const InputDecoration(
                        labelText: 'Apellidos *',
                        hintText: 'Ingrese los dos apellidos',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validarApellidos,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => _validateForm(),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 16.0),

                    // --- CAMPO DNI ---
                    TextFormField(
                      controller: _dniController,
                      decoration: InputDecoration(
                        labelText: 'DNI (8 dígitos)*',
                        border: const OutlineInputBorder(),
                        errorStyle: const TextStyle(
                          color: Colors.red, // Color del mensaje de error
                          fontSize: 12, // Tamaño del texto del error
                        ),
                        errorBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color:
                                Colors.red, // Color del borde cuando hay error
                            width: 2.0,
                          ),
                        ),
                        focusedErrorBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color:
                                Colors
                                    .red, // Color del borde mientras está enfocado y hay error
                            width: 2.0,
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.number, // Solo números
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
                        border: const OutlineInputBorder(),
                        errorStyle: const TextStyle(
                          color: Colors.red,
                        ), // Mensajes de error en rojo
                        errorBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ), // Borde rojo cuando hay error
                        focusedErrorBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 2.0),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        // <-- AÑADIR INPUT FORMATTERS
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(
                          9,
                        ), // Limita a 9 dígitos
                      ],
                      validator: _validarTelefono, // Valida Teléfono
                      onChanged: (value) {
                        setState(() {
                          _validateForm(); // Valida mientras el usuario escribe
                        });
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        // labelText: 'Sexo*', // LÍNEA ANTERIOR
                        labelText: 'Género*', // LÍNEA CORREGIDA
                        border: OutlineInputBorder(),
                      ),
                      value: _sexo, // Valor actual de la selección
                      items: const [
                        DropdownMenuItem(
                          value: 'Masculino',
                          child: Text('Masculino'),
                        ),
                        DropdownMenuItem(
                          value: 'Femenino',
                          child: Text('Femenino'),
                        ),
                        // Puedes añadir más opciones si es necesario
                        // DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          // return 'Por favor, seleccione el sexo.'; // MENSAJE ANTERIOR
                          return 'Por favor, seleccione el género.'; // MENSAJE CORREGIDO
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          _sexo = value; // Actualiza el valor
                        });
                        _validateForm(); // <-- AÑADE ESTA LÍNEA para revalidar el formulario
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 16.0),

                    // --- Selección de Fecha ---
                    TextFormField(
                      controller: _fechaDesaparicionController,
                      decoration: const InputDecoration(
                        labelText: 'Fecha de Desaparición*',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap:
                          () => _selectDate(
                            context,
                            _fechaDesaparicionController,
                          ),
                      readOnly: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingrese la fecha de desaparición.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    // Dropdown para Departamentos
                    // Modifica los DropdownButtonFormField agregando estos estilos:
                    DropdownButtonFormField<String>(
                      value: selectedDepartamento,
                      decoration: InputDecoration(
                        labelText: 'Departamento *',
                        labelStyle: TextStyle(
                          color: Colors.black,
                        ), // Color del label
                        hintText: 'Seleccione departamento',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                        ), // Color del hint
                        border: OutlineInputBorder(),
                      ),
                      items:
                          departamentos.map((departamento) {
                            return DropdownMenuItem<String>(
                              value: departamento['id'],
                              child: Text(
                                departamento['name'],
                                style: TextStyle(
                                  color: Colors.black,
                                ), // Color del texto
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedDepartamento = value;
                          _loadProvincias(value!);
                          _validateForm();
                        });
                      },
                      validator:
                          (value) =>
                              value == null
                                  ? 'Seleccione un departamento'
                                  : null,
                      style: TextStyle(
                        color: Colors.black,
                      ), // Color del texto seleccionado
                    ),

                    // Aplica el mismo estilo a los otros DropdownButtonFormField (provincia y distrito)
                    if (provincias.isNotEmpty) ...[
                      // Use collection if for cleaner conditional rendering
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Seleccionar Provincia',
                          border: OutlineInputBorder(),
                        ),
                        value: selectedProvincia,
                        items:
                            provincias.map((prov) {
                              return DropdownMenuItem<String>(
                                value: prov['id'] ?? '',
                                child: Text(prov['name'] ?? 'Sin nombre'),
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
                            // _provincia = value; // <-- ELIMINA ESTA LÍNEA
                            _validateForm();
                          });
                          if (value != null &&
                              value.isNotEmpty &&
                              value != previousSelection) {
                            _loadDistritos(value);
                          }
                        },
                      ),
                      const SizedBox(height: 16.0), // Add spacing
                    ],

                    // Dropdown para Distritos
                    if (distritos.isNotEmpty) ...[
                      // Use collection if
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Seleccionar Distrito',
                          border: OutlineInputBorder(),
                        ),
                        value: selectedDistrito,
                        items:
                            distritos.map((dist) {
                              return DropdownMenuItem<String>(
                                value: dist['id'] ?? '',
                                child: Text(dist['name'] ?? 'Sin nombre'),
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
                            _validateForm();
                          });
                        },
                      ),
                      const SizedBox(height: 16.0), // Add spacing
                    ],

                    TextFormField(
                      controller: _detallesAdicionalesController,
                      decoration: const InputDecoration(
                        labelText: 'Detalles Adicionales (Opcional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        setState(() {
                          // No requiere validación en tiempo real
                        });
                      },
                    ),
                    const SizedBox(height: 16.0),
                    // --- BOTÓN PARA FOTO DE LA PERSONA ---
                    ElevatedButton(
                      onPressed: () => _showImageSourceDialog(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _fotoFile == null
                                ? Colors
                                    .grey[200] // Fondo gris claro cuando no hay imagen
                                : Theme.of(context).primaryColor,
                        foregroundColor:
                            _fotoFile == null
                                ? Colors
                                    .black87 // Texto oscuro cuando no hay imagen
                                : Colors
                                    .white, // Texto blanco cuando hay imagen seleccionada
                        padding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                      child: Text(
                        _fotoFile == null
                            ? 'Seleccionar Foto *'
                            : 'Foto Seleccionada',
                      ),
                    ),
                    SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: () => _showImageSourceDialog(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _imagenFichaFile == null
                                ? Colors
                                    .grey[200] // Fondo gris claro cuando no hay imagen
                                : Theme.of(context).primaryColor,
                        foregroundColor:
                            _imagenFichaFile == null
                                ? Colors
                                    .black87 // Texto oscuro cuando no hay imagen
                                : Colors
                                    .white, // Texto blanco cuando hay imagen seleccionada
                        padding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                      child: Text(
                        _imagenFichaFile == null
                            ? 'Seleccionar Ficha *'
                            : 'Ficha Seleccionada',
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    const SizedBox(height: 32.0),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: ElevatedButton(
                        onPressed:
                            _isGuardarActivo && !_isLoading
                                ? _guardarReporte
                                : null, // Deshabilitado si está cargando o el formulario no es válido
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isGuardarActivo ? null : Colors.grey,
                        ),
                        child:
                            _isLoading
                                ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                )
                                : const Text('Guardar Reporte'),
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
