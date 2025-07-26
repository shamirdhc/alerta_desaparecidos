import 'package:flutter/material.dart';
import '../../../common/state_enum.dart';
import '../../../domain/entities/desaparecido.dart';
import '../../../domain/use_cases/obtener_desaparecidos_use_case.dart';
import '../../../domain/enums.dart';

class ManageFoundViewModel extends ChangeNotifier {
  final ObtenerDesaparecidosUseCase _obtenerDesaparecidosUseCase;

  ManageFoundViewModel(this._obtenerDesaparecidosUseCase);

  RequestState _state = RequestState.Empty;
  List<Desaparecido> _encontrados = [];
  List<Desaparecido> _searchedEncontrados = [];
  String _message = '';
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  Desaparecido? _lastDocument;
  MissingFilter _currentFilter = MissingFilter.active;

  RequestState get state => _state;
  List<Desaparecido> get encontrados => _encontrados;
  List<Desaparecido> get searchedEncontrados => _searchedEncontrados;
  String get message => _message;
  bool get hasMoreData => _hasMoreData;
  bool get isLoadingMore => _isLoadingMore;
  MissingFilter get currentFilter => _currentFilter;

  set currentFilter(MissingFilter filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  Future<void> getFoundPeople({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _encontrados.clear();
      _lastDocument = null;
      _hasMoreData = true;
    }

    if (_state == RequestState.Loading || !_hasMoreData) return;

    _state = RequestState.Loading;
    notifyListeners();

    final result = await _obtenerDesaparecidosUseCase.execute(
      filter: MissingFilter.all, // Obtener todos y filtrar localmente
      limit: 50, // Aumentar límite para compensar el filtrado local
      lastDesaparecido: _lastDocument,
    );

    result.fold(
      (failure) {
        _state = RequestState.Error;
        _message = failure.message;
      },
      (paginatedResponse) {
        // Filtrar localmente solo personas encontradas
        final foundPeople = paginatedResponse.data
            .where((desaparecido) => desaparecido.estado == 'encontrado')
            .toList();
            
        if (foundPeople.isEmpty) {
          _state = _encontrados.isEmpty ? RequestState.Empty : RequestState.Loaded;
          _hasMoreData = false;
        } else {
          _encontrados.addAll(foundPeople);
          _lastDocument = paginatedResponse.data.last;
          _hasMoreData = paginatedResponse.data.length == 50;
          _state = RequestState.Loaded;
        }
      },
    );
    notifyListeners();
  }

  Future<void> loadFoundPeople({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _encontrados.clear();
      _lastDocument = null;
      _hasMoreData = true;
    }

    if (_state == RequestState.Loading || !_hasMoreData) return;

    _state = RequestState.Loading;
    notifyListeners();

    final result = await _obtenerDesaparecidosUseCase.execute(
      filter: MissingFilter.all,
      limit: 50,
      lastDesaparecido: _lastDocument,
    );

    result.fold(
      (failure) {
        _state = RequestState.Error;
        _message = failure.message;
      },
      (paginatedResponse) {
        // Filtrar localmente solo personas encontradas
        final foundPeople = paginatedResponse.data
            .where((desaparecido) => desaparecido.estado == 'encontrado')
            .toList();
            
        if (foundPeople.isEmpty) {
          _state = _encontrados.isEmpty ? RequestState.Empty : RequestState.Loaded;
          _hasMoreData = false;
        } else {
          _encontrados.addAll(foundPeople);
          _lastDocument = paginatedResponse.data.last;
          _hasMoreData = paginatedResponse.data.length == 50;
          _state = RequestState.Loaded;
        }
      },
    );

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> loadMoreFoundPeople() async {
    if (_isLoadingMore || !_hasMoreData) return;

    _isLoadingMore = true;
    notifyListeners();

    final result = await _obtenerDesaparecidosUseCase.execute(
      filter: MissingFilter.all,
      limit: 50,
      lastDesaparecido: _lastDocument,
    );

    result.fold(
      (failure) {
        _message = failure.message;
      },
      (paginatedResponse) {
        // Filtrar localmente solo personas encontradas
        final foundPeople = paginatedResponse.data
            .where((desaparecido) => desaparecido.estado == 'encontrado')
            .toList();
            
        if (foundPeople.isEmpty) {
          _hasMoreData = false;
        } else {
          _encontrados.addAll(foundPeople);
          _lastDocument = paginatedResponse.data.last;
          _hasMoreData = paginatedResponse.data.length == 50;
        }
      },
    );

    _isLoadingMore = false;
    notifyListeners();
  }

  void searchFoundPeople(String query) {
    if (query.isEmpty) {
      _searchedEncontrados.clear();
    } else {
      _searchedEncontrados = _encontrados
          .where((encontrado) =>
              encontrado.nombres.toLowerCase().contains(query.toLowerCase()) ||
              encontrado.apellidos.toLowerCase().contains(query.toLowerCase()) ||
              (encontrado.dni?.contains(query) ?? false))
          .toList();
    }
    notifyListeners();
  }

  void clearSearch() {
    _searchedEncontrados.clear();
    notifyListeners();
  }

  void refresh() {
    getFoundPeople(forceRefresh: true);
  }
}