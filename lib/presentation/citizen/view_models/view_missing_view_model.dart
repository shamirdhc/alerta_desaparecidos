import 'package:flutter/foundation.dart';
import 'package:alerta_desaparecidos/domain/entities/desaparecido.dart';
import 'package:alerta_desaparecidos/domain/use_cases/obtener_desaparecidos_use_case.dart';
import 'package:alerta_desaparecidos/common/state_enum.dart';
import 'package:alerta_desaparecidos/domain/enums.dart';
import 'package:alerta_desaparecidos/common/constants/peru_locations.dart';

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
  bool get hasMoreData => _hasMoreData;
  Desaparecido? _lastDesaparecido;

  String? _currentSearchQuery;
  String? _currentDepartamento;
  String? _currentProvincia;
  MissingFilter _currentStatusFilter = MissingFilter.active;

  final int _itemsPerPage = 30;
  int _activeRequestId = 0;
  int _fetchedCount = 0;

  int _totalCount = 0;
  int get totalCount => _totalCount;

  // 🔥 MÉTODO ROBUSTO PARA EVITAR DUPLICADOS Y FUSIONAR MEJORAS
  void _addUniqueDesaparecidos(List<Desaparecido> newData) {
    for (final d in newData) {
      final id = d.id?.trim();
      final dni = d.dni?.trim();
      final normName = PeruLocations.normalize('${d.nombres} ${d.apellidos}');
      final normDept = PeruLocations.normalize(d.departamento ?? '');
      final dateStr = d.fechaDesaparicion != null
          ? '${d.fechaDesaparicion!.year}-${d.fechaDesaparicion!.month}-${d.fechaDesaparicion!.day}'
          : '';

      int existingIdx = -1;

      if (id != null && id.isNotEmpty) {
        existingIdx = _desaparecidos.indexWhere((item) => item.id == id);
      }

      if (existingIdx == -1 && dni != null && dni.isNotEmpty && dni.length >= 8) {
        existingIdx = _desaparecidos.indexWhere((item) {
          final itemDni = item.dni?.trim();
          return itemDni != null && itemDni == dni;
        });
      }

      if (existingIdx == -1 && normName.isNotEmpty) {
        existingIdx = _desaparecidos.indexWhere((item) {
          final itemNormName = PeruLocations.normalize('${item.nombres} ${item.apellidos}');
          if (itemNormName != normName) return false;

          final itemNormDept = PeruLocations.normalize(item.departamento ?? '');
          final itemDateStr = item.fechaDesaparicion != null
              ? '${item.fechaDesaparicion!.year}-${item.fechaDesaparicion!.month}-${item.fechaDesaparicion!.day}'
              : '';

          final sameDept = normDept.isNotEmpty &&
              itemNormDept.isNotEmpty &&
              (normDept == itemNormDept ||
                  PeruLocations.matchesDepartment(
                    caseDept: item.departamento,
                    targetDept: d.departamento ?? '',
                  ));
          final sameDate = dateStr.isNotEmpty && itemDateStr.isNotEmpty && dateStr == itemDateStr;

          return sameDept || sameDate;
        });
      }

      if (existingIdx != -1) {
        final existing = _desaparecidos[existingIdx];
        final existingFoto = existing.fotoUrl ?? '';
        final newFoto = d.fotoUrl ?? '';
        final existingFicha = existing.imagenFichaUrl ?? '';
        final newFicha = d.imagenFichaUrl ?? '';

        if ((!existingFoto.contains('firebasestorage') && newFoto.contains('firebasestorage')) ||
            (existingFicha.isEmpty && newFicha.isNotEmpty)) {
          _desaparecidos[existingIdx] = d;
        }
      } else {
        _desaparecidos.add(d);
      }
    }
  }

  Future<void> getMissingPeople({
    bool forceRefresh = false,
    String? searchQuery,
    String? departamento,
    String? provincia,
    String? status,
  }) async {
    final int requestId = ++_activeRequestId;

    if (forceRefresh) {
      _desaparecidos.clear();
      _fetchedCount = 0;
      _lastDesaparecido = null;
      _hasMoreData = true;
      _totalCount = 0;
      _currentSearchQuery = searchQuery;
      _currentDepartamento = departamento;
      _currentProvincia = provincia;

      if (status == 'encontrado') {
        _currentStatusFilter = MissingFilter.found;
      } else {
        _currentStatusFilter = MissingFilter.active;
      }
    } else {
      if (_state == RequestState.Loading || !_hasMoreData) {
        return;
      }
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
      offset: 0,
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
        final newData = response.data;
        _totalCount = response.totalCount;
        _fetchedCount = newData.length;

        if (newData.isEmpty) {
          _hasMoreData = false;
        } else {
          _lastDesaparecido = newData.last;

          List<Desaparecido> filteredByStatus = newData;
          if (status == 'encontrado') {
            filteredByStatus = newData
                .where((d) => (d.estado ?? '').trim().toLowerCase() == 'encontrado')
                .toList();
          } else {
            filteredByStatus = newData
                .where((d) => (d.estado ?? '').trim().toLowerCase() != 'encontrado')
                .toList();
          }

          filteredByStatus = filteredByStatus.where((d) {
            final hasFoto = d.fotoUrl != null && d.fotoUrl!.trim().isNotEmpty;
            final hasFicha = d.imagenFichaUrl != null && d.imagenFichaUrl!.trim().isNotEmpty;
            return hasFoto || hasFicha;
          }).toList();

          final filteredData = _filterLocally(filteredByStatus, _currentSearchQuery);

          _addUniqueDesaparecidos(filteredData);

          // ✅ CORRECCIÓN CRÍTICA: Usar response.hasMore en lugar de newData.length < _itemsPerPage
          // para que la deduplicación en memoria nunca detenga el scroll infinito en la Página 1.
          _hasMoreData = response.hasMore;
          if (_totalCount > 0 && _desaparecidos.length >= _totalCount && _currentProvincia == null) {
            _hasMoreData = false;
          }
        }

        _state = _desaparecidos.isEmpty ? RequestState.Empty : RequestState.Loaded;
        notifyListeners();
      },
    );
  }

  Future<void> searchMissingPeople(
    String query, {
    String? departamento,
    String? provincia,
    String? status,
  }) async {
    await getMissingPeople(
      forceRefresh: true,
      searchQuery: query,
      departamento: departamento,
      provincia: provincia,
      status: status,
    );
  }

  Future<void> loadMoreMissingPeople() async {
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
      offset: _fetchedCount,
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
        final newData = response.data;
        _totalCount = response.totalCount;
        _fetchedCount += newData.length;

        if (newData.isEmpty) {
          _hasMoreData = false;
        } else {
          _lastDesaparecido = newData.last;

          List<Desaparecido> filteredByStatus = newData;
          if (_currentStatusFilter == MissingFilter.found) {
            filteredByStatus = newData
                .where((d) => (d.estado ?? '').trim().toLowerCase() == 'encontrado')
                .toList();
          } else {
            filteredByStatus = newData
                .where((d) => (d.estado ?? '').trim().toLowerCase() != 'encontrado')
                .toList();
          }

          filteredByStatus = filteredByStatus.where((d) {
            final hasFoto = d.fotoUrl != null && d.fotoUrl!.trim().isNotEmpty;
            final hasFicha = d.imagenFichaUrl != null && d.imagenFichaUrl!.trim().isNotEmpty;
            return hasFoto || hasFicha;
          }).toList();

          final filteredData = _filterLocally(filteredByStatus, _currentSearchQuery);

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
