// lib/presentation/police/screens/add_missing_screen.dart
import 'dart:io';
import 'package:alerta_desaparecidos/helpers/database_helpers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../domain/entities/desaparecido.dart';
import '../../../common/state_enum.dart';
import '../view_models/add_missing_view_model.dart';

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

  String? selectedDepartamento;
  String? selectedProvincia;
  String? selectedDistrito;

  bool _isLoading = false; // Estado de carga inicializado como falso

  final DatabaseHelper dbHelper = DatabaseHelper();

  final TextEditingController _nombreCompletoController =
      TextEditingController();
  final TextEditingController _dniController = TextEditingController();
  String? _sexo;
  final TextEditingController _telefonoContactoController =
      TextEditingController();
  final TextEditingController _fechaDesaparicionController =
      TextEditingController();
  final TextEditingController _detallesAdicionalesController =
      TextEditingController();
  final TextEditingController _fotoUrlController = TextEditingController();
  File? _fotoFile;
  String? _fotoUrl;
  final TextEditingController _imagenFichaUrlController =
      TextEditingController();
  File? _imagenFichaFile;
  String? _imagenFichaUrl;
  bool _isGuardarActivo = false;

  final TextEditingController _searchController = TextEditingController();
  String? _departamento; // Nuevo campo
  String? _provincia;    // Nuevo campo
  String? _distrito;     // Nuevo campo

  @override
  void initState() {
    super.initState();

    _loadDepartamentos();

    // Listeners para los controladores del formulario
    _nombreCompletoController.addListener(_validateForm);
    _dniController.addListener(_validateForm);
    _telefonoContactoController.addListener(_validateForm);
    _fotoUrlController.addListener(_validateForm);
    _imagenFichaUrlController.addListener(_validateForm);
  }

  void _loadDepartamentos() async {
    final data = await dbHelper.getDepartamentos();
    setState(() {
      departamentos = data;
    });
  }

  void _loadProvincias(String departamentoId) async { // Cambiado a String
    final data = await dbHelper.getProvincias(departamentoId); // Ahora pasa String
    setState(() {
      provincias = data;
      distritos = [];
      selectedProvincia = null;
      selectedDistrito = null;
    });
  }

  void _loadDistritos(String provinciaId) async { // Cambiado a String
    final data = await dbHelper.getDistritos(provinciaId); // Ahora pasa String
    setState(() {
      distritos = data;
      selectedDistrito = null;
    });
  }

  void _validateForm() {
    final nombreCompletoValido = _validarNombreCompleto(_nombreCompletoController.text) == null;
    final dniValido = _validarDNI(_dniController.text) == null;
    final telefonoValido = _validarTelefono(_telefonoContactoController.text) == null;
    final fotoUrlValido = _fotoUrlController.text.isNotEmpty;
    final imagenFichaUrlValido = _imagenFichaUrlController.text.isNotEmpty;

    print('nombreCompletoValido: $nombreCompletoValido');
    print('dniValido: $dniValido');
    print('telefonoValido: $telefonoValido');
    print('_sexo: $_sexo');
    print('_departamento: $_departamento');
    print('_provincia: $_provincia');
    print('_distrito: $_distrito');
    print('fotoUrlValido: $fotoUrlValido');
    print('imagenFichaUrlValido: $imagenFichaUrlValido');
    print('Fecha desaparición: ${_fechaDesaparicionController.text}');
    print('_isGuardarActivo: $_isGuardarActivo');

    setState(() {
      _isGuardarActivo =
          nombreCompletoValido &&
              dniValido &&
              telefonoValido &&
              _sexo != null &&
              fotoUrlValido &&
              imagenFichaUrlValido &&
              _fechaDesaparicionController.text.isNotEmpty &&
              _departamento != null &&
              _provincia != null &&
              _distrito != null;
    });
  }

  String? _validarNombreCompleto(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre completo es obligatorio.';
    }

    final partes = value.trim().split(' ');
    final nombreCount = partes.where((p) => p.isNotEmpty).length - 2;
    final apellidoCount = partes.where((p) => p.isNotEmpty).length;

    print('Nombre Count: $nombreCount, Apellido Count: $apellidoCount'); // Depuración

    if (apellidoCount < 2 || nombreCount > 3) {
      return 'Ingrese hasta 3 nombres y exactamente 2 apellidos.';
    }

    return null;
  }

  String? _validarDNI(String? value) {
    if (value == null || value.isEmpty) {
      return 'El DNI es obligatorio.';
    }

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

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
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

  Future<void> _seleccionarFoto(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _fotoFile = File(pickedFile.path); // Almacena el archivo seleccionado
      });
    }
  }

  Future<void> _seleccionarImagenFicha(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _imagenFichaFile = File(pickedFile.path); // Almacena el archivo seleccionado
      });
    }
  }

  Future<void> _subirFoto(File file) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'desaparecidos/fotos/${DateTime.now().millisecondsSinceEpoch}',
      );
      final uploadTask = storageRef.putFile(file);
      await uploadTask.whenComplete(() => null);
      final downloadUrl = await storageRef.getDownloadURL();
      setState(() {
        _fotoUrl = downloadUrl; // Asigna la URL específica para la foto
        _validateForm(); // Valida el formulario después de subir
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir la foto: $e')),
      );
    }
  }

  Future<void> _subirImagenFicha(File file) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'desaparecidos/imagenes_ficha/${DateTime.now().millisecondsSinceEpoch}',
      );
      final uploadTask = storageRef.putFile(file);
      await uploadTask.whenComplete(() => null);
      final downloadUrl = await storageRef.getDownloadURL();
      setState(() {
        _imagenFichaUrl = downloadUrl; // Asigna la URL específica para la imagen de ficha
        _validateForm(); // Valida el formulario después de subir
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir la imagen de ficha: $e')),
      );
    }
  }

  Future<void> _guardarReporte() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // Muestra el estado de "cargando"
      });

      try {
        // Subir imágenes seleccionadas a Firebase Storage
        final fotoUrl = await _subirImagen(
          _fotoFile,
          'desaparecidos/fotos/${DateTime.now().millisecondsSinceEpoch}',
        );

        final imagenFichaUrl = await _subirImagen(
          _imagenFichaFile,
          'desaparecidos/imagenes_ficha/${DateTime.now().millisecondsSinceEpoch}',
        );

        // Crear objeto Desaparecido con URLs de las imágenes subidas
        final desaparecido = Desaparecido(
          nombreCompleto: _nombreCompletoController.text.trim(),
          sexo: _sexo,
          dni: _dniController.text.trim(),
          telefonoContacto: _telefonoContactoController.text.trim(),
          fechaDesaparicion: DateTime.parse(_fechaDesaparicionController.text),
          departamento: selectedDepartamento != null
              ? departamentos.firstWhere((dep) => dep['id'] == selectedDepartamento)['name']
              : null,
          provincia: selectedProvincia != null
              ? provincias.firstWhere((prov) => prov['id'] == selectedProvincia)['name']
              : null,
          distrito: selectedDistrito != null
              ? distritos.firstWhere((dist) => dist['id'] == selectedDistrito)['name']
              : null,
          detallesAdicionales: _detallesAdicionalesController.text.trim(),
          fotoUrl: fotoUrl,
          imagenFichaUrl: imagenFichaUrl,
          fechaCreacion: DateTime.now(),
          fechaActualizacion: DateTime.now(),
        );

        // Guardar en Firestore
        await Provider.of<AddMissingViewModel>(context, listen: false).reportDesaparecido(desaparecido);

        setState(() {
          _isLoading = false; // Oculta el estado de "cargando"
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Reporte guardado exitosamente.'),
        ));
      } catch (e) {
        // Si ocurre un error, desactiva el estado de "cargando" y muestra un mensaje
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar el reporte: $e'),
        ));
      }
    } else {
      // Si el formulario no es válido, muestra un mensaje
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Por favor, complete todos los campos obligatorios correctamente.'),
      ));
    }
  }

  Future<String?> _subirImagen(File? file, String path) async {
    if (file == null) return null; // Retorna null si no hay archivo
    try {
      final storageRef = FirebaseStorage.instance.ref().child(path);
      final uploadTask = storageRef.putFile(file);
      await uploadTask.whenComplete(() => null);
      return await storageRef.getDownloadURL(); // Retorna la URL generada
    } catch (e) {
      print('Error al subir la imagen: $e');
      return null; // Retorna null si ocurre un error
    }
  }

  Future<bool> _onWillPop(BuildContext context) async {
    if (_fotoUrl != null) {
      try {
        await FirebaseStorage.instance.refFromURL(_fotoUrl!).delete();
      } catch (e) {
        print("Error al eliminar foto al ir atrás: $e");
      }
    }
    if (_imagenFichaUrl != null) {
      try {
        await FirebaseStorage.instance.refFromURL(_imagenFichaUrl!).delete();
      } catch (e) {
        print("Error al eliminar imagen de ficha al ir atrás: $e");
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => _onWillPop(context),
      child: Scaffold(
        appBar: AppBar(title: const Text('Reportar Desaparecido')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextFormField(
                  controller: _nombreCompletoController,
                  decoration: InputDecoration(
                    labelText: 'Nombre Completo (máx. 3 nombres, 2 apellidos)*',
                    border: const OutlineInputBorder(),
                    errorStyle: const TextStyle(color: Colors.red), // Mensajes de error en rojo
                    errorBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2.0),
                    ), // Borde en rojo cuando hay error
                    focusedErrorBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2.0),
                    ),
                  ),
                  validator: _validarNombreCompleto, // Función de validación
                  onChanged: (value) {
                    setState(() {
                      _validateForm(); // Valida en tiempo real
                    });
                  },
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _dniController,
                  decoration: InputDecoration(
                    labelText: 'DNI (8 dígitos)*',
                    border: const OutlineInputBorder(),
                    errorStyle: const TextStyle(color: Colors.red), // Mensajes de error en rojo
                    errorBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2.0),
                    ), // Borde rojo cuando hay error
                    focusedErrorBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2.0),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: _validarDNI, // Valida DNI
                  onChanged: (value) {
                    setState(() {
                      _validateForm(); // Valida mientras el usuario escribe
                    });
                  },
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _telefonoContactoController,
                  decoration: InputDecoration(
                    labelText: 'Teléfono Contacto (9 dígitos)*',
                    border: const OutlineInputBorder(),
                    errorStyle: const TextStyle(color: Colors.red), // Mensajes de error en rojo
                    errorBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2.0),
                    ), // Borde rojo cuando hay error
                    focusedErrorBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2.0),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: _validarTelefono, // Valida Teléfono
                  onChanged: (value) {
                    setState(() {
                      _validateForm(); // Valida mientras el usuario escribe
                    });
                  },
                ),
                const SizedBox(height: 16.0),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Sexo*',
                    border: OutlineInputBorder(),
                  ),
                  value: _sexo, // Valor actual de la selección
                  items: const [
                    DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                    DropdownMenuItem(value: 'Femenino', child: Text('Femenino')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, seleccione el sexo.';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      _sexo = value; // Actualiza el valor de sexo
                    });
                    _validateForm(); // Valida el formulario tras la actualización
                  },
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _fechaDesaparicionController,
                  decoration: const InputDecoration(
                    labelText: 'Fecha de Desaparición*',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap:
                      () => _selectDate(context, _fechaDesaparicionController),
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
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Seleccionar Departamento',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedDepartamento, // Verifica que sea String? (nullable)
                  items: departamentos.map((dep) {
                    return DropdownMenuItem<String>(
                      value: dep['id'] ?? '', // Usa un string vacío si `id` es nulo
                      child: Text(dep['name'] ?? 'Sin nombre'), // Usa texto predeterminado si `nombre` es nulo
                    );
                  }).toList(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, seleccione un departamento.';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      selectedDepartamento = value; // Actualiza el estado local
                      _departamento = value; // Actualiza la variable utilizada en la validación
                    });
                    _loadProvincias(value ?? ''); // Carga las provincias basadas en el departamento seleccionado
                    _validateForm(); // Valida el formulario
                  },
                ),

// Dropdown para Provincias
                if (provincias.isNotEmpty)
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Seleccionar Provincia',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedProvincia,
                    items: provincias.map((prov) {
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
                    onChanged: (value) {
                      setState(() {
                        selectedProvincia = value; // Actualiza la selección local
                        _provincia = value; // Actualiza la variable global para validar
                      });
                      _loadDistritos(value ?? ''); // Carga los distritos relacionados
                      _validateForm(); // Valida el formulario
                    },
                  ),

// Dropdown para Distritos
                if (distritos.isNotEmpty)
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Seleccionar Distrito',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedDistrito,
                    items: distritos.map((dist) {
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
                    onChanged: (value) {
                      setState(() {
                        selectedDistrito = value; // Actualiza la selección local
                        _distrito = value; // Actualiza la variable global para validar
                      });
                      _validateForm(); // Valida el formulario
                    },
                  ),
                const SizedBox(height: 16.0),
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
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _seleccionarFoto(ImageSource.gallery), // Llama al método específico
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'URL de la Foto*',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.image),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Text(
                                  _fotoUrlController.text.isNotEmpty
                                      ? 'Foto seleccionada'
                                      : 'Seleccionar foto',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _seleccionarImagenFicha(ImageSource.gallery), // Llama al método específico
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'URL de la Imagen de Ficha*',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.image_search),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Text(
                                  _imagenFichaUrlController.text.isNotEmpty
                                      ? 'Imagen de ficha seleccionada'
                                      : 'Seleccionar imagen de ficha',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32.0),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ElevatedButton(
                    onPressed: _isGuardarActivo && !_isLoading
                        ? _guardarReporte
                        : null, // Deshabilitado si está cargando o el formulario no es válido
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isGuardarActivo ? null : Colors.grey,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                        : const Text('Guardar Reporte'),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Consumer<AddMissingViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.state == RequestState.Loading) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (viewModel.state == RequestState.Loaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Reporte de desaparecido guardado exitosamente.',
                    ),
                  ),
                );
                Navigator.pop(context);
                viewModel.resetState();
              });
              return const SizedBox.shrink();
            } else if (viewModel.state == RequestState.Error) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(viewModel.message)));
                viewModel.resetState();
              });
              return const SizedBox.shrink();
            } else {
              return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }
}
