import 'package:flutter/foundation.dart';
import 'package:alerta_desaparecidos/domain/entities/desaparecido.dart';
import 'package:alerta_desaparecidos/domain/use_cases/obtener_desaparecidos_use_case.dart';
import 'package:alerta_desaparecidos/common/state_enum.dart';
import 'package:alerta_desaparecidos/domain/enums.dart';

class ViewFoundViewModel extends ChangeNotifier {
  final ObtenerDesaparecidosUseCase obtenerDesaparecidosUseCase;

  ViewFoundViewModel(this.obtenerDesaparecidosUseCase);

  List<Desaparecido> _desaparecidos = [];
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
  
  // FIJO: Siempre filtrar por personas encontradas
  final MissingFilter _currentStatusFilter = MissingFilter.found;

  final int _itemsPerPage = 10;

  // Método principal para obtener/refrescar la lista
  Future<void> getFoundPeople({
    bool forceRefresh = false,
    String? searchQuery,
    String? departamento,
  }) async {
    if (forceRefresh) {
      _desaparecidos = [];
      _lastDesaparecido = null;
      _hasMoreData = true;
      _currentSearchQuery = searchQuery;
      _currentDepartamento = departamento;
    }

    if (_state == RequestState.Loading || !_hasMoreData) return;

    _state = RequestState.Loading;
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
        _message = failure.message;
        _state = RequestState.Error;
        notifyListeners();
      },
      (newData) {
        if (newData.isEmpty) {
          _hasMoreData = false;
        } else {
          _lastDesaparecido = newData.last;
          final filteredData = _filterLocally(newData, _currentSearchQuery);
          _desaparecidos.addAll(filteredData);
        }
        _state = _desaparecidos.isEmpty ? RequestState.Empty : RequestState.Loaded;
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
      searchQuery: _currentSearchQuery, // AGREGAR ESTA LÍNEA
    );
  
    result.fold(
      (failure) {
        print('Error al cargar más personas encontradas: ${failure.message}');
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

  // Método para filtrar localmente
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