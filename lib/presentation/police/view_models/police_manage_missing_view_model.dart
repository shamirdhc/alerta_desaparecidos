import 'package:flutter/foundation.dart';
import '../../../common/state_enum.dart';
import '../../../domain/entities/desaparecido.dart';
import '../../../domain/use_cases/get_missing_cases_usecase.dart';
import '../../../domain/use_cases/mark_case_as_found_usecase.dart';
import '../../../domain/enums.dart';

class PoliceManageMissingViewModel extends ChangeNotifier {
  final GetMissingCasesUseCase _getMissingCasesUseCase;
  final MarkCaseAsFoundUseCase _markCaseAsFoundUseCase;

  PoliceManageMissingViewModel({
    required GetMissingCasesUseCase getMissingCasesUseCase,
    required MarkCaseAsFoundUseCase markCaseAsFoundUseCase,
  })  : _getMissingCasesUseCase = getMissingCasesUseCase,
        _markCaseAsFoundUseCase = markCaseAsFoundUseCase;

  // Estados
  RequestState _state = RequestState.Empty;
  String _message = '';
  List<Desaparecido> _desaparecidos = [];
  List<Desaparecido> _filteredDesaparecidos = [];

  // Filtros
  MissingFilter _currentFilter = MissingFilter.all;
  String _searchQuery = '';
  String? _departamentoFilter;
  String? _prioridadFilter;
  String? _estadoFilter;
  DateTime? _fechaInicioFilter;
  DateTime? _fechaFinFilter;
  String? _ubicacionFilter;
  SortOption _sortOption = SortOption.newest;

  // Estadísticas basadas en casos filtrados
  int _activeCases = 0;
  int _urgentCases = 0;
  int _casesThisMonth = 0;

  // Selección múltiple
  bool _isMultiSelectMode = false;
  Set<String> _selectedCaseIds = <String>{};

  // Paginación
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 1;
  static const int _pageSize = 20;

  // Getters
  RequestState get state => _state;
  String get message => _message;
  List<Desaparecido> get desaparecidos => _desaparecidos;
  List<Desaparecido> get filteredDesaparecidos => _filteredDesaparecidos;
  MissingFilter get currentFilter => _currentFilter;
  String get searchQuery => _searchQuery;
  String? get departamentoFilter => _departamentoFilter;
  String? get prioridadFilter => _prioridadFilter;
  String? get estadoFilter => _estadoFilter;
  DateTime? get fechaInicioFilter => _fechaInicioFilter;
  DateTime? get fechaFinFilter => _fechaFinFilter;
  String? get ubicacionFilter => _ubicacionFilter;
  SortOption get sortOption => _sortOption;

  // Estadísticas basadas en casos filtrados
  int get activeCases => _activeCases;
  int get urgentCases => _urgentCases;
  int get casesThisMonth => _casesThisMonth;

  // Selección múltiple
  bool get isMultiSelectMode => _isMultiSelectMode;
  Set<String> get selectedCaseIds => _selectedCaseIds;
  int get selectedCasesCount => _selectedCaseIds.length;
  bool get hasSelectedCases => _selectedCaseIds.isNotEmpty;

  // Paginación
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;

  // Cargar casos
  Future<void> loadMissingCases({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _currentPage = 1;
      _hasMoreData = true;
      _desaparecidos.clear();
      _filteredDesaparecidos.clear();
    }

    _state = RequestState.Loading;
    notifyListeners();

    try {
      final result = await _getMissingCasesUseCase.execute();
      result.fold(
        (failure) {
          _state = RequestState.Error;
          _message = failure.message;
        },
        (cases) {
          _desaparecidos = cases;
          _applyFiltersAndSort();
          _updateStatistics();
          _state = cases.isEmpty ? RequestState.Empty : RequestState.Loaded;
          _message = '';
        },
      );
    } catch (e) {
      _state = RequestState.Error;
      _message = 'Error inesperado: $e';
    }

    notifyListeners();
  }

  // Buscar casos
  void searchCases(String query) {
    _searchQuery = query;
    _applyFiltersAndSort();
    _updateStatistics();
    notifyListeners();
  }

  // Aplicar filtros y ordenamiento
  void _applyFiltersAndSort() {
    List<Desaparecido> filtered = List.from(_desaparecidos);

    // Aplicar filtro de búsqueda
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((caso) {
        final fullName = '${caso.nombres} ${caso.apellidos}'.toLowerCase();
        final dni = caso.dni?.toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return fullName.contains(query) || dni.contains(query);
      }).toList();
    }

    // Aplicar filtro principal
    switch (_currentFilter) {
      case MissingFilter.active:
        filtered = filtered.where((caso) => caso.estado != 'encontrado').toList();
        break;
      case MissingFilter.all:
      default:
        // No filtrar por estado
        break;
    }

    // Aplicar filtros adicionales
    if (_departamentoFilter != null) {
      filtered = filtered.where((caso) => 
        caso.departamento?.toUpperCase() == _departamentoFilter?.toUpperCase()).toList();
    }

    if (_prioridadFilter != null) {
      filtered = filtered.where((caso) {
        final priority = _calculatePriority(caso);
        switch (_prioridadFilter) {
          case 'urgente':
            return priority == 4;
          case 'alta':
            return priority == 3;
          case 'media':
            return priority == 2;
          case 'baja':
            return priority == 1;
          default:
            return true;
        }
      }).toList();
    }

    if (_estadoFilter != null) {
      filtered = filtered.where((caso) => caso.estado == _estadoFilter).toList();
    }

    if (_fechaInicioFilter != null) {
      filtered = filtered.where((caso) {
        return caso.fechaDesaparicion?.isAfter(_fechaInicioFilter!) ?? false;
      }).toList();
    }

    if (_fechaFinFilter != null) {
      filtered = filtered.where((caso) {
        return caso.fechaDesaparicion?.isBefore(_fechaFinFilter!) ?? false;
      }).toList();
    }

    if (_ubicacionFilter != null && _ubicacionFilter!.isNotEmpty) {
      filtered = filtered.where((caso) {
        final ubicacion = '${caso.departamento ?? ''} ${caso.provincia ?? ''} ${caso.distrito ?? ''}'.toLowerCase();
        return ubicacion.contains(_ubicacionFilter!.toLowerCase());
      }).toList();
    }

    // Aplicar ordenamiento
    switch (_sortOption) {
      case SortOption.newest:
        filtered.sort((a, b) => (b.fechaDesaparicion ?? DateTime.now()).compareTo(a.fechaDesaparicion ?? DateTime.now()));
        break;
      case SortOption.oldest:
        filtered.sort((a, b) => (a.fechaDesaparicion ?? DateTime.now()).compareTo(b.fechaDesaparicion ?? DateTime.now()));
        break;
      case SortOption.priority:
        filtered.sort((a, b) => _calculatePriority(b).compareTo(_calculatePriority(a)));
        break;
      case SortOption.alphabetical:
        filtered.sort((a, b) => '${a.nombres} ${a.apellidos}'.compareTo('${b.nombres} ${b.apellidos}'));
        break;
    }

    _filteredDesaparecidos = filtered;
  }

  // Calcular edad de una persona
  int? _calculateAge(DateTime? fechaNacimiento) {
    if (fechaNacimiento == null) return null;
    final now = DateTime.now();
    int age = now.year - fechaNacimiento.year;
    if (now.month < fechaNacimiento.month || 
        (now.month == fechaNacimiento.month && now.day < fechaNacimiento.day)) {
      age--;
    }
    return age;
  }

  // Verificar si es menor de edad (urgente)
  bool _isMinor(Desaparecido caso) {
    final age = _calculateAge(caso.fechaNacimiento);
    return age != null && age < 18;
  }

  // Calcular prioridad del caso
  int _calculatePriority(Desaparecido caso) {
    if (caso.estado == 'encontrado') return 0;
    
    // Solo menores de edad son urgentes (prioridad 4)
    if (_isMinor(caso)) return 4;

    final now = DateTime.now();
    final fechaDesaparicion = caso.fechaDesaparicion ?? now;
    final daysSinceDisappearance = now.difference(fechaDesaparicion).inDays;

    // Prioridad basada en días transcurridos
    if (daysSinceDisappearance <= 7) return 3; // Alta
    if (daysSinceDisappearance <= 30) return 2; // Media
    return 1; // Baja
  }

  // Actualizar estadísticas basadas en casos filtrados
  void _updateStatistics() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    // Usar todos los casos (no filtrados) para las estadísticas del dashboard
    final casesToAnalyze = _desaparecidos;

    _activeCases = casesToAnalyze.where((caso) => caso.estado != 'encontrado').length;
    
    // Solo menores de edad son urgentes
    _urgentCases = casesToAnalyze.where((caso) => 
      caso.estado != 'encontrado' && _isMinor(caso)).length;
    
    // Casos reportados este mes
    _casesThisMonth = casesToAnalyze.where((caso) {
      return caso.fechaDesaparicion != null && 
             caso.fechaDesaparicion!.isAfter(firstDayOfMonth.subtract(const Duration(days: 1)));
    }).length;
  }

  // Marcar caso como encontrado
  Future<void> markCaseAsFound(String caseId, String details) async {
    try {
      final result = await _markCaseAsFoundUseCase.execute(caseId, details);
      result.fold(
        (failure) {
          _message = failure.message;
        },
        (success) {
          // Actualizar el caso en la lista local
          final index = _desaparecidos.indexWhere((caso) => caso.id == caseId);
          if (index != -1) {
            _desaparecidos[index] = _desaparecidos[index].copyWith(
              estado: 'encontrado',
              fechaEncontrado: DateTime.now(),
              encontradoDetalles: details,
            );
            _applyFiltersAndSort();
            _updateStatistics();
          }
          _message = 'Caso marcado como encontrado exitosamente';
        },
      );
    } catch (e) {
      _message = 'Error al marcar caso como encontrado: $e';
    }
    notifyListeners();
  }

  // Marcar casos seleccionados como encontrados
  Future<void> markSelectedCasesAsFound(String details) async {
    if (_selectedCaseIds.isEmpty) return;

    try {
      for (final caseId in _selectedCaseIds) {
        await markCaseAsFound(caseId, details);
      }
      
      // Limpiar selección y salir del modo de selección múltiple
      _selectedCaseIds.clear();
      _isMultiSelectMode = false;
      
      _message = 'Casos marcados como encontrados exitosamente';
    } catch (e) {
      _message = 'Error al marcar casos como encontrados: $e';
    }
    notifyListeners();
  }

  // Gestión de selección múltiple
  void enableMultiSelectMode() {
    _isMultiSelectMode = true;
    notifyListeners();
  }

  void disableMultiSelectMode() {
    _isMultiSelectMode = false;
    _selectedCaseIds.clear();
    notifyListeners();
  }

  void toggleCaseSelection(String caseId) {
    if (_selectedCaseIds.contains(caseId)) {
      _selectedCaseIds.remove(caseId);
    } else {
      _selectedCaseIds.add(caseId);
    }
    
    // Si no hay casos seleccionados, salir del modo de selección múltiple
    if (_selectedCaseIds.isEmpty) {
      _isMultiSelectMode = false;
    }
    
    notifyListeners();
  }

  void selectAllCases() {
    _selectedCaseIds.clear();
    for (final caso in _filteredDesaparecidos) {
      if (caso.id != null && caso.estado != 'encontrado') {
        _selectedCaseIds.add(caso.id!);
      }
    }
    notifyListeners();
  }

  void selectAllVisibleCases() {
    _selectedCaseIds.clear();
    for (final caso in _filteredDesaparecidos) {
      if (caso.id != null && caso.estado != 'encontrado') {
        _selectedCaseIds.add(caso.id!);
      }
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedCaseIds.clear();
    notifyListeners();
  }

  // Setters para filtros
  void setFilter(MissingFilter filter) {
    _currentFilter = filter;
    _applyFiltersAndSort();
    _updateStatistics();
    notifyListeners();
  }

  void setDepartamentoFilter(String? departamento) {
    _departamentoFilter = departamento?.toUpperCase();
    _applyFiltersAndSort();
    _updateStatistics();
    notifyListeners();
  }

  void setPrioridadFilter(String? prioridad) {
    _prioridadFilter = prioridad;
    _applyFiltersAndSort();
    _updateStatistics();
    notifyListeners();
  }

  void setEstadoFilter(String? estado) {
    _estadoFilter = estado;
    _applyFiltersAndSort();
    _updateStatistics();
    notifyListeners();
  }

  void setFechaFilter(DateTime? inicio, DateTime? fin) {
    _fechaInicioFilter = inicio;
    _fechaFinFilter = fin;
    _applyFiltersAndSort();
    _updateStatistics();
    notifyListeners();
  }

  void setUbicacionFilter(String? ubicacion) {
    _ubicacionFilter = ubicacion;
    _applyFiltersAndSort();
    _updateStatistics();
    notifyListeners();
  }

  void setSortOption(SortOption option) {
    _sortOption = option;
    _applyFiltersAndSort();
    notifyListeners();
  }

  // Limpiar filtros
  void clearFilters() {
    _currentFilter = MissingFilter.all;
    _searchQuery = '';
    _departamentoFilter = null;
    _prioridadFilter = null;
    _estadoFilter = null;
    _fechaInicioFilter = null;
    _fechaFinFilter = null;
    _ubicacionFilter = null;
    _sortOption = SortOption.newest;
    _applyFiltersAndSort();
    _updateStatistics();
    notifyListeners();
  }

  // Cargar más casos (paginación)
  Future<void> loadMoreCases() async {
    if (_isLoadingMore || !_hasMoreData) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      _currentPage++;
      // Simular carga de más datos
      await Future.delayed(const Duration(seconds: 1));
      
      // En una implementación real, aquí cargarías más datos desde el backend
      // Por ahora, simplemente marcamos que no hay más datos después de la primera página
      _hasMoreData = false;
    } catch (e) {
      _currentPage--;
      _message = 'Error al cargar más casos: $e';
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  // Resetear estado
  void resetState() {
    _state = RequestState.Empty;
    _message = '';
    _desaparecidos.clear();
    _filteredDesaparecidos.clear();
    _selectedCaseIds.clear();
    _isMultiSelectMode = false;
    _currentPage = 1;
    _hasMoreData = true;
    clearFilters();
    notifyListeners();
  }
}