import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alerta_desaparecidos/presentation/police/view_models/manage_missing_view_model.dart';
import 'package:alerta_desaparecidos/domain/enums.dart';
import 'missing_details_screen.dart';
import 'package:alerta_desaparecidos/common/state_enum.dart';
import 'add_missing_screen.dart';

class ManageMissingScreen extends StatefulWidget {
  const ManageMissingScreen({super.key});

  @override
  State<ManageMissingScreen> createState() => _ManageMissingScreenState();
}

class _ManageMissingScreenState extends State<ManageMissingScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Diferir la llamada de `getMissingPeople` hasta después de la construcción inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ManageMissingViewModel>(
        context,
        listen: false,
      ).getMissingPeople();
    });

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    Provider.of<ManageMissingViewModel>(
      context,
      listen: false,
    ).searchMissingPeople(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ManageMissingViewModel>(context);
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Buscar por nombre...',
            border: InputBorder.none,
          ),
        )
            : const Text('Lista de Desaparecidos'),
        actions: <Widget>[
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  Provider.of<ManageMissingViewModel>(
                    context,
                    listen: false,
                  ).searchMissingPeople(''); // Limpiar la búsqueda
                });
              },
            ),
          DropdownButton<MissingFilter>(
            value: viewModel.currentFilter,
            items: const [
              DropdownMenuItem(
                value: MissingFilter.active,
                child: Text('Activos'),
              ),
              DropdownMenuItem(
                value: MissingFilter.found,
                child: Text('Encontrados'),
              ),
              DropdownMenuItem(value: MissingFilter.all, child: Text('Todos')),
            ],
            onChanged: (MissingFilter? newValue) {
              if (newValue != null) {
                setState(() {
                  viewModel.currentFilter = newValue;
                });
              }
            },
          ),
        ],
      ),
      body: viewModel.state == RequestState.Loading
          ? const Center(child: CircularProgressIndicator())
          : viewModel.state == RequestState.Error
          ? Center(child: Text(viewModel.message))
          : viewModel.searchedDesaparecidos.isEmpty &&
          _searchController.text.isNotEmpty
          ? const Center(
        child: Text('No se encontraron resultados para la búsqueda.'),
      )
          : viewModel.desaparecidos.isEmpty
          ? const Center(
        child: Text(
          'No hay casos de desaparecidos registrados con este filtro.',
        ),
      )
          : NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification is ScrollEndNotification &&
              !viewModel.isLoadingMore &&
              viewModel.hasMoreData &&
              notification.metrics.extentAfter < 300) {
            viewModel.loadMoreMissingPeople();
          }
          return false;
        },
        child: ListView.builder(
          itemCount: _searchController.text.isNotEmpty
              ? viewModel.searchedDesaparecidos.length +
              (viewModel.hasMoreData &&
                  viewModel.searchedDesaparecidos.isNotEmpty &&
                  !viewModel.isLoadingMore
                  ? 1
                  : 0)
              : viewModel.desaparecidos.length +
              (viewModel.hasMoreData &&
                  viewModel.desaparecidos.isNotEmpty &&
                  !viewModel.isLoadingMore
                  ? 1
                  : 0),
          itemBuilder: (context, index) {
            if (_searchController.text.isNotEmpty
                ? index == viewModel.searchedDesaparecidos.length &&
                viewModel.hasMoreData
                : index == viewModel.desaparecidos.length &&
                viewModel.hasMoreData) {
              return const Center(child: CircularProgressIndicator());
            }
            final desaparecido = _searchController.text.isNotEmpty
                ? viewModel.searchedDesaparecidos[index]
                : viewModel.desaparecidos[index];
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(desaparecido.nombreCompleto),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desaparecido.fechaDesaparicion != null)
                      Text(
                        'Desaparecido el: ${desaparecido.fechaDesaparicion!.day}/${desaparecido.fechaDesaparicion!.month}/${desaparecido.fechaDesaparicion!.year}',
                      ),
                    if (desaparecido.ubicacionDesaparicion != null)
                      Text(
                        'Ubicación aprox.: Lat: ${desaparecido.ubicacionDesaparicion!.latitude.toStringAsFixed(2)}, Lng: ${desaparecido.ubicacionDesaparicion!.longitude.toStringAsFixed(2)}',
                      ),
                    if (desaparecido.estado != null)
                      Text('Estado: ${desaparecido.estado}'),
                    if (desaparecido.dni != null)
                      Text('DNI: ${desaparecido.dni}'),
                    if (desaparecido.telefonoContacto != null)
                      Text(
                        'Teléfono: ${desaparecido.telefonoContacto}',
                      ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MissingDetailsScreen(
                        desaparecido: desaparecido,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddMissingScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Desaparecido'),
      ),
    );
  }
}