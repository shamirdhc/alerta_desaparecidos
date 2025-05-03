import 'package:flutter/foundation.dart';
import 'package:alerta_desaparecidos/domain/entities/desaparecido.dart';
import 'package:alerta_desaparecidos/domain/use_cases/obtener_desaparecidos_use_case.dart';
import 'package:alerta_desaparecidos/common/state_enum.dart'; // O domain/enums
// --- Añade esta línea ---
import 'package:alerta_desaparecidos/domain/enums.dart'; // O la ruta correcta donde esté MissingFilter

class ViewMissingViewModel extends ChangeNotifier {
  final ObtenerDesaparecidosUseCase obtenerDesaparecidosUseCase;

  ViewMissingViewModel(this.obtenerDesaparecidosUseCase);

  List<Desaparecido> _desaparecidos = [];
  List<Desaparecido> get desaparecidos => _desaparecidos;

  RequestState _state = RequestState.Empty;
  RequestState get state => _state;

  String _message = '';
  String get message => _message;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMoreData = true; // Para saber si intentar cargar más
  Desaparecido? _lastDesaparecido; // Para la paginación

  // --- CAMBIO: Guardar filtros actuales ---
  String? _currentSearchQuery;
  String? _currentDepartamento;
  // --- FIN CAMBIO ---

  final int _itemsPerPage = 10; // Define un límite por página

  // Método principal para obtener/refrescar la lista
  Future<void> getMissingPeople({
    bool forceRefresh = false,
    String? searchQuery, // Añadir parámetro opcional
    String? departamento, // Añadir parámetro opcional
  }) async {
    if (forceRefresh) {
      _desaparecidos = [];
      _lastDesaparecido = null;
      _hasMoreData = true;
      _currentSearchQuery = searchQuery; // Guardar query para filtro local
      _currentDepartamento = departamento;
    }

    if (_state == RequestState.Loading || !_hasMoreData) return;

    _state = RequestState.Loading;
    notifyListeners();

    // --- CAMBIO: Pasar solo departamento a la consulta de Firestore ---
    // La búsqueda por nombre/apellido (LIKE) se hará localmente.
    // Si tu `obtenerDesaparecidosUseCase` *necesita* un searchQuery para
    // otra cosa (ej. ordenamiento inicial), puedes mantenerlo.
    // Si no, puedes pasar null o string vacío para `searchQuery` aquí.
    // Asumiremos por ahora que solo filtramos por departamento en Firestore.
    final result = await obtenerDesaparecidosUseCase.execute(
      lastDesaparecido: _lastDesaparecido,
      // searchQuery: null, // Opcional: anular query para Firestore si no se usa
      departamento: _currentDepartamento,
      limit: _itemsPerPage, // <-- Añadir límite
      filter: MissingFilter.active, // <-- Añadir filtro (ciudadano solo ve activos)
    );
    // --- FIN CAMBIO ---

    result.fold(
      (failure) {
        _message = failure.message;
        _state = RequestState.Error;
        notifyListeners();
      },
      (newData) {
        if (newData.isEmpty) {
          _hasMoreData = false; // Firestore no devolvió más datos
        } else {
          // --- CAMBIO: Actualizar _lastDesaparecido ANTES de filtrar ---
          // Usamos el último documento real de Firestore para la paginación
          _lastDesaparecido = newData.last;
          // --- FIN CAMBIO ---

          // --- CAMBIO: Aplicar filtro local ---
          final filteredData = _filterLocally(newData, _currentSearchQuery);
          _desaparecidos.addAll(filteredData);
          // --- FIN CAMBIO ---

          // Opcional: Si usas límite, puedes refinar _hasMoreData aquí
          // if (newData.length < 10) _hasMoreData = false;
        }
        _state = RequestState.Loaded;
        notifyListeners();
      },
    );
  }

  // Método para buscar (reinicia la lista con nuevos filtros)
  Future<void> searchMissingPeople(String query, {String? departamento}) async {
    // Llama a getMissingPeople con forceRefresh para reiniciar la lista
    // y aplicar los nuevos filtros de búsqueda y departamento.
    await getMissingPeople(
      forceRefresh: true,
      searchQuery: query,
      departamento: departamento,
    );
  }

  // Método para cargar más resultados (paginación)
  Future<void> loadMoreMissingPeople({String? searchQuery, String? departamento}) async {
    if (_isLoadingMore || !_hasMoreData || _state == RequestState.Loading) return;

    _isLoadingMore = true;
    notifyListeners();

    // Verificar si los filtros cambiaron (esta lógica está bien)
    if (searchQuery != _currentSearchQuery || departamento != _currentDepartamento) {
       print("Filters changed during load more. Refreshing instead.");
       _isLoadingMore = false;
       notifyListeners();
       await getMissingPeople(forceRefresh: true, searchQuery: searchQuery, departamento: departamento);
       return;
    }

    // --- CAMBIO: Añadir limit y filter ---
    // Igual que en getMissingPeople, la búsqueda LIKE es local.
    final result = await obtenerDesaparecidosUseCase.execute(
      lastDesaparecido: _lastDesaparecido,
      // searchQuery: null, // Opcional: anular query para Firestore
      departamento: _currentDepartamento,
      limit: _itemsPerPage, // <-- Añadir límite
      filter: MissingFilter.active, // <-- Añadir filtro (ciudadano solo ve activos)
    );
    // --- FIN CAMBIO ---

    result.fold(
      (failure) {
        print('Error al cargar más: ${failure.message}');
        _hasMoreData = false; // Asumir que no se puede cargar más
      },
      (newData) {
        if (newData.isEmpty) {
          _hasMoreData = false; // Firestore no devolvió más datos
        } else {
          // --- CAMBIO: Actualizar _lastDesaparecido ANTES de filtrar ---
          _lastDesaparecido = newData.last;
          // --- FIN CAMBIO ---

          // --- CAMBIO: Aplicar filtro local ---
          final filteredData = _filterLocally(newData, _currentSearchQuery);
          _desaparecidos.addAll(filteredData);
          // --- FIN CAMBIO ---

          // Opcional: Si usas límite, puedes refinar _hasMoreData aquí
          // if (newData.length < 10) _hasMoreData = false;
        }
      },
    );

    _isLoadingMore = false;
    notifyListeners();
  }

  // --- NUEVA FUNCIÓN: Filtrado local tipo LIKE ---
  List<Desaparecido> _filterLocally(List<Desaparecido> data, String? query) {
    if (query == null || query.trim().isEmpty) {
      return data; // No hay consulta, devolver todos los datos
    }
    final upperCaseQuery = query.trim().toUpperCase();
    return data.where((item) {
      final nombreCompleto = '${item.nombres} ${item.apellidos}'.toUpperCase();
      // Puedes ajustar si quieres buscar solo en nombres o apellidos por separado
      // final nombreMatches = item.nombres.toUpperCase().contains(upperCaseQuery);
      // final apellidoMatches = item.apellidos.toUpperCase().contains(upperCaseQuery);
      // return nombreMatches || apellidoMatches;
      return nombreCompleto.contains(upperCaseQuery); // Busca en nombre + apellido
    }).toList();
  }
  // --- FIN NUEVA FUNCIÓN ---
}