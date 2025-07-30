import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_missing_view_model.dart';
import 'package:alerta_desaparecidos/domain/entities/desaparecido.dart';
import 'package:alerta_desaparecidos/common/state_enum.dart';
import 'package:alerta_desaparecidos/helpers/database_helpers.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Timer? _debounceTimer;

  bool _isSearching = false;
  bool _hasSearchError = false;
  String _lastSearchQuery = '';

  List<Map<String, dynamic>> _departamentosData = [];
  String? _selectedDepartamento;
  final String _fixedStatus = 'DESAPARECIDOS';
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Enhanced color palettes for emotional context
  final List<Color> _departmentColors = [
    const Color(0xFF1976D2), // Blue
    const Color(0xFF7B1FA2), // Purple
    const Color(0xFF388E3C), // Green
    const Color(0xFFD32F2F), // Red
    const Color(0xFF00796B), // Teal
    const Color(0xFFE91E63), // Pink
    const Color(0xFFF57C00), // Orange
    const Color(0xFF5D4037), // Brown
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
    String? departamentoDelUsuario;

    try {
      // Obtener el usuario autenticado
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Obtener datos del usuario desde Firestore
        final userDoc =
            await FirebaseFirestore.instance
                .collection('ciudadanos')
                .doc(user.uid)
                .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          departamentoDelUsuario = userData?['departamento'] as String?;
          print('[USER] DEPARTAMENTO DEL USUARIO: $departamentoDelUsuario');
        } else {
          print('[USER] No se encontró el documento del usuario en Firestore');
        }
      } else {
        print('[USER] Usuario no autenticado');
      }
    } catch (e) {
      print('[USER] ERROR AL OBTENER DEPARTAMENTO DEL USUARIO: $e');
    }

    if (!mounted) return;

    bool departamentoFueEstablecido = false;

    // Intentar establecer el departamento del usuario registrado
    if (departamentoDelUsuario != null && _departamentosData.isNotEmpty) {
      // Buscar el departamento en la lista, excluyendo "Todos los departamentos"
      final departamentosReales =
          _departamentosData
              .where((d) => d['name'] != 'Todos los departamentos')
              .toList();

      final match = departamentosReales.firstWhere(
        (d) =>
            (d['name'] as String?)?.toUpperCase() ==
            departamentoDelUsuario!.toUpperCase(),
        orElse: () => <String, dynamic>{},
      );

      if (match.isNotEmpty && match['name'] != null) {
        setState(() {
          _selectedDepartamento = match['name'] as String;
        });
        departamentoFueEstablecido = true;
        print(
          '[USER] DEPARTAMENTO SELECCIONADO AUTOMÁTICAMENTE (DEL REGISTRO): $_selectedDepartamento',
        );
      } else {
        print(
          '[USER] DEPARTAMENTO DEL USUARIO "$departamentoDelUsuario" NO ENCONTRADO EN LA LISTA LOCAL.',
        );
      }
    }

    // Si no se pudo establecer el departamento del usuario, usar el valor por defecto
    if (!departamentoFueEstablecido && _departamentosData.isNotEmpty) {
      setState(() {
        _selectedDepartamento = 'Todos los departamentos';
      });
      print(
        '[USER] DEPARTAMENTO SELECCIONADO POR DEFECTO: $_selectedDepartamento',
      );
    }

    _fetchDataWithCurrentFilters();
  }

  @override
  void dispose() {
    // Cancelar timers pendientes
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
    final String? departamentoParaFiltrar =
        _selectedDepartamento == 'Todos los departamentos'
            ? null
            : _selectedDepartamento
                ?.toUpperCase(); // 🔧 CONVERSIÓN A MAYÚSCULAS

    final String statusParaFiltrar = _fixedStatus;
    final String? searchQuery =
        _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim();

    print('🔧 [DEBUG] _fetchDataWithCurrentFilters llamado con:');
    print('   - departamento: $departamentoParaFiltrar');
    print('   - status: $statusParaFiltrar');
    print('   - searchQuery: "$searchQuery"');

    Provider.of<ViewMissingViewModel>(context, listen: false).getMissingPeople(
      forceRefresh: true,
      searchQuery: searchQuery,
      departamento: departamentoParaFiltrar, // Ahora será "APURÍMAC"
      status: statusParaFiltrar == 'DESAPARECIDOS' ? 'activo' : 'encontrado',
    );
  }

  void _onSearchChanged() {
    final currentQuery = _searchController.text.trim();

    // Cancelar timer anterior si existe
    _debounceTimer?.cancel();

    if (mounted) {
      setState(() {
        _isSearching = currentQuery.isNotEmpty;
        _hasSearchError = false;
      });
    }

    // Debounce mejorado (800ms para mejor UX)
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted && _lastSearchQuery != currentQuery) {
        _lastSearchQuery = currentQuery;
        _performSearch();
      }
    });
  }

  Future<void> _performSearch() async {
    try {
      if (mounted) {
        setState(() {
          _isSearching = true;
          _hasSearchError = false;
        });
      }

      _fetchDataWithCurrentFilters();

      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _hasSearchError = true;
        });
      }
      print('Error en búsqueda: $e');
    }
  }

  void _clearSearch() {
    _searchController.clear();
    if (mounted) {
      setState(() {
        _isSearching = false;
        _hasSearchError = false;
        _lastSearchQuery = '';
      });
    }
    _fetchDataWithCurrentFilters();
  }

  Future<void> _loadDepartamentos() async {
    try {
      final data = await _dbHelper.getDepartamentos();
      if (mounted) {
        setState(() {
          // Agregar la opción "Todos los departamentos" al inicio
          _departamentosData = [
            {'name': 'Todos los departamentos'},
            ...data,
          ];
        });
      }
    } catch (e) {
      print('Error al cargar departamentos: $e');
      if (mounted) {
        setState(() {
          _departamentosData = [
            {'name': 'Todos los departamentos'},
          ];
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

  // 🔥 WIDGET DE AYUDA CONTEXTUAL
  Widget _buildSearchHelp() {
    if (_searchController.text.isNotEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.blue.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Puedes buscar por nombres, apellidos separados o DNI',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
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
                // 🎨 COMPACT MODERN HEADER SECTION
                Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.red.shade700,
                        Colors.red.shade900,
                        Colors.purple.shade800,
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.shade300.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Decorative background pattern
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [
                                Colors.white.withOpacity(0.1),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Compact decorative elements
                      Positioned(
                        top: 10,
                        right: 20,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 35,
                        left: 25,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                      ),
                      // Compact main content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Row(
                          children: [
                            // Compact icon
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.search_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Compact text content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'BÚSQUEDA ACTIVA',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1.5,
                                      shadows: [
                                        Shadow(
                                          offset: Offset(1, 1),
                                          blurRadius: 3,
                                          color: Colors.black.withOpacity(0.3),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Cada búsqueda puede ser la esperanza que una familia necesita',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.9),
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 🎨 COMPACT MODERN FILTER SECTION
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 15.0,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4.0,
                        spreadRadius: 0,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Compact filter section title
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade400,
                                    Colors.blue.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.tune_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Filtros de Búsqueda',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Compact dropdown
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14.0),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1.5,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.grey.shade50, Colors.white],
                            ),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedDepartamento,
                            decoration: InputDecoration(
                              labelText: 'Departamento',
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(10),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.orange.shade400,
                                      Colors.orange.shade600,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            dropdownColor: Colors.white,
                            icon: Container(
                              margin: const EdgeInsets.only(right: 10),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.grey.shade600,
                                size: 20,
                              ),
                            ),
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            selectedItemBuilder: (BuildContext context) {
                              return _departamentosData.map<Widget>((
                                Map<String, dynamic> item,
                              ) {
                                final String? deptoName =
                                    item['name'] as String?;
                                return Container(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    deptoName?.toUpperCase() ?? 'N/A',
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList();
                            },
                            items:
                                _departamentosData.map<
                                  DropdownMenuItem<String>
                                >((Map<String, dynamic> item) {
                                  final String? deptoName =
                                      item['name'] as String?;
                                  int index = _departamentosData.indexWhere(
                                    (d) => d['name'] == deptoName,
                                  );

                                  Color itemBackgroundColor;
                                  Color textColor;

                                  if (deptoName == 'Todos los departamentos') {
                                    itemBackgroundColor = Colors.blue.shade600;
                                    textColor = Colors.white;
                                  } else {
                                    itemBackgroundColor =
                                        _departmentColors[(index - 1) %
                                            _departmentColors.length];
                                    textColor = Colors.white;
                                  }

                                  return DropdownMenuItem<String>(
                                    value: deptoName,
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12.0,
                                        horizontal: 16.0,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            itemBackgroundColor,
                                            itemBackgroundColor.withOpacity(
                                              0.9,
                                            ),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          8.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: itemBackgroundColor
                                                .withOpacity(0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        deptoName?.toUpperCase() ?? 'N/A',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                          fontSize: 13,
                                        ),
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                  );
                                }).toList(),
                            onChanged: _onDepartamentoChanged,
                          ),
                        ),

                        const SizedBox(height: 12.0),

                        // Compact search field
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14.0),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.grey.shade50, Colors.white],
                            ),
                            border: Border.all(
                              color:
                                  _isSearching
                                      ? Colors.blue.shade300
                                      : Colors.grey.shade200,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    _isSearching
                                        ? Colors.blue.shade100.withOpacity(0.5)
                                        : Colors.grey.shade100.withOpacity(0.5),
                                blurRadius: 6.0,
                                spreadRadius: 0,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            inputFormatters: [UpperCaseTextFormatter()],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Buscar por nombre, apellidos o DNI...',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w400,
                                fontSize: 13,
                              ),
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(10),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors:
                                        _isSearching
                                            ? [
                                              Colors.blue.shade400,
                                              Colors.blue.shade600,
                                            ]
                                            : [
                                              Colors.grey.shade400,
                                              Colors.grey.shade600,
                                            ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.search_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                              suffixIcon:
                                  _searchController.text.isNotEmpty
                                      ? Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_isSearching)
                                              Container(
                                                width: 16,
                                                height: 16,
                                                margin: const EdgeInsets.only(
                                                  right: 6,
                                                ),
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.blue.shade600),
                                                ),
                                              ),
                                            Container(
                                              margin: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: IconButton(
                                                icon: Icon(
                                                  Icons.clear_rounded,
                                                  color: Colors.grey.shade600,
                                                  size: 16,
                                                ),
                                                onPressed: _clearSearch,
                                                tooltip: 'Limpiar búsqueda',
                                                padding: const EdgeInsets.all(
                                                  2,
                                                ),
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 28,
                                                      minHeight: 28,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12.0),

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
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    color: Colors.red.shade400,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    emptyMessage,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
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
                                // 🎬 ANIMACIÓN ESCALONADA PARA CADA TARJETA - CORREGIDA
                                TweenAnimationBuilder<double>(
                                  duration: Duration(
                                    milliseconds: 600 + (index * 100),
                                  ),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, child) {
                                    // Asegurar que los valores estén en rango válido
                                    final clampedValue = value.clamp(0.0, 1.0);
                                    final offsetY = 30 * (1 - clampedValue);
                                    final scale = 0.9 + (0.1 * clampedValue);

                                    return Transform.translate(
                                      offset: Offset(0, offsetY),
                                      child: Opacity(
                                        opacity: clampedValue,
                                        child: Transform.scale(
                                          scale: scale,
                                          child:
                                              _buildEnhancedMissingPersonCard(
                                                desaparecido,
                                                index + 1,
                                                vm.totalCount,
                                              ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (!isLastItem && vm.desaparecidos.length > 1)
                                  // 🎬 ANIMACIÓN PARA EL SEPARADOR - CORREGIDA
                                  TweenAnimationBuilder<double>(
                                    duration: Duration(
                                      milliseconds: 800 + (index * 50),
                                    ),
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    curve: Curves.easeInOut,
                                    builder: (context, value, child) {
                                      final clampedValue = value.clamp(
                                        0.0,
                                        1.0,
                                      );
                                      return Opacity(
                                        opacity: clampedValue,
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 16.0,
                                            vertical: 8.0,
                                          ),
                                          height: 1,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.transparent,
                                                Colors.red.withOpacity(
                                                  0.3 * clampedValue,
                                                ),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
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
    // Calcular edad
    int? edad;
    if (desaparecido.fechaNacimiento != null) {
      final now = DateTime.now();
      final birthDate = desaparecido.fechaNacimiento!;
      edad = now.year - birthDate.year;
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        edad--;
      }
    }

    // 🎨 COMPACT MODERN COLOR SCHEME
    final cardGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white,
        Colors.grey.shade50,
        Colors.blue.shade50.withOpacity(0.2),
      ],
    );

    final accentColor = Colors.blue.shade600;
    final textPrimary = Colors.grey.shade800;
    final textSecondary = Colors.grey.shade600;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final String status =
                (desaparecido.estado ?? '').trim().toLowerCase();
            if (status == 'encontrado') {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder:
                      (context, animation, secondaryAnimation) =>
                          FoundPersonDetailsScreen(desaparecido: desaparecido),
                  transitionsBuilder: (
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ) {
                    return SlideTransition(
                      position: animation.drive(
                        Tween(
                          begin: const Offset(1.0, 0.0),
                          end: Offset.zero,
                        ).chain(CurveTween(curve: Curves.easeInOut)),
                      ),
                      child: child,
                    );
                  },
                ),
              );
            } else {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder:
                      (context, animation, secondaryAnimation) =>
                          MissingPersonDetailsScreen(
                            desaparecido: desaparecido,
                          ),
                  transitionsBuilder: (
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ) {
                    return SlideTransition(
                      position: animation.drive(
                        Tween(
                          begin: const Offset(1.0, 0.0),
                          end: Offset.zero,
                        ).chain(CurveTween(curve: Curves.easeInOut)),
                      ),
                      child: child,
                    );
                  },
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 🎨 COMPACT PHOTO SECTION CON ANIMACIÓN CORREGIDA
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    final clampedValue = value.clamp(0.0, 1.0);
                    return Transform.scale(
                      scale: 0.8 + (0.2 * clampedValue),
                      child: Opacity(
                        opacity: clampedValue,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.grey.shade200,
                                Colors.grey.shade300,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GestureDetector(
                              onTap: () {
                                if (desaparecido.fotoUrl != null &&
                                    desaparecido.fotoUrl!.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => FullScreenImageScreen(
                                            imageUrl: desaparecido.fotoUrl!,
                                            heroTag: 'photo_${desaparecido.id}',
                                          ),
                                    ),
                                  );
                                }
                              },
                              child: Hero(
                                tag: 'photo_${desaparecido.id}',
                                child:
                                    desaparecido.fotoUrl != null &&
                                            desaparecido.fotoUrl!.isNotEmpty
                                        ? Image.network(
                                          desaparecido.fotoUrl!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          loadingBuilder: (
                                            context,
                                            child,
                                            loadingProgress,
                                          ) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.grey.shade200,
                                                    Colors.grey.shade300,
                                                  ],
                                                ),
                                              ),
                                              child: Center(
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(accentColor),
                                                ),
                                              ),
                                            );
                                          },
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.grey.shade200,
                                                    Colors.grey.shade300,
                                                  ],
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.person_rounded,
                                                color: Colors.grey.shade500,
                                                size: 45,
                                              ),
                                            );
                                          },
                                        )
                                        : Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.grey.shade200,
                                                Colors.grey.shade300,
                                              ],
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.person_rounded,
                                            color: Colors.grey.shade500,
                                            size: 45,
                                          ),
                                        ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(width: 12),

                // 🎨 COMPACT INFO SECTION CON ANIMACIONES ESCALONADAS CORREGIDAS
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Compact header with counter and status - ANIMADO CORREGIDO
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 400),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          final clampedValue = value.clamp(0.0, 1.0);
                          return Transform.translate(
                            offset: Offset(-20 * (1 - clampedValue), 0),
                            child: Opacity(
                              opacity: clampedValue,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          accentColor,
                                          accentColor.withOpacity(0.8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: accentColor.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '$currentIndex/$totalCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (desaparecido.estado ?? '')
                                                      .trim()
                                                      .toLowerCase() ==
                                                  'encontrado'
                                              ? Colors.green.shade100
                                              : Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            (desaparecido.estado ?? '')
                                                        .trim()
                                                        .toLowerCase() ==
                                                    'encontrado'
                                                ? Colors.green.shade300
                                                : Colors.orange.shade300,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      (desaparecido.estado ?? '')
                                                  .trim()
                                                  .toLowerCase() ==
                                              'encontrado'
                                          ? 'ENCONTRADO'
                                          : 'DESAPARECIDO',
                                      style: TextStyle(
                                        color:
                                            (desaparecido.estado ?? '')
                                                        .trim()
                                                        .toLowerCase() ==
                                                    'encontrado'
                                                ? Colors.green.shade700
                                                : Colors.orange.shade700,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 8),

                      // Nombres y apellidos separados - ANIMADOS CORREGIDOS
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 500),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          final clampedValue = value.clamp(0.0, 1.0);
                          return Transform.translate(
                            offset: Offset(-15 * (1 - clampedValue), 0),
                            child: Opacity(
                              opacity: clampedValue,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Nombres en la primera línea
                                  Text(
                                    desaparecido.nombres ?? '',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                      height: 1.1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // Apellidos en la segunda línea
                                  Text(
                                    desaparecido.apellidos ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary.withOpacity(0.8),
                                      height: 1.1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 8),

                      // 🎨 FIRST INFO ROW - Age and Date - ANIMADO CORREGIDO
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 600),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          final clampedValue = value.clamp(0.0, 1.0);
                          return Transform.translate(
                            offset: Offset(-10 * (1 - clampedValue), 0),
                            child: Opacity(
                              opacity: clampedValue,
                              child: Row(
                                children: [
                                  if (edad != null) ...[
                                    _buildCompactInfoChip(
                                      Icons.cake_rounded,
                                      '$edad años',
                                      Colors.purple.shade400,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  if (desaparecido.fechaDesaparicion !=
                                      null) ...[
                                    _buildCompactInfoChip(
                                      Icons.calendar_today_rounded,
                                      '${desaparecido.fechaDesaparicion!.day}/${desaparecido.fechaDesaparicion!.month}/${desaparecido.fechaDesaparicion!.year}',
                                      Colors.red.shade400,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // 🎨 SECOND INFO ROW - Location (full width) - ANIMADO CORREGIDO
                      if (desaparecido.departamento?.isNotEmpty == true ||
                          desaparecido.distrito?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 700),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            final clampedValue = value.clamp(0.0, 1.0);
                            return Transform.translate(
                              offset: Offset(-5 * (1 - clampedValue), 0),
                              child: Opacity(
                                opacity: clampedValue,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildCompactInfoChip(
                                        Icons.location_on_rounded,
                                        _buildLocationText(desaparecido),
                                        Colors.orange.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 🎨 COMPACT ACTION BUTTON CON ANIMACIÓN CORREGIDA
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    final clampedValue = value.clamp(0.0, 1.0);
                    return Transform.scale(
                      scale: 0.8 + (0.2 * clampedValue),
                      child: Opacity(
                        opacity: clampedValue,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accentColor,
                                accentColor.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                final String status =
                                    (desaparecido.estado ?? '')
                                        .trim()
                                        .toLowerCase();
                                if (status == 'encontrado') {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                          ) => FoundPersonDetailsScreen(
                                            desaparecido: desaparecido,
                                          ),
                                      transitionsBuilder: (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                        child,
                                      ) {
                                        return SlideTransition(
                                          position: animation.drive(
                                            Tween(
                                              begin: const Offset(1.0, 0.0),
                                              end: Offset.zero,
                                            ).chain(
                                              CurveTween(
                                                curve: Curves.easeInOut,
                                              ),
                                            ),
                                          ),
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                          ) => MissingPersonDetailsScreen(
                                            desaparecido: desaparecido,
                                          ),
                                      transitionsBuilder: (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                        child,
                                      ) {
                                        return SlideTransition(
                                          position: animation.drive(
                                            Tween(
                                              begin: const Offset(1.0, 0.0),
                                              end: Offset.zero,
                                            ).chain(
                                              CurveTween(
                                                curve: Curves.easeInOut,
                                              ),
                                            ),
                                          ),
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ... existing code ...

  // 🎬 MÉTODO PARA ANIMAR EL TAP DE LA TARJETA
  void _animateCardTap() {
    _animationController.reverse().then((_) {
      _animationController.forward();
    });
  }

  // 🎨 COMPACT INFO CHIP WIDGET CON ANIMACIÓN
  Widget _buildAnimatedCompactInfoChip(
    IconData icon,
    String value,
    Color accentColor, {
    int delay = 0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 500 + delay),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, animValue, child) {
        return Transform.scale(
          scale: animValue,
          child: Opacity(
            opacity: animValue,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: accentColor.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 12, color: accentColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 🎨 HELPER METHOD FOR LOCATION TEXT
  String _buildLocationText(Desaparecido desaparecido) {
    final List<String> locationParts = [];

    if (desaparecido.distrito?.isNotEmpty == true) {
      locationParts.add(desaparecido.distrito!);
    }

    if (desaparecido.departamento?.isNotEmpty == true) {
      locationParts.add(desaparecido.departamento!);
    }

    return locationParts.join(', ');
  }

  // 🎨 COMPACT INFO CHIP WIDGET
  Widget _buildCompactInfoChip(IconData icon, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ), // Mantiene el padding actual
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accentColor), // Mantiene el tamaño actual
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11, // Mantiene el tamaño actual
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
