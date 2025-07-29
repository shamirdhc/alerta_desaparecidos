import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/agenda_policial_service.dart';
import '../../../data/models/comisaria_model.dart';

class SearchEssaysScreen extends StatefulWidget {
  const SearchEssaysScreen({super.key});

  @override
  State<SearchEssaysScreen> createState() => _SearchEssaysScreenState();
}

class _SearchEssaysScreenState extends State<SearchEssaysScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<String> _departamentosDisponibles = [];
  List<ComisariaModel> _comisarias = [];
  List<ComisariaModel> _comisariasFiltradas = [];

  String? _departamentoSeleccionado;
  bool _isLoading = false;
  bool _isSearching = false;
  String _mensaje = '';

  @override
  void initState() {
    super.initState();
    _initializeService();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    setState(() {
      _isLoading = true;
      _mensaje = 'Inicializando servicio...';
    });

    try {
      await AgendaPolicialService.inicializarSincronizacion();
      await _cargarDepartamentos();
    } catch (e) {
      setState(() {
        _mensaje = 'Error al inicializar: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarDepartamentos() async {
    try {
      final departamentos =
          await AgendaPolicialService.getDepartamentosDisponibles();
      setState(() {
        _departamentosDisponibles = departamentos;
        if (departamentos.isNotEmpty) {
          _mensaje = '${departamentos.length} departamentos disponibles';
        } else {
          _mensaje = 'No se encontraron departamentos';
        }
      });
    } catch (e) {
      setState(() {
        _mensaje = 'Error al cargar departamentos: $e';
      });
    }
  }

  Future<void> _seleccionarDepartamento(String departamento) async {
    setState(() {
      _departamentoSeleccionado = departamento;
      _isLoading = true;
      _mensaje = 'Cargando comisarías de $departamento...';
      _comisarias.clear();
      _comisariasFiltradas.clear();
      _searchController.clear();
    });

    try {
      final comisarias =
          await AgendaPolicialService.cargarComisariasDepartamento(
            departamento,
          );
      setState(() {
        _comisarias = comisarias;
        _comisariasFiltradas = comisarias;
        _mensaje =
            '${comisarias.length} comisarías encontradas en $departamento';
      });
    } catch (e) {
      setState(() {
        _mensaje = 'Error al cargar comisarías: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (_departamentoSeleccionado == null) return;

    if (query.isEmpty) {
      setState(() {
        _comisariasFiltradas = _comisarias;
        _isSearching = false;
      });
    } else {
      setState(() {
        _isSearching = true;
      });
      _buscarComisarias(query);
    }
  }

  Future<void> _buscarComisarias(String query) async {
    if (_departamentoSeleccionado == null) return;

    try {
      final resultados = await AgendaPolicialService.buscarComisarias(
        _departamentoSeleccionado!,
        query,
      );

      setState(() {
        _comisariasFiltradas = resultados;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _mensaje = 'Error en búsqueda: $e';
      });
    }
  }

  Future<void> _realizarLlamada(String telefono) async {
    if (telefono.isEmpty) {
      _mostrarMensaje('Número de teléfono no disponible');
      return;
    }

    try {
      final uri = Uri(scheme: 'tel', path: telefono);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _mostrarMensaje('No se puede realizar la llamada');
      }
    } catch (e) {
      _mostrarMensaje('Error al realizar llamada: $e');
    }
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Agenda Policial',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1565C0),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Header con información
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Directorio de Comisarías PNP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _mensaje,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          // Selector de departamento
          if (_departamentosDisponibles.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _departamentoSeleccionado,
                  hint: const Text('Seleccionar departamento'),
                  isExpanded: true,
                  items:
                      _departamentosDisponibles.map((departamento) {
                        return DropdownMenuItem<String>(
                          value: departamento,
                          child: Text(departamento),
                        );
                      }).toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      _seleccionarDepartamento(value);
                    }
                  },
                ),
              ),
            ),
          ],

          // Barra de búsqueda
          if (_departamentoSeleccionado != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar comisaría...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon:
                      _isSearching
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                          : _searchController.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          )
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Lista de comisarías
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Cargando datos...'),
                        ],
                      ),
                    )
                    : _departamentoSeleccionado == null
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_city,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Selecciona un departamento\npara ver las comisarías',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : _comisariasFiltradas.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No se encontraron comisarías',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _comisariasFiltradas.length,
                      itemBuilder: (context, index) {
                        final comisaria = _comisariasFiltradas[index];
                        return _buildComisariaCard(comisaria);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildComisariaCard(ComisariaModel comisaria) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              comisaria.nombre,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 8),
            if (comisaria.unidad.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.business, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      comisaria.unidad,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            if (comisaria.provincia.isNotEmpty ||
                comisaria.distrito.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${comisaria.provincia}${comisaria.provincia.isNotEmpty && comisaria.distrito.isNotEmpty ? ' - ' : ''}${comisaria.distrito}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (comisaria.telefono.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      comisaria.telefono,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _realizarLlamada(comisaria.telefono),
                    icon: const Icon(Icons.call, size: 16),
                    label: const Text('Llamar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
