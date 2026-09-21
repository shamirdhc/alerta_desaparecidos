import 'package:flutter/foundation.dart';
import 'package:alerta_desaparecidos/domain/entities/desaparecido.dart';
import 'package:alerta_desaparecidos/domain/use_cases/obtener_desaparecidos_use_case.dart';
import 'package:alerta_desaparecidos/common/state_enum.dart';
import 'package:alerta_desaparecidos/domain/enums.dart';

class ViewMissingViewModel extends ChangeNotifier {
  final ObtenerDesaparecidosUseCase obtenerDesaparecidosUseCase;

  ViewMissingViewModel(this.obtenerDesaparecidosUseCase);

  final List<Desaparecido> _desaparecidos = [];
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

  // 🔥 MÉTODO PARA EVITAR DUPLICADOS
  void _addUniqueDesaparecidos(List<Desaparecido> newData) {
    final existingIds = _desaparecidos.map((d) => d.id).toSet();
    final uniqueData = newData.where((d) => !existingIds.contains(d.id)).toList();
    
    print('🔍 [DEBUG] Agregando ${uniqueData.length} elementos únicos de ${newData.length} recibidos');
    _desaparecidos.addAll(uniqueData);
  }

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
      _desaparecidos.clear(); // 🔥 USAR CLEAR() EN LUGAR DE ASIGNAR []
      _lastDesaparecido = null;
      _hasMoreData = true;
      _totalCount = 0; // 🔥 RESETEAR TOTAL COUNT
      _currentSearchQuery = searchQuery;
      _currentDepartamento = departamento;
      
      // Cambiar la lógica: si es "encontrado", usar filtro 'all' y filtrar localmente
      if (status == 'encontrado') {
        _currentStatusFilter = MissingFilter.all;
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
        final newData = response.data;
        
        print('✅ [DEBUG] Datos recibidos de Firebase: ${newData.length} elementos');
        
        if (newData.isEmpty) {
          _hasMoreData = false;
          print('🚫 [DEBUG] No hay más datos disponibles');
        } else {
          _lastDesaparecido = newData.last;
          
          // 🔥 FILTRAR POR ESTADO SI ES NECESARIO
          List<Desaparecido> filteredByStatus = newData;
          if (status == 'encontrado') {
            filteredByStatus = newData.where((d) => 
              (d.estado ?? '').trim().toLowerCase() == 'encontrado'
            ).toList();
            print('🎯 [DEBUG] Filtrados por estado "encontrado": ${filteredByStatus.length}');
          }
          
          // 🔥 APLICAR FILTRO LOCAL DE BÚSQUEDA
          final filteredData = _filterLocally(filteredByStatus, _currentSearchQuery);
          
          // 🔥 AGREGAR SOLO ELEMENTOS ÚNICOS
          _addUniqueDesaparecidos(filteredData);
          
          // 🔥 ACTUALIZAR TOTAL COUNT CORRECTAMENTE - Siempre usar el tamaño actual de la lista
          _totalCount = _desaparecidos.length;
          
          // 🔥 VERIFICAR SI HAY MÁS DATOS
          if (newData.length < _itemsPerPage) {
            _hasMoreData = false;
          }
        }
        
        _state = _desaparecidos.isEmpty ? RequestState.Empty : RequestState.Loaded;
        print('📊 [DEBUG] Estado final: ${_desaparecidos.length} elementos en la lista, total: $_totalCount');
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
        final newData = response.data;
        
        if (newData.isEmpty) {
          _hasMoreData = false;
        } else {
          _lastDesaparecido = newData.last;
          
          // 🔥 APLICAR FILTROS CONSISTENTES
          List<Desaparecido> filteredByStatus = newData;
          if (_currentStatusFilter == MissingFilter.all) {
            // Si estamos en modo "encontrado", filtrar por estado
            filteredByStatus = newData.where((d) => 
              (d.estado ?? '').trim().toLowerCase() == 'encontrado'
            ).toList();
          }
          
          final filteredData = _filterLocally(filteredByStatus, _currentSearchQuery);
          
          // 🔥 AGREGAR SOLO ELEMENTOS ÚNICOS
          _addUniqueDesaparecidos(filteredData);
          
          // 🔥 ACTUALIZAR TOTAL COUNT DESPUÉS DE CARGAR MÁS DATOS
          _totalCount = _desaparecidos.length;
  
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
      final String nombresProcessed = d.nombres.trim().toUpperCase();
      final String apellidosProcessed = d.apellidos.trim().toUpperCase();
      final String dniProcessed = (d.dni ?? '').trim();
      final String fullNameProcessed = '$nombresProcessed $apellidosProcessed'.trim();

      if (fullNameProcessed.isEmpty && upperQuery.isNotEmpty) {
        return false;
      }

      // 🔥 BÚSQUEDA MEJORADA: nombres, apellidos o DNI
      return fullNameProcessed.contains(upperQuery) || 
             dniProcessed.contains(upperQuery);
    }).toList();
  }
}
