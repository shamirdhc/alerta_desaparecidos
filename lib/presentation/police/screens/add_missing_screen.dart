// lib/presentation/police/screens/add_missing_screen.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
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
  final TextEditingController _nombreCompletoController =
      TextEditingController();
  final TextEditingController _dniController = TextEditingController();
  String? _sexo;
  final TextEditingController _telefonoContactoController =
      TextEditingController();
  final TextEditingController _fechaDesaparicionController =
      TextEditingController();
  final TextEditingController _ubicacionDesaparicionController =
      TextEditingController();
  LatLng? _ubicacionSeleccionada;
  String _ubicacionTexto = '';
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
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  LatLng _initialCameraPosition = const LatLng(
    -12.0464,
    -77.0428,
  ); // Posición inicial por defecto
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Listeners para los controladores del formulario
    _nombreCompletoController.addListener(_validateForm);
    _dniController.addListener(_validateForm);
    _telefonoContactoController.addListener(_validateForm);
    _fotoUrlController.addListener(_validateForm);
    _imagenFichaUrlController.addListener(_validateForm);

    // Solicitar permisos antes de obtener la ubicación actual
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _solicitarPermisos()
          .then((_) {
            _obtenerUbicacionActual();
          })
          .catchError((e) {
            print('Error al solicitar permisos: $e');
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: $e')));
          });
    });
  }

  Future<void> _obtenerUbicacionActual() async {
    setState(() {
      // Puedes mostrar un indicador de carga aquí si lo deseas
    });
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _initialCameraPosition = LatLng(position.latitude, position.longitude);
      _moverCamara(_initialCameraPosition);
    } catch (e) {
      print("Error al obtener la ubicación actual: $e");
      // Manejar el error (ej. mostrar un mensaje al usuario)
    } finally {
      setState(() {
        // Ocultar el indicador de carga si lo mostraste
      });
    }
  }

  void _moverCamara(LatLng latLng) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
  }

  Future<void> _solicitarPermisos() async {
    LocationPermission permiso = await Geolocator.checkPermission();

    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        throw Exception('Los permisos de ubicación fueron denegados.');
      }
    }

    if (permiso == LocationPermission.deniedForever) {
      throw Exception(
        'Los permisos de ubicación fueron denegados permanentemente. Por favor, habilítelos desde la configuración.',
      );
    }
  }

  void _validateForm() {
    final nombreCompletoValido =
        _validarNombreCompleto(_nombreCompletoController.text) == null;
    final dniValido = _validarDNI(_dniController.text) == null;
    final telefonoValido =
        _validarTelefono(_telefonoContactoController.text) == null;
    final fotoUrlValido = _fotoUrlController.text.isNotEmpty;
    final imagenFichaUrlValido = _imagenFichaUrlController.text.isNotEmpty;

    setState(() {
      _isGuardarActivo =
          nombreCompletoValido &&
          dniValido &&
          telefonoValido &&
          _sexo != null &&
          _ubicacionSeleccionada != null &&
          fotoUrlValido &&
          imagenFichaUrlValido &&
          _fechaDesaparicionController.text.isNotEmpty;
    });
  }

  String? _validarNombreCompleto(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre completo es obligatorio.';
    }

    final partes = value.trim().split(' ');
    final nombreCount =
        partes.where((p) => p.isNotEmpty).length - 2; // Cantidad de nombres
    final apellidoCount =
        partes.where((p) => p.isNotEmpty).length; // Cantidad de apellidos

    if (apellidoCount < 2 || nombreCount > 3) {
      return 'Ingrese hasta 3 nombres y exactamente 2 apellidos.';
    }

    return null; // Validación exitosa
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

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
        _validateForm();
      });
    }
  }

  Future<void> _seleccionarUbicacion(BuildContext context) async {
    final LatLng? selectedLocation = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => _MapaSeleccionUbicacion()),
    );

    if (selectedLocation != null) {
      setState(() {
        _ubicacionSeleccionada = selectedLocation;
        _obtenerDireccion(_ubicacionSeleccionada!);
        _validateForm();
      });
    }
  }

  Future<void> _obtenerDireccion(LatLng latLng) async {
    try {
      final geocodingInstance = GeocodingPlatform.instance;
      if (geocodingInstance == null) {
        throw Exception('GeocodingPlatform.instance no está inicializado.');
      }

      // Configura el identificador de idioma y región
      await geocodingInstance.setLocaleIdentifier('es_PE');

      // Obtén los datos de la dirección basados en las coordenadas
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          _ubicacionTexto =
              '${p.administrativeArea ?? ''}/'
              '${p.subAdministrativeArea ?? ''}/'
              '${p.locality ?? ''}/'
              '${p.street ?? p.name ?? ''}';
          _ubicacionDesaparicionController.text = _ubicacionTexto;
        });
      } else {
        setState(() {
          _ubicacionDesaparicionController.text = 'Ubicación seleccionada';
        });
      }
    } catch (e) {
      setState(() {
        _ubicacionDesaparicionController.text = 'Error al obtener la dirección';
      });
      print("Error al obtener la dirección: $e");
    }
  }

  Future<void> _seleccionarImagen(
    ImageSource source,
    TextEditingController controller,
    Function(File?) setFile,
    Function(String?) setUrl,
  ) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setFile(File(pickedFile.path));
      _subirImagen(File(pickedFile.path), controller, setUrl);
    }
  }

  Future<void> _subirImagen(
    File file,
    TextEditingController controller,
    Function(String?) setUrl,
  ) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'desaparecidos/${DateTime.now().millisecondsSinceEpoch}',
      );
      final uploadTask = storageRef.putFile(file);
      await uploadTask.whenComplete(() => null);
      final downloadUrl = await storageRef.getDownloadURL();
      setState(() {
        controller.text = downloadUrl;
        setUrl(downloadUrl);
        _validateForm();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al subir la imagen: $e')));
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
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo (máx. 3 nombres, 2 apellidos)*',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validarNombreCompleto,
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _dniController,
                  decoration: const InputDecoration(
                    labelText: 'DNI (8 dígitos)*',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: _validarDNI,
                ),
                const SizedBox(height: 16.0),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Sexo*',
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
                      _validateForm();
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
                    labelText: 'Teléfono Contacto (9 dígitos)*',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: _validarTelefono,
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
                InkWell(
                  onTap: () => _seleccionarUbicacion(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Ubicación de Desaparición*',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.map),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            _ubicacionDesaparicionController.text.isNotEmpty
                                ? _ubicacionDesaparicionController.text
                                : 'Seleccionar ubicación en el mapa',
                          ),
                        ),
                      ],
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
                ),
                const SizedBox(height: 16.0),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap:
                            () => _seleccionarImagen(
                              ImageSource.gallery,
                              _fotoUrlController,
                              (file) => setState(() => _fotoFile = file),
                              (url) => setState(() => _fotoUrl = url),
                            ),
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
                        onTap:
                            () => _seleccionarImagen(
                              ImageSource.gallery,
                              _imagenFichaUrlController,
                              (file) => setState(() => _imagenFichaFile = file),
                              (url) => setState(() => _imagenFichaUrl = url),
                            ),
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
                    onPressed:
                        _isGuardarActivo
                            ? () {
                              if (_formKey.currentState!.validate()) {
                                final desaparecido = Desaparecido(
                                  nombreCompleto:
                                      _nombreCompletoController.text.trim(),
                                  sexo: _sexo,
                                  dni:
                                      _dniController.text.trim().isNotEmpty
                                          ? _dniController.text.trim()
                                          : null,
                                  telefonoContacto:
                                      _telefonoContactoController.text
                                              .trim()
                                              .isNotEmpty
                                          ? _telefonoContactoController.text
                                              .trim()
                                          : null,
                                  fechaDesaparicion: DateTime.parse(
                                    _fechaDesaparicionController.text,
                                  ),
                                  ubicacionDesaparicion:
                                      _ubicacionSeleccionada != null
                                          ? GeoPoint(
                                            _ubicacionSeleccionada!.latitude,
                                            _ubicacionSeleccionada!.longitude,
                                          )
                                          : null,
                                  detallesAdicionales:
                                      _detallesAdicionalesController.text
                                              .trim()
                                              .isNotEmpty
                                          ? _detallesAdicionalesController.text
                                              .trim()
                                          : null,
                                  fotoUrl: _fotoUrl,
                                  imagenFichaUrl: _imagenFichaUrl,
                                  fechaCreacion: DateTime.now(),
                                  fechaActualizacion: DateTime.now(),
                                );
                                Provider.of<AddMissingViewModel>(
                                  context,
                                  listen: false,
                                ).reportDesaparecido(desaparecido);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Por favor, complete todos los campos obligatorios correctamente.',
                                    ),
                                  ),
                                );
                              }
                            }
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isGuardarActivo ? null : Colors.grey,
                    ),
                    child: const Text('Guardar Reporte'),
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

class _MapaSeleccionUbicacion extends StatefulWidget {
  const _MapaSeleccionUbicacion();

  @override
  _MapaSeleccionUbicacionState createState() => _MapaSeleccionUbicacionState();
}

class _MapaSeleccionUbicacionState extends State<_MapaSeleccionUbicacion> {
  GoogleMapController? _mapController;
  LatLng? _ubicacionSeleccionada;
  LatLng _initialCameraPosition = const LatLng(
    -12.0464,
    -77.0428,
  ); // Posición inicial por defecto
  final TextEditingController _searchController = TextEditingController();
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();

    // Solicitar permisos antes de obtener la ubicación actual
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _solicitarPermisos()
          .then((_) {
            _obtenerUbicacionActual();
          })
          .catchError((e) {
            print('Error al solicitar permisos: $e');
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: $e')));
          });
    });
  }

  Future<void> _solicitarPermisos() async {
    LocationPermission permiso = await Geolocator.checkPermission();

    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        throw Exception('Los permisos de ubicación fueron denegados.');
      }
    }

    if (permiso == LocationPermission.deniedForever) {
      throw Exception(
        'Los permisos de ubicación fueron denegados permanentemente. Por favor, habilítelos desde la configuración.',
      );
    }
  }

  Future<void> _obtenerUbicacionActual() async {
    setState(() {
      // Puedes mostrar un indicador de carga aquí si lo deseas
    });
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _initialCameraPosition = LatLng(position.latitude, position.longitude);
      _moverCamara(_initialCameraPosition);
    } catch (e) {
      print("Error al obtener la ubicación actual: $e");
      // Manejar el error (ej. mostrar un mensaje al usuario)
    } finally {
      setState(() {
        // Ocultar el indicador de carga si lo mostraste
      });
    }
  }

  void _moverCamara(LatLng latLng) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
  }

  Future<void> _buscarUbicacion() async {
    if (_searchController.text.isNotEmpty) {
      try {
        // Obtén la instancia de GeocodingPlatform
        final geocodingInstance = GeocodingPlatform.instance;
        if (geocodingInstance == null) {
          throw Exception('GeocodingPlatform.instance no está inicializado.');
        }

        // Configura el identificador de idioma y región
        await geocodingInstance.setLocaleIdentifier('es_PE');

        // Busca la ubicación basándote en la dirección ingresada
        List<Location> locations = await locationFromAddress(
          _searchController.text,
        );

        if (locations.isNotEmpty) {
          // Mueve la cámara a la ubicación encontrada
          _moverCamara(
            LatLng(locations.first.latitude, locations.first.longitude),
          );
        } else {
          // Muestra un mensaje si no hay resultados
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontraron resultados para la búsqueda.'),
            ),
          );
        }
      } catch (e) {
        // Maneja errores y muestra un mensaje al usuario
        print("Error al buscar la ubicación: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al buscar la ubicación.')),
        );
      }
    }
  }

  void _agregarMarker(LatLng latLng) {
    setState(() {
      _ubicacionSeleccionada = latLng;
      _markers = {
        Marker(
          markerId: const MarkerId('ubicacion_seleccionada'),
          position: latLng,
        ),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar Ubicación')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar ubicación',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _buscarUbicacion,
                ),
              ),
            ),
          ),
          Expanded(
            child: GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(
                target: _initialCameraPosition,
                zoom: 12,
              ),
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              onTap: (LatLng latLng) {
                _agregarMarker(latLng);
              },
              markers: _markers,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed:
                  _ubicacionSeleccionada != null
                      ? () => Navigator.pop(context, _ubicacionSeleccionada)
                      : null,
              child: const Text('Seleccionar esta ubicación'),
            ),
          ),
        ],
      ),
    );
  }
}
