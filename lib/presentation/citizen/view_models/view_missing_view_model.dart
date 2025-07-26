import 'package:flutter/foundation.dart';
import 'package:alerta_desaparecidos/domain/entities/desaparecido.dart';
import 'package:alerta_desaparecidos/domain/use_cases/obtener_desaparecidos_use_case.dart';
import 'package:alerta_desaparecidos/common/state_enum.dart';
import 'package:alerta_desaparecidos/domain/enums.dart';

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

  bool _hasMoreData = true;
  Desaparecido? _lastDesaparecido;

  String? _currentSearchQuery;
  String? _currentDepartamento;
  MissingFilter _currentStatusFilter = MissingFilter.active;

  final int _itemsPerPage = 10;

  // Variable para el total real
  int _totalCount = 0;
  int get totalCount => _totalCount;

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
      
      // Cambiar la lógica: si es "encontrado", usar filtro 'all' y filtrar localmente
      if (status == 'encontrado') {
        _currentStatusFilter = MissingFilter.all; // Cambio aquí
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
      (response) {
        // ✅ Acceder a las propiedades del PaginatedResponse
        final newData = response.data;
        _totalCount = response.totalCount;
        
        print('✅ [DEBUG] Datos recibidos de Firebase: ${newData.length} elementos');
        
        if (newData.isEmpty) {
          _hasMoreData = false;
          print('🚫 [DEBUG] No hay más datos disponibles');
        } else {
          _lastDesaparecido = newData.last;
          if (_currentSearchQuery != null && _currentSearchQuery!.isNotEmpty) {
            _desaparecidos.addAll(newData);
          } else {
            final filteredData = _filterLocally(newData, _currentSearchQuery);
            _desaparecidos.addAll(filteredData);
          }
        }
        
        _state = RequestState.Loaded;
        print('📊 [DEBUG] Estado final: ${_desaparecidos.length} elementos en la lista');
        notifyListeners();
      },
    );
  }

  Future<void> searchMissingPeople(String query, {String? departamento, String? status}) async {
    await getMissingPeople(
      forceRefresh: true,
      searchQuery: query,
      departamento: departamento,
      status: status,
    );
  }

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
      searchQuery: _currentSearchQuery,
    );
  
    result.fold(
      (failure) {
        print('Error al cargar más desaparecidos: ${failure.message}');
        _message = failure.message;
        _hasMoreData = false;
        _isLoadingMore = false;
        notifyListeners();
      },
      (response) {
        // ✅ Acceder a las propiedades del PaginatedResponse
        final newData = response.data;
        
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

  List<Desaparecido> _filterLocally(List<Desaparecido> data, String? query) {
    final trimmedQuery = query?.trim();

    if (trimmedQuery == null || trimmedQuery.isEmpty) {
      return data;
    }
    final upperQuery = trimmedQuery.toUpperCase();

    return data.where((d) {
      final String nombresProcessed = (d.nombres ?? '').trim().toUpperCase();
      final String apellidosProcessed = (d.apellidos ?? '').trim().toUpperCase();
      final String fullNameProcessed = '$nombresProcessed $apellidosProcessed'.trim();

      if (fullNameProcessed.isEmpty && upperQuery.isNotEmpty) {
        return false;
      }

      return fullNameProcessed.contains(upperQuery);
    }).toList();
  }
}
