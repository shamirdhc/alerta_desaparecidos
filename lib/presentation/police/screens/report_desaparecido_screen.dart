import 'package:alerta_desaparecidos/helpers/database_helpers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alerta_desaparecidos/presentation/police/view_models/report_desaparecido_view_model.dart';
import 'package:alerta_desaparecidos/domain/use_cases/reportar_desaparicion_use_case.dart';
import 'package:alerta_desaparecidos/data/repositories/desaparecido_repository_impl.dart';
import 'package:alerta_desaparecidos/data/data_sources/desaparecido_remote_data_source.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alerta_desaparecidos/common/state_enum.dart';
import 'package:geolocator/geolocator.dart';
import 'package:alerta_desaparecidos/domain/entities/desaparecido.dart';
import 'package:alerta_desaparecidos/domain/enums.dart'; // Asegúrate de tener esta importación

class ReportDesaparecidoScreen extends StatefulWidget {
  const ReportDesaparecidoScreen({super.key});

  @override
  State<ReportDesaparecidoScreen> createState() =>
      _ReportDesaparecidoScreenState();
}

class _ReportDesaparecidoScreenState extends State<ReportDesaparecidoScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreCompletoController =
      TextEditingController();
  final TextEditingController _dniController = TextEditingController();
  String? _sexo;
  final TextEditingController _telefonoContactoController =
      TextEditingController();
  final TextEditingController _ubicacionController = TextEditingController();
  DateTime? _fechaDesaparicion;
  final TextEditingController _detallesAdicionalesController =
      TextEditingController();
  final TextEditingController _fotoUrlController = TextEditingController();
  final TextEditingController _imagenFichaUrlController =
      TextEditingController();
  GeoPoint? _ubicacionDesaparicion;
  bool _isLocating = false;

  List<Map<String, dynamic>> departamentos = [];
  List<Map<String, dynamic>> provincias = [];
  List<Map<String, dynamic>> distritos = [];

  String? selectedDepartamento; // ID del departamento seleccionado
  String? selectedProvincia; // ID de la provincia seleccionada
  String? selectedDistrito; // ID del distrito seleccionado

  final DatabaseHelper dbHelper = DatabaseHelper(); // Instancia del helper para la base de datos

  @override
  void initState() {
    super.initState();
    _loadDepartamentos(); // Cargar departamentos al iniciar la pantalla
  }

  void _loadDepartamentos() async {
    final data = await dbHelper.getDepartamentos(); // Consulta a la base de datos
    setState(() {
      departamentos = data;
    });
  }

  void _loadProvincias(String departamentoId) async { // Cambiado a String
    final data = await dbHelper.getProvincias(departamentoId); // Consulta a la base de datos
    setState(() {
      provincias = data;
      distritos = []; // Limpiar distritos al cambiar provincia
      selectedProvincia = null;
      selectedDistrito = null;
    });
  }

  void _loadDistritos(String provinciaId) async { // Cambiado a String
    final data = await dbHelper.getDistritos(provinciaId); // Consulta a la base de datos
    setState(() {
      distritos = data;
      selectedDistrito = null; // Limpiar distrito al cambiar provincia
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaDesaparicion ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _fechaDesaparicion = picked;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Los servicios de ubicación están desactivados.'),
        ),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permisos de ubicación denegados.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Los permisos de ubicación están permanentemente denegados.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLocating = true;
      _loadDepartamentos(); // Cargar departamentos al iniciar la pantalla
    });

    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _ubicacionDesaparicion = GeoPoint(
          position.latitude,
          position.longitude,
        );
        _ubicacionController.text =
            'Lat: ${position.latitude.toStringAsFixed(2)}, Lng: ${position.longitude.toStringAsFixed(2)}';
        _isLocating = false;
      });
    } catch (e) {
      setState(() {
        _isLocating = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener la ubicación: $e')),
        );
      });
    }
  }

  @override
  void dispose() {
    _nombreCompletoController.dispose();
    _dniController.dispose();
    _telefonoContactoController.dispose();
    _ubicacionController.dispose();
    _detallesAdicionalesController.dispose();
    _fotoUrlController.dispose();
    _imagenFichaUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final desaparecidoRemoteDataSource = DesaparecidoRemoteDataSource(
          FirebaseFirestore.instance,
        );
        final desaparecidoRepository = DesaparecidoRepositoryImpl(
          desaparecidoRemoteDataSource,
        );
        final reportarDesaparicionUseCase = ReportarDesaparicionUseCase(
          desaparecidoRepository,
        );
        return ReportDesaparecidoViewModel(reportarDesaparicionUseCase);
      },
      child: Consumer<ReportDesaparecidoViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: AppBar(title: const Text('Reportar Persona Desaparecida')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                      controller: _nombreCompletoController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre Completo *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingrese el nombre completo.';
                        }
                        return null;
                      },
                      onChanged: (value) => viewModel.nombreCompleto = value,
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _dniController,
                      decoration: const InputDecoration(
                        labelText: 'DNI (Opcional)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => viewModel.dni = value,
                    ),
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Sexo *',
                        border: OutlineInputBorder(),
                      ),
                      value: _sexo,
                      items:
                          <String>[
                            'Masculino',
                            'Femenino',
                          ].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _sexo = newValue;
                          viewModel.sexo = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, seleccione el sexo.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _telefonoContactoController,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono Contacto (Opcional)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      onChanged: (value) => viewModel.telefonoContacto = value,
                    ),
                    const SizedBox(height: 16.0),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ubicación de Desaparición *', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 8.0),
                        DropdownButtonFormField<String>( // Cambiado a String
                          decoration: const InputDecoration(
                            labelText: 'Seleccionar Departamento',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedDepartamento, // Ahora es String?
                          items: departamentos.map((dep) {
                            return DropdownMenuItem<String>( // Cambiado a String
                              value: dep['id'] as String, // Convertido explícitamente a String
                              child: Text(dep['nombre'] as String), // Convertido explícitamente a String
                            );
                          }).toList(),
                          validator: (value) {
                            if (value == null) {
                              return 'Por favor, seleccione un departamento.';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {
                              selectedDepartamento = value!; // String asignado correctamente
                              _loadProvincias(value); // String pasado al método
                            });
                          },
                        ),
                        const SizedBox(height: 16.0),
                        if (provincias.isNotEmpty)
                          DropdownButtonFormField<String>( // Cambiado a String
                            decoration: const InputDecoration(
                              labelText: 'Seleccionar Provincia',
                              border: OutlineInputBorder(),
                            ),
                            value: selectedProvincia, // Ahora es String?
                            items: provincias.map((prov) {
                              return DropdownMenuItem<String>( // Cambiado a String
                                value: prov['id'] as String, // Convertido explícitamente a String
                                child: Text(prov['nombre'] as String), // Convertido explícitamente a String
                              );
                            }).toList(),
                            validator: (value) {
                              if (value == null) {
                                return 'Por favor, seleccione una provincia.';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              setState(() {
                                selectedProvincia = value!; // String asignado correctamente
                                _loadDistritos(value); // String pasado al método
                              });
                            },
                          ),
                        const SizedBox(height: 16.0),
                        if (distritos.isNotEmpty)
                          DropdownButtonFormField<String>( // Cambiado a String
                            decoration: const InputDecoration(
                              labelText: 'Seleccionar Distrito',
                              border: OutlineInputBorder(),
                            ),
                            value: selectedDistrito, // Ahora es String?
                            items: distritos.map((dist) {
                              return DropdownMenuItem<String>( // Cambiado a String
                                value: dist['id'] as String, // Convertido explícitamente a String
                                child: Text(dist['nombre'] as String), // Convertido explícitamente a String
                              );
                            }).toList(),
                            validator: (value) {
                              if (value == null) {
                                return 'Por favor, seleccione un distrito.';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              setState(() {
                                selectedDistrito = value!; // String asignado correctamente
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha de Desaparición *',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _fechaDesaparicion == null
                              ? 'Seleccionar fecha'
                              : '${_fechaDesaparicion!.day}/${_fechaDesaparicion!.month}/${_fechaDesaparicion!.year}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _detallesAdicionalesController,
                      decoration: const InputDecoration(
                        labelText: 'Detalles Adicionales (Opcional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged:
                          (value) => viewModel.detallesAdicionales = value,
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _fotoUrlController,
                      decoration: const InputDecoration(
                        labelText: 'URL de la Foto (Opcional)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => viewModel.fotoUrl = value,
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _imagenFichaUrlController,
                      decoration: const InputDecoration(
                        labelText: 'URL de la Imagen de Ficha (Opcional)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => viewModel.imagenFichaUrl = value,
                    ),
                    const SizedBox(height: 24.0),
                    ElevatedButton(
                      onPressed: viewModel.reportState == RequestState.Loading
                          ? null
                          : () {
                        if (_formKey.currentState!.validate()) {
                          final desaparecido = Desaparecido(
                            nombreCompleto: _nombreCompletoController.text.trim(),
                            sexo: _sexo!,
                            dni: _dniController.text.isNotEmpty
                                ? _dniController.text.trim()
                                : null,
                            telefonoContacto: _telefonoContactoController.text.isNotEmpty
                                ? _telefonoContactoController.text.trim()
                                : null,
                            fechaDesaparicion: _fechaDesaparicion!,
                            departamento: selectedDepartamento != null
                                ? departamentos.firstWhere((dep) => dep['id'] == selectedDepartamento)['nombre']
                                : null,
                            provincia: selectedProvincia != null
                                ? provincias.firstWhere((prov) => prov['id'] == selectedProvincia)['nombre']
                                : null,
                            distrito: selectedDistrito != null
                                ? distritos.firstWhere((dist) => dist['id'] == selectedDistrito)['nombre']
                                : null,
                            detallesAdicionales: _detallesAdicionalesController.text.isNotEmpty
                                ? _detallesAdicionalesController.text.trim()
                                : null,
                            fotoUrl: _fotoUrlController.text.isNotEmpty
                                ? _fotoUrlController.text.trim()
                                : null,
                            imagenFichaUrl: _imagenFichaUrlController.text.isNotEmpty
                                ? _imagenFichaUrlController.text.trim()
                                : null,
                            fechaCreacion: DateTime.now(),
                            fechaActualizacion: DateTime.now(),
                            estado: EstadoDesaparecido.activo.toString(), // Convertir a String
                          );
                          viewModel.reportDesaparecido(desaparecido);
                        }
                      },
                      child: viewModel.reportState == RequestState.Loading
                          ? const CircularProgressIndicator()
                          : const Text('Guardar Reporte'),
                    ),
                    if (viewModel.reportState == RequestState.Error)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          viewModel.message,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (viewModel.reportState == RequestState.Loaded)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          viewModel.message,
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
