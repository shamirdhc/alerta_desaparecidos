import 'package:flutter/material.dart';
import '../../../common/state_enum.dart';
import '../../../domain/entities/desaparecido.dart';
import '../../../domain/use_cases/obtener_desaparecidos_use_case.dart';
import '../../../domain/enums.dart'; // Importa el enum desde la capa de dominio

class ManageMissingViewModel extends ChangeNotifier {
  final ObtenerDesaparecidosUseCase _obtenerDesaparecidosUseCase;
  static const int _itemsPerPage = 10; // Tamaño del lote
  int _currentPage = 0;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String _currentSearchQuery = '';
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;

  ManageMissingViewModel(this._obtenerDesaparecidosUseCase);

  RequestState _state = RequestState.Empty;
  RequestState get state => _state;

  final List<Desaparecido> _desaparecidos = [];
  List<Desaparecido> get desaparecidos => _desaparecidos;

  List<Desaparecido> _searchedDesaparecidos = [];
  List<Desaparecido> get searchedDesaparecidos => _searchedDesaparecidos;

  String _message = '';
  String get message => _message;

  MissingFilter _currentFilter = MissingFilter.active;
  MissingFilter get currentFilter => _currentFilter;
  set currentFilter(MissingFilter value) {
    _currentFilter = value;
    _resetPaginationAndData();
    _loadMissingPeople();
  }

  Future<void> _loadMissingPeople() async {
    if (_isLoadingMore || !_hasMoreData) return;
    _isLoadingMore = true;
    notifyListeners();

    final result = await _obtenerDesaparecidosUseCase.execute(
      filter: _currentFilter,
      limit: _itemsPerPage,
      offset: _currentPage * _itemsPerPage,
      searchQuery: _currentSearchQuery,
    );

    result.fold(
      (failure) {
        _message = failure.message;
        _state = _desaparecidos.isEmpty ? RequestState.Error : _state;
        _hasMoreData = false;
      },
      (data) {
        if (data.isEmpty) {
          _hasMoreData = false;
        } else {
          _desaparecidos.addAll(data);
          _currentPage++;
        }
        _filterSearchResults(); // Filtrar después de cargar nuevos datos
        _state = RequestState.Loaded;
      },
    );
    _isLoadingMore = false;
    notifyListeners();
  }

  void getMissingPeople() {
    _resetPaginationAndData();
    _loadMissingPeople();
  }

  void searchMissingPeople(String query) {
    _currentSearchQuery = query;
    _resetPaginationAndData();
    _loadMissingPeople();
  }

  void loadMoreMissingPeople() {
    _loadMissingPeople();
  }

  void _filterSearchResults() {
    if (_currentSearchQuery.isEmpty) {
      _searchedDesaparecidos = List.from(_desaparecidos); // Crear una copia
    } else {
      _searchedDesaparecidos =
          _desaparecidos
              .where(
                (desaparecido) => desaparecido.nombreCompleto
                    .toLowerCase()
                    .contains(_currentSearchQuery.toLowerCase()),
              )
              .toList();
    }
    notifyListeners();
  }

  void _resetPaginationAndData() {
    _state = RequestState.Empty;
    _message = '';
    _desaparecidos.clear();
    _searchedDesaparecidos.clear();
    _currentPage = 0;
    _hasMoreData = true;
    _isLoadingMore = false;
    notifyListeners();
  }

  void resetState() {
    _resetPaginationAndData();
    _currentFilter = MissingFilter.active;
    notifyListeners();
  }
}
