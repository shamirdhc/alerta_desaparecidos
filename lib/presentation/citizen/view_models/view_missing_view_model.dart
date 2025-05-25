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
  // --- NUEVO: Guardar filtro de estado actual ---
  MissingFilter _currentStatusFilter = MissingFilter.active; // Por defecto 'activo' (DESAPARECIDOS)
  // --- FIN NUEVO ---

  final int _itemsPerPage = 10; // Define un límite por página

  // Método principal para obtener/refrescar la lista
  Future<void> getMissingPeople({
    bool forceRefresh = false,
    String? searchQuery, // Añadir parámetro opcional
    String? departamento, // Añadir parámetro opcional
    // --- NUEVO: Parámetro para el filtro de estado ---
    String? status, // 'activo' o 'encontrado'
    // --- FIN NUEVO ---
  }) async {
    if (forceRefresh) {
      _desaparecidos = [];
      _lastDesaparecido = null;
      _hasMoreData = true;
      _currentSearchQuery = searchQuery; // Guardar query para filtro local
      _currentDepartamento = departamento;
      // --- NUEVO: Actualizar _currentStatusFilter basado en el parámetro status ---
      if (status == 'encontrado') {
        _currentStatusFilter = MissingFilter.found;
      } else {
        _currentStatusFilter = MissingFilter.active; // Default a active si status es nulo o 'activo'
      }
      // --- FIN NUEVO ---
    }

    if (_state == RequestState.Loading || !_hasMoreData) return;

    _state = RequestState.Loading;
    notifyListeners();

    final result = await obtenerDesaparecidosUseCase.execute(
      lastDesaparecido: _lastDesaparecido,
      departamento: _currentDepartamento,
      limit: _itemsPerPage,
      // --- MODIFICADO: Usar _currentStatusFilter --- 
      filter: _currentStatusFilter,
      // --- FIN MODIFICADO ---
    );

    result.fold(
      (failure) {
        _message = failure.message;
        _state = RequestState.Error;
        // --- DEBUG PRINT --- ELIMINADO
        // print('[VM DEBUG] getMissingPeople: Error fetching - ${failure.message}');
        // --- FIN DEBUG PRINT --- ELIMINADO
        notifyListeners();
      },
      (newData) {
        // --- DEBUG PRINT --- ELIMINADO
        // print('[VM DEBUG] getMissingPeople: Data received from Firebase: ${newData.length} items.');
        // --- FIN DEBUG PRINT --- ELIMINADO

        if (newData.isEmpty) {
          _hasMoreData = false;
        } else {
          _lastDesaparecido = newData.last;

          // --- DEBUG PRINT --- ELIMINADO
          // print('[VM DEBUG] getMissingPeople: Applying local filter with query: "$_currentSearchQuery"');
          // --- FIN DEBUG PRINT --- ELIMINADO
          final filteredData = _filterLocally(newData, _currentSearchQuery);
          // --- DEBUG PRINT --- ELIMINADO
          // print('[VM DEBUG] getMissingPeople: Data after local filter: ${filteredData.length} items.');
          // --- FIN DEBUG PRINT --- ELIMINADO
          _desaparecidos.addAll(filteredData);
        }
        _state = RequestState.Loaded;
        notifyListeners();
      },
    );
  }

  // Método para buscar (reinicia la lista con nuevos filtros)
  // --- MODIFICADO: Añadir parámetro status --- 
  Future<void> searchMissingPeople(String query, {String? departamento, String? status}) async {
  // --- FIN MODIFICADO ---
    // Llama a getMissingPeople con forceRefresh para reiniciar la lista
    // y aplicar los nuevos filtros de búsqueda y departamento.
    await getMissingPeople(
      forceRefresh: true,
      searchQuery: query,
      departamento: departamento,
      // --- MODIFICADO: Pasar el status --- 
      status: status,
      // --- FIN MODIFICADO ---
    );
  }

  // Método para cargar más resultados (paginación)
  Future<void> loadMoreMissingPeople() async {
    if (_isLoadingMore || !_hasMoreData || _state == RequestState.Loading) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    final result = await obtenerDesaparecidosUseCase.execute(
      lastDesaparecido: _lastDesaparecido,
      departamento: _currentDepartamento,
      limit: _itemsPerPage,
      // --- MODIFICADO: Usar _currentStatusFilter para la paginación --- 
      filter: _currentStatusFilter,
      // --- FIN MODIFICADO ---
    );

    result.fold(
      (failure) {
        // El print de error real puede quedarse si lo deseas, o eliminarlo si prefieres.
        // Por ahora, lo mantendremos como un log de error útil.
        print(
          'Error al cargar más desaparecidos: ${failure.message}',
        ); // Este es un error, no un debug.
        _message = failure.message;
        _hasMoreData = false;
        _isLoadingMore = false;
        notifyListeners();
      },
      (newData) {
        // --- DEBUG PRINT --- ELIMINADO
        // print('[VM DEBUG] loadMoreMissingPeople: Data received from Firebase: ${newData.length} items.');
        // --- FIN DEBUG PRINT --- ELIMINADO

        if (newData.isEmpty) {
          _hasMoreData = false;
        } else {
          _lastDesaparecido = newData.last;

          // --- DEBUG PRINT --- ELIMINADO
          // print('[VM DEBUG] loadMoreMissingPeople: Applying local filter with query: "$_currentSearchQuery"');
          // --- FIN DEBUG PRINT --- ELIMINADO
          final filteredData = _filterLocally(newData, _currentSearchQuery);
          // --- DEBUG PRINT --- ELIMINADO
          // print('[VM DEBUG] loadMoreMissingPeople: Data after local filter: ${filteredData.length} items.');
          // --- FIN DEBUG PRINT --- ELIMINADO
          _desaparecidos.addAll(filteredData);

          if (newData.length < _itemsPerPage) {
            _hasMoreData = false;
          }
        }
        _isLoadingMore = false;
        notifyListeners();
      },
    );

    // _isLoadingMore = false; // Movido dentro de fold
    // notifyListeners(); // Movido dentro de fold
  }

  // --- FIN CAMBIO --- // This comment belongs to loadMoreMissingPeople

  // --- ADD THE _filterLocally METHOD DEFINITION HERE ---
  List<Desaparecido> _filterLocally(List<Desaparecido> data, String? query) {
    final trimmedQuery =
        query?.trim(); // Elimina espacios al inicio/final del query

    // Si el query es nulo o vacío después de trim, no hay nada que filtrar, devuelve todos los datos.
    if (trimmedQuery == null || trimmedQuery.isEmpty) {
      return data;
    }
    final upperQuery =
        trimmedQuery
            .toUpperCase(); // Convierte el query a mayúsculas para comparación case-insensitive

    return data.where((d) {
      // Procesa los nombres y apellidos del desaparecido:
      // 1. Usa ?? '' para evitar errores si son null.
      // 2. Usa .trim() para quitar espacios extra.
      // 3. Usa .toUpperCase() para comparación case-insensitive.
      final String nombresProcessed = (d.nombres ?? '').trim().toUpperCase();
      final String apellidosProcessed =
          (d.apellidos ?? '').trim().toUpperCase();

      // Combina los nombres y apellidos procesados.
      // El .trim() final es por si uno de los campos estaba vacío, para no tener doble espacio.
      final String fullNameProcessed =
          '$nombresProcessed $apellidosProcessed'.trim();

      // Si el nombre completo procesado está vacío, no puede coincidir con un query no vacío.
      if (fullNameProcessed.isEmpty && upperQuery.isNotEmpty) {
        // Condición más precisa
        return false;
      }

      // Verifica si el nombre completo procesado contiene el query.
      return fullNameProcessed.contains(upperQuery);
    }).toList();
  }

  // --- END OF _filterLocally METHOD ---
}
