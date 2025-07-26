import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../helpers/database_helpers.dart';
import '../../../common/state_enum.dart';
import '../../../domain/entities/desaparecido.dart';
import '../view_models/police_manage_missing_view_model.dart';
import '../../../domain/enums.dart';
import 'police_missing_details_screen.dart';
import 'add_missing_screen.dart';

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
  String? _policeDepartamento;

  // Dashboard
  bool _showDashboard = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
    await _getPoliceDepartamento();
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

      setState(() {
        _departamentos = [
          {'name': 'TODOS LOS DEPARTAMENTOS'},
          ...data
              .map((d) => {'name': d['name'].toString().toUpperCase()})
              .toList(),
        ];
      });
    } catch (e) {
      debugPrint('Error loading departamentos: $e');
    }
  }

  Future<void> _getPoliceDepartamento() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final policeDoc =
            await FirebaseFirestore.instance
                .collection('policias')
                .where('telefono', isEqualTo: user.phoneNumber)
                .get();

        if (policeDoc.docs.isNotEmpty) {
          final policeData = policeDoc.docs.first.data();
          final departamento =
              (policeData['departamento'] as String?)?.toUpperCase();

          if (departamento != null && _departamentos.isNotEmpty) {
            final match = _departamentos.firstWhere(
              (d) => d['name'] == departamento,
              orElse: () => {'name': 'TODOS LOS DEPARTAMENTOS'},
            );

            setState(() {
              _policeDepartamento = departamento;
              _selectedDepartamento = match['name'];
            });

            // Aplicar filtro automáticamente
            final viewModel = Provider.of<PoliceManageMissingViewModel>(
              context,
              listen: false,
            );
            viewModel.setDepartamentoFilter(departamento);
          }
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

  int _calculatePriority(Desaparecido desaparecido) {
    if (desaparecido.fechaDesaparicion == null) return 1;
    final daysSince =
        DateTime.now().difference(desaparecido.fechaDesaparicion!).inDays;
    if (daysSince > 30) return 4; // Urgente
    if (daysSince > 14) return 3; // Alta
    if (daysSince > 7) return 2; // Media
    return 1; // Baja
  }

  // Calcular edad de una persona
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
    return Consumer<PoliceManageMissingViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                  Color(0xFF334155),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildAppBar(viewModel),
                  if (_showDashboard) _buildDashboard(viewModel),
                  _buildSearchAndFilters(viewModel),
                  Expanded(child: _buildCasesList(viewModel)),
                ],
              ),
            ),
          ),
          floatingActionButton: _buildFloatingActionButton(),
        );
      },
    );
  }

  Widget _buildAppBar(PoliceManageMissingViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  'Gestión de Desaparecidos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showDashboard = !_showDashboard;
                  });
                },
                icon: Icon(
                  _showDashboard ? Icons.dashboard : Icons.dashboard_outlined,
                  color: Colors.white,
                ),
              ),
              if (viewModel.isMultiSelectMode)
                IconButton(
                  onPressed: () => viewModel.disableMultiSelectMode(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
            ],
          ),
          if (viewModel.isMultiSelectMode) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${viewModel.selectedCasesCount} casos seleccionados',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed:
                            viewModel.hasSelectedCases
                                ? () => viewModel.selectAllVisibleCases()
                                : null,
                        icon: const Icon(Icons.select_all, color: Colors.white),
                      ),
                      IconButton(
                        onPressed:
                            viewModel.hasSelectedCases
                                ? () => _showMarkAsFoundDialog(viewModel)
                                : null,
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
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

  Widget _buildDashboard(PoliceManageMissingViewModel viewModel) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade700, Colors.red.shade500],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  FontAwesomeIcons.chartLine,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Panel de Control',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    'Total: ${viewModel.filteredDesaparecidos.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Una sola fila con 3 estadísticas
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Este Mes',
                    viewModel.casesThisMonth.toString(),
                    FontAwesomeIcons.calendarDays,
                    Colors.purple.shade400,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Activos',
                    viewModel.activeCases.toString(),
                    FontAwesomeIcons.userClock,
                    Colors.orange.shade400,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Menores',
                    viewModel.urgentCases.toString(),
                    FontAwesomeIcons.child,
                    Colors.red.shade400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(PoliceManageMissingViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Barra de búsqueda
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o DNI...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withOpacity(0.7),
                ),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            viewModel.searchCases('');
                          },
                          icon: Icon(
                            Icons.clear,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filtros rápidos (solo departamentos y ordenar)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Filtro de departamento
                _buildDepartmentFilter(viewModel),
                const SizedBox(width: 8),
                _buildSortButton(viewModel),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentFilter(PoliceManageMissingViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDepartamento,
          hint: const Text(
            'Departamento',
            style: TextStyle(color: Colors.white70),
          ),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white),
          items:
              _departamentos.map((dept) {
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
            // Aplicar filtro de departamento
            final departamentoParaFiltrar =
                value == 'TODOS LOS DEPARTAMENTOS' ? null : value;
            viewModel.setDepartamentoFilter(departamentoParaFiltrar);
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Colors.white.withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected
                    ? Colors.white.withOpacity(0.5)
                    : Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton(PoliceManageMissingViewModel viewModel) {
    return PopupMenuButton<SortOption>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            const Text(
              'Ordenar',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
      onSelected: (SortOption option) {
        viewModel.setSortOption(option);
      },
      itemBuilder:
          (context) => [
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
              child: Text('Menores'),
            ),
            const PopupMenuItem(
              value: SortOption.alphabetical,
              child: Text('Alfabético'),
            ),
          ],
    );
  }

  Widget _buildCasesList(PoliceManageMissingViewModel viewModel) {
    if (viewModel.state == RequestState.Loading &&
        viewModel.filteredDesaparecidos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (viewModel.state == RequestState.Error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              FontAwesomeIcons.exclamationTriangle,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar casos',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.message,
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => viewModel.loadMissingCases(forceRefresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (viewModel.state == RequestState.Empty ||
        viewModel.filteredDesaparecidos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              FontAwesomeIcons.userSlash,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay casos disponibles',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No se encontraron casos con los filtros actuales',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
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
        padding: const EdgeInsets.all(16),
        itemCount:
            viewModel.filteredDesaparecidos.length +
            (viewModel.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= viewModel.filteredDesaparecidos.length) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            );
          }

          final desaparecido = viewModel.filteredDesaparecidos[index];
          return _buildCaseCard(desaparecido, viewModel);
        },
      ),
    );
  }

  Widget _buildCaseCard(
    Desaparecido desaparecido,
    PoliceManageMissingViewModel viewModel,
  ) {
    final isSelected = viewModel.selectedCaseIds.contains(desaparecido.id);
    final isFound = desaparecido.estado == 'encontrado';

    // Calcular edad
    final age = _calculateAge(desaparecido.fechaNacimiento);
    final isMinor = age != null && age < 18;

    Color priorityColor;
    IconData priorityIcon;
    String priorityText;

    if (isFound) {
      priorityColor = Colors.green;
      priorityIcon = FontAwesomeIcons.userCheck;
      priorityText = 'ENCONTRADO';
    } else if (isMinor) {
      priorityColor = Colors.red;
      priorityIcon = FontAwesomeIcons.child;
      priorityText = 'MENOR';
    } else {
      priorityColor = Colors.blue;
      priorityIcon = FontAwesomeIcons.user;
      priorityText = 'ADULTO';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isSelected
                  ? Colors.white.withOpacity(0.5)
                  : Colors.white.withOpacity(0.2),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (viewModel.isMultiSelectMode) {
              viewModel.toggleCaseSelection(desaparecido.id!);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => PoliceMissingDetailsScreen(
                        desaparecido: desaparecido,
                      ),
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Foto y estado (más grande)
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: priorityColor.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child:
                            desaparecido.fotoUrl != null &&
                                    desaparecido.fotoUrl!.isNotEmpty
                                ? Image.network(
                                  desaparecido.fotoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey.shade300,
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.grey,
                                        size: 40,
                                      ),
                                    );
                                  },
                                )
                                : Container(
                                  color: Colors.grey.shade300,
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                ),
                      ),
                    ),
                    // Indicador de prioridad
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: priorityColor,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: priorityColor.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          priorityIcon,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                    // Checkbox para selección múltiple
                    if (viewModel.isMultiSelectMode)
                      Positioned(
                        bottom: -2,
                        left: -2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: isSelected ? Colors.green : Colors.grey,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Información del caso
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${desaparecido.nombres} ${desaparecido.apellidos}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: priorityColor.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              priorityText,
                              style: TextStyle(
                                color: priorityColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.badge,
                        'DNI: ${desaparecido.dni ?? 'No especificado'}',
                      ),
                      const SizedBox(height: 4),
                      _buildInfoRow(
                        Icons.cake,
                        'Edad: ${age != null ? '$age años' : 'No especificada'}',
                      ),
                      const SizedBox(height: 4),
                      _buildInfoRow(
                        Icons.calendar_today,
                        'Desaparecido: ${_formatDate(desaparecido.fechaDesaparicion)}',
                      ),
                      const SizedBox(height: 4),
                      _buildInfoRow(
                        Icons.location_on,
                        '${desaparecido.departamento ?? ''}, ${desaparecido.provincia ?? ''}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade600, Colors.red.shade400],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const AddMissingScreen()),
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
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  void _changeFilter(
    PoliceManageMissingViewModel viewModel,
    MissingFilter filter,
  ) {
    viewModel.setFilter(filter);
    viewModel.loadMissingCases(forceRefresh: true);
  }

  void _showMarkAsFoundDialog(PoliceManageMissingViewModel viewModel) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text(
              'Marcar como encontrados',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              '¿Está seguro de marcar ${viewModel.selectedCasesCount} casos como encontrados?',
              style: const TextStyle(color: Colors.white70),
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
                    'Marcado como encontrado desde selección múltiple',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirmar'),
              ),
            ],
          ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Fecha no especificada';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
}
