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
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ubicacionController,
                            decoration: const InputDecoration(
                              labelText: 'Ubicación de Desaparición *',
                              border: OutlineInputBorder(),
                            ),
                            readOnly: true,
                            validator: (value) {
                              if (_ubicacionDesaparicion == null) {
                                return 'Por favor, seleccione la ubicación de desaparición.';
                              }
                              return null;
                            },
                            onChanged:
                                (value) =>
                                    viewModel.ubicacionDesaparicion =
                                        _ubicacionDesaparicion,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        IconButton(
                          icon: Icon(
                            _isLocating ? Icons.location_searching : Icons.map,
                          ),
                          onPressed: _isLocating ? null : _getCurrentLocation,
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
                      onPressed:
                          viewModel.reportState == RequestState.Loading
                              ? null
                              : () {
                                if (_formKey.currentState!.validate()) {
                                  final desaparecido = Desaparecido(
                                    nombreCompleto:
                                        _nombreCompletoController.text,
                                    sexo: _sexo!,
                                    dni:
                                        _dniController.text.isNotEmpty
                                            ? _dniController.text
                                            : null,
                                    telefonoContacto:
                                        _telefonoContactoController
                                                .text
                                                .isNotEmpty
                                            ? _telefonoContactoController.text
                                            : null,
                                    fechaDesaparicion: _fechaDesaparicion!,
                                    ubicacionDesaparicion:
                                        _ubicacionDesaparicion!,
                                    detallesAdicionales:
                                        _detallesAdicionalesController
                                                .text
                                                .isNotEmpty
                                            ? _detallesAdicionalesController
                                                .text
                                            : null,
                                    fotoUrl:
                                        _fotoUrlController.text.isNotEmpty
                                            ? _fotoUrlController.text
                                            : null,
                                    imagenFichaUrl:
                                        _imagenFichaUrlController
                                                .text
                                                .isNotEmpty
                                            ? _imagenFichaUrlController.text
                                            : null,
                                    fechaCreacion: DateTime.now(),
                                    fechaActualizacion: DateTime.now(),
                                    estado:
                                        EstadoDesaparecido.activo
                                            .toString(), // Convertir a String
                                  );
                                  viewModel.reportDesaparecido(desaparecido);
                                }
                              },
                      child:
                          viewModel.reportState == RequestState.Loading
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
