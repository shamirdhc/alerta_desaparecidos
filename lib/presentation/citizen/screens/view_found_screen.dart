import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_found_view_model.dart';
import 'package:alerta_desaparecidos/domain/entities/desaparecido.dart';
import 'package:alerta_desaparecidos/common/state_enum.dart';
import 'package:alerta_desaparecidos/helpers/database_helpers.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:alerta_desaparecidos/common/styles/custom_input_decoration.dart';
import 'found_person_details_screen.dart';

class ViewFoundScreen extends StatefulWidget {
  const ViewFoundScreen({super.key});

  @override
  State<ViewFoundScreen> createState() => _ViewFoundScreenState();
}

class _ViewFoundScreenState extends State<ViewFoundScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDepartamento;
  List<Map<String, dynamic>> _departamentosData = [];
  final ScrollController _scrollController = ScrollController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Solo personas encontradas
  final String _fixedStatus = 'ENCONTRADOS';

  final List<Color> _departmentColors = [
    const Color(0xFFE8F5E9), // Light Green
    const Color(0xFFE0F2F1), // Light Teal
    const Color(0xFFF1F8E9), // Light Lime
    const Color(0xFFE0F7FA), // Light Cyan
    const Color(0xFFE4F5E4), // Very Light Green
    const Color(0xFFEAF7EA), // Pale Green
    const Color(0xFFE6F3E6), // Soft Green
    const Color(0xFFE1F5FE), // Light Blue
    const Color(0xFFE8F6F3), // Mint Green
    const Color(0xFFF0F8F0), // Very Pale Green
    const Color(0xFFE5F3E5), // Soft Mint
    const Color(0xFFEDF7ED), // Pale Mint
    const Color(0xFFE9F5E9), // Light Mint
    const Color(0xFFE3F2E3), // Soft Light Green
    const Color(0xFFEBF6EB), // Very Light Mint
    const Color(0xFFE7F4E7), // Gentle Green
    const Color(0xFFE2F1E2), // Subtle Green
    const Color(0xFFEEF7EE), // Whisper Green
    const Color(0xFFE6F3E6), // Faint Green
    const Color(0xFFEAF5EA), // Delicate Green
    const Color(0xFFE4F2E4), // Tender Green
    const Color(0xFFE8F4E8), // Mild Green
    const Color(0xFFECF6EC), // Gentle Mint
    const Color(0xFFE5F3E5), // Soft Sage
    const Color(0xFFE9F5E9), // Light Sage
  ];

  // Green gradient for found persons
  List<Color> get _backgroundGradientColors {
    return [
      const Color(0xFFE8F5E9), // Very light green
      const Color(0xFFCCE5CC), // Light green
      const Color(0xFFB3D9B3), // Soft green - joy/hope
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
          }
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
      }
    }

    if (!departamentoFueEstablecido && _departamentosData.isNotEmpty) {
      setState(() {
        _selectedDepartamento =
            'Todos los departamentos'; // 🔧 ESTABLECER "TODOS" POR DEFECTO
      });
      departamentoFueEstablecido = true;
    }

    if (_selectedDepartamento != null) {
      _fetchDataWithCurrentFilters();
    } else {
      Provider.of<ViewFoundViewModel>(
        context,
        listen: false,
      ).getFoundPeople(forceRefresh: true);
      _fetchDataWithCurrentFilters();
    }
  }

  @override
  void dispose() {
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
      Provider.of<ViewFoundViewModel>(
        context,
        listen: false,
      ).loadMoreFoundPeople();
    }
  }

  void _fetchDataWithCurrentFilters() {
    // Normalizar el departamento a mayúsculas para que coincida con Firebase
    final String? departamentoParaFiltrar =
        _selectedDepartamento == 'Todos los departamentos'
            ? null
            : _selectedDepartamento
                ?.toUpperCase(); // 🔧 CONVERSIÓN A MAYÚSCULAS

    final String? searchQuery =
        _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim();

    print('🔧 [DEBUG] ViewFound _fetchDataWithCurrentFilters llamado con:');
    print('   - departamento: $departamentoParaFiltrar');
    print('   - searchQuery: "$searchQuery"');

    Provider.of<ViewFoundViewModel>(context, listen: false).getFoundPeople(
      forceRefresh: true,
      searchQuery: searchQuery,
      departamento: departamentoParaFiltrar, // Ahora será "APURÍMAC"
    );
  }

  void _onSearchChanged() {
    _fetchDataWithCurrentFilters();
  }

  Future<void> _loadDepartamentos() async {
    try {
      final data = await _dbHelper.getDepartamentos();
      if (mounted) {
        setState(() {
          _departamentosData = [
            {'name': 'Todos los departamentos'}, // 🔧 AGREGAR OPCIÓN "TODOS"
            ...data,
          ];
        });
      }
    } catch (e) {
      print('Error loading departamentos: $e');
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
    final viewModel = Provider.of<ViewFoundViewModel>(context);

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
                // Enhanced Header Section for Found Persons
                Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade600, Colors.green.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.4),
                        blurRadius: 15.0,
                        spreadRadius: 3.0,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Title with icons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/icons/encontrados_icon.png',
                            height: 35,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          const Flexible(
                            child: Text(
                              'PERSONAS ENCONTRADAS',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 3,
                                    color: Colors.black26,
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Image.asset(
                            'assets/icons/encontrados_icon.png',
                            height: 35,
                            color: Colors.white,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Success message
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '¡Celebramos cada reencuentro!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                // Enhanced Filter Section (only department filter)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  padding: const EdgeInsets.all(16.0),
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
                    children: [
                      // Department filter only
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
                                      ? (_selectedDepartamento ==
                                                  'Todos los departamentos'
                                              ? Colors.blue.shade600
                                              : _departmentColors[(_departamentosData
                                                          .indexWhere(
                                                            (d) =>
                                                                d['name'] ==
                                                                _selectedDepartamento,
                                                          ) -
                                                      1) %
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
                                    ? (_selectedDepartamento ==
                                            'Todos los departamentos'
                                        ? Colors.blue.shade600
                                        : _departmentColors[(_departamentosData
                                                    .indexWhere(
                                                      (d) =>
                                                          d['name'] ==
                                                          _selectedDepartamento,
                                                    ) -
                                                1) %
                                            _departmentColors.length])
                                    : Colors.grey.shade400,
                            width: 2.0,
                          ),
                          color:
                              _selectedDepartamento != null &&
                                      _departamentosData.indexWhere(
                                            (d) =>
                                                d['name'] ==
                                                _selectedDepartamento,
                                          ) !=
                                          -1
                                  ? (_selectedDepartamento ==
                                          'Todos los departamentos'
                                      ? Colors.blue.shade600.withOpacity(0.1)
                                      : _departmentColors[(_departamentosData
                                                      .indexWhere(
                                                        (d) =>
                                                            d['name'] ==
                                                            _selectedDepartamento,
                                                      ) -
                                                  1) %
                                              _departmentColors.length]
                                          .withOpacity(0.1))
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
                                  // 🔧 USAR LA MISMA LÓGICA QUE EN MISSING
                                  itemBackgroundColor =
                                      _departmentColors[(index - 1) %
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
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: Text(
                                      deptoName?.toUpperCase() ?? 'N/A',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: itemTextColor,
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
                              final String? deptoName = item['name'] as String?;
                              int index = _departamentosData.indexWhere(
                                (d) => d['name'] == deptoName,
                              );

                              Color selectedBgColor;
                              if (deptoName == 'Todos los departamentos') {
                                selectedBgColor = Colors.blue.shade600;
                              } else if (index != -1 && index > 0) {
                                selectedBgColor =
                                    _departmentColors[(index - 1) %
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
                                  borderRadius: BorderRadius.circular(8.0),
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
                      const SizedBox(height: 16.0),
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
                              color: Colors.green.shade700,
                              size: 24,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                color: Colors.green.shade300,
                                width: 2.0,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                color: Colors.green.shade700,
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

                const SizedBox(height: 16.0),

                // Enhanced content list
                Expanded(
                  child: Consumer<ViewFoundViewModel>(
                    builder: (context, vm, child) {
                      if (vm.state == RequestState.Loading &&
                          vm.desaparecidos.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.green.shade700,
                                ),
                                strokeWidth: 4.0,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Cargando información...',
                                style: TextStyle(
                                  color: Colors.green.shade700,
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
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
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
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      if (vm.desaparecidos.isEmpty) {
                        String emptyMessage;
                        if (_searchController.text.trim().isNotEmpty) {
                          emptyMessage =
                              'NO SE ENCONTRARON RESULTADOS PARA "${_searchController.text}".';
                        } else if (_selectedDepartamento != null) {
                          emptyMessage =
                              'NO HAY PERSONAS ENCONTRADAS REGISTRADAS EN ESTE DEPARTAMENTO.';
                        } else {
                          emptyMessage =
                              'NO HAY PERSONAS ENCONTRADAS REGISTRADAS.';
                        }

                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.celebration,
                                color: Colors.green.shade400,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                emptyMessage,
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Cada reencuentro es una victoria.',
                                style: TextStyle(
                                  color: Colors.green.shade600,
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
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
                                        Colors.green.shade700,
                                      ),
                                      strokeWidth: 3.0,
                                    ),
                                  ),
                                )
                                : const SizedBox.shrink();
                          }

                          final desaparecido = vm.desaparecidos[index];
                          return _buildFoundPersonCard(
                            desaparecido,
                            index + 1,
                            vm.desaparecidos.length,
                          );
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

  Widget _buildFoundPersonCard(
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

    // Enhanced emotional color scheme for found persons (GREEN THEME)
    final Color cardBorderColor = Colors.green.shade800;
    final Color cardShadowColor = Colors.green.shade600;
    final Color cardBackgroundColor = Colors.green.shade50;
    final List<Color> cardGradientColors = [Colors.white, Colors.green.shade50];
    final Color colorTextoNombreCompleto = Colors.green.shade800;
    final Color colorTextoInfo =
        theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87;

    Widget buildInfoRow(String label, String? value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colorTextoInfo,
                ),
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
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                padding: const EdgeInsets.all(16.0),
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
                                ? AspectRatio(
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

                    const SizedBox(height: 12),

                    // SUCCESS INDICATOR - Check icon and "¡Persona Encontrada!"
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 12.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(8.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '¡Persona Encontrada!',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
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
                          fontSize: 16,
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

                    const SizedBox(height: 12),
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
                              DateFormat(
                                'dd/MM/yyyy',
                              ).format(desaparecido.fechaDesaparicion!),
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => FoundPersonDetailsScreen(
                          desaparecido: desaparecido,
                        ),
                  ),
                );
              },
              child: Container(
                width: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade100, Colors.green.shade200],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border(
                    left: BorderSide(color: cardBorderColor, width: 2.0),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 12.0,
                  horizontal: 4.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Enhanced counter
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cardBorderColor,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: cardShadowColor.withOpacity(0.3),
                            blurRadius: 4.0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$currentIndex/$totalCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color: cardBorderColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chevron_right,
                            size: 24,
                            color: cardBorderColor,
                          ),
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
