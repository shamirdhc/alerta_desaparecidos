import 'package:flutter/foundation.dart';
import 'package:alerta_desaparecidos/domain/entities/desaparecido.dart';
import 'package:alerta_desaparecidos/domain/use_cases/obtener_desaparecidos_use_case.dart';
import 'package:alerta_desaparecidos/common/state_enum.dart';
import 'package:alerta_desaparecidos/domain/enums.dart';

class ViewFoundViewModel extends ChangeNotifier {
  final ObtenerDesaparecidosUseCase obtenerDesaparecidosUseCase;

  ViewFoundViewModel(this.obtenerDesaparecidosUseCase);

  final List<Desaparecido> _desaparecidos = [];
  List<Desaparecido> get desaparecidos => _desaparecidos;

  RequestState _state = RequestState.Empty;
  RequestState get state => _state;

  String _message = '';
  String get message => _message;

  bool _hasMoreData = true;
  bool get hasMoreData => _hasMoreData;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  Desaparecido? _lastDesaparecido;
  String? _currentSearchQuery;
  String? _currentDepartamento;
  
  // Usar 'all' para obtener todos los registros y filtrar localmente por personas encontradas
  final MissingFilter _currentStatusFilter = MissingFilter.all;

  final int _itemsPerPage = 50; // Aumentar para compensar filtrado local

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

  Future<void> getFoundPeople({
    bool forceRefresh = false,
    String? searchQuery,
    String? departamento,
  }) async {
    if (forceRefresh) {
      _desaparecidos.clear(); // 🔥 USAR CLEAR() EN LUGAR DE ASIGNAR []
      _lastDesaparecido = null;
      _hasMoreData = true;
      _totalCount = 0; // 🔥 RESETEAR TOTAL COUNT
      _currentSearchQuery = searchQuery;
      _currentDepartamento = departamento;
    }

    if (_state == RequestState.Loading || !_hasMoreData) return;

    _state = RequestState.Loading;
    notifyListeners();

    print('🔍 Iniciando búsqueda de personas encontradas...');

    final result = await obtenerDesaparecidosUseCase.execute(
      lastDesaparecido: _lastDesaparecido,
      departamento: _currentDepartamento,
      limit: _itemsPerPage,
      filter: _currentStatusFilter,
      searchQuery: _currentSearchQuery,
    );

    result.fold(
      (failure) {
        _message = failure.message;
        _state = RequestState.Error;
        notifyListeners();
      },
      (response) {
        print('📊 Total de registros recibidos: ${response.data.length}');
        
        // 🔥 FILTRAR LOCALMENTE SOLO PERSONAS CON ESTADO "ENCONTRADO"
        final foundPeople = response.data
            .where((desaparecido) {
              final estado = (desaparecido.estado ?? '').trim().toLowerCase();
              final isFound = estado == 'encontrado';
              if (isFound) {
                print('✅ Persona encontrada: ${desaparecido.nombres} ${desaparecido.apellidos}');
              }
              return isFound;
            })
            .toList();
        
        print('🎯 Personas encontradas después del filtro: ${foundPeople.length}');
        
        if (response.data.isEmpty) {
          _hasMoreData = false;
        } else {
          _lastDesaparecido = response.data.last;
          
          // 🔥 APLICAR FILTRO LOCAL DE BÚSQUEDA
          final filteredData = _filterLocally(foundPeople, _currentSearchQuery);
          
          // 🔥 AGREGAR SOLO ELEMENTOS ÚNICOS
          _addUniqueDesaparecidos(filteredData);

          // 🔥 ACTUALIZAR TOTAL COUNT CORRECTAMENTE
          if (forceRefresh) {
            _totalCount = _desaparecidos.length; // Para búsquedas, usar el tamaño actual
          } else {
            _totalCount = foundPeople.length; // Para carga inicial, usar personas encontradas
          }

          // 🔥 VERIFICAR SI HAY MÁS DATOS
          if (response.data.length < _itemsPerPage) {
            _hasMoreData = false;
          }
        }
        _state = _desaparecidos.isEmpty ? RequestState.Empty : RequestState.Loaded;
        print('📊 [DEBUG] Estado final: ${_desaparecidos.length} elementos en la lista, total: $_totalCount');
        notifyListeners();
      },
    );
  }

  // Método para buscar (reinicia la lista con nuevos filtros)
  Future<void> searchFoundPeople(String query, {String? departamento}) async {
    await getFoundPeople(
      forceRefresh: true,
      searchQuery: query,
      departamento: departamento,
    );
  }

  // Método para cargar más resultados (paginación)
  Future<void> loadMoreFoundPeople() async {
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
        print('Error al cargar más personas encontradas: ${failure.message}');
        _message = failure.message;
        _hasMoreData = false;
        _isLoadingMore = false;
        notifyListeners();
      },
      (response) {
        // 🔥 FILTRAR LOCALMENTE SOLO PERSONAS CON ESTADO "ENCONTRADO"
        final foundPeople = response.data
            .where((desaparecido) {
              final estado = (desaparecido.estado ?? '').trim().toLowerCase();
              return estado == 'encontrado';
            })
            .toList();
        
        if (response.data.isEmpty) {
          _hasMoreData = false;
        } else {
          _lastDesaparecido = response.data.last;
          
          // 🔥 APLICAR FILTRO LOCAL DE BÚSQUEDA
          final filteredData = _filterLocally(foundPeople, _currentSearchQuery);
          
          // 🔥 AGREGAR SOLO ELEMENTOS ÚNICOS
          _addUniqueDesaparecidos(filteredData);
  
          if (response.data.length < _itemsPerPage) {
            _hasMoreData = false;
          }
        }
        _isLoadingMore = false;
        notifyListeners();
      },
    );
  }

  // Método para filtrar localmente
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