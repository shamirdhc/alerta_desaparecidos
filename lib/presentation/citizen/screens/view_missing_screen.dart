import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_missing_view_model.dart';
import 'package:alerta_desaparecidos/domain/entities/desaparecido.dart';
import 'package:alerta_desaparecidos/common/state_enum.dart';
import 'package:alerta_desaparecidos/helpers/database_helpers.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:alerta_desaparecidos/common/styles/custom_input_decoration.dart';
import 'found_person_details_screen.dart';
import 'missing_person_details_screen.dart';
import 'full_screen_image_screen.dart';

class ViewMissingScreen extends StatefulWidget {
  const ViewMissingScreen({super.key});

  @override
  State<ViewMissingScreen> createState() => _ViewMissingScreenState();
}

class _ViewMissingScreenState extends State<ViewMissingScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDepartamento;
  List<Map<String, dynamic>> _departamentosData = [];
  final ScrollController _scrollController = ScrollController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Agregar timer para debounce
  Timer? _debounceTimer;

  final String _fixedStatus = 'DESAPARECIDOS';

  // Enhanced color palettes for emotional context
  final List<Color> _departmentColors = [
    const Color(0xFFE3F2FD), // Light Blue
    const Color(0xFFEDE7F6), // Light Purple
    const Color(0xFFE8F5E9), // Light Green
    const Color(0xFFFFEBEE), // Light Red
    const Color(0xFFE0F2F1), // Light Teal
    const Color(0xFFFCE4EC), // Light Pink
    const Color(0xFFFFFDE7), // Light Yellow
    const Color(0xFFFFF3E0), // Light Orange
  ];

  // Enhanced gradient colors for missing persons
  List<Color> get _backgroundGradientColors {
    return [
      const Color(0xFFFFE5E5), // Very light red
      const Color(0xFFFFCCCC), // Light red
      const Color(0xFFFFB3B3), // Soft red - concern/worry
    ];
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _initializeScreen();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _animationController.forward();
  }

  Future<void> _initializeScreen() async {
    await _loadDepartamentos();
    if (mounted) {
      await _determineInitialDepartamento();
    }
  }

  Future<void> _determineInitialDepartamento() async {
    String? departamentoDetectadoPorGps;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('[GPS] PERMISO DE UBICACIÓN DENEGADO.');
      } else if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          String? gpsDeptName = place.administrativeArea;
          if (gpsDeptName != null && gpsDeptName.isNotEmpty) {
            departamentoDetectadoPorGps = gpsDeptName.toUpperCase();
            print(
              '[GPS] DEPARTAMENTO DETECTADO POR GPS: $departamentoDetectadoPorGps',
            );
          } else {
            print('[GPS] NO SE PUDO DETERMINAR EL DEPARTAMENTO DESDE GPS.');
          }
        } else {
          print('[GPS] NO SE PUDIERON OBTENER DETALLES DE LA UBICACIÓN.');
        }
      }
    } catch (e) {
      print('[GPS] ERROR AL OBTENER UBICACIÓN/DEPARTAMENTO GPS: $e');
    }

    if (!mounted) return;

    bool departamentoFueEstablecido = false;

    if (departamentoDetectadoPorGps != null && _departamentosData.isNotEmpty) {
      final match = _departamentosData.firstWhere(
        (d) =>
            (d['name'] as String?)?.toUpperCase() ==
            departamentoDetectadoPorGps,
        orElse: () => <String, dynamic>{},
      );

      if (match.isNotEmpty && match['name'] != null) {
        setState(() {
          _selectedDepartamento = match['name'] as String;
        });
        departamentoFueEstablecido = true;
        print(
          '[GPS] DEPARTAMENTO SELECCIONADO AUTOMÁTICAMENTE (POR GPS): $_selectedDepartamento',
        );
      } else {
        print(
          '[GPS] DEPARTAMENTO GPS "$departamentoDetectadoPorGps" NO ENCONTRADO EN LA LISTA LOCAL.',
        );
      }
    }

    if (!departamentoFueEstablecido && _departamentosData.isNotEmpty) {
      setState(() {
        // Por defecto seleccionar "Todos los departamentos"
        _selectedDepartamento = 'Todos los departamentos';
      });
      if (_selectedDepartamento != null) {
        departamentoFueEstablecido = true;
        print(
          '[GPS] DEPARTAMENTO SELECCIONADO AUTOMÁTICAMENTE (TODOS): $_selectedDepartamento',
        );
      }
    }

    if (_selectedDepartamento != null) {
      _fetchDataWithCurrentFilters();
    } else {
      print('[GPS] NO SE PUDO SELECCIONAR NINGÚN DEPARTAMENTO.');
      Provider.of<ViewMissingViewModel>(
        context,
        listen: false,
      ).getMissingPeople(
        forceRefresh: true,
        status: 'activo', // Para personas desaparecidas
      );
      _fetchDataWithCurrentFilters();
    }
  }

  @override
  void dispose() {
    // Cancelar timer pendiente
    _debounceTimer?.cancel();
    _animationController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      Provider.of<ViewMissingViewModel>(
        context,
        listen: false,
      ).loadMoreMissingPeople();
    }
  }

  void _fetchDataWithCurrentFilters() {
    // Normalizar el departamento a mayúsculas para que coincida con Firebase
    final String? departamentoParaFiltrar = _selectedDepartamento == 'Todos los departamentos' 
        ? null 
        : _selectedDepartamento?.toUpperCase(); // 🔧 CONVERSIÓN A MAYÚSCULAS
    
    final String statusParaFiltrar = _fixedStatus;
    final String? searchQuery = _searchController.text.trim().isEmpty
        ? null
        : _searchController.text.trim();

    print('🔧 [DEBUG] _fetchDataWithCurrentFilters llamado con:');
    print('   - departamento: $departamentoParaFiltrar');
    print('   - status: $statusParaFiltrar');
    print('   - searchQuery: "$searchQuery"');

    Provider.of<ViewMissingViewModel>(
      context,
      listen: false,
    ).getMissingPeople(
      forceRefresh: true,
      searchQuery: searchQuery,
      departamento: departamentoParaFiltrar, // Ahora será "APURÍMAC"
      status: statusParaFiltrar == 'DESAPARECIDOS' ? 'activo' : 'encontrado',
    );
  }

  void _onSearchChanged() {
    // Cancelar timer anterior si existe
    _debounceTimer?.cancel();
    
    // Crear nuevo timer con delay de 500ms
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _fetchDataWithCurrentFilters();
      }
    });
  }

  Future<void> _loadDepartamentos() async {
    try {
      final data = await _dbHelper.getDepartamentos();
      if (mounted) {
        setState(() {
          // Agregar la opción "Todos los departamentos" al inicio
          _departamentosData = [
            {'name': 'Todos los departamentos'},
            ...data
          ];
        });
      }
    } catch (e) {
      print('Error al cargar departamentos: $e');
      if (mounted) {
        setState(() {
          _departamentosData = [{'name': 'Todos los departamentos'}];
        });
      }
    }
  }

  void _onDepartamentoChanged(String? newValue) {
    setState(() {
      _selectedDepartamento = newValue;
    });
    _fetchDataWithCurrentFilters();
  }



  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ViewMissingViewModel>(context);
    final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _backgroundGradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Enhanced Header Section
                Container(
                  margin: const EdgeInsets.only(top: 16.0, bottom: 16.0),
                  padding: const EdgeInsets.all(20.0),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade700, Colors.red.shade900],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 15.0,
                        spreadRadius: 3.0,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Mensaje innovador y sensibilizador
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Icono principal
                            Container(
                              padding: const EdgeInsets.all(6.0),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.favorite,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Mensaje principal
                            Text(
                              'CADA BÚSQUEDA CUENTA',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.0,
                                shadows: [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 2,
                                    color: Colors.black26,
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            // Submensaje
                            Text(
                              'Tu participación puede ser la esperanza que una familia necesita',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.9),
                                fontStyle: FontStyle.italic,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            // Elementos decorativos
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 20,
                                  height: 1.5,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.visibility,
                                  color: Colors.white.withOpacity(0.8),
                                  size: 12,
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 20,
                                  height: 1.5,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(1),
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

                // Enhanced Filter Section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8.0,
                        spreadRadius: 1.0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Department filter
                      Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.0),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    _selectedDepartamento != null &&
                                            _departamentosData.indexWhere(
                                                  (d) =>
                                                      d['name'] ==
                                                      _selectedDepartamento,
                                                ) !=
                                                -1
                                        ? (_selectedDepartamento == 'Todos los departamentos'
                                            ? Colors.blue.shade600
                                            : _departmentColors[(_departamentosData
                                                        .indexWhere(
                                                          (d) =>
                                                              d['name'] ==
                                                              _selectedDepartamento,
                                                        ) - 1) %
                                                    _departmentColors.length])
                                            .withOpacity(0.3)
                                        : Colors.grey.withOpacity(0.2),
                                blurRadius: 8.0,
                                spreadRadius: 1.0,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color:
                                  _selectedDepartamento != null &&
                                          _departamentosData.indexWhere(
                                                (d) =>
                                                    d['name'] ==
                                                    _selectedDepartamento,
                                              ) !=
                                              -1
                                      ? (_selectedDepartamento == 'Todos los departamentos'
                                          ? Colors.blue.shade600
                                          : _departmentColors[(_departamentosData
                                                      .indexWhere(
                                                        (d) =>
                                                            d['name'] ==
                                                            _selectedDepartamento,
                                                      ) - 1) %
                                                  _departmentColors.length])
                                      : Colors.grey.shade400,
                              width: 2.0,
                            ),
                            color: _selectedDepartamento != null &&
                                    _departamentosData.indexWhere(
                                          (d) => d['name'] == _selectedDepartamento,
                                        ) !=
                                        -1
                                ? (_selectedDepartamento == 'Todos los departamentos'
                                    ? Colors.blue.shade600.withOpacity(0.1)
                                    : _departmentColors[(_departamentosData
                                                .indexWhere(
                                                  (d) =>
                                                      d['name'] ==
                                                      _selectedDepartamento,
                                                ) - 1) %
                                            _departmentColors.length].withOpacity(0.1))
                                : Colors.white,
                          ),
                        child: DropdownButtonFormField<String>(
                            decoration: getCustomDropdownDecoration(
                              context: context,
                              labelText: 'Departamento',
                              customFillColor: Colors.transparent,
                            ),
                          hint: const Center(
                            child: Text(
                              'DEPARTAMENTO',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          value: _selectedDepartamento,
                          isExpanded: true,
                          items:
                              _departamentosData.asMap().entries.map<
                                DropdownMenuItem<String>
                              >((entry) {
                                int index = entry.key;
                                Map<String, dynamic> depto = entry.value;
                                final String? deptoName =
                                    depto['name'] as String?;
                                
                                // Color especial para "Todos los departamentos"
                                Color itemBackgroundColor;
                                if (deptoName == 'Todos los departamentos') {
                                  itemBackgroundColor = Colors.blue.shade600;
                                } else {
                                  itemBackgroundColor = _departmentColors[(index - 1) %
                                      _departmentColors.length];
                                }
                                
                                Color itemTextColor =
                                    ThemeData.estimateBrightnessForColor(
                                              itemBackgroundColor,
                                            ) ==
                                            Brightness.dark
                                        ? Colors.white.withOpacity(0.9)
                                        : Colors.black.withOpacity(0.7);

                                return DropdownMenuItem<String>(
                                  value: deptoName,
                                  child: Container(
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12.0,
                                      horizontal: 10.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: itemBackgroundColor,
                                      borderRadius: BorderRadius.circular(
                                        8.0,
                                      ),
                                    ),
                                    child: Text(
                                      deptoName?.toUpperCase() ?? 'N/A',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: deptoName == 'Todos los departamentos'
                                            ? Colors.white
                                            : itemTextColor,
                                        fontSize: 15,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              }).toList(),
                          selectedItemBuilder: (BuildContext context) {
                            return _departamentosData.map<Widget>((
                              Map<String, dynamic> item,
                            ) {
                              final String? deptoName =
                                  item['name'] as String?;
                              int index = _departamentosData.indexWhere(
                                (d) => d['name'] == deptoName,
                              );

                              Color selectedBgColor;
                              if (deptoName == 'Todos los departamentos') {
                                selectedBgColor = Colors.blue.shade600;
                              } else if (index != -1 && index > 0) {
                                selectedBgColor = _departmentColors[(index - 1) %
                                    _departmentColors.length];
                              } else {
                                selectedBgColor = Colors.grey.shade200;
                              }
                              
                              Color selectedTextColor =
                                  ThemeData.estimateBrightnessForColor(
                                            selectedBgColor,
                                          ) ==
                                          Brightness.dark
                                      ? Colors.white.withOpacity(0.9)
                                      : Colors.black.withOpacity(0.7);

                              return Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selectedBgColor,
                                  borderRadius: BorderRadius.circular(
                                    8.0,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 8.0,
                                ),
                                child: Text(
                                  deptoName?.toUpperCase() ?? 'N/A',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: selectedTextColor,
                                    fontSize: 15,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList();
                          },
                          onChanged: _onDepartamentoChanged,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      // Enhanced search field
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8.0,
                              spreadRadius: 1.0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          inputFormatters: [UpperCaseTextFormatter()],
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre y/o apellidos...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.red.shade700,
                              size: 24,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                color: Colors.red.shade300,
                                width: 2.0,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                color: Colors.red.shade700,
                                width: 3.0,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 16.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8.0),

                // Enhanced content list
                Expanded(
                  child: Consumer<ViewMissingViewModel>(
                    builder: (context, vm, child) {
                      if (vm.state == RequestState.Loading &&
                          vm.desaparecidos.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.red.shade700,
                                ),
                                strokeWidth: 4.0,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Cargando información...',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      if (vm.state == RequestState.Error) {
                        return Center(
                          child: Container(
                            margin: const EdgeInsets.all(16.0),
                            padding: const EdgeInsets.all(20.0),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Error: ${vm.message}',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      if (vm.state != RequestState.Loading &&
                          vm.desaparecidos.isEmpty) {
                        String emptyMessage =
                            'NO HAY CASOS ACTIVOS REGISTRADOS.';
                        if (_searchController.text.isNotEmpty &&
                            _selectedDepartamento != null) {
                          emptyMessage =
                              'NO SE ENCONTRARON RESULTADOS PARA "${_searchController.text}" EN EL DEPARTAMENTO SELECCIONADO.';
                        } else if (_searchController.text.isNotEmpty) {
                          emptyMessage =
                              'NO SE ENCONTRARON RESULTADOS PARA "${_searchController.text}".';
                        } else if (_selectedDepartamento != null) {
                          emptyMessage =
                              'NO HAY CASOS ACTIVOS REGISTRADOS EN ESTE DEPARTAMENTO.';
                        }
                        return Center(
                          child: Container(
                            margin: const EdgeInsets.all(16.0),
                            padding: const EdgeInsets.all(24.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(16.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10.0,
                                  spreadRadius: 2.0,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  color: Colors.red.shade400,
                                  size: 64,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  emptyMessage,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        itemCount:
                            vm.desaparecidos.length +
                            (vm.isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == vm.desaparecidos.length) {
                            return vm.isLoadingMore
                                ? Container(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                )
                                : const SizedBox.shrink();
                          }

                          if (index < vm.desaparecidos.length) {
                            final desaparecido = vm.desaparecidos[index];
                            final bool isLastItem =
                                index == vm.desaparecidos.length - 1;

                            return Column(
                              children: [
                                _buildEnhancedMissingPersonCard(
                                  desaparecido,
                                  index + 1,
                                  vm.totalCount,
                                ),
                                if (!isLastItem && vm.desaparecidos.length > 1)
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 8.0,
                                    ),
                                    height: 1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Colors.red.withOpacity(0.3),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedMissingPersonCard(
    Desaparecido desaparecido,
    int currentIndex,
    int totalCount,
  ) {
    int? calcularEdad(DateTime? fechaNacimiento) {
      if (fechaNacimiento == null) return null;
      final hoy = DateTime.now();
      int edad = hoy.year - fechaNacimiento.year;
      if (hoy.month < fechaNacimiento.month ||
          (hoy.month == fechaNacimiento.month &&
              hoy.day < fechaNacimiento.day)) {
        edad--;
      }
      return edad;
    }

    final int? edadCalculada = calcularEdad(desaparecido.fechaNacimiento);
    final String nombreCompleto =
        '${desaparecido.nombres}, ${desaparecido.apellidos}'.toUpperCase();
    final theme = Theme.of(context);

    // Enhanced emotional color scheme for missing persons
    final Color cardBorderColor = Colors.red.shade800;
    final Color cardShadowColor = Colors.red.shade600;
    final Color cardBackgroundColor = Colors.red.shade50;
    final List<Color> cardGradientColors = [Colors.white, Colors.red.shade50];
    final Color colorTextoNombreCompleto = Colors.red.shade800;
    final Color colorTextoInfo =
        theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87;

    Widget buildInfoRow(String label, String? value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colorTextoInfo,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                (value ?? 'DESCONOCIDO').toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  color: colorTextoInfo,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cardGradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: cardShadowColor.withOpacity(0.3),
            blurRadius: 12.0,
            spreadRadius: 3.0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 8.0,
            spreadRadius: 1.0,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left side: Image and Information
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Enhanced image container
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: cardBorderColor, width: 3.0),
                        boxShadow: [
                          BoxShadow(
                            color: cardShadowColor.withOpacity(0.4),
                            blurRadius: 8.0,
                            spreadRadius: 2.0,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9.0),
                        child:
                            (desaparecido.fotoUrl != null &&
                                    desaparecido.fotoUrl!.isNotEmpty)
                                ? GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FullScreenImageScreen(
                                            imageUrl: desaparecido.fotoUrl!,
                                            heroTag: 'missing_${desaparecido.id}',
                                          ),
                                        ),
                                      );
                                    },
                                    child: Hero(
                                      tag: 'missing_${desaparecido.id}',
                                      child: AspectRatio(
                                        aspectRatio: 16 / 10,
                                        child: Image.network(
                                          desaparecido.fotoUrl!,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (
                                            context,
                                            child,
                                            loadingProgress,
                                          ) {
                                            if (loadingProgress == null) return child;
                                            return Container(
                                              color: cardBackgroundColor,
                                              child: Center(
                                                child: CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<Color>(
                                                        cardBorderColor,
                                                      ),
                                                  strokeWidth: 3.0,
                                                ),
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey.shade200,
                                              child: Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey.shade600,
                                                  size: 50,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  )
                                : AspectRatio(
                                  aspectRatio: 16 / 10,
                                  child: Container(
                                    color: Colors.grey.shade200,
                                    child: Center(
                                      child: Icon(
                                        Icons.person_outline,
                                        color: Colors.grey.shade600,
                                        size: 80,
                                      ),
                                    ),
                                  ),
                                ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    // Enhanced name display
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6.0,
                        horizontal: 10.0,
                      ),
                      decoration: BoxDecoration(
                        color: cardBorderColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: cardBorderColor.withOpacity(0.3),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        nombreCompleto,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colorTextoNombreCompleto,
                          shadows: [
                            Shadow(
                              offset: const Offset(1, 1),
                              blurRadius: 2,
                              color: Colors.black.withOpacity(0.1),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(height: 10),
                    // Enhanced information section
                    Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: cardBorderColor.withOpacity(0.2),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          buildInfoRow(
                            'EDAD:',
                            edadCalculada != null
                                ? '$edadCalculada AÑOS'
                                : 'DESCONOCIDA',
                          ),
                          buildInfoRow(
                            'DEPARTAMENTO:',
                            desaparecido.departamento,
                          ),
                          buildInfoRow('PROVINCIA:', desaparecido.provincia),
                          buildInfoRow('DISTRITO:', desaparecido.distrito),
                          if (desaparecido.fechaDesaparicion != null)
                            buildInfoRow(
                              'FECHA DESAP.:',
                              DateFormat('dd/MM/yy').format(desaparecido.fechaDesaparicion!),
                            )
                          else
                            buildInfoRow('FECHA DESAP.:', 'DESCONOCIDA'),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),

            // Right side: Enhanced action button
            InkWell(
              onTap: () async {
                final String currentStatus =
                    (desaparecido.estado ?? '').trim().toUpperCase();
                print(
                  'Navegando para ID: ${desaparecido.id}, Estado reportado: "${desaparecido.estado}", Estado normalizado: "$currentStatus"',
                );

                if (currentStatus == 'ENCONTRADO') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => FoundPersonDetailsScreen(
                            desaparecido: desaparecido,
                          ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => MissingPersonDetailsScreen(
                            desaparecido: desaparecido,
                          ),
                    ),
                  );
                }
              },
              child: Container(
                width: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade400,
                      Colors.red.shade500,
                      Colors.red.shade700,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border(
                    left: BorderSide(color: cardBorderColor, width: 2.0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 8.0,
                      offset: const Offset(2, 4),
                    ),
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 12.0,
                      offset: const Offset(-2, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 4.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Enhanced counter with pulsing effect
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.yellow.shade100,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4.0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$currentIndex/$totalCount',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                          shadows: [
                            Shadow(
                              offset: const Offset(0.5, 0.5),
                              blurRadius: 1,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(6.0),
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withOpacity(0.9),
                                Colors.yellow.shade200.withOpacity(0.7),
                                Colors.orange.shade300.withOpacity(0.5),
                              ],
                              center: Alignment.center,
                              radius: 0.8,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.6),
                                blurRadius: 8.0,
                                offset: const Offset(0, 0),
                              ),
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 12.0,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.search,
                            size: 20,
                            color: Colors.red.shade700,
                            shadows: [
                              Shadow(
                                offset: const Offset(1, 1),
                                blurRadius: 2,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Call-to-action text
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.yellow.shade300,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'VER',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
