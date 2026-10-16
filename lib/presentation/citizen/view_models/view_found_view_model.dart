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
  String? _currentProvincia;

  final MissingFilter _currentStatusFilter = MissingFilter.found;

  final int _itemsPerPage = 40;
  int _activeRequestId = 0;

  int _totalCount = 0;
  int get totalCount => _totalCount;

  void _addUniqueDesaparecidos(List<Desaparecido> newData) {
    final existingIds = _desaparecidos.map((d) => d.id).toSet();
    final uniqueData = newData.where((d) => !existingIds.contains(d.id)).toList();
    _desaparecidos.addAll(uniqueData);
  }

  Future<void> getFoundPeople({
    bool forceRefresh = false,
    String? searchQuery,
    String? departamento,
    String? provincia,
  }) async {
    final int requestId = ++_activeRequestId;

    if (forceRefresh) {
      _desaparecidos.clear();
      _lastDesaparecido = null;
      _hasMoreData = true;
      _totalCount = 0;
      _currentSearchQuery = searchQuery;
      _currentDepartamento = departamento;
      _currentProvincia = provincia;
    } else {
      if (_state == RequestState.Loading || !_hasMoreData) return;
    }

    _state = RequestState.Loading;
    notifyListeners();

    final result = await obtenerDesaparecidosUseCase.execute(
      lastDesaparecido: _lastDesaparecido,
      departamento: _currentDepartamento,
      provincia: _currentProvincia,
      limit: _itemsPerPage,
      filter: _currentStatusFilter,
      searchQuery: _currentSearchQuery,
    );

    if (requestId != _activeRequestId) {
      return;
    }

    result.fold(
      (failure) {
        _message = failure.message;
        _state = RequestState.Error;
        notifyListeners();
      },
      (response) {
        final foundPeople = response.data.where((desaparecido) {
          final estado = (desaparecido.estado ?? '').trim().toLowerCase();
          return estado == 'encontrado';
        }).toList();

        if (response.data.isEmpty) {
          _hasMoreData = false;
        } else {
          _lastDesaparecido = response.data.last;
          final filteredData = _filterLocally(foundPeople, _currentSearchQuery);
          _addUniqueDesaparecidos(filteredData);

          if (_currentSearchQuery != null && _currentSearchQuery!.trim().isNotEmpty) {
            _totalCount = _desaparecidos.length;
          } else {
            _totalCount = response.totalCount > 0 ? response.totalCount : _desaparecidos.length;
          }

          _hasMoreData = response.hasMore;
        }
        _state = _desaparecidos.isEmpty ? RequestState.Empty : RequestState.Loaded;
        notifyListeners();
      },
    );
  }

  Future<void> searchFoundPeople(String query, {String? departamento, String? provincia}) async {
    await getFoundPeople(
      forceRefresh: true,
      searchQuery: query,
      departamento: departamento,
      provincia: provincia,
    );
  }

  Future<void> loadMoreFoundPeople() async {
    if (_isLoadingMore || !_hasMoreData || _state == RequestState.Loading) {
      return;
    }

    final int requestId = _activeRequestId;
    _isLoadingMore = true;
    notifyListeners();

    final result = await obtenerDesaparecidosUseCase.execute(
      lastDesaparecido: _lastDesaparecido,
      departamento: _currentDepartamento,
      provincia: _currentProvincia,
      limit: _itemsPerPage,
      filter: _currentStatusFilter,
      searchQuery: _currentSearchQuery,
    );

    if (requestId != _activeRequestId) {
      _isLoadingMore = false;
      return;
    }

    result.fold(
      (failure) {
        _message = failure.message;
        _hasMoreData = false;
        _isLoadingMore = false;
        notifyListeners();
      },
      (response) {
        final foundPeople = response.data.where((desaparecido) {
          final estado = (desaparecido.estado ?? '').trim().toLowerCase();
          return estado == 'encontrado';
        }).toList();

        if (response.data.isEmpty) {
          _hasMoreData = false;
        } else {
          _lastDesaparecido = response.data.last;
          final filteredData = _filterLocally(foundPeople, _currentSearchQuery);
          _addUniqueDesaparecidos(filteredData);
          _hasMoreData = response.hasMore;
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

      return fullNameProcessed.contains(upperQuery) || dniProcessed.contains(upperQuery);
    }).toList();
  }
}