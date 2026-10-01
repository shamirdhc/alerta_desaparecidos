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

  final int _itemsPerPage = 30;
  int _activeRequestId = 0;

  // Variable para el total real
  int _totalCount = 0;
  int get totalCount => _totalCount;

  String _personKey(Desaparecido d) {
    final nom = '${d.nombres} ${d.apellidos}'.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    final dept = (d.departamento ?? '').trim().toUpperCase();
    final fecha = d.fechaDesaparicion != null 
        ? '${d.fechaDesaparicion!.year}-${d.fechaDesaparicion!.month}-${d.fechaDesaparicion!.day}' 
        : '';
    return '$nom|$dept|$fecha';
  }

  // 🔥 MÉTODO ROBUSTO PARA EVITAR DUPLICADOS Y FUSIONAR MEJORAS
  void _addUniqueDesaparecidos(List<Desaparecido> newData) {
    final existingKeys = <String, int>{};
    for (int i = 0; i < _desaparecidos.length; i++) {
      existingKeys[_personKey(_desaparecidos[i])] = i;
      if (_desaparecidos[i].id != null) {
        existingKeys[_desaparecidos[i].id!] = i;
      }
    }

    for (final d in newData) {
      final key = _personKey(d);
      final idKey = d.id;
      final existingIdx = existingKeys[key] ?? (idKey != null ? existingKeys[idKey] : null);

      if (existingIdx != null) {
        // Actualizar siempre con la información más reciente del servidor
        _desaparecidos[existingIdx] = d;
      } else {
        _desaparecidos.add(d);
        final newIdx = _desaparecidos.length - 1;
        existingKeys[key] = newIdx;
        if (idKey != null) {
          existingKeys[idKey] = newIdx;
        }
      }
    }
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
  
    final int requestId = ++_activeRequestId;

    if (forceRefresh) {
      print('   - Reiniciando lista y configurando filtros...');
      _desaparecidos.clear();
      _lastDesaparecido = null;
      _hasMoreData = true;
      _totalCount = 0;
      _currentSearchQuery = searchQuery;
      _currentDepartamento = departamento;
      
      if (status == 'encontrado') {
        _currentStatusFilter = MissingFilter.found;
      } else {
        _currentStatusFilter = MissingFilter.active;
      }
    } else {
      if (_state == RequestState.Loading || !_hasMoreData) {
        print('   - Saliendo temprano: state=$_state, hasMoreData=$_hasMoreData');
        return;
      }
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
      offset: 0,
    );
  
    if (requestId != _activeRequestId) {
      print('⚠️ [DEBUG] Respuesta descartada porque llegó una petición más reciente (ID: $requestId vs $_activeRequestId)');
      return;
    }

    result.fold(
      (failure) {
        print('❌ [DEBUG] Error en getMissingPeople: ${failure.message}');
        _message = failure.message;
        _state = RequestState.Error;
        notifyListeners();
      },
      (response) {
        final newData = response.data;
        _totalCount = response.totalCount;
        
        print('✅ [DEBUG] Datos recibidos: ${newData.length} elementos (Total en BD: $_totalCount)');
        
        if (newData.isEmpty) {
          _hasMoreData = false;
          print('🚫 [DEBUG] No hay más datos disponibles');
        } else {
          _lastDesaparecido = newData.last;
          
          List<Desaparecido> filteredByStatus = newData;
          if (status == 'encontrado') {
            filteredByStatus = newData.where((d) => 
              (d.estado ?? '').trim().toLowerCase() == 'encontrado'
            ).toList();
          } else {
            filteredByStatus = newData.where((d) => 
              (d.estado ?? '').trim().toLowerCase() != 'encontrado'
            ).toList();
          }

          // 🛡️ REGLA: Sólo mostrar en el feed casos que tengan fotografía o Nota de Alerta disponible
          filteredByStatus = filteredByStatus.where((d) {
            final hasFoto = d.fotoUrl != null && d.fotoUrl!.trim().isNotEmpty;
            final hasFicha = d.imagenFichaUrl != null && d.imagenFichaUrl!.trim().isNotEmpty;
            return hasFoto || hasFicha;
          }).toList();
          
          final filteredData = _filterLocally(filteredByStatus, _currentSearchQuery);
          
          _addUniqueDesaparecidos(filteredData);
          
          if (newData.length < _itemsPerPage || _desaparecidos.length >= _totalCount) {
            _hasMoreData = false;
          }
        }
        
        _state = _desaparecidos.isEmpty ? RequestState.Empty : RequestState.Loaded;
        print('📊 [DEBUG] Estado final: ${_desaparecidos.length} elementos en memoria, total BD: $_totalCount');
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
  
    final int requestId = _activeRequestId;
    _isLoadingMore = true;
    notifyListeners();
  
    final result = await obtenerDesaparecidosUseCase.execute(
      lastDesaparecido: _lastDesaparecido,
      departamento: _currentDepartamento,
      limit: _itemsPerPage,
      filter: _currentStatusFilter,
      searchQuery: _currentSearchQuery,
      offset: _desaparecidos.length,
    );
  
    if (requestId != _activeRequestId) {
      _isLoadingMore = false;
      return;
    }

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
        _totalCount = response.totalCount;
        
        if (newData.isEmpty) {
          _hasMoreData = false;
        } else {
          _lastDesaparecido = newData.last;
          
          List<Desaparecido> filteredByStatus = newData;
          if (_currentStatusFilter == MissingFilter.found) {
            filteredByStatus = newData.where((d) => 
              (d.estado ?? '').trim().toLowerCase() == 'encontrado'
            ).toList();
          } else {
            filteredByStatus = newData.where((d) => 
              (d.estado ?? '').trim().toLowerCase() != 'encontrado'
            ).toList();
          }

          // 🛡️ REGLA: Sólo mostrar en el feed casos que tengan fotografía o Nota de Alerta disponible
          filteredByStatus = filteredByStatus.where((d) {
            final hasFoto = d.fotoUrl != null && d.fotoUrl!.trim().isNotEmpty;
            final hasFicha = d.imagenFichaUrl != null && d.imagenFichaUrl!.trim().isNotEmpty;
            return hasFoto || hasFicha;
          }).toList();
          
          final filteredData = _filterLocally(filteredByStatus, _currentSearchQuery);
          
          _addUniqueDesaparecidos(filteredData);
  
          if (newData.length < _itemsPerPage || _desaparecidos.length >= _totalCount) {
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
