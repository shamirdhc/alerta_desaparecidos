import '../../../services/gps_location_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../helpers/database_helpers.dart';
import '../../../helpers/share_helper.dart';
import '../../../common/state_enum.dart';
import '../../../domain/entities/desaparecido.dart';
import '../view_models/police_manage_missing_view_model.dart';
import '../../../domain/enums.dart';
import 'missing_details_screen.dart';
import 'report_desaparecido_screen.dart';
import '../../citizen/screens/full_screen_image_screen.dart';
import '../../common_widgets/theme_sun_moon_toggle.dart';
import '../../common_widgets/app_cached_image.dart';

class PoliceManageMissingScreen extends StatefulWidget {
  const PoliceManageMissingScreen({super.key});

  @override
  State<PoliceManageMissingScreen> createState() =>
      _PoliceManageMissingScreenState();
}

class _PoliceManageMissingScreenState extends State<PoliceManageMissingScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Filtros
  String? _selectedDepartamento;
  List<Map<String, dynamic>> _departamentos = [];

  // Dashboard
  bool _showDashboard = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  Future<void> _initializeScreen() async {
    await _loadDepartamentos();
    if (!mounted) return;
    await _getPoliceDepartamento();
    if (!mounted) return;
    final viewModel = Provider.of<PoliceManageMissingViewModel>(
      context,
      listen: false,
    );
    viewModel.loadMissingCases(forceRefresh: true);
  }

  Future<void> _loadDepartamentos() async {
    try {
      final dbHelper = DatabaseHelper();
      final data = await dbHelper.getDepartamentos();

      if (!mounted) return;
      setState(() {
        _departamentos = [
          {'name': 'TODOS LOS DEPARTAMENTOS'},
          ...data.map((d) => {'name': d['name'].toString().toUpperCase()}),
        ];
      });
    } catch (e) {
      debugPrint('Error loading departamentos: $e');
    }
  }

  Future<void> _getPoliceDepartamento() async {
    try {
      String? departamento;
      final loc = await GpsLocationService.getSavedLocation();
      if (loc != null) {
        departamento = loc.departamento;
      }

      final user = FirebaseAuth.instance.currentUser;
      if ((departamento == null || departamento.isEmpty) && user != null) {
        final doc = await FirebaseFirestore.instance.collection('policias').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          departamento = doc.data()!['departamento'] as String?;
        }

        if ((departamento == null || departamento.isEmpty) && user.phoneNumber != null) {
          final policeDoc = await FirebaseFirestore.instance
              .collection('policias')
              .where('telefono', isEqualTo: user.phoneNumber)
              .limit(1)
              .get();
          if (policeDoc.docs.isNotEmpty) {
            departamento = policeDoc.docs.first.data()['departamento'] as String?;
          }
        }
      }

      if (departamento != null && _departamentos.isNotEmpty) {
        final match = _departamentos.firstWhere(
          (d) => GpsLocationService.matches(d['name']?.toString() ?? '', departamento!),
          orElse: () => {'name': 'TODOS LOS DEPARTAMENTOS'},
        );

        if (match['name'] != 'TODOS LOS DEPARTAMENTOS') {
          if (!mounted) return;
          setState(() {
            _selectedDepartamento = match['name'];
          });

          final viewModel = Provider.of<PoliceManageMissingViewModel>(
            context,
            listen: false,
          );
          viewModel.setDepartamentoFilter(match['name']);
          return;
        }
      }
    } catch (e) {
      debugPrint('Error getting police departamento: $e');
    }

    if (_selectedDepartamento == null && _departamentos.isNotEmpty) {
      setState(() {
        _selectedDepartamento = 'TODOS LOS DEPARTAMENTOS';
      });
    }
  }

  void _onSearchChanged() {
    final viewModel = Provider.of<PoliceManageMissingViewModel>(
      context,
      listen: false,
    );
    viewModel.searchCases(_searchController.text);
  }

  int? _calculateAge(DateTime? fechaNacimiento) {
    if (fechaNacimiento == null) return null;
    final now = DateTime.now();
    int age = now.year - fechaNacimiento.year;
    if (now.month < fechaNacimiento.month ||
        (now.month == fechaNacimiento.month && now.day < fechaNacimiento.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<PoliceManageMissingViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0xFF0F172A),
                        Color(0xFF1E293B),
                        Color(0xFF0B132B),
                      ]
                    : const [
                        Color(0xFFF8FAFC),
                        Color(0xFFF1F5F9),
                        Color(0xFFEFF6FF),
                      ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    children: [
                      _buildAppBar(viewModel, isDark),
                      if (_showDashboard) _buildDashboard(viewModel, isDark),
                      _buildSearchAndFilters(viewModel, isDark),
                      _buildQuickFilterChips(viewModel, isDark),
                      Expanded(child: _buildCasesList(viewModel, isDark)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          floatingActionButton: _buildFloatingActionButton(isDark),
        );
      },
    );
  }

  Widget _buildAppBar(PoliceManageMissingViewModel viewModel, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00796B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF004D40).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                tooltip: 'Regresar',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GESTIÓN DE CASOS PNP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      'Base Nacional • Notas de Alerta & Fichas HD',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const ThemeSunMoonToggle(compact: true),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showDashboard = !_showDashboard;
                  });
                },
                icon: Icon(
                  _showDashboard ? Icons.insights_rounded : Icons.insights_outlined,
                  color: _showDashboard ? const Color(0xFFFFB300) : Colors.white,
                  size: 22,
                ),
                tooltip: 'Estadísticas del Mando',
              ),
              if (viewModel.isMultiSelectMode)
                IconButton(
                  onPressed: () => viewModel.disableMultiSelectMode(),
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Cancelar Selección',
                ),
            ],
          ),
          if (viewModel.isMultiSelectMode) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${viewModel.selectedCasesCount} casos seleccionados',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: viewModel.hasSelectedCases ? () => viewModel.selectAllVisibleCases() : null,
                        icon: const Icon(Icons.select_all_rounded, color: Colors.white, size: 18),
                        label: const Text('Todos', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: viewModel.hasSelectedCases ? () => _showMarkAsFoundDialog(viewModel, isDark) : null,
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.black, size: 16),
                        label: const Text('Ubicados', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDashboard(PoliceManageMissingViewModel viewModel, bool isDark) {
    final conFicha = viewModel.filteredDesaparecidos
        .where((d) => d.imagenFichaUrl != null && d.imagenFichaUrl!.trim().isNotEmpty)
        .length;
    final menores = viewModel.filteredDesaparecidos.where((d) {
      final a = _calculateAge(d.fechaNacimiento);
      return a != null && a < 18;
    }).length;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart_rounded, color: Color(0xFF004D40), size: 20),
                const SizedBox(width: 8),
                Text(
                  'RESUMEN TÁCTICO DE FILTRADO',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Visibles',
                    '${viewModel.filteredDesaparecidos.length}',
                    Icons.groups_rounded,
                    const Color(0xFF0284C7),
                    isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatItem(
                    'Menores',
                    '$menores',
                    Icons.child_care_rounded,
                    const Color(0xFFE11D48),
                    isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatItem(
                    'Con Ficha HD',
                    '$conFicha',
                    Icons.verified_rounded,
                    const Color(0xFF00796B),
                    isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(PoliceManageMissingViewModel viewModel, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Buscar por nombres, apellidos o DNI...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDark ? Colors.white60 : const Color(0xFF004D40),
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          viewModel.searchCases('');
                        },
                        icon: Icon(Icons.clear, color: isDark ? Colors.white60 : Colors.black54, size: 18),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildDepartmentFilter(viewModel, isDark)),
              const SizedBox(width: 8),
              _buildSortButton(viewModel, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterChips(PoliceManageMissingViewModel viewModel, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Todos',
            icon: Icons.all_inclusive_rounded,
            isSelected: !viewModel.soloConFichaFilter && !viewModel.soloMenoresFilter && !viewModel.soloConPistasFilter,
            color: const Color(0xFF0284C7),
            isDark: isDark,
            onTap: () {
              viewModel.clearFilters();
              if (_selectedDepartamento != null && _selectedDepartamento != 'TODOS LOS DEPARTAMENTOS') {
                viewModel.setDepartamentoFilter(_selectedDepartamento);
              }
            },
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            label: 'Con Nota de Alerta HD',
            icon: Icons.verified_rounded,
            isSelected: viewModel.soloConFichaFilter,
            color: const Color(0xFF00796B),
            isDark: isDark,
            onTap: () => viewModel.toggleSoloConFichaFilter(),
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            label: 'Menores de Edad',
            icon: Icons.child_care_rounded,
            isSelected: viewModel.soloMenoresFilter,
            color: const Color(0xFFE11D48),
            isDark: isDark,
            onTap: () => viewModel.toggleSoloMenoresFilter(),
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            label: 'Con Pistas',
            icon: Icons.comment_rounded,
            isSelected: viewModel.soloConPistasFilter,
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            onTap: () => viewModel.toggleSoloConPistasFilter(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(isDark ? 0.35 : 0.2)
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : (isDark ? Colors.white12 : Colors.black12),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: isSelected ? color : (isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? (isDark ? Colors.white : color)
                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentFilter(PoliceManageMissingViewModel viewModel, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDepartamento,
          isExpanded: true,
          hint: Text(
            'Departamento',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12),
          ),
          icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12),
          items: _departamentos.map((dept) {
            return DropdownMenuItem<String>(
              value: dept['name'],
              child: Text(
                dept['name'],
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedDepartamento = value;
            });
            final departamentoParaFiltrar =
                value == 'TODOS LOS DEPARTAMENTOS' ? null : value;
            viewModel.setDepartamentoFilter(departamentoParaFiltrar);
          },
        ),
      ),
    );
  }

  Widget _buildSortButton(PoliceManageMissingViewModel viewModel, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
        ),
      ),
      child: PopupMenuButton<SortOption>(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sort_rounded, color: isDark ? Colors.white70 : const Color(0xFF004D40), size: 16),
              const SizedBox(width: 4),
              Text(
                'Ordenar',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        onSelected: (SortOption option) {
          viewModel.setSortOption(option);
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: SortOption.newest,
            child: Text('Más recientes'),
          ),
          const PopupMenuItem(
            value: SortOption.oldest,
            child: Text('Más antiguos'),
          ),
          const PopupMenuItem(
            value: SortOption.priority,
            child: Text('Menores de edad primero'),
          ),
          const PopupMenuItem(
            value: SortOption.alphabetical,
            child: Text('Alfabético'),
          ),
        ],
      ),
    );
  }

  Widget _buildCasesList(PoliceManageMissingViewModel viewModel, bool isDark) {
    if (viewModel.state == RequestState.Loading && viewModel.filteredDesaparecidos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF004D40)),
        ),
      );
    }

    if (viewModel.state == RequestState.Error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 48),
            const SizedBox(height: 12),
            Text(
              'Error al cargar casos policiales',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              viewModel.message,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => viewModel.loadMissingCases(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004D40),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (viewModel.state == RequestState.Empty || viewModel.filteredDesaparecidos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: isDark ? Colors.white30 : Colors.black26,
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              'No se encontraron casos',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Intente con otro filtro de departamento o término de búsqueda',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!viewModel.isLoadingMore &&
            viewModel.hasMoreData &&
            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          viewModel.loadMoreCases();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: viewModel.filteredDesaparecidos.length + (viewModel.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= viewModel.filteredDesaparecidos.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          final desaparecido = viewModel.filteredDesaparecidos[index];
          return _buildCaseCard(desaparecido, viewModel, isDark);
        },
      ),
    );
  }

  Widget _buildCaseCard(
    Desaparecido desaparecido,
    PoliceManageMissingViewModel viewModel,
    bool isDark,
  ) {
    final isSelected = viewModel.selectedCaseIds.contains(desaparecido.id);
    final isFound = desaparecido.estado == 'encontrado';

    final age = _calculateAge(desaparecido.fechaNacimiento);
    final isMinor = age != null && age < 18;
    final hasFichaOficial = desaparecido.imagenFichaUrl != null && desaparecido.imagenFichaUrl!.trim().isNotEmpty;
    final commentsCount = viewModel.getCommentsCount(desaparecido.id ?? '');

    Color priorityColor;
    String priorityText;

    if (isFound) {
      priorityColor = const Color(0xFF10B981);
      priorityText = 'UBICADO';
    } else if (isMinor) {
      priorityColor = const Color(0xFFE11D48);
      priorityText = 'MENOR DE EDAD';
    } else {
      priorityColor = const Color(0xFF0284C7);
      priorityText = 'ADULTO';
    }

    // Identificar si desapareció hace menos de 72 horas
    final bool isCritical = desaparecido.fechaDesaparicion != null &&
        DateTime.now().difference(desaparecido.fechaDesaparicion!).inHours >= 0 &&
        DateTime.now().difference(desaparecido.fechaDesaparicion!).inHours < 72;

    // Foto preferente con fallback a la ficha oficial
    final primaryImg = (desaparecido.fotoUrl != null && desaparecido.fotoUrl!.isNotEmpty)
        ? desaparecido.fotoUrl!
        : (hasFichaOficial ? desaparecido.imagenFichaUrl! : '');

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF00796B)
              : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            if (viewModel.isMultiSelectMode) {
              viewModel.toggleCaseSelection(desaparecido.id!);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MissingDetailsScreen(desaparecido: desaparecido),
                ),
              );
            }
          },
          onLongPress: () {
            if (!viewModel.isMultiSelectMode) {
              viewModel.enableMultiSelectMode();
              viewModel.toggleCaseSelection(desaparecido.id!);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Nombre y Badges
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (viewModel.isMultiSelectMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                          color: isSelected ? const Color(0xFF10B981) : Colors.grey,
                          size: 22,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        '${desaparecido.nombres} ${desaparecido.apellidos}',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: priorityColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        priorityText,
                        style: TextStyle(
                          color: priorityColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isCritical) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '< 72h',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // Contenido: Foto y Detalles
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagen / Foto con soporte para Zoom
                    Stack(
                      children: [
                        Container(
                          width: 90,
                          height: 110,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: priorityColor.withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                          child: primaryImg.isNotEmpty
                              ? AppCachedImage(
                                  imageUrl: primaryImg,
                                  fallbackImageUrl: hasFichaOficial ? desaparecido.imagenFichaUrl : null,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 300,
                                  memCacheHeight: 400,
                                  borderRadius: BorderRadius.circular(11),
                                  errorWidget: _buildPlaceholderPhoto(),
                                )
                              : _buildPlaceholderPhoto(),
                        ),
                        if (primaryImg.isNotEmpty)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FullScreenImageScreen(
                                      imageUrl: primaryImg,
                                      heroTag: 'img_${desaparecido.id}',
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.65),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Datos Operativos
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            Icons.badge_rounded,
                            'DNI: ${desaparecido.dni?.isNotEmpty == true ? desaparecido.dni : 'No registrado'}',
                            isDark,
                          ),
                          const SizedBox(height: 3),
                          _buildDetailRow(
                            Icons.cake_rounded,
                            'Edad: ${age != null ? '$age años' : 'No especificada'}',
                            isDark,
                          ),
                          const SizedBox(height: 3),
                          _buildDetailRow(
                            Icons.calendar_today_rounded,
                            'Fecha: ${_formatDate(desaparecido.fechaDesaparicion)}',
                            isDark,
                          ),
                          const SizedBox(height: 3),
                          _buildDetailRow(
                            Icons.location_on_rounded,
                            '${desaparecido.departamento ?? ''} • ${desaparecido.provincia ?? ''}',
                            isDark,
                          ),
                          if (commentsCount > 0) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.comment_rounded, color: Color(0xFF10B981), size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$commentsCount pistas ciudadanas',
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // BARRA ESPECIAL: NOTA DE ALERTA OFICIAL HD & COMPARTIR
                if (hasFichaOficial) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00796B).withOpacity(isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF00796B).withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: Color(0xFF00796B), size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NOTA DE ALERTA PNP OFICIAL HD',
                                style: TextStyle(
                                  color: Color(0xFF00796B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Afiche legal oficial registrado para difusión',
                                style: TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FullScreenImageScreen(
                                  imageUrl: desaparecido.imagenFichaUrl!,
                                  heroTag: 'ficha_${desaparecido.id}',
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00796B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'Ver Afiche',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _shareOfficialCase(desaparecido),
                          icon: const Icon(Icons.share_rounded, color: Color(0xFF00796B), size: 18),
                          tooltip: 'Compartir Nota de Alerta',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Botón para acceder al expediente
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MissingDetailsScreen(desaparecido: desaparecido),
                          ),
                        );
                      },
                      icon: const Icon(Icons.folder_open_rounded, size: 16),
                      label: const Text('Ver Expediente Completo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF004D40),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildPlaceholderPhoto() {
    return Container(
      color: Colors.grey.shade300,
      child: const Center(
        child: Icon(Icons.person, color: Colors.grey, size: 40),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 13),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withOpacity(0.35),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        tooltip: 'Registrar Caso Policial',
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const ReportDesaparecidoScreen()),
          );
          if (result == true && mounted) {
            final viewModel = Provider.of<PoliceManageMissingViewModel>(
              context,
              listen: false,
            );
            viewModel.loadMissingCases(forceRefresh: true);
          }
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 26),
      ),
    );
  }

  void _shareOfficialCase(Desaparecido d) async {
    final String fullName = '${d.nombres} ${d.apellidos}'.trim();
    final String location = '${d.distrito ?? ''}, ${d.provincia ?? ''}, ${d.departamento ?? ''}'.replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '');
    final String dateStr = d.fechaDesaparicion != null ? '${d.fechaDesaparicion!.day}/${d.fechaDesaparicion!.month}/${d.fechaDesaparicion!.year}' : 'Reciente';

    final String message =
        '🚨 *ALERTA POLICIAL PNP: PERSONA DESAPARECIDA* 🚨\n\n'
        '• Nombre: $fullName\n'
        '• DNI: ${d.dni?.isNotEmpty == true ? d.dni : 'En proceso'}\n'
        '• Lugar: $location\n'
        '• Fecha de Desaparición: $dateStr\n\n'
        '📌 Se adjunta la *Nota de Alerta Oficial* emitida por la Policía Nacional del Perú.\n'
        'Si cuenta con alguna información sobre su paradero, comuníquese de inmediato a la *Línea 114 PNP* o acérquese a la Comisaría más cercana.\n\n'
        '¡Su colaboración es vital para salvar vidas!';

    final String? notaUrl = d.imagenFichaUrl?.isNotEmpty == true
        ? d.imagenFichaUrl
        : (d.fotoUrl?.isNotEmpty == true ? d.fotoUrl : null);

    await ShareHelper.shareCase(
      context: context,
      message: message,
      subject: 'Alerta PNP: $fullName',
      imageUrl: notaUrl,
    );
  }

  void _showMarkAsFoundDialog(PoliceManageMissingViewModel viewModel, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Marcar como Ubicados',
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Está seguro de marcar ${viewModel.selectedCasesCount} casos seleccionados como personas ubicadas?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              viewModel.markSelectedCasesAsFound(
                'Marcado como encontrado por autoridad policial en lote',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar Ubicación'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No especificada';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
}
