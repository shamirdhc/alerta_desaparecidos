import 'package:flutter/material.dart';
import '../../../common/state_enum.dart';
import '../../../domain/entities/desaparecido.dart';
import '../../../domain/use_cases/obtener_desaparecidos_use_case.dart';
import '../../../domain/enums.dart';

class ManageFoundViewModel extends ChangeNotifier {
  final ObtenerDesaparecidosUseCase _obtenerDesaparecidosUseCase;

  ManageFoundViewModel(this._obtenerDesaparecidosUseCase);

  RequestState _state = RequestState.Empty;
  final List<Desaparecido> _encontrados = [];
  List<Desaparecido> _searchedEncontrados = [];
  String _message = '';
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  Desaparecido? _lastDocument;
  final MissingFilter _currentFilter = MissingFilter.found;
  String _searchQuery = '';
  bool _filterOnlyWithFicha = false;
  bool _filterOnlyMinors = false;
  String? _selectedDepartamento;

  RequestState get state => _state;
  List<Desaparecido> get encontrados => _encontrados;
  String get message => _message;
  bool get hasMoreData => _hasMoreData;
  bool get isLoadingMore => _isLoadingMore;
  MissingFilter get currentFilter => _currentFilter;
  bool get filterOnlyWithFicha => _filterOnlyWithFicha;
  bool get filterOnlyMinors => _filterOnlyMinors;
  String? get selectedDepartamento => _selectedDepartamento;
  String get searchQuery => _searchQuery;

  List<Desaparecido> get filteredEncontrados {
    return _encontrados.where((e) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = e.nombres.toLowerCase().contains(q) ||
            e.apellidos.toLowerCase().contains(q) ||
            (e.dni?.contains(q) ?? false);
        if (!matchName) return false;
      }
      if (_filterOnlyWithFicha) {
        final hasFicha = e.imagenFichaUrl != null && e.imagenFichaUrl!.trim().isNotEmpty;
        if (!hasFicha) return false;
      }
      if (_filterOnlyMinors) {
        if (e.edadCalculada == null || e.edadCalculada! >= 18) return false;
      }
      if (_selectedDepartamento != null && _selectedDepartamento!.isNotEmpty) {
        if ((e.departamento ?? '').trim().toLowerCase() != _selectedDepartamento!.toLowerCase()) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void toggleOnlyWithFicha() {
    _filterOnlyWithFicha = !_filterOnlyWithFicha;
    notifyListeners();
  }

  void toggleOnlyMinors() {
    _filterOnlyMinors = !_filterOnlyMinors;
    notifyListeners();
  }

  void setSelectedDepartamento(String? dep) {
    _selectedDepartamento = dep;
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
      filter: MissingFilter.found,
      limit: 50,
      lastDesaparecido: _lastDocument,
    );

    result.fold(
      (failure) {
        _state = RequestState.Error;
        _message = failure.message;
      },
      (paginatedResponse) {
        final foundPeople = paginatedResponse.data
            .where((desaparecido) => (desaparecido.estado ?? '').trim().toLowerCase() == 'encontrado')
            .toList();
            
        if (foundPeople.isEmpty) {
          _state = _encontrados.isEmpty ? RequestState.Empty : RequestState.Loaded;
          _hasMoreData = false;
        } else {
          _encontrados.addAll(foundPeople);
          _lastDocument = paginatedResponse.data.last;
          _hasMoreData = paginatedResponse.data.length >= 20;
          _state = RequestState.Loaded;
        }
      },
    );
    notifyListeners();
  }

  Future<void> loadFoundPeople({bool forceRefresh = false}) async {
    await getFoundPeople(forceRefresh: forceRefresh);
  }

  Future<void> loadMoreFoundPeople() async {
    if (_isLoadingMore || !_hasMoreData) return;

    _isLoadingMore = true;
    notifyListeners();

    final result = await _obtenerDesaparecidosUseCase.execute(
      filter: MissingFilter.found,
      limit: 50,
      lastDesaparecido: _lastDocument,
    );

    result.fold(
      (failure) {
        _message = failure.message;
      },
      (paginatedResponse) {
        final foundPeople = paginatedResponse.data
            .where((desaparecido) => (desaparecido.estado ?? '').trim().toLowerCase() == 'encontrado')
            .toList();
            
        if (foundPeople.isEmpty) {
          _hasMoreData = false;
        } else {
          _encontrados.addAll(foundPeople);
          _lastDocument = paginatedResponse.data.last;
          _hasMoreData = paginatedResponse.data.length >= 20;
        }
      },
    );

    _isLoadingMore = false;
    notifyListeners();
  }

  void searchFoundPeople(String query) {
    _searchQuery = query.trim();
    if (_searchQuery.isEmpty) {
      _searchedEncontrados.clear();
    } else {
      _searchedEncontrados = _encontrados
          .where((encontrado) =>
              encontrado.nombres.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              encontrado.apellidos.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (encontrado.dni?.contains(_searchQuery) ?? false))
          .toList();
    }
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _searchedEncontrados.clear();
    notifyListeners();
  }

  void refresh() {
    getFoundPeople(forceRefresh: true);
  }
}