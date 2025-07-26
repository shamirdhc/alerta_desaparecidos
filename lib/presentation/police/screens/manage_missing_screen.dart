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
    _searchController.addListener(_onSearchChanged);
    // Usar addPostFrameCallback para asegurar que el ViewModel esté listo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = Provider.of<ManageMissingViewModel>(
        context,
        listen: false,
      );
      // Siempre intentar cargar datos al entrar si no están ya cargados o en proceso
      // Esto ayuda al volver a la pantalla.
      if (viewModel.state != RequestState.Loaded &&
          viewModel.state != RequestState.Loading) {
        viewModel.getMissingPeople(
          forceRefresh: true,
        ); // Forzar refresco inicial
      }
    });
  }

  // Y no olvides quitar el listener en dispose:
  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // Asegúrate de tener un método _onSearchChanged si no lo tienes:
  void _onSearchChanged() {
    // Puedes añadir un debounce aquí si quieres esperar a que el usuario deje de escribir
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
        title:
            _isSearching
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
              DropdownMenuItem(value: MissingFilter.all, child: Text('Todos')),
            ],
            onChanged: (MissingFilter? newValue) {
              if (newValue != null && newValue != viewModel.currentFilter) {
                // Evita recargar si se selecciona el mismo filtro
                // No necesitas setState aquí si Provider notifica los cambios
                // setState(() { // Puedes quitar o mantener setState según cómo funcione tu ViewModel
                //   viewModel.currentFilter = newValue;
                // });
                viewModel.currentFilter =
                    newValue; // Actualiza el filtro en el ViewModel
                viewModel.getMissingPeople(
                  forceRefresh: true,
                ); // Llama a cargar los datos para el NUEVO filtro
                // Asumiendo que tienes forceRefresh o un método similar
                // para indicar que es una nueva carga, no paginación.
                // Si no, simplemente viewModel.getMissingPeople();
              }
            },
          ),
        ],
      ),
      body:
          viewModel.state == RequestState.Loading
              ? const Center(child: CircularProgressIndicator())
              : viewModel.state == RequestState.Error
              ? Center(child: Text(viewModel.message))
              : viewModel.state == RequestState.Empty
              ? const Center(child: Text('No hay datos disponibles.'))
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
                  itemCount:
                      _searchController.text.isNotEmpty
                          ? viewModel.searchedDesaparecidos.length +
                              (viewModel.hasMoreData && viewModel.isLoadingMore
                                  ? 1
                                  : 0)
                          : viewModel.desaparecidos.length +
                              (viewModel.hasMoreData && viewModel.isLoadingMore
                                  ? 1
                                  : 0),
                  itemBuilder: (context, index) {
                    if ((_searchController.text.isNotEmpty &&
                            index >= viewModel.searchedDesaparecidos.length) ||
                        (!_searchController.text.isNotEmpty &&
                            index >= viewModel.desaparecidos.length)) {
                      return viewModel.isLoadingMore
                          ? const Center(child: CircularProgressIndicator())
                          : Container();
                    }
                    final desaparecido =
                        _searchController.text.isNotEmpty
                            ? viewModel.searchedDesaparecidos[index]
                            : viewModel.desaparecidos[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        leading:
                            desaparecido.fotoUrl != null &&
                                    desaparecido.fotoUrl!.isNotEmpty
                                ? CircleAvatar(
                                  backgroundImage: NetworkImage(
                                    desaparecido.fotoUrl!,
                                  ),
                                )
                                : const Icon(Icons.person, size: 40),
                        title: Text(
                          '${desaparecido.nombres} ${desaparecido.apellidos}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (desaparecido.fechaDesaparicion != null)
                              Text(
                                'Desaparecido el: ${desaparecido.fechaDesaparicion!.day}/${desaparecido.fechaDesaparicion!.month}/${desaparecido.fechaDesaparicion!.year}',
                              ),
                            if (desaparecido.departamento != null)
                              Text(
                                'Departamento: ${desaparecido.departamento}',
                              ),
                            if (desaparecido.provincia != null)
                              Text('Provincia: ${desaparecido.provincia}'),
                            if (desaparecido.distrito != null)
                              Text('Distrito: ${desaparecido.distrito}'),
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
                              builder:
                                  (context) => MissingDetailsScreen(
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Marcar la función como async
          // --- INICIO: Modificar navegación ---
          final result = await Navigator.push<bool>(
            // Espera un resultado booleano
            context,
            MaterialPageRoute(builder: (context) => const AddMissingScreen()),
          );

          // Si el resultado es true (porque hicimos pop(context, true) al guardar)
          if (result == true && mounted) {
            // Llama al método del ViewModel para refrescar la lista
            // Asegúrate que tu ViewModel tenga un método para refrescar,
            // podría ser el mismo getMissingPeople o uno nuevo.
            Provider.of<ManageMissingViewModel>(
              context,
              listen: false,
            ).getMissingPeople(
              forceRefresh: true,
            ); // Asumiendo que tienes forceRefresh o un método similar
          }
          // --- FIN: Modificar navegación ---
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
