import 'package:flutter/material.dart';
import '../../../common/state_enum.dart';
import '../../../domain/entities/desaparecido.dart';
import '../../../domain/use_cases/obtener_desaparecidos_use_case.dart';
import '../../../domain/enums.dart';

class ManageMissingViewModel extends ChangeNotifier {
  final ObtenerDesaparecidosUseCase _obtenerDesaparecidosUseCase;
  static const int _itemsPerPage = 10; // Tamaño del lote
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String _currentSearchQuery = '';
  Desaparecido? _lastDesaparecido; // Último desaparecido para paginación

  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;

  ManageMissingViewModel(this._obtenerDesaparecidosUseCase);

  RequestState _state = RequestState.Empty;
  RequestState get state => _state;

  final List<Desaparecido> _desaparecidos = [];
  List<Desaparecido> get desaparecidos => List.unmodifiable(_desaparecidos);

  List<Desaparecido> _searchedDesaparecidos = [];
  List<Desaparecido> get searchedDesaparecidos => List.unmodifiable(_searchedDesaparecidos);

  String _message = '';
  String get message => _message;

  MissingFilter _currentFilter = MissingFilter.active;
  MissingFilter get currentFilter => _currentFilter;

  set currentFilter(MissingFilter value) {
    if (_currentFilter != value) {
      _currentFilter = value;
      _resetPaginationAndData(silent: true); // Sin `notifyListeners` directo
      _loadMissingPeople();
    }
  }

  Future<void> _loadMissingPeople() async {
    if (_isLoadingMore || !_hasMoreData) return;
    _isLoadingMore = true;
    notifyListeners();

    final result = await _obtenerDesaparecidosUseCase.execute(
      filter: _currentFilter,
      limit: _itemsPerPage,
      lastDesaparecido: _lastDesaparecido, // Reemplazo de `offset`
      searchQuery: _currentSearchQuery,
    );

    result.fold(
          (failure) {
        _message = failure.message;
        if (_desaparecidos.isEmpty) {
          _state = RequestState.Error;
        }
        _hasMoreData = false;
      },
          (data) {
        if (data.isEmpty) {
          _hasMoreData = false;
        } else {
          _desaparecidos.addAll(data);
          _lastDesaparecido = _desaparecidos.last; // Actualizamos el último elemento
        }
        _filterSearchResults(silent: true); // Evitar múltiples notificaciones
        _state = RequestState.Loaded;
      },
    );

    _isLoadingMore = false;
    notifyListeners(); // Notificar solo al final
  }

  void getMissingPeople() {
    _resetPaginationAndData(silent: true);
    _loadMissingPeople();
  }

  void searchMissingPeople(String query) {
    _currentSearchQuery = query;
    _resetPaginationAndData(silent: true);
    _loadMissingPeople();
  }

  void loadMoreMissingPeople() {
    _loadMissingPeople();
  }

  void _filterSearchResults({bool silent = false}) {
    if (_currentSearchQuery.isEmpty) {
      _searchedDesaparecidos = List.from(_desaparecidos); // Crear copia
    } else {
      _searchedDesaparecidos = _desaparecidos
          .where((desaparecido) => desaparecido.nombreCompleto
          .toLowerCase()
          .contains(_currentSearchQuery.toLowerCase()))
          .toList();
    }
    if (!silent) notifyListeners();
  }

  void _resetPaginationAndData({bool silent = false}) {
    _state = RequestState.Empty;
    _message = '';
    _desaparecidos.clear();
    _searchedDesaparecidos.clear();
    _lastDesaparecido = null; // Reinicia el último desaparecido
    _hasMoreData = true;
    _isLoadingMore = false;
    if (!silent) notifyListeners();
  }

  void resetState() {
    _resetPaginationAndData();
    _currentFilter = MissingFilter.active;
    notifyListeners();
  }
}