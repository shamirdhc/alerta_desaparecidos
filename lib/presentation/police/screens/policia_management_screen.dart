import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../common/state_enum.dart';
import '../../../domain/entities/policia.dart';
import '../view_models/policia_management_view_model.dart';
import '../widgets/policia_form_dialog.dart';
import '../widgets/policia_card.dart';
import '../widgets/policia_stats_card.dart';

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.security, color: Colors.red[600], size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Acceso Denegado',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.admin_panel_settings_outlined,
                        size: 48,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Privilegios Insuficientes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No tienes los permisos necesarios para acceder al centro de control de cuentas policiales.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Solo administradores autorizados',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(
                    context,
                  ).pop(); // Regresar a la pantalla anterior
                },
                child: const Text('Entendido'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Consumer<PoliciaManagementViewModel>(
                  builder: (context, viewModel, child) {
                    if (viewModel.adminCheckState == RequestState.Loading) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    if (!viewModel.isAdmin) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      children: [
                        _buildStatsSection(viewModel),
                        _buildSearchBar(viewModel),
                        Expanded(child: _buildPoliciasList(viewModel)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Consumer<PoliciaManagementViewModel>(
        builder: (context, viewModel, child) {
          if (!viewModel.isAdmin) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: () => _showPoliciaForm(context),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1565C0),
            icon: const Icon(Icons.person_add),
            label: const Text('Nuevo Policía'),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Centro de Control',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Gestión de Cuentas Policiales',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(PoliciaManagementViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: PoliciaStatsCard(
              title: 'Total',
              value: viewModel.totalPolicias.toString(),
              icon: Icons.people,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PoliciaStatsCard(
              title: 'Admins',
              value: viewModel.adminPolicias.toString(),
              icon: Icons.admin_panel_settings,
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PoliciaStatsCard(
              title: 'Regulares',
              value: viewModel.regularPolicias.toString(),
              icon: Icons.person,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(PoliciaManagementViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: _searchController,
        onChanged: viewModel.searchPolicias,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, teléfono, CIP...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
          suffixIcon:
              _searchController.text.isNotEmpty
                  ? IconButton(
                    onPressed: () {
                      _searchController.clear();
                      viewModel.searchPolicias('');
                    },
                    icon: Icon(
                      Icons.clear,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  )
                  : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildPoliciasList(PoliciaManagementViewModel viewModel) {
    if (viewModel.state == RequestState.Loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (viewModel.state == RequestState.Error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.white.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar policías',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.errorMessage,
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: viewModel.loadPolicias,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (viewModel.policias.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.white.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              viewModel.searchQuery.isEmpty
                  ? 'No hay policías registrados'
                  : 'No se encontraron resultados',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.searchQuery.isEmpty
                  ? 'Agrega el primer policía usando el botón +'
                  : 'Intenta con otros términos de búsqueda',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.builder(
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
      builder:
          (context) =>
              PoliciaFormDialog(policia: policia, viewModel: viewModel),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Policia policia) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Confirmar Eliminación'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning, color: Colors.orange, size: 48),
                const SizedBox(height: 16),
                Text(
                  '¿Estás seguro de que deseas eliminar a ${policia.nombreCompleto}?',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Esta acción no se puede deshacer.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<PoliciaManagementViewModel>().deletePolicia(
                    policia.uid,
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.white),
                ),
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
