import '../../../services/gps_location_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_found_view_model.dart';
import 'package:alerta_desaparecidos/domain/entities/desaparecido.dart';
import 'package:alerta_desaparecidos/common/state_enum.dart';
import 'package:alerta_desaparecidos/helpers/database_helpers.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alerta_desaparecidos/helpers/share_helper.dart';
import 'found_person_details_screen.dart';
import 'full_screen_image_screen.dart';
import 'package:alerta_desaparecidos/common/styles/app_colors.dart';
import 'package:alerta_desaparecidos/presentation/common_widgets/scale_on_tap.dart';
import 'package:alerta_desaparecidos/common/localization/app_strings.dart';
import 'package:alerta_desaparecidos/presentation/common_widgets/app_cached_image.dart';

class ViewFoundScreen extends StatefulWidget {
  const ViewFoundScreen({super.key});

  @override
  State<ViewFoundScreen> createState() => _ViewFoundScreenState();
}

class _ViewFoundScreenState extends State<ViewFoundScreen>
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
  String? _userDepartamento;
  final DatabaseHelper _dbHelper = DatabaseHelper();

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

    try {
      // 1. SharedPreferences primero (inmediato)
      final prefs = await SharedPreferences.getInstance();
      departamentoDelUsuario = prefs.getString('user_departamento') ??
          prefs.getString('user_department') ??
          prefs.getString(GpsLocationService.keyUserDept);

      // 2. Fallback a GpsLocationService
      if (departamentoDelUsuario == null || departamentoDelUsuario.isEmpty) {
        final loc = await GpsLocationService.getSavedLocation();
        if (loc != null) {
          departamentoDelUsuario = loc.departamento;
        }
      }

      // 3. Fallback a Firestore
      final user = FirebaseAuth.instance.currentUser;
      final bool needsDeptFromFirestore = departamentoDelUsuario == null || departamentoDelUsuario.isEmpty;
      if (needsDeptFromFirestore && user != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('ciudadanos')
                .doc(user.uid)
                .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          departamentoDelUsuario = userData?['departamento'] as String?;
        }
      }
    } catch (e) {
      debugPrint('[USER] Error al obtener departamento: $e');
    }

    if (!mounted) return;

    _userDepartamento = departamentoDelUsuario;

    if (departamentoDelUsuario != null && _departamentosData.isNotEmpty) {
      final departamentosReales =
          _departamentosData
              .where((d) => d['name'] != 'Todos los departamentos')
              .toList();

      final match = departamentosReales.firstWhere(
        (d) => GpsLocationService.matches(
          d['name']?.toString() ?? '',
          departamentoDelUsuario!,
        ),
        orElse: () => <String, dynamic>{},
      );

      if (match.isNotEmpty && match['name'] != null) {
        setState(() {
          _selectedDepartamento = match['name'] as String;
        });
      } else {
        setState(() {
          _selectedDepartamento = 'Todos los departamentos';
        });
      }
    } else {
      setState(() {
        _selectedDepartamento = 'Todos los departamentos';
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
      Provider.of<ViewFoundViewModel>(
        context,
        listen: false,
      ).loadMoreFoundPeople();
    }
  }

  void _fetchDataWithCurrentFilters() {
    final String? departamentoParaFiltrar =
        (_selectedDepartamento == null ||
         _selectedDepartamento == 'Todos los departamentos' ||
         _selectedDepartamento == 'TODOS LOS DEPARTAMENTOS' ||
         _selectedDepartamento == 'Todos')
            ? null
            : _selectedDepartamento;

    final String? searchQuery =
        _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim();

    Provider.of<ViewFoundViewModel>(context, listen: false).getFoundPeople(
      forceRefresh: true,
      searchQuery: searchQuery,
      departamento: departamentoParaFiltrar,
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
    try {
      final data = await _dbHelper.getDepartamentos();
      if (mounted) {
        setState(() {
          _departamentosData = [
            {'name': 'Todos los departamentos'},
            ...data,
          ];
        });
      }
    } catch (e) {
      debugPrint('Error al cargar departamentos: $e');
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

  void _showDepartmentPickerModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                            color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Casos Resueltos por Región',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF064E3B),
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
                          borderRadius: BorderRadius.circular(14),
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
                  Divider(
                    height: 1,
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filteredDeptos.length,
                      separatorBuilder:
                          (_, __) => Divider(
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200,
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
                                : Icons.place_rounded,
                            color:
                                isSelected
                                    ? const Color(0xFF10B981)
                                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
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
                                      ? const Color(0xFF10B981)
                                      : (isDark ? Colors.white : Colors.grey.shade800),
                            ),
                          ),
                          trailing:
                              isSelected
                                  ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF10B981),
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

  Future<void> _shareFoundPerson(Desaparecido d) async {
    final fullName = '${d.nombres} ${d.apellidos}'.trim();
    final location = '${d.distrito ?? ''}, ${d.departamento ?? ''}'.trim();
    final message =
        '💚 *¡GRAN NOTICIA! PERSONA LOCALIZADA Y A SALVO* 💚\n\n'
        '• Nombre: $fullName\n'
        '• Región: $location\n\n'
        'Gracias al trabajo coordinado de la Policía Nacional del Perú y al apoyo de la ciudadanía, el caso ha sido resuelto favorablemente.\n\n'
        '¡Celebramos cada reencuentro familiar!';

    await ShareHelper.shareCase(
      context: context,
      message: message,
      subject: 'Persona Localizada: $fullName',
    );
  }

  int? _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.backgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // 🟢 1. HEADER TRIUNFAL FIJO (Celebración y alivio)
              _buildTopCelebrationHeader(isDark, strings),

              // 🎛️ 2. PANEL DE CONTROL FIJO (DOCK SUPERIOR)
              _buildDockedControlPanel(isDark, strings),

              // 📋 3. LISTA DESPLAZABLE DE CASOS RESUELTOS Y ENCONTRADOS
              Expanded(
                child: Consumer<ViewFoundViewModel>(
                  builder: (context, vm, child) {
                    if (vm.state == RequestState.Loading &&
                        vm.desaparecidos.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF059669),
                              ),
                              strokeWidth: 3.0,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Cargando casos resueltos...',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
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
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _fetchDataWithCurrentFilters,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Reintentar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (vm.desaparecidos.isEmpty &&
                        vm.state != RequestState.Loading) {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.all(24.0),
                          padding: const EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.10) : AppColors.borderSubtle,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.sentiment_neutral_rounded,
                                color: Color(0xFF10B981),
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                strings.noFoundPersonsFound,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF064E3B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? (strings.isQuechua
                                        ? 'Manam kaywan kuskachasqa kanchu: "${_searchController.text}".'
                                        : 'No hay registros coincidentes con "${_searchController.text}".')
                                    : strings.noRecordsInDept,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
                                  mainAxisExtent: 510,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount:
                                    vm.desaparecidos.length + (vm.isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == vm.desaparecidos.length) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFF059669),
                                        ),
                                        strokeWidth: 2.5,
                                      ),
                                    );
                                  }

                                  final desaparecido = vm.desaparecidos[index];
                                  return _buildJoyfulFoundPersonCard(
                                    desaparecido,
                                    index + 1,
                                    vm.desaparecidos.length,
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
                                  vm.desaparecidos.length + (vm.isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == vm.desaparecidos.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFF059669),
                                        ),
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  );
                                }

                                final desaparecido = vm.desaparecidos[index];
                                return _buildJoyfulFoundPersonCard(
                                  desaparecido,
                                  index + 1,
                                  vm.desaparecidos.length,
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

  // 🟢 1. HEADER TRIUNFAL FIJO (Celebración y alivio)
  Widget _buildTopCelebrationHeader(bool isDark, AppStrings strings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF042F2E), // Deep Teal/Emerald
                  const Color(0xFF064E3B), // Forest Emerald
                  const Color(0xFF047857), // Vivid Emerald
                ]
              : [
                  const Color(0xFF064E3B), // Deep Emerald Green
                  const Color(0xFF047857), // Forest Emerald
                  const Color(0xFF059669), // Vivid Emerald
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : const Color(0xFF047857).withValues(alpha: 0.35),
            blurRadius: 12,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFFFFD700),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.isQuechua ? 'TARISQA HINASPA ALLINLLA RUNAKUNA' : '¡PERSONAS LOCALIZADAS Y A SALVO!',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strings.isQuechua ? 'Ayllunkuwan kuska kashanku • Kusisqa willakuy' : 'Celebrando familias reunidas y esperanza cumplida',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
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

  // 🎛️ 2. PANEL DE CONTROL FIJO (DOCK SUPERIOR)
  Widget _buildDockedControlPanel(bool isDark, AppStrings strings) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? const Color(0xFF10B981).withValues(alpha: 0.35)
                : const Color(0xFF10B981).withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.40)
                : Colors.black.withValues(alpha: 0.06),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          // Barra de Búsqueda y Departamento Selector
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF10B981).withValues(alpha: 0.35)
                      : const Color(0xFF10B981).withValues(alpha: 0.25),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: _isSearching
                        ? const Color(0xFF10B981)
                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      inputFormatters: [UpperCaseTextFormatter()],
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF064E3B),
                      ),
                      decoration: InputDecoration(
                        hintText: strings.searchHint,
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                          fontSize: 13,
                          fontWeight: FontWeight.normal,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                      onPressed: _clearSearch,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: _showDepartmentPickerModal,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.40 : 0.30),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
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
                                color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 16,
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botón rápido "Mi Región" si aplica
          if (_userDepartamento != null && _userDepartamento!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Row(
                children: [
                  ScaleOnTap(
                    onTap: () {
                      _onDepartamentoChanged(
                        _selectedDepartamento?.toUpperCase() ==
                                _userDepartamento!.toUpperCase()
                            ? 'Todos los departamentos'
                            : _userDepartamento,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: _selectedDepartamento?.toUpperCase() ==
                                _userDepartamento!.toUpperCase()
                            ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.18)
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedDepartamento?.toUpperCase() ==
                                  _userDepartamento!.toUpperCase()
                              ? const Color(0xFF10B981)
                              : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.grey.shade300),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.place_rounded,
                            size: 13,
                            color: _selectedDepartamento?.toUpperCase() ==
                                    _userDepartamento!.toUpperCase()
                                ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            strings.myRegionLabel(_userDepartamento!.toUpperCase()),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _selectedDepartamento?.toUpperCase() ==
                                      _userDepartamento!.toUpperCase()
                                  ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                                  : (isDark ? Colors.white70 : Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Total de personas ubicadas
          Consumer<ViewFoundViewModel>(
            builder: (context, vm, _) {
              final count = vm.totalCount > 0 ? vm.totalCount : vm.desaparecidos.length;
              final deptLabel = (_selectedDepartamento == null || _selectedDepartamento == 'Todos los departamentos')
                  ? (strings.isQuechua ? 'Perú suyuntinpi' : 'en todo el país')
                  : (strings.isQuechua ? '${_selectedDepartamento!.toUpperCase()} suyupi' : 'en ${_selectedDepartamento!.toUpperCase()}');
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, size: 13, color: Color(0xFF10B981)),
                          const SizedBox(width: 5),
                          Text(
                            strings.isQuechua ? '$count tarisqa runakuna ($deptLabel)' : '$count personas ubicadas $deptLabel',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PNP Oficial',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // 📌 LÍNEA DE DEMARCACIÓN DEL PANEL FIJO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3.5),
            color: isDark
                ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                : const Color(0xFFECFDF5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 11,
                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                ),
                const SizedBox(width: 5),
                Text(
                  '${strings.fixedFilterPanel} • ${strings.swipeDownToSeeFound}',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                  ),
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

  // 💚 TARJETA CELEBRATORIA DE PERSONA LOCALIZADA (ALEGRÍA Y ALIVIO)
  Widget _buildJoyfulFoundPersonCard(
    Desaparecido desaparecido,
    int currentIndex,
    int totalCount, {
    bool isGrid = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final int? edad = _calculateAge(desaparecido.fechaNacimiento);
    final String fullName =
        '${desaparecido.nombres} ${desaparecido.apellidos}'.trim().toUpperCase();
    final String location =
        '${desaparecido.distrito ?? ''}, ${desaparecido.departamento ?? ''}'
            .replaceAll(RegExp(r'^,\s*|,\s*$'), '')
            .toUpperCase();

    return RepaintBoundary(
      child: Container(
        margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.90) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? const Color(0xFF10B981).withValues(alpha: 0.35)
              : const Color(0xFF10B981).withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0xFF059669).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Tira superior de celebración y alivio
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF047857), // Forest
                  Color(0xFF10B981), // Emerald
                ],
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(23),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFFFFD700),
                  size: 15,
                ),
                const SizedBox(width: 7),
                Text(
                  strings.isQuechua ? '¡ALLINLLAM TARISQA KASHAN!' : '¡LOCALIZADO(A) SANO Y SALVO!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                if (desaparecido.fechaEncontrado != null)
                  Text(
                    '${desaparecido.fechaEncontrado!.day}/${desaparecido.fechaEncontrado!.month}/${desaparecido.fechaEncontrado!.year}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),

          // 2. Foto con insignia de caso cerrado favorablemente
          InkWell(
            onTap: () {
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
            child: Stack(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  color: isDark
                      ? const Color(0xFF064E3B).withValues(alpha: 0.25)
                      : const Color(0xFFECFDF5),
                  child: AppCachedImage(
                    imageUrl: desaparecido.fotoUrl,
                    fallbackImageUrl: desaparecido.imagenFichaUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 600,
                    memCacheHeight: 450,
                    errorWidget: const Center(
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ),

                // Gradiente inferior
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
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ),

                // Insignia dorada "Reunido con su familia"
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF064E3B).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFFD700),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: Color(0xFFFFD700),
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          strings.badgeASalvo,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Botón de ampliar foto
                Positioned(
                  top: 10,
                  right: 10,
                  child: InkWell(
                    onTap: () {
                      if (desaparecido.fotoUrl != null &&
                          desaparecido.fotoUrl!.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => FullScreenImageScreen(
                                  imageUrl: desaparecido.fotoUrl!,
                                  heroTag: 'found_${desaparecido.id}',
                                ),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fullscreen_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                // Contador de índice
                Positioned(
                  bottom: 8,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
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

          // 3. Contenido de la persona (Estructura Clara: Título con indicación, Datos en bloque Expediente, Botones de Acción táctiles)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre completo con affordance de pulsar
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FoundPersonDetailsScreen(
                          desaparecido: desaparecido,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          fullName,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF064E3B),
                            letterSpacing: 0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              strings.viewFile,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 9,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 📋 BLOQUE DE INFORMACIÓN / EXPEDIENTE DE LOCALIZACIÓN (Datos de solo lectura)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'EXPEDIENTE DE LOCALIZACIÓN',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (edad != null)
                            _buildSuccessChip(
                              icon: Icons.cake_rounded,
                              text: '$edad ${strings.ageYears.toUpperCase()}',
                              isDark: isDark,
                            ),
                          if (desaparecido.sexo != null &&
                              desaparecido.sexo!.isNotEmpty)
                            _buildSuccessChip(
                              icon: Icons.person_outline_rounded,
                              text: desaparecido.sexo!.toUpperCase(),
                              isDark: isDark,
                            ),
                          if (location.isNotEmpty)
                            _buildSuccessChip(
                              icon: Icons.place_rounded,
                              text: location,
                              isDark: isDark,
                            ),
                        ],
                      ),
                      if (desaparecido.encontradoDetalles != null &&
                          desaparecido.encontradoDetalles!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                                : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.celebration_rounded,
                                size: 14,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  desaparecido.encontradoDetalles!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ⚡ BARRA DE BOTONES DE ACCIÓN (Clara diferenciación táctil)
                Row(
                  children: [
                    // Botón principal: Ver Ficha Completa (Elevado, gradiente verde, 3D shadow)
                    Expanded(
                      child: ScaleOnTap(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FoundPersonDetailsScreen(
                                desaparecido: desaparecido,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF059669), Color(0xFF10B981)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF059669).withValues(alpha: 0.40),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.assignment_turned_in_rounded, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                strings.viewFullFile,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  color: Colors.white,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Botón secundario: Compartir (Borde marcado y fondo interactivo)
                    ScaleOnTap(
                      onTap: () => _shareFoundPerson(desaparecido),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.5),
                            width: 1.3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.3)
                                  : Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.share_rounded,
                              size: 15,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              strings.share,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildSuccessChip({
    required IconData icon,
    required String text,
    bool isDark = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.45 : 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
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
