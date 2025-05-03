import 'package:flutter/material.dart';
import '../../../common/state_enum.dart';
import '../../../domain/entities/desaparecido.dart';
import '../../../domain/use_cases/obtener_desaparecidos_use_case.dart';
import '../../../domain/enums.dart';

class ManageMissingViewModel extends ChangeNotifier {
  final ObtenerDesaparecidosUseCase _obtenerDesaparecidosUseCase;
  static const int _itemsPerPage = 10; // Tamaño del lote
  bool _isLoadingMore = false; // Específico para paginación
  bool _hasMoreData = true;
  String _currentSearchQuery = '';
  Desaparecido? _lastDesaparecido; // Último desaparecido para paginación

  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;

  ManageMissingViewModel(this._obtenerDesaparecidosUseCase);

  // Iniciar en Empty o Loading podría ser mejor que Empty si siempre cargas al inicio
  RequestState _state = RequestState.Empty;
  RequestState get state => _state;

  final List<Desaparecido> _desaparecidos = [];
  List<Desaparecido> get desaparecidos => List.unmodifiable(_desaparecidos);

  List<Desaparecido> _searchedDesaparecidos = [];
  List<Desaparecido> get searchedDesaparecidos =>
      List.unmodifiable(_searchedDesaparecidos);

  String _message = '';
  String get message => _message;

  MissingFilter _currentFilter = MissingFilter.active;
  MissingFilter get currentFilter => _currentFilter;

  // Setter para el filtro, llama a getMissingPeople con forceRefresh
  set currentFilter(MissingFilter value) {
    if (_currentFilter != value) {
      _currentFilter = value;
      // Llama a getMissingPeople forzando un refresco para el nuevo filtro
      getMissingPeople(forceRefresh: true);
    }
  }

  // Método principal para cargar/refrescar datos
  Future<void> getMissingPeople({bool forceRefresh = false}) async {
    // --- Resetear datos PRIMERO si es un forceRefresh ---
    if (forceRefresh) {
      // Siempre limpiar datos y reiniciar paginación en un refresco forzado
      _resetPaginationAndData(silent: true);
    }

    // --- Ahora manejar estado y prevenir cargas concurrentes ---
    // Prevenir paginación si ya se está cargando más O si un refresco completo está en progreso
    if (!forceRefresh && (_isLoadingMore || _state == RequestState.Loading)) {
      return;
    }
    // Prevenir iniciar un nuevo refresco completo si ya hay uno en progreso
    if (forceRefresh && _state == RequestState.Loading) {
      // Opcional: Registrar que se omitió un refresco porque ya había uno en curso
      // print('[ViewModel DEBUG] Skipping forceRefresh, already loading.');
      return;
    }

    // --- Establecer estado de carga ---
    if (forceRefresh) {
      _state = RequestState.Loading; // Estado principal de carga
    } else {
      _isLoadingMore = true; // Indicador de carga para paginación
    }
    // Notificar inmediatamente *después* de establecer el estado/flag
    notifyListeners();

    try {
      // --- CAMBIO AQUÍ: Pasar el filtro actual al UseCase ---
      final result = await _obtenerDesaparecidosUseCase.execute(
        filter: _currentFilter, // <-- AÑADIR ESTA LÍNEA
        limit: _itemsPerPage,
        lastDesaparecido: forceRefresh ? null : _lastDesaparecido,
        searchQuery: _currentSearchQuery,
        // Asegúrate de que si necesitas filtrar por departamento aquí,
        // lo pases como parámetro nombrado 'departamento', si el UseCase lo soporta.
        // Ejemplo: departamento: _algunaVariableDeDepartamentoSiExiste,
      );
      // --- FIN CAMBIO ---

      // --- Procesar resultados ---
      result.fold(
        (failure) {
          _message = failure.message;
          _state = RequestState.Error; // Establecer estado de error
          _hasMoreData = false; // Detener paginación en error
        },
        // Dentro de getMissingPeople -> result.fold -> (data) { ... }
        (data) {
          print(
            '[ViewModel DEBUG] Received data. Count BEFORE addAll: ${_desaparecidos.length}. Data length: ${data.length}. ForceRefresh: $forceRefresh',
          );

          if (data.isEmpty) {
            _hasMoreData = false;
            // Solo cambia a Empty si la lista principal (_desaparecidos) también está vacía
            if (_desaparecidos.isEmpty) {
              _state =
                  RequestState.Empty; // <-- ¿Se llega aquí incorrectamente?
            } else {
              // Si ya había datos (paginando), mantener Loaded aunque esta página esté vacía
              _state = RequestState.Loaded;
            }
          } else {
            _desaparecidos.addAll(data);
            print(
              '[ViewModel DEBUG] Data added. Count AFTER addAll: ${_desaparecidos.length}',
            );
            _lastDesaparecido = _desaparecidos.last;
            _hasMoreData = data.length == _itemsPerPage;
            _state =
                RequestState
                    .Loaded; // <-- Asegúrate que se llega aquí cuando hay datos
          }
          // ¿Qué hace exactamente _filterSearchResults? ¿Podría vaciar la lista que muestra la UI?
          _filterSearchResults(silent: true);
        },
      );
    } catch (e) {
      debugPrint('Error fetching missing people: $e'); // Usar debugPrint
      _message = 'Ocurrió un error inesperado.';
      _state = RequestState.Error;
      _hasMoreData = false;
    } finally {
      // --- Limpieza final del estado ---
      _isLoadingMore =
          false; // Siempre reiniciar el flag del cargador de paginación
      // Si el estado general sigue siendo Loading (ej., ocurrió un error antes de que se estableciera Loaded/Empty),
      // determinar el estado final basado en si tenemos datos.
      if (_state == RequestState.Loading) {
        _state =
            _desaparecidos.isEmpty ? RequestState.Empty : RequestState.Loaded;
      }
      notifyListeners(); // Notificación final
    }
  }

  // Método para buscar, llama a getMissingPeople con forceRefresh
  void searchMissingPeople(String query) {
    // Solo disparar búsqueda si la consulta cambia realmente
    final trimmedQuery = query.trim();
    if (_currentSearchQuery != trimmedQuery) {
      _currentSearchQuery = trimmedQuery;
      // Llama a getMissingPeople forzando un refresco para la nueva búsqueda
      getMissingPeople(forceRefresh: true);
    }
  }

  // Método para cargar la siguiente página (paginación)
  Future<void> loadMoreMissingPeople() async {
    // No cargar más si ya se está cargando, no hay más datos, o el estado principal es Loading
    if (_isLoadingMore || !_hasMoreData || _state == RequestState.Loading)
      return;

    // Llama a getMissingPeople sin forzar refresco para cargar la siguiente página
    await getMissingPeople(forceRefresh: false);
  }

  // Filtra los resultados localmente basado en la query actual
  void _filterSearchResults({bool silent = false}) {
    if (_currentSearchQuery.isEmpty) {
      _searchedDesaparecidos = List.from(
        _desaparecidos,
      ); // Copia completa si no hay búsqueda
    } else {
      _searchedDesaparecidos =
          _desaparecidos.where((desaparecido) {
            final nombreCompletoConcatenado =
                '${desaparecido.nombres} ${desaparecido.apellidos}';
            return nombreCompletoConcatenado.toLowerCase().contains(
              _currentSearchQuery.toLowerCase(),
            );
          }).toList();
    }
    // No notificar si es silent, la notificación principal se hace en getMissingPeople
    // if (!silent) notifyListeners();
  }

  // Método para reiniciar paginación y datos internos
  void _resetPaginationAndData({bool silent = false}) {
    print(
      '[ViewModel DEBUG] Resetting data. Count BEFORE clear: ${_desaparecidos.length}',
    ); // <-- AÑADIR ESTA LÍNEA
    _desaparecidos.clear();
    _searchedDesaparecidos.clear();
    print(
      '[ViewModel DEBUG] Resetting data. Count AFTER clear: ${_desaparecidos.length}',
    ); // <-- AÑADIR ESTA LÍNEA
    _lastDesaparecido = null;
    _hasMoreData = true;
    _isLoadingMore = false; // Asegurar que esto también se reinicie
    // No es necesario notificar aquí si silent es true, getMissingPeople lo hará
    // if (!silent) {
    //   notifyListeners();
    // }
  }

  // Método para resetear completamente el estado (ej. al salir de la pantalla si es necesario)
  void resetState() {
    _resetPaginationAndData(silent: true);
    _currentFilter = MissingFilter.active; // Volver al filtro por defecto
    _currentSearchQuery = ''; // Limpiar búsqueda
    _state = RequestState.Empty; // Estado inicial
    notifyListeners();
  }

  // ELIMINAR el método _loadMissingPeople antiguo si existía, ya que su lógica
  // se ha integrado en getMissingPeople y loadMoreMissingPeople.
}
