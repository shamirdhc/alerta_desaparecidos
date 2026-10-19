import '../../../services/gps_location_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_missing_view_model.dart';
import 'package:alerta_desaparecidos/domain/entities/desaparecido.dart';
import 'package:alerta_desaparecidos/common/state_enum.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:alerta_desaparecidos/helpers/share_helper.dart';
import 'missing_person_details_screen.dart';
import 'full_screen_image_screen.dart';
import 'package:alerta_desaparecidos/common/constants/peru_locations.dart';
import 'package:alerta_desaparecidos/common/styles/app_colors.dart';
import 'package:alerta_desaparecidos/presentation/common_widgets/scale_on_tap.dart';
import 'package:alerta_desaparecidos/common/localization/app_strings.dart';
import 'package:alerta_desaparecidos/presentation/common/widgets/branded_loading_dialog.dart';
import 'package:alerta_desaparecidos/presentation/common_widgets/app_cached_image.dart';


enum MissingQuickFilter {
  todos,
  miProvincia,
  menoresAmber,
  recientes48h,
  miDepartamento,
}

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
  String _lastSearchQuery = '';

  List<Map<String, dynamic>> _departamentosData = [];
  String? _selectedDepartamento;
  String? _selectedProvincia;
  String? _userDepartamento;
  String? _userProvincia;
  final String _fixedStatus = 'DESAPARECIDOS';

  MissingQuickFilter _currentQuickFilter = MissingQuickFilter.todos;

  // Variables de memoización para filtrado O(1) de alto rendimiento
  List<Desaparecido>? _cachedFilteredList;
  List<Desaparecido>? _lastRawList;
  String? _lastSelectedDepartamento;
  String? _lastSelectedProvincia;
  MissingQuickFilter? _lastQuickFilter;
  String? _lastUserProvincia;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
    String? provinciaDelUsuario;

    try {
      // 1. SharedPreferences primero (inmediato, sin esperar red)
      final prefs = await SharedPreferences.getInstance();
      departamentoDelUsuario = prefs.getString('user_departamento') ??
          prefs.getString('user_department') ??
          prefs.getString(GpsLocationService.keyUserDept);
      provinciaDelUsuario = prefs.getString('user_provincia') ??
          prefs.getString(GpsLocationService.keyUserProv);

      // 2. Si el departamento está vacío pero tenemos provincia, deducir departamento de PeruLocations
      if ((departamentoDelUsuario == null || departamentoDelUsuario.trim().isEmpty) &&
          provinciaDelUsuario != null &&
          provinciaDelUsuario.trim().isNotEmpty) {
        final provClean = provinciaDelUsuario.toUpperCase().trim();
        for (final entry in PeruLocations.departamentosYProvincias.entries) {
          if (entry.value.any((p) => p.toUpperCase().trim() == provClean)) {
            departamentoDelUsuario = entry.key;
            break;
          }
        }
      }

      // 3. Fallback a GpsLocationService
      if (departamentoDelUsuario == null || departamentoDelUsuario.trim().isEmpty) {
        final loc = await GpsLocationService.getSavedLocation();
        if (loc != null) {
          departamentoDelUsuario = loc.departamento;
          provinciaDelUsuario ??= loc.provincia;
        }
      }

      // 4. Fallback a Firestore si sigue vacío
      final user = FirebaseAuth.instance.currentUser;
      final bool needsDeptFromFirestore = departamentoDelUsuario == null || departamentoDelUsuario.trim().isEmpty;
      if (needsDeptFromFirestore && user != null) {
        var userDoc = await FirebaseFirestore.instance
            .collection('ciudadanos')
            .doc(user.uid)
            .get();

        if (!userDoc.exists || userDoc.data() == null) {
          userDoc = await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .get();
        }

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          if (userData['departamento'] != null) {
            departamentoDelUsuario = userData['departamento'] as String?;
          }
          if (userData['provincia'] != null) {
            provinciaDelUsuario ??= userData['provincia'] as String?;
          }
        }
      }

      // 5. Segunda deducción por provincia si vino de Firestore
      if ((departamentoDelUsuario == null || departamentoDelUsuario.trim().isEmpty) &&
          provinciaDelUsuario != null &&
          provinciaDelUsuario.trim().isNotEmpty) {
        final provClean = provinciaDelUsuario.toUpperCase().trim();
        for (final entry in PeruLocations.departamentosYProvincias.entries) {
          if (entry.value.any((p) => p.toUpperCase().trim() == provClean)) {
            departamentoDelUsuario = entry.key;
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('[USER] Error al obtener departamento y provincia: $e');
    }

    if (!mounted) return;

    _userDepartamento = departamentoDelUsuario;
    _userProvincia = provinciaDelUsuario;
    bool departamentoFueEstablecido = false;

    // Normalizar y fijar el departamento del usuario como seleccionado por defecto
    if (departamentoDelUsuario != null && departamentoDelUsuario.trim().isNotEmpty) {
      final canon = PeruLocations.canonicalDepartment(departamentoDelUsuario);
      String canonDept = canon ?? departamentoDelUsuario.trim().toUpperCase();

      setState(() {
        _selectedDepartamento = canonDept;
        _selectedProvincia = null; // "Todas las provincias" por defecto al inicio
        _currentQuickFilter = MissingQuickFilter.todos;
        _cachedFilteredList = null;
      });
      departamentoFueEstablecido = true;
    }

    if (!departamentoFueEstablecido) {
      setState(() {
        _selectedDepartamento = 'Todos los departamentos';
        _selectedProvincia = null;
        _currentQuickFilter = MissingQuickFilter.todos;
        _cachedFilteredList = null;
      });
    }

    _fetchDataWithCurrentFilters();
  }

  @override
  void dispose() {
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
    final cleanDept = _selectedDepartamento?.trim();
    final String? departamentoParaFiltrar =
        (cleanDept == null ||
         cleanDept.isEmpty ||
         cleanDept.toLowerCase() == 'todos' ||
         cleanDept.toLowerCase() == 'todos los departamentos')
            ? null
            : cleanDept;

    final cleanProv = _selectedProvincia?.trim();
    final String? provinciaParaFiltrar =
        (cleanProv == null ||
         cleanProv.isEmpty ||
         cleanProv.toLowerCase() == 'todas' ||
         cleanProv.toLowerCase() == 'todas las provincias')
            ? (_currentQuickFilter == MissingQuickFilter.miProvincia ? _userProvincia : null)
            : cleanProv;

    final String? searchQuery =
        _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim();

    Provider.of<ViewMissingViewModel>(context, listen: false).getMissingPeople(
      forceRefresh: true,
      searchQuery: searchQuery,
      departamento: departamentoParaFiltrar,
      provincia: provinciaParaFiltrar,
      status: _fixedStatus == 'DESAPARECIDOS' ? 'activo' : 'encontrado',
    );
  }

  void _onSearchChanged() {
    final currentQuery = _searchController.text.trim();
    _debounceTimer?.cancel();

    if (mounted) {
      setState(() {
        _isSearching = currentQuery.isNotEmpty;
      });
    }

    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted && _lastSearchQuery != currentQuery) {
        _lastSearchQuery = currentQuery;
        _fetchDataWithCurrentFilters();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    if (mounted) {
      setState(() {
        _isSearching = false;
        _lastSearchQuery = '';
      });
    }
    _fetchDataWithCurrentFilters();
  }

  Future<void> _loadDepartamentos() async {
    final List<Map<String, dynamic>> allDeptos = [
      {'name': 'Todos los departamentos'},
      ...PeruLocations.departamentos.map((dept) => {'name': dept}),
    ];
    if (mounted) {
      setState(() {
        _departamentosData = allDeptos;
      });
    }
  }

  void _onDepartamentoChanged(String? newValue) {
    setState(() {
      _selectedDepartamento = newValue;
      _selectedProvincia = null; // Al cambiar departamento, siempre selecciona "Todas las provincias"
      _currentQuickFilter = MissingQuickFilter.todos;
      _cachedFilteredList = null;
    });
    _fetchDataWithCurrentFilters();
  }

  void _showDepartmentPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String searchDept = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredDeptos =
                _departamentosData.where((d) {
                  final name = (d['name'] as String? ?? '').toLowerCase();
                  return name.contains(searchDept.toLowerCase());
                }).toList();

            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.map_rounded,
                            color: AppColors.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Seleccionar Departamento',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.policeNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: TextField(
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar departamento...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 20,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          searchDept = val;
                        });
                      },
                    ),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filteredDeptos.length,
                      separatorBuilder:
                          (_, __) => Divider(
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                            color: isDark ? Colors.white12 : Colors.grey.shade200,
                          ),
                      itemBuilder: (context, idx) {
                        final item = filteredDeptos[idx];
                        final name = item['name'] as String? ?? '';
                        final isSelected = _selectedDepartamento == name;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          leading: Icon(
                            name == 'Todos los departamentos'
                                ? Icons.public
                                : Icons.location_on_outlined,
                            color:
                                isSelected
                                    ? (isDark ? AppColors.accentColor : AppColors.primaryColor)
                                    : (isDark ? Colors.white60 : Colors.grey.shade600),
                          ),
                          title: Text(
                            name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                              color:
                                  isSelected
                                      ? (isDark ? AppColors.accentColor : AppColors.primaryColor)
                                      : (isDark ? Colors.white : Colors.grey.shade800),
                            ),
                          ),
                          trailing:
                              isSelected
                                  ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primaryColor,
                                  )
                                  : null,
                          onTap: () {
                            Navigator.pop(context);
                            _onDepartamentoChanged(name);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _callEmergencyLine() async {
    final uri = Uri.parse('tel:114');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Línea 114 disponible 24/7')),
        );
      }
    }
  }

  Future<void> _shareMissingPerson(Desaparecido d) async {
    final fullName = '${d.nombres} ${d.apellidos}'.trim();
    final location = '${d.distrito ?? ''}, ${d.departamento ?? ''}'.trim();
    final message =
        '🚨 *ALERTA PNP - PERSONA DESAPARECIDA* 🚨\n\n'
        '• Nombre: $fullName\n'
        '• Lugar: $location\n'
        '• Fecha: ${d.fechaDesaparicion != null ? '${d.fechaDesaparicion!.day}/${d.fechaDesaparicion!.month}/${d.fechaDesaparicion!.year}' : 'Reciente'}\n\n'
        'Si tienes alguna pista o información sobre su paradero, comunícate de inmediato a la *Línea Gratuita 114* de la Policía Nacional del Perú o a través de la aplicación Alerta Desaparecidos.\n\n'
        '¡Tu ayuda puede salvar una vida!';

    final String? notaAlertaUrl = d.imagenFichaUrl?.isNotEmpty == true
        ? d.imagenFichaUrl
        : (d.fotoUrl?.isNotEmpty == true ? d.fotoUrl : null);

    await ShareHelper.shareCase(
      context: context,
      message: message,
      subject: 'Alerta PNP: $fullName',
      imageUrl: notaAlertaUrl,
    );
  }

  String _calculateElapsedDays(DateTime? date) {
    if (date == null) return 'Fecha no especificada';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(targetDate).inDays;

    if (difference <= 0) {
      return 'Desapareció hoy';
    } else if (difference == 1) {
      return 'Desapareció hace 1 día';
    } else {
      return 'Desapareció hace $difference días';
    }
  }

  int? _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return (age > 0 && age <= 120) ? age : null;
  }

  /// Calcula y memoriza el ordenamiento y filtrado de desaparecidos.
  /// Si la lista original y los filtros no han cambiado, retorna la lista en caché en O(1)
  /// eliminando el consumo de CPU durante el scroll y las animaciones.
  List<Desaparecido> _computeFilteredList(List<Desaparecido> rawList) {
    if (_cachedFilteredList != null &&
        identical(rawList, _lastRawList) &&
        _selectedDepartamento == _lastSelectedDepartamento &&
        _selectedProvincia == _lastSelectedProvincia &&
        _currentQuickFilter == _lastQuickFilter &&
        _userProvincia == _lastUserProvincia) {
      return _cachedFilteredList!;
    }

    _lastRawList = rawList;
    _lastSelectedDepartamento = _selectedDepartamento;
    _lastSelectedProvincia = _selectedProvincia;
    _lastQuickFilter = _currentQuickFilter;
    _lastUserProvincia = _userProvincia;

    List<Desaparecido> listToDisplay = List.from(rawList);

    // 🏛️ 1. FILTRADO ESTRICTO POR DEPARTAMENTO
    if (_selectedDepartamento != null &&
        _selectedDepartamento!.isNotEmpty &&
        _selectedDepartamento != 'Todos los departamentos' &&
        _selectedDepartamento != 'Todos') {
      listToDisplay = listToDisplay.where((d) {
        return PeruLocations.matchesDepartment(
          caseDept: d.departamento,
          targetDept: _selectedDepartamento!,
          caseProv: d.provincia,
          caseDist: d.distrito,
        );
      }).toList();
    }

    // 🏙️ 2. FILTRADO POR PROVINCIA ESPECÍFICA SELECCIONADA
    if (_selectedProvincia != null &&
        _selectedProvincia!.isNotEmpty &&
        _selectedProvincia != 'Todas las provincias' &&
        _selectedProvincia != 'Todas') {
      listToDisplay = listToDisplay.where((d) {
        return PeruLocations.matchesProvince(
          caseProv: d.provincia,
          caseDist: d.distrito,
          caseDetalles: d.detallesAdicionales,
          targetProv: _selectedProvincia!,
        );
      }).toList();
    }

    // ⚡ 3. FILTROS RÁPIDOS
    if (_currentQuickFilter == MissingQuickFilter.miProvincia &&
        _userProvincia != null &&
        _userProvincia!.isNotEmpty) {
      listToDisplay = listToDisplay.where((d) {
        return PeruLocations.matchesProvince(
          caseProv: d.provincia,
          caseDist: d.distrito,
          caseDetalles: d.detallesAdicionales,
          targetProv: _userProvincia!,
        );
      }).toList();
    } else if (_currentQuickFilter == MissingQuickFilter.menoresAmber) {
      listToDisplay = listToDisplay.where((d) {
        final age = d.edadCalculada ?? _calculateAge(d.fechaNacimiento);
        return age != null && age > 0 && age < 18;
      }).toList();
    } else if (_currentQuickFilter == MissingQuickFilter.recientes48h) {
      final now = DateTime.now();
      listToDisplay = listToDisplay.where((d) {
        if (d.fechaDesaparicion == null) return false;
        return now.difference(d.fechaDesaparicion!).inHours <= 48;
      }).toList();
    }

    // 🛡️ 4. DEDUPLICACIÓN DEFENSIVA GARANTIZADA (CERO DUPLICADOS EN PANTALLA)
    final Set<String> seenIds = <String>{};
    final Set<String> seenDnis = <String>{};
    final Set<String> seenKeys = <String>{};
    final List<Desaparecido> deduplicated = [];

    for (final d in listToDisplay) {
      final id = d.id?.trim();
      final dni = d.dni?.trim();
      final normName = PeruLocations.normalize('${d.nombres} ${d.apellidos}');
      final normDept = PeruLocations.normalize(d.departamento ?? '');
      final key = '$normName|$normDept';

      if (id != null && id.isNotEmpty && !seenIds.add(id)) continue;
      if (dni != null && dni.isNotEmpty && dni.length >= 8 && !seenDnis.add(dni)) continue;
      if (normName.isNotEmpty && !seenKeys.add(key)) continue;

      deduplicated.add(d);
    }
    listToDisplay = deduplicated;

    // 🚨 5. PRIORIDAD ABSOLUTA: Casos más recientes siempre al inicio (orden cronológico descendente)
    listToDisplay.sort((a, b) {
      final dateA = a.fechaDesaparicion ?? DateTime(2000);
      final dateB = b.fechaDesaparicion ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    _cachedFilteredList = listToDisplay;
    return listToDisplay;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final bgColor = isDark ? const Color(0xFF090D16) : AppColors.backgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // 🔴 HEADER DE EMERGENCIA POLICIAL CON BOTÓN 114
              _buildTopEmergencyHeader(strings),

              // 🎛️ PANEL DE CONTROL FIJO Y FILTROS DOCK (DIFERENCIADO DEL ÁREA DESPLAZABLE)
              _buildDockedControlPanel(isDark, strings),

              // 📋 LISTA DE TARJETAS DE PERSONAS DESAPARECIDAS (ALTO IMPACTO)
              Expanded(
                child: Consumer<ViewMissingViewModel>(
                  builder: (context, vm, child) {
                    if (vm.state == RequestState.Loading &&
                        vm.desaparecidos.isEmpty) {
                      return const Center(
                        child: BrandedLoadingWidget(
                          message: 'Consultando base de datos PNP...',
                          submessage: 'Sincronizando alertas oficiales en tiempo real',
                          size: 64,
                        ),
                      );
                    }

                    if (vm.state == RequestState.Error) {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.all(20.0),
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: Colors.red.shade700,
                                size: 40,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Error al cargar: ${vm.message}',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _fetchDataWithCurrentFilters,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Reintentar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Aplicar filtro rápido y de provincia con caché O(1) memoizada
                    final List<Desaparecido> listToDisplay = _computeFilteredList(vm.desaparecidos);
                    if (listToDisplay.length < 8 &&
                        vm.hasMoreData &&
                        !vm.isLoadingMore &&
                        vm.state == RequestState.Loaded) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) vm.loadMoreMissingPeople();
                      });
                    }

                    if (listToDisplay.isEmpty &&
                        vm.state != RequestState.Loading) {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.all(24.0),
                          padding: const EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.borderSubtle,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                color: Colors.grey.shade400,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                strings.noActiveCasesFound,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.policeNavy,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? (strings.isQuechua
                                        ? 'Manam kaywan kuskachasqa kanchu: "${_searchController.text}".'
                                        : 'No hay registros coincidentes con "${_searchController.text}".')
                                    : strings.noActiveCasesFilter,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth > 700;
                        if (isDesktop) {
                          return Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1400),
                              child: GridView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 440,
                                  mainAxisExtent: 535,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount:
                                    listToDisplay.length + (vm.isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == listToDisplay.length) {
                                    return Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.red.shade600,
                                        ),
                                        strokeWidth: 2.5,
                                      ),
                                    );
                                  }

                                  final desaparecido = listToDisplay[index];
                                  return _buildUrgentMissingPersonCard(
                                    desaparecido,
                                    index + 1,
                                    listToDisplay.length,
                                    isGrid: true,
                                  );
                                },
                              ),
                            ),
                          );
                        }

                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
                              itemCount:
                                  listToDisplay.length + (vm.isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == listToDisplay.length) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.red.shade600,
                                        ),
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  );
                                }

                                final desaparecido = listToDisplay[index];
                                return _buildUrgentMissingPersonCard(
                                  desaparecido,
                                  index + 1,
                                  listToDisplay.length,
                                  isGrid: false,
                                );
                              },
                            ),
                          ),
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
    );
  }

  /// 🔴 Header de Emergencia Policial (Fijo)
  Widget _buildTopEmergencyHeader(AppStrings strings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: AppColors.policeHeroGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.25),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.crisis_alert_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.isQuechua ? 'SUYUPI MASKAY LLIKA' : 'RED NACIONAL DE BÚSQUEDA',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      strings.isQuechua ? 'Utqay Willakuykuna • PNP Alerta' : 'Casos Activos • Alerta Inmediata PNP',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _callEmergencyLine,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone, color: Colors.white, size: 14),
                      SizedBox(width: 5),
                      Text(
                        '114',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🎛️ Panel de Control Pinned / Docked (Filtros, Búsqueda y Región)
  Widget _buildDockedControlPanel(bool isDark, AppStrings strings) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          // Fila de Búsqueda y Selector de Departamento
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.borderSubtle,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: _isSearching
                        ? AppColors.primaryColor
                        : (isDark ? Colors.white60 : Colors.grey.shade500),
                    size: 21,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      inputFormatters: [UpperCaseTextFormatter()],
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFF8FAFC) : AppColors.policeNavy,
                      ),
                      decoration: InputDecoration(
                        hintText: strings.searchHint,
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                          fontSize: 12.5,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      color: isDark ? Colors.white60 : Colors.grey.shade500,
                      onPressed: _clearSearch,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 6),
                  // Botón Departamento
                  InkWell(
                    onTap: _showDepartmentPickerModal,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : AppColors.primaryColor.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 13,
                            color: isDark ? AppColors.accentColor : AppColors.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 85),
                            child: Text(
                              _selectedDepartamento == null ||
                                      _selectedDepartamento == 'Todos los departamentos'
                                  ? strings.allOption
                                  : _selectedDepartamento!.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.primaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 16,
                            color: isDark ? Colors.white70 : AppColors.primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Chips de Provincia si hay departamento seleccionado
          if (_selectedDepartamento != null &&
              _selectedDepartamento != 'Todos los departamentos' &&
              _selectedDepartamento != 'Todos') ...[
            Builder(
              builder: (context) {
                final provincias = PeruLocations.getProvincias(_selectedDepartamento!);
                if (provincias.isEmpty) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: strings.allProvinces,
                          icon: Icons.done_all_rounded,
                          isActive: _selectedProvincia == null ||
                              _selectedProvincia == 'Todas las provincias' ||
                              _selectedProvincia == 'Todas',
                          onTap: () {
                            setState(() {
                              _selectedProvincia = null;
                              _cachedFilteredList = null;
                            });
                            _fetchDataWithCurrentFilters();
                          },
                        ),
                        const SizedBox(width: 6),
                        ...provincias.map((prov) {
                          final isSelected = _selectedProvincia != null &&
                              PeruLocations.normalize(_selectedProvincia!) ==
                                  PeruLocations.normalize(prov);
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _buildFilterChip(
                              label: prov,
                              icon: null,
                              isActive: isSelected,
                              badgeColor: isDark ? AppColors.accentColor : AppColors.policeNavy,
                              onTap: () {
                                setState(() {
                                  _selectedProvincia = isSelected ? null : prov;
                                  _cachedFilteredList = null;
                                });
                                _fetchDataWithCurrentFilters();
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],

          // ⚡ CHIPS DE FILTRADO TÁCTICO RÁPIDO (Menores Amber, Recientes 48h, Mi Zona)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  _buildFilterChip(
                    label: strings.isQuechua ? 'Llapan' : 'Todos (8 meses)',
                    icon: Icons.layers_rounded,
                    isActive: _currentQuickFilter == MissingQuickFilter.todos,
                    onTap: () {
                      setState(() {
                        _currentQuickFilter = MissingQuickFilter.todos;
                        _cachedFilteredList = null;
                      });
                      _fetchDataWithCurrentFilters();
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: strings.isQuechua ? 'Erqekuna (Amber)' : 'Menores (Alerta Amber)',
                    icon: Icons.child_care_rounded,
                    isActive: _currentQuickFilter == MissingQuickFilter.menoresAmber,
                    badgeColor: Colors.amber.shade700,
                    onTap: () {
                      setState(() {
                        _currentQuickFilter = _currentQuickFilter == MissingQuickFilter.menoresAmber
                            ? MissingQuickFilter.todos
                            : MissingQuickFilter.menoresAmber;
                        _cachedFilteredList = null;
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: strings.isQuechua ? '48 pacha' : 'Últimas 48h',
                    icon: Icons.bolt_rounded,
                    isActive: _currentQuickFilter == MissingQuickFilter.recientes48h,
                    badgeColor: Colors.red.shade600,
                    onTap: () {
                      setState(() {
                        _currentQuickFilter = _currentQuickFilter == MissingQuickFilter.recientes48h
                            ? MissingQuickFilter.todos
                            : MissingQuickFilter.recientes48h;
                        _cachedFilteredList = null;
                      });
                    },
                  ),
                  if (_userProvincia != null && _userProvincia!.trim().isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      label: 'Mi Provincia (${_userProvincia!})',
                      icon: Icons.my_location_rounded,
                      isActive: _currentQuickFilter == MissingQuickFilter.miProvincia,
                      badgeColor: Colors.teal.shade600,
                      onTap: () {
                        setState(() {
                          _currentQuickFilter = _currentQuickFilter == MissingQuickFilter.miProvincia
                              ? MissingQuickFilter.todos
                              : MissingQuickFilter.miProvincia;
                          _cachedFilteredList = null;
                        });
                        _fetchDataWithCurrentFilters();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 📌 LÍNEA DE DEMARCACIÓN DOCK (Diferencia claramente el panel fijo de la lista deslizable)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4.5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B132B) : const Color(0xFFEDF2F7),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.push_pin_rounded,
                      size: 11,
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      strings.fixedFilterPanel,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.swipeDownToSee,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    required bool isActive,
    required VoidCallback onTap,
    Color? badgeColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = badgeColor ?? (isDark ? AppColors.accentColor : AppColors.primaryColor);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              isActive
                  ? activeColor.withValues(alpha: isDark ? 0.25 : 0.15)
                  : (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.8) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isActive
                    ? activeColor
                    : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.grey.shade300),
            width: isActive ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isActive ? activeColor : (isDark ? Colors.white60 : Colors.grey.shade600),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? activeColor : (isDark ? Colors.white70 : Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔴 TARJETA DE IMPACTO Y URGENCIA PARA DESAPARECIDOS (DIFERENCIA CLARA: FICHA vs BOTONES)
  Widget _buildUrgentMissingPersonCard(
    Desaparecido desaparecido,
    int currentIndex,
    int totalCount, {
    bool isGrid = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final int? edad = desaparecido.edadCalculada ?? _calculateAge(desaparecido.fechaNacimiento);
    final bool isMinor = edad != null && edad > 0 && edad < 18;
    final String fullName =
        '${desaparecido.nombres} ${desaparecido.apellidos}'.trim().toUpperCase();
    final String location =
        '${desaparecido.distrito ?? ''}, ${desaparecido.departamento ?? ''}'
            .replaceAll(RegExp(r'^,\s*|,\s*$'), '')
            .toUpperCase();

    final bool isUserProximity = (_userProvincia != null &&
            _userProvincia!.isNotEmpty &&
            desaparecido.provincia != null &&
            desaparecido.provincia!.toUpperCase().trim() == _userProvincia!.toUpperCase().trim()) ||
        (_userDepartamento != null &&
            _userDepartamento!.isNotEmpty &&
            desaparecido.departamento != null &&
            desaparecido.departamento!.toUpperCase().trim() == _userDepartamento!.toUpperCase().trim());

    return RepaintBoundary(
      child: Container(
        margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.95) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isMinor
              ? (isDark ? Colors.amber.shade400.withValues(alpha: 0.7) : Colors.amber.shade400)
              : (isDark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFE2E8F0)),
          width: isMinor ? 1.6 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.40)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Tira superior de urgencia
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isMinor
                    ? [const Color(0xFFB91C1C), const Color(0xFFD97706)]
                    : [const Color(0xFFB91C1C), const Color(0xFFDC2626)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(21),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    isMinor
                        ? (strings.isQuechua ? '🚨 AMBER WILLAY • ERQE / WAMRA' : '🚨 ALERTA AMBER • MENOR DE EDAD')
                        : (strings.isQuechua ? '🔴 UTQAY WILLAY • POLICIA' : '🔴 CASO ACTIVO • ALERTA POLICIAL'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _calculateElapsedDays(desaparecido.fechaDesaparicion),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // 2. Foto destacada con accesos directos
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MissingPersonDetailsScreen(
                    desaparecido: desaparecido,
                  ),
                ),
              );
            },
            child: Stack(
              children: [
                // Contenedor de la foto con caché de alto rendimiento y límite de RAM
                Container(
                  height: 210,
                  width: double.infinity,
                  color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                  child: AppCachedImage(
                    imageUrl: desaparecido.fotoUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 600,
                    memCacheHeight: 450,
                    errorWidget: _buildCardPhotoPlaceholder(desaparecido, isDark),
                  ),
                ),

                // Gradiente en la parte inferior de la foto
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                ),

                // Badge de Fase Crítica (< 72 Horas)
                if (desaparecido.fechaDesaparicion != null &&
                    DateTime.now().difference(desaparecido.fechaDesaparicion!).inHours >= 0 &&
                    DateTime.now().difference(desaparecido.fechaDesaparicion!).inHours < 72)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, color: Colors.amberAccent, size: 14),
                          SizedBox(width: 3),
                          Text(
                            '< 72h CRÍTICO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Botón e indicador de ampliar foto o ficha
                Positioned(
                  top: 10,
                  right: 10,
                  child: InkWell(
                    onTap: () {
                      final targetImg = (desaparecido.fotoUrl != null && desaparecido.fotoUrl!.isNotEmpty)
                          ? desaparecido.fotoUrl!
                          : (desaparecido.imagenFichaUrl?.isNotEmpty == true ? desaparecido.imagenFichaUrl! : null);
                      if (targetImg != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FullScreenImageScreen(
                              imageUrl: targetImg,
                              fallbackImageUrl: desaparecido.imagenFichaUrl,
                              heroTag: 'photo_${desaparecido.id}',
                            ),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white30, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (desaparecido.fotoUrl != null && desaparecido.fotoUrl!.isNotEmpty)
                                ? Icons.zoom_in_rounded
                                : Icons.description_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (desaparecido.fotoUrl != null && desaparecido.fotoUrl!.isNotEmpty)
                                ? strings.zoomIn
                                : 'Ver Ficha',
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Contador de índice
                Positioned(
                  bottom: 8,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      strings.caseIndexCounter(currentIndex, totalCount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Encabezado de Identidad y Botón de Acceso a Ficha
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MissingPersonDetailsScreen(
                    desaparecido: desaparecido,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: fullName,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.policeNavy,
                          letterSpacing: 0.2,
                        ),
                        children: [
                          if (edad != null && edad > 0) ...[
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: '($edad)',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? (isMinor ? const Color(0xFFFFB74D) : const Color(0xFF38BDF8))
                                    : (isMinor ? const Color(0xFFD97706) : const Color(0xFF0284C7)),
                              ),
                            ),
                          ],
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                          : const Color(0xFF0284C7).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF38BDF8).withValues(alpha: 0.35)
                            : const Color(0xFF0284C7).withValues(alpha: 0.30),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          strings.viewFile,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. FICHA DE DATOS POLICIALES (Contenedor sombreado NO interactivo que agrupa toda la información)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.75) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.badge_rounded, size: 12, color: isDark ? Colors.white38 : Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      strings.alertDataTitle,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: isDark ? Colors.white38 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _buildStaticDataBadge(
                      icon: Icons.cake_rounded,
                      label: edad != null ? '$edad ${strings.ageYears.toUpperCase()}' : 'EDAD N/D',
                      color: isMinor ? Colors.amber.shade800 : AppColors.policeBlue,
                      isDark: isDark,
                    ),
                    if (desaparecido.sexo != null && desaparecido.sexo!.isNotEmpty)
                      _buildStaticDataBadge(
                        icon: Icons.person_outline_rounded,
                        label: desaparecido.sexo!.toUpperCase(),
                        color: isDark ? Colors.tealAccent.shade200 : Colors.blueGrey,
                        isDark: isDark,
                      ),
                    if (desaparecido.fechaDesaparicion != null)
                      _buildStaticDataBadge(
                        icon: Icons.calendar_today_rounded,
                        label: '${desaparecido.fechaDesaparicion!.day}/${desaparecido.fechaDesaparicion!.month}/${desaparecido.fechaDesaparicion!.year}',
                        color: isDark ? Colors.redAccent.shade100 : Colors.red.shade700,
                        isDark: isDark,
                      ),
                    if (isUserProximity)
                      _buildStaticDataBadge(
                        icon: Icons.near_me_rounded,
                        label: strings.inYourZone(desaparecido.distrito ?? desaparecido.provincia ?? (strings.isQuechua ? 'Sispan' : 'Cerca')),
                        color: const Color(0xFF059669),
                        isDark: isDark,
                      ),
                  ],
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 13, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (desaparecido.unidadACargo != null && desaparecido.unidadACargo!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 12, color: isDark ? Colors.lightBlueAccent : AppColors.policeBlue),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          (() {
                            final u = desaparecido.unidadACargo!;
                            final uUpper = u.toUpperCase();
                            if (uUpper.contains("POLICÍA NACIONAL DEL PERÚ") ||
                                uUpper.contains("POLICIA NACIONAL DEL PERU") ||
                                uUpper.contains("DEPINCRI") ||
                                uUpper.contains("DIVINCRI") ||
                                uUpper.contains("FAMILIA") ||
                                uUpper.contains("TRANSITO") ||
                                uUpper.contains("TRÁNSITO") ||
                                uUpper.contains("EMERGENCIA") ||
                                uUpper.contains("DIVINTRAP") ||
                                uUpper.contains("DIRITPTIM")) {
                              return (desaparecido.distrito != null && desaparecido.distrito!.trim().isNotEmpty)
                                  ? 'Comisaría PNP ${desaparecido.distrito}'
                                  : 'Comisaría PNP de la Jurisdicción';
                            }
                            return u;
                          })(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // 5. BARRA DE BOTONES DE ACCIÓN (100% Inconfundibles con información estática)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                // Botón Primario: Aportar Pista
                Expanded(
                  flex: 3,
                  child: ScaleOnTap(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MissingPersonDetailsScreen(
                            desaparecido: desaparecido,
                            autoOpenPista: true,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? const [Color(0xFF0284C7), Color(0xFF0369A1)]
                              : const [Color(0xFF0284C7), Color(0xFF0C4A6E)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.remove_red_eye_rounded, size: 15, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            strings.isQuechua ? 'Willakuyta Qoy' : 'APORTAR PISTA',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11.5,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Botón Secundario: Compartir
                ScaleOnTap(
                  onTap: () => _shareMissingPerson(desaparecido),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade300,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share_rounded, size: 15, color: isDark ? Colors.white : AppColors.policeNavy),
                        const SizedBox(width: 4),
                        Text(
                          strings.share,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.policeNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),
                // Botón Emergencia: Línea 114
                ScaleOnTap(
                  onTap: _callEmergencyLine,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.red.shade900.withValues(alpha: 0.35) : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.shade400.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_in_talk_rounded, size: 14, color: isDark ? Colors.red.shade300 : Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '114',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildCardPhotoPlaceholder(Desaparecido desaparecido, bool isDark) {
    final int? edad = desaparecido.edadCalculada ?? _calculateAge(desaparecido.fechaNacimiento);
    final bool isMinor = edad != null && edad > 0 && edad < 18;
    return Container(
      color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMinor ? Icons.child_care_rounded : Icons.person_rounded,
                size: 48,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Foto no disponible',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticDataBadge({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
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
