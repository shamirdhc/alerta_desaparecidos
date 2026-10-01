import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../view_models/manage_found_view_model.dart';
import '../../../domain/entities/desaparecido.dart';
import 'found_details_screen.dart';
import '../../../common/state_enum.dart';
import '../../../helpers/share_helper.dart';
import '../../common_widgets/theme_sun_moon_toggle.dart';
import '../../citizen/screens/full_screen_image_screen.dart';

class ManageFoundScreen extends StatefulWidget {
  const ManageFoundScreen({super.key});

  @override
  State<ManageFoundScreen> createState() => _ManageFoundScreenState();
}

class _ManageFoundScreenState extends State<ManageFoundScreen>
    with TickerProviderStateMixin {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = Provider.of<ManageFoundViewModel>(
        context,
        listen: false,
      );
      if (viewModel.state != RequestState.Loaded &&
          viewModel.state != RequestState.Loading) {
        viewModel.getFoundPeople(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    Provider.of<ManageFoundViewModel>(
      context,
      listen: false,
    ).searchFoundPeople(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ManageFoundViewModel>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              children: [
                _buildModernAppBar(isDark, textColor, subtitleColor),
                _buildStatsHeader(viewModel, isDark),
                _buildTacticalChipsBar(viewModel, isDark),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildFoundList(viewModel, isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(isDark),
    );
  }

  Widget _buildModernAppBar(bool isDark, Color textColor, Color subtitleColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: FaIcon(
                  FontAwesomeIcons.arrowLeft,
                  color: isDark ? Colors.white : const Color(0xFF003366),
                  size: 18,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PERSONAS UBICADAS',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Casos resueltos y archivados oficialmente',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const ThemeSunMoonToggle(),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      Provider.of<ManageFoundViewModel>(
                        context,
                        listen: false,
                      ).searchFoundPeople('');
                    }
                  });
                },
                icon: FaIcon(
                  _isSearching
                      ? FontAwesomeIcons.xmark
                      : FontAwesomeIcons.magnifyingGlass,
                  color: const Color(0xFF10B981),
                  size: 16,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981).withOpacity(0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          if (_isSearching) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, apellidos o DNI...',
                  hintStyle: TextStyle(
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            Provider.of<ManageFoundViewModel>(
                              context,
                              listen: false,
                            ).searchFoundPeople('');
                          },
                        )
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsHeader(ManageFoundViewModel viewModel, bool isDark) {
    final count = viewModel.encontrados.length;
    final conFichaCount = viewModel.encontrados
        .where((e) => e.imagenFichaUrl != null && e.imagenFichaUrl!.isNotEmpty)
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
              : [const Color(0xFF059669), const Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const FaIcon(
              FontAwesomeIcons.circleCheck,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'LOCALIZADOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Casos resueltos con éxito ($conFichaCount con Ficha Oficial HD)',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalChipsBar(ManageFoundViewModel viewModel, bool isDark) {
    return Container(
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip(
            label: 'Todos (${viewModel.encontrados.length})',
            isSelected: !viewModel.filterOnlyWithFicha &&
                !viewModel.filterOnlyMinors &&
                viewModel.selectedDepartamento == null,
            onTap: () {
              if (viewModel.filterOnlyWithFicha) viewModel.toggleOnlyWithFicha();
              if (viewModel.filterOnlyMinors) viewModel.toggleOnlyMinors();
              viewModel.setSelectedDepartamento(null);
            },
            isDark: isDark,
            icon: FontAwesomeIcons.users,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Con Ficha HD',
            isSelected: viewModel.filterOnlyWithFicha,
            onTap: () => viewModel.toggleOnlyWithFicha(),
            isDark: isDark,
            icon: FontAwesomeIcons.fileImage,
            badgeColor: const Color(0xFF0284C7),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Menores de Edad',
            isSelected: viewModel.filterOnlyMinors,
            onTap: () => viewModel.toggleOnlyMinors(),
            isDark: isDark,
            icon: FontAwesomeIcons.child,
            badgeColor: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required IconData icon,
    Color? badgeColor,
  }) {
    final activeColor = badgeColor ?? const Color(0xFF10B981);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.18)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              icon,
              size: 13,
              color: isSelected
                  ? activeColor
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white : const Color(0xFF1E293B)),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoundList(ManageFoundViewModel viewModel, bool isDark) {
    if (viewModel.state == RequestState.Loading &&
        viewModel.encontrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
            const SizedBox(height: 16),
            Text(
              'Cargando personas ubicadas...',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (viewModel.state == RequestState.Error &&
        viewModel.encontrados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FaIcon(
                FontAwesomeIcons.triangleExclamation,
                color: Color(0xFFEF4444),
                size: 44,
              ),
              const SizedBox(height: 16),
              Text(
                'No se pudo cargar el listado',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                viewModel.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => viewModel.refresh(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final displayList = viewModel.filteredEncontrados;

    if (displayList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const FaIcon(
                  FontAwesomeIcons.userCheck,
                  color: Color(0xFF10B981),
                  size: 48,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No se encontraron personas ubicadas',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Prueba ajustando los filtros tácticos o el término de búsqueda.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollEndNotification &&
            !viewModel.isLoadingMore &&
            viewModel.hasMoreData &&
            notification.metrics.extentAfter < 300) {
          viewModel.loadMoreFoundPeople();
        }
        return false;
      },
      child: RefreshIndicator(
        color: const Color(0xFF10B981),
        onRefresh: () async => viewModel.refresh(),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          itemCount: displayList.length +
              (viewModel.hasMoreData && viewModel.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= displayList.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                ),
              );
            }

            final encontrado = displayList[index];
            return _buildFoundCard(encontrado, isDark);
          },
        ),
      ),
    );
  }

  Widget _buildFoundCard(Desaparecido encontrado, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final hasFicha = encontrado.imagenFichaUrl != null &&
        encontrado.imagenFichaUrl!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToDetails(encontrado),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Foto con badge de éxito
                  Stack(
                    children: [
                      Container(
                        width: 76,
                        height: 96,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10.5),
                          child: encontrado.fotoUrl != null &&
                                  encontrado.fotoUrl!.isNotEmpty
                              ? Image.network(
                                  encontrado.fotoUrl!,
                                  fit: BoxFit.cover,
                                  cacheWidth: 300,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: FaIcon(
                                        FontAwesomeIcons.user,
                                        color: Color(0xFF10B981),
                                        size: 32,
                                      ),
                                    );
                                  },
                                )
                              : const Center(
                                  child: FaIcon(
                                    FontAwesomeIcons.user,
                                    color: Color(0xFF10B981),
                                    size: 32,
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const FaIcon(
                            FontAwesomeIcons.check,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Información central
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'UBICADO',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            if (encontrado.edadCalculada != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${encontrado.edadCalculada} años',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${encontrado.nombres} ${encontrado.apellidos}',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        if (encontrado.dni != null &&
                            encontrado.dni!.isNotEmpty)
                          _buildDetailRow(
                            FontAwesomeIcons.idCard,
                            'DNI: ${encontrado.dni}',
                            textSecondary,
                          ),

                        if (encontrado.fechaEncontrado != null)
                          _buildDetailRow(
                            FontAwesomeIcons.calendarCheck,
                            'Ubicado: ${DateFormat('dd/MM/yyyy').format(encontrado.fechaEncontrado!)}',
                            const Color(0xFF10B981),
                          ),

                        if (encontrado.departamento != null &&
                            encontrado.departamento!.isNotEmpty)
                          _buildDetailRow(
                            FontAwesomeIcons.locationDot,
                            '${encontrado.departamento}${encontrado.provincia != null ? ' - ${encontrado.provincia}' : ''}',
                            textSecondary,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),
                  FaIcon(
                    FontAwesomeIcons.chevronRight,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFFCBD5E1),
                    size: 14,
                  ),
                ],
              ),

              // Barra de acciones inferiores tácticas (Ficha HD + Compartir)
              const SizedBox(height: 10),
              Divider(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                height: 1,
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  if (hasFicha)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullScreenImageScreen(
                                imageUrl: encontrado.imagenFichaUrl!,
                              ),
                            ),
                          );
                        },
                        icon: const FaIcon(
                          FontAwesomeIcons.fileImage,
                          size: 13,
                          color: Color(0xFF0284C7),
                        ),
                        label: const Text(
                          'Ver Ficha HD',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: BorderSide(
                            color: const Color(0xFF0284C7).withOpacity(0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Text(
                        'Expediente archivado en sede',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),

                  IconButton(
                    onPressed: () => _shareFoundCase(context, encontrado),
                    icon: const FaIcon(
                      FontAwesomeIcons.shareNodes,
                      size: 14,
                      color: Color(0xFF10B981),
                    ),
                    tooltip: 'Compartir reporte de caso resuelto',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981).withOpacity(0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          FaIcon(icon, size: 10, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
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

  Widget _buildFloatingActionButton(bool isDark) {
    return FloatingActionButton.extended(
      onPressed: () {
        Provider.of<ManageFoundViewModel>(context, listen: false).refresh();
      },
      backgroundColor: const Color(0xFF10B981),
      foregroundColor: Colors.white,
      elevation: 3,
      icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 15),
      label: const Text(
        'Actualizar',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  void _navigateToDetails(Desaparecido encontrado) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoundDetailsScreen(encontrado: encontrado),
      ),
    );
  }

  Future<void> _shareFoundCase(
      BuildContext context, Desaparecido encontrado) async {
    final fullName =
        '${encontrado.nombres} ${encontrado.apellidos}'.trim();
    final dniText = (encontrado.dni != null && encontrado.dni!.isNotEmpty)
        ? '(DNI: ${encontrado.dni}) '
        : '';
    final message =
        '🟢 *PERSONA UBICADA - CASO RESUELTO*\n\n'
        'La Policía Nacional del Perú comunica con satisfacción que *$fullName* $dniText'
        'ha sido *UBICADO(A)* y se encuentra a buen recaudo con sus familiares.\n\n'
        'Agradecemos a la ciudadanía y a los medios de comunicación por su valiosa colaboración.';

    final String? notaUrl = (encontrado.imagenFichaUrl?.isNotEmpty == true)
        ? encontrado.imagenFichaUrl
        : (encontrado.fotoUrl?.isNotEmpty == true ? encontrado.fotoUrl : null);

    await ShareHelper.shareCase(
      context: context,
      message: message,
      subject: 'Persona Ubicada: $fullName',
      imageUrl: notaUrl,
    );
  }
}