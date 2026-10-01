import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../common/state_enum.dart';
import '../../../domain/entities/policia.dart';
import '../view_models/policia_management_view_model.dart';
import '../widgets/policia_form_dialog.dart';
import '../widgets/policia_card.dart';
import '../widgets/policia_stats_card.dart';
import '../../common_widgets/theme_sun_moon_toggle.dart';

class PoliciaManagementScreen extends StatefulWidget {
  const PoliciaManagementScreen({super.key});

  @override
  State<PoliciaManagementScreen> createState() =>
      _PoliciaManagementScreenState();
}

class _PoliciaManagementScreenState extends State<PoliciaManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAdminAndLoad();
    });
  }

  Future<void> _checkAdminAndLoad() async {
    final viewModel = context.read<PoliciaManagementViewModel>();
    await viewModel.checkAdminStatus();

    if (!viewModel.isAdmin) {
      _showAccessDeniedDialog();
      return;
    }

    await viewModel.loadPolicias();
  }

  void _showAccessDeniedDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.security, color: Color(0xFFEF4444), size: 26),
            const SizedBox(width: 10),
            Text(
              'Acceso Restringido',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 44,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Privilegios Superadmin Requeridos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Esta consola está reservada exclusivamente para directores y administradores de la Policía Nacional del Perú.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              children: [
                _buildHeader(isDark, textColor, subtitleColor),
                Expanded(
                  child: Consumer<PoliciaManagementViewModel>(
                    builder: (context, viewModel, child) {
                      if (viewModel.adminCheckState == RequestState.Loading) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF003366),
                          ),
                        );
                      }

                      if (!viewModel.isAdmin) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        children: [
                          _buildStatsSection(viewModel),
                          _buildSearchBar(viewModel, isDark),
                          Expanded(
                            child: _buildPoliciasList(viewModel, isDark),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Consumer<PoliciaManagementViewModel>(
        builder: (context, viewModel, child) {
          if (!viewModel.isAdmin) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: () => _showPoliciaForm(context),
            backgroundColor: const Color(0xFF003366),
            foregroundColor: Colors.white,
            elevation: 3,
            icon: const Icon(Icons.person_add, size: 20),
            label: const Text(
              'Nuevo Policía',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color textColor, Color subtitleColor) {
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
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: FaIcon(
              FontAwesomeIcons.arrowLeft,
              color: isDark ? Colors.white : const Color(0xFF003366),
              size: 18,
            ),
            style: IconButton.styleFrom(
              backgroundColor:
                  isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'CONSOLA SUPERADMIN',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PNP',
                        style: TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Gestión y control de cuentas policiales autorizadas',
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
        ],
      ),
    );
  }

  Widget _buildStatsSection(PoliciaManagementViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: PoliciaStatsCard(
              title: 'Total Oficiales',
              value: viewModel.totalPolicias.toString(),
              icon: Icons.badge,
              color: const Color(0xFF0284C7),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PoliciaStatsCard(
              title: 'Superadmins',
              value: viewModel.adminPolicias.toString(),
              icon: Icons.shield,
              color: const Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PoliciaStatsCard(
              title: 'Operativos',
              value: viewModel.regularPolicias.toString(),
              icon: Icons.local_police,
              color: const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(
      PoliciaManagementViewModel viewModel, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: viewModel.searchPolicias,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre, CIP, unidad o teléfono...',
            hintStyle: TextStyle(
              color: isDark
                  ? const Color(0xFF64748B)
                  : const Color(0xFF94A3B8),
              fontSize: 13.5,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: Color(0xFF003366),
              size: 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController.clear();
                      viewModel.searchPolicias('');
                    },
                    icon: Icon(
                      Icons.clear,
                      size: 18,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildPoliciasList(
      PoliciaManagementViewModel viewModel, bool isDark) {
    if (viewModel.state == RequestState.Loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF003366)),
      );
    }

    if (viewModel.state == RequestState.Error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(height: 12),
              Text(
                'Error al cargar la nómina policial',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                viewModel.errorMessage,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: viewModel.loadPolicias,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (viewModel.policias.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF003366).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 48,
                color: Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              viewModel.searchQuery.isEmpty
                  ? 'No hay oficiales registrados'
                  : 'Sin resultados de búsqueda',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              viewModel.searchQuery.isEmpty
                  ? 'Agregue el primer oficial autorizado con el botón inferior.'
                  : 'Intente con otro término o número de CIP.',
              style: TextStyle(
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF003366),
      onRefresh: () async => viewModel.loadPolicias(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
        itemCount: viewModel.policias.length,
        itemBuilder: (context, index) {
          final policia = viewModel.policias[index];
          return PoliciaCard(
            policia: policia,
            onEdit: () => _showPoliciaForm(context, policia: policia),
            onDelete: () => _showDeleteConfirmation(context, policia),
          );
        },
      ),
    );
  }

  void _showPoliciaForm(BuildContext context, {Policia? policia}) {
    final viewModel = context.read<PoliciaManagementViewModel>();
    showDialog(
      context: context,
      builder: (context) =>
          PoliciaFormDialog(policia: policia, viewModel: viewModel),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Policia policia) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          'Confirmar Retiro de Cuenta',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFEF4444), size: 44),
            const SizedBox(height: 12),
            Text(
              '¿Está seguro de que desea eliminar la cuenta policial de ${policia.nombreCompleto}?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Esta acción revocará inmediatamente su acceso a los expedientes reservados.',
              style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<PoliciaManagementViewModel>().deletePolicia(
                    policia.uid,
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
