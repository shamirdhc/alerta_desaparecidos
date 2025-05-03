import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Necesario para formatear la fecha
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_missing_view_model.dart';
import 'package:alerta_desaparecidos/domain/entities/desaparecido.dart';
import 'package:alerta_desaparecidos/common/state_enum.dart'; // Asegúrate que RequestState esté aquí o en domain/enums
import 'package:alerta_desaparecidos/presentation/citizen/screens/citizen_missing_details_screen.dart';
import 'package:alerta_desaparecidos/helpers/database_helpers.dart';
import 'package:flutter/services.dart';

class ViewMissingScreen extends StatefulWidget {
  const ViewMissingScreen({super.key});

  @override
  State<ViewMissingScreen> createState() => _ViewMissingScreenState();
}

class _ViewMissingScreenState extends State<ViewMissingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDepartamento;
  List<Map<String, dynamic>> _departamentosData = [];
  final ScrollController _scrollController = ScrollController();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Carga inicial sin filtros específicos (o podrías pasar null explícitamente)
      Provider.of<ViewMissingViewModel>(
        context,
        listen: false,
      ).getMissingPeople(forceRefresh: true);
    });

    _loadDepartamentos();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // --- CAMBIO: Pasar ambos filtros al cargar más ---
      Provider.of<ViewMissingViewModel>(
        context,
        listen: false,
      ).loadMoreMissingPeople(
        searchQuery: _searchController.text,
        departamento: _selectedDepartamento,
      );
      // --- FIN CAMBIO ---
    }
  }

  void _onSearchChanged() {
    // --- CAMBIO: Pasar ambos filtros al buscar ---
    Provider.of<ViewMissingViewModel>(
      context,
      listen: false,
    ).searchMissingPeople(
      _searchController.text,
      departamento: _selectedDepartamento, // Pasar el departamento actual
    );
    // --- FIN CAMBIO ---
  }

  Future<void> _loadDepartamentos() async {
    try {
      final data = await _dbHelper.getDepartamentos();
      if (mounted) {
        setState(() {
          _departamentosData = data;
          // print('Departamentos cargados: $_departamentosData'); // Debug
        });
      }
    } catch (e) {
      print('Error al cargar departamentos: $e');
      if (mounted) {
        setState(() {
          _departamentosData = [];
        });
        // Considera mostrar un SnackBar al usuario aquí
      }
    }
  }

  void _onDepartamentoChanged(String? newValue) {
    setState(() {
      _selectedDepartamento = newValue;
    });

    // --- CAMBIO AQUÍ: Convertir a mayúsculas antes de filtrar ---
    final departamentoParaFiltrar = _selectedDepartamento?.toUpperCase();
    // --- FIN CAMBIO ---

    Provider.of<ViewMissingViewModel>(
      context,
      listen: false,
    ).searchMissingPeople(
      _searchController.text, // Mantener el texto de búsqueda actual
      // --- CAMBIO AQUÍ: Usar el valor en mayúsculas ---
      departamento:
          departamentoParaFiltrar, // Aplicar el departamento en mayúsculas
      // --- FIN CAMBIO ---
    );
  }

  @override
  Widget build(BuildContext context) {
    // Escucha los cambios en el ViewModel
    final viewModel = Provider.of<ViewMissingViewModel>(context);

    // --- CAMBIO: Eliminar filtrado local ---
    // Ya no necesitamos filtrar aquí, usamos la lista del ViewModel directamente
    // final List<Desaparecido> displayList =
    //     viewModel.desaparecidos
    //         .where(
    //           (d) =>
    //               (_selectedDepartamento == null ||
    //                   d.departamento == _selectedDepartamento),
    //         )
    //         .toList();
    // --- FIN CAMBIO ---

    // Debug prints (puedes quitarlos en producción)
    // print('[UI DEBUG] viewModel.state: ${viewModel.state}');
    // print(
    //   '[UI DEBUG] viewModel.desaparecidos count: ${viewModel.desaparecidos.length}',
    // );
    // print( // Ya no aplica el displayList local
    //   '[UI DEBUG] displayList count after depto filter: ${displayList.length}',
    // );

    return Column(
      children: [
        // --- Fila 1: Filtro de Departamento ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: DropdownButtonFormField<String>(
            value: _selectedDepartamento,
            hint: const Text('Filtrar por Departamento'),
            isExpanded: true,
            items:
                _departamentosData.map<DropdownMenuItem<String>>((
                  Map<String, dynamic> depto,
                ) {
                  // --- CAMBIO: Usar 'name' como valor si el ID no está o es inconsistente ---
                  // Asegúrate que el valor coincida con cómo guardas el departamento en Firestore
                  final String? deptoName = depto['name'] as String?;
                  return DropdownMenuItem<String>(
                    value:
                        deptoName, // Usar el nombre directamente si así está en Firestore
                    child: Text(deptoName ?? 'Nombre no disponible'),
                  );
                  // --- FIN CAMBIO ---
                }).toList(),
            onChanged: _onDepartamentoChanged, // Asignar el método aquí
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
        ),

        // --- Fila 2: Barra de Búsqueda ---
        // (Sin cambios aquí)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _searchController,
            inputFormatters: [
              // Esto fuerza a que todo lo escrito sea en mayúsculas
              UpperCaseTextFormatter(),
            ],
            decoration: InputDecoration(
              hintText: 'Buscar por nombre y/o apellidos...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
            ),
          ),
        ),

        // --- Fila 3: Título "SE BUSCA" ---
        // (Sin cambios aquí)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: const Text(
            'SE BUSCA',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent, // O el color que prefieras
            ),
          ),
        ),

        // --- Lista de Desaparecidos ---
        Expanded(
          child: Consumer<ViewMissingViewModel>(
            builder: (context, vm, child) {
              if (vm.state == RequestState.Loading &&
                  vm.desaparecidos.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (vm.state == RequestState.Error) {
                return Center(child: Text('Error: ${vm.message}'));
              }
              // --- CAMBIO: Usar vm.desaparecidos directamente ---
              if (vm.state != RequestState.Loading &&
                  vm.desaparecidos.isEmpty) {
                // --- CAMBIO: Actualizar texto de "sin resultados" ---
                String emptyMessage = 'NO HAY CASOS ACTIVOS REGISTRADOS.';
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
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      emptyMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ),
                );
                // --- FIN CAMBIO ---
              }

              // Si hay datos para mostrar
              return ListView.builder(
                controller: _scrollController,
                // --- CAMBIO: Usar vm.desaparecidos.length ---
                itemCount: vm.desaparecidos.length + (vm.isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  // --- CAMBIO: Comparar con vm.desaparecidos.length ---
                  if (index == vm.desaparecidos.length) {
                    return vm.isLoadingMore
                        ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                        : const SizedBox.shrink();
                  }

                  // --- CAMBIO: Usar vm.desaparecidos ---
                  if (index < vm.desaparecidos.length) {
                    final desaparecido = vm.desaparecidos[index];
                    // --- FIN CAMBIO ---
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => CitizenMissingDetailsScreen(
                                  desaparecido: desaparecido,
                                ),
                          ),
                        );
                      },
                      child: _buildMissingPersonCard(desaparecido),
                    );
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Widget para construir la tarjeta de una persona desaparecida ---
  // (Sin cambios en _buildMissingPersonCard)
  Widget _buildMissingPersonCard(Desaparecido desaparecido) {
    // Función interna para calcular la edad
    int? calcularEdad(DateTime? fechaNacimiento) {
      // <-- Acepta DateTime?
      if (fechaNacimiento == null) {
        return null; // Retorna null si la fecha es nula
      }
      final hoy = DateTime.now();
      int edad = hoy.year - fechaNacimiento.year;
      if (hoy.month < fechaNacimiento.month ||
          (hoy.month == fechaNacimiento.month &&
              hoy.day < fechaNacimiento.day)) {
        edad--;
      }
      return edad;
    }

    // Calcula la edad (ahora puede ser null)
    final int? edadCalculada = calcularEdad(desaparecido.fechaNacimiento);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mostrar imagen si existe URL
            if (desaparecido.fotoUrl != null &&
                desaparecido.fotoUrl!.isNotEmpty)
              Center(
                // Centrar la imagen
                child: ClipRRect(
                  // Para bordes redondeados si quieres
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    desaparecido.fotoUrl!,
                    height: 150, // Ajusta la altura como necesites
                    width: double.infinity, // Ocupar ancho de la tarjeta
                    fit: BoxFit.cover, // Cubrir el espacio asignado
                    // Indicador de carga mientras se descarga la imagen
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(
                        height: 150,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    // Widget a mostrar si hay error al cargar la imagen
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        height: 150,
                        child: Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (desaparecido.fotoUrl != null &&
                desaparecido.fotoUrl!.isNotEmpty)
              const SizedBox(height: 12), // Espacio después de la imagen
            // Nombre y Apellidos
            Text(
              '${desaparecido.nombres} ${desaparecido.apellidos}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // --- CAMBIO: Mostrar edad o texto alternativo ---
            // Edad Calculada (mostrar solo si no es nula)
            if (edadCalculada != null)
              Text('Edad: $edadCalculada años')
            else
              const Text(
                'Edad: Desconocida',
              ), // Texto si la fecha de nacimiento es nula
            // --- FIN CAMBIO ---
            const SizedBox(height: 4),

            // Departamento
            Text('Departamento: ${desaparecido.departamento}'),
            const SizedBox(height: 4),

            // --- CAMBIO: Mostrar fecha de desaparición o texto alternativo ---
            // Fecha de Desaparición (formateada, si no es nula)
            if (desaparecido.fechaDesaparicion != null)
              Text(
                'Fecha desaparición: ${DateFormat('dd/MM/yyyy').format(desaparecido.fechaDesaparicion!)}',
              ) // Usar ! porque ya comprobamos que no es null
            else
              const Text(
                'Fecha desaparición: Desconocida',
              ), // Texto si la fecha es nula
            // --- FIN CAMBIO ---
            const SizedBox(height: 4),

            // Puedes añadir más detalles aquí si los tienes en tu entidad Desaparecido
            // Text('Contextura: ${desaparecido.contextura}'),
            // Text('Tez: ${desaparecido.tez}'),
          ],
        ),
      ),
    );
  }
}

// ...existing code...

// Coloca esto al final del archivo, fuera de cualquier otra clase:
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
