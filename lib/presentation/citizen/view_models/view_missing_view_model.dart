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
  // Método principal para obtener/refrescar la lista
  Future<void> getMissingPeople({
    bool forceRefresh = false,
    String? searchQuery,
    String? departamento,
    String? status,
  }) async {
    print('🔥 [DEBUG] getMissingPeople llamado con:');
    print('   - forceRefresh: $forceRefresh');
    print('   - searchQuery: "$searchQuery"');
    print('   - departamento: "$departamento"');
    print('   - status: "$status"');
  
    if (forceRefresh) {
      print('   - Reiniciando lista y configurando filtros...');
      _desaparecidos = [];
      _lastDesaparecido = null;
      _hasMoreData = true;
      _currentSearchQuery = searchQuery;
      _currentDepartamento = departamento;
      
      if (status == 'encontrado') {
        _currentStatusFilter = MissingFilter.found;
      } else {
        _currentStatusFilter = MissingFilter.active;
      }
      print('   - _currentStatusFilter actualizado a: $_currentStatusFilter');
    }
  
    if (_state == RequestState.Loading || !_hasMoreData) {
      print('   - Saliendo temprano: state=$_state, hasMoreData=$_hasMoreData');
      return;
    }
  
    _state = RequestState.Loading;
    notifyListeners();
  
    print('🔥 [DEBUG] Ejecutando obtenerDesaparecidosUseCase con:');
    print('   - filter: $_currentStatusFilter');
    print('   - departamento: "$_currentDepartamento"');
    print('   - limit: $_itemsPerPage');
  
    final result = await obtenerDesaparecidosUseCase.execute(
      lastDesaparecido: _lastDesaparecido,
      departamento: _currentDepartamento,
      limit: _itemsPerPage,
      filter: _currentStatusFilter,
      searchQuery: _currentSearchQuery,
    );
  
    result.fold(
      (failure) {
        print('❌ [DEBUG] Error en getMissingPeople: ${failure.message}');
        _message = failure.message;
        _state = RequestState.Error;
        notifyListeners();
      },
      (newData) {
        print('✅ [DEBUG] Datos recibidos de Firebase: ${newData.length} elementos');
        
        if (newData.isNotEmpty) {
          print('📋 [DEBUG] Primeros datos recibidos:');
          for (int i = 0; i < (newData.length > 3 ? 3 : newData.length); i++) {
            final d = newData[i];
            print('   [$i] ${d.nombres} ${d.apellidos} - Estado: ${d.estado} - Dept: ${d.departamento}');
          }
        }
  
        if (newData.isEmpty) {
          _hasMoreData = false;
          print('🚫 [DEBUG] No hay más datos disponibles');
        } else {
          _lastDesaparecido = newData.last;
          final filteredData = _filterLocally(newData, _currentSearchQuery);
          print('🔍 [DEBUG] Después del filtro local: ${filteredData.length} elementos');
          _desaparecidos.addAll(filteredData);
        }
        
        _state = RequestState.Loaded;
        print('📊 [DEBUG] Estado final: ${_desaparecidos.length} elementos en la lista');
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
      filter: _currentStatusFilter,
      searchQuery: _currentSearchQuery, // AGREGAR ESTA LÍNEA
    );
  
    result.fold(
      (failure) {
        print('Error al cargar más desaparecidos: ${failure.message}');
        _message = failure.message;
        _hasMoreData = false;
        _isLoadingMore = false;
        notifyListeners();
      },
      (newData) {
        if (newData.isEmpty) {
          _hasMoreData = false;
        } else {
          _lastDesaparecido = newData.last;
          final filteredData = _filterLocally(newData, _currentSearchQuery);
          _desaparecidos.addAll(filteredData);
  
          if (newData.length < _itemsPerPage) {
            _hasMoreData = false;
          }
        }
        _isLoadingMore = false;
        notifyListeners();
      },
    );
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
