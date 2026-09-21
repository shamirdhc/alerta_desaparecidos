import 'package:flutter/foundation.dart';
import '../../../common/state_enum.dart';
import '../../../domain/entities/policia.dart';
import '../../../domain/use_cases/policia_management_use_cases.dart';

class PoliciaManagementViewModel extends ChangeNotifier {
  final GetAllPoliciasUseCase _getAllPoliciasUseCase;
  final GetCurrentPoliciaUseCase _getCurrentPoliciaUseCase;
  final IsCurrentUserAdminUseCase _isCurrentUserAdminUseCase;
  final CreatePoliciaUseCase _createPoliciaUseCase;
  final UpdatePoliciaUseCase _updatePoliciaUseCase;
  final DeletePoliciaUseCase _deletePoliciaUseCase;

  PoliciaManagementViewModel({
    required GetAllPoliciasUseCase getAllPoliciasUseCase,
    required GetCurrentPoliciaUseCase getCurrentPoliciaUseCase,
    required IsCurrentUserAdminUseCase isCurrentUserAdminUseCase,
    required CreatePoliciaUseCase createPoliciaUseCase,
    required UpdatePoliciaUseCase updatePoliciaUseCase,
    required DeletePoliciaUseCase deletePoliciaUseCase,
  }) : _getAllPoliciasUseCase = getAllPoliciasUseCase,
       _getCurrentPoliciaUseCase = getCurrentPoliciaUseCase,
       _isCurrentUserAdminUseCase = isCurrentUserAdminUseCase,
       _createPoliciaUseCase = createPoliciaUseCase,
       _updatePoliciaUseCase = updatePoliciaUseCase,
       _deletePoliciaUseCase = deletePoliciaUseCase;

  // Estados
  RequestState _state = RequestState.Empty;
  RequestState _createState = RequestState.Empty;
  RequestState _updateState = RequestState.Empty;
  RequestState _deleteState = RequestState.Empty;
  RequestState _adminCheckState = RequestState.Empty;

  // Datos
  List<Policia> _policias = [];
  List<Policia> _filteredPolicias = [];
  Policia? _currentPolicia;
  bool _isAdmin = false;
  String _searchQuery = '';
  String _errorMessage = '';
  String _successMessage = '';

  // Estadísticas
  int _totalPolicias = 0;
  int _adminPolicias = 0;
  int _regularPolicias = 0;

  // Getters
  RequestState get state => _state;
  RequestState get createState => _createState;
  RequestState get updateState => _updateState;
  RequestState get deleteState => _deleteState;
  RequestState get adminCheckState => _adminCheckState;

  List<Policia> get policias => _filteredPolicias;
  Policia? get currentPolicia => _currentPolicia;
  bool get isAdmin => _isAdmin;
  String get searchQuery => _searchQuery;
  String get errorMessage => _errorMessage;
  String get successMessage => _successMessage;

  int get totalPolicias => _totalPolicias;
  int get adminPolicias => _adminPolicias;
  int get regularPolicias => _regularPolicias;

  // Verificar si el usuario actual es administrador
  Future<void> checkAdminStatus() async {
    print('🔍 [DEBUG] Iniciando verificación de admin...');
    _adminCheckState = RequestState.Loading;
    notifyListeners();

    try {
      print('🔍 [DEBUG] Obteniendo policía actual...');
      _currentPolicia = await _getCurrentPoliciaUseCase();
      print('🔍 [DEBUG] Policía actual obtenido: ${_currentPolicia?.toString()}');
      
      print('🔍 [DEBUG] Verificando permisos de admin...');
      _isAdmin = await _isCurrentUserAdminUseCase();
      print('🔍 [DEBUG] Es admin: $_isAdmin');
      
      _adminCheckState = RequestState.Loaded;
    } catch (e) {
      print('❌ [DEBUG] Error en checkAdminStatus: $e');
      _adminCheckState = RequestState.Error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  // Cargar todos los policías
  Future<void> loadPolicias() async {
    _state = RequestState.Loading;
    notifyListeners();

    try {
      _policias = await _getAllPoliciasUseCase();
      _applyFilters();
      _updateStatistics();
      _state = RequestState.Loaded;
      _errorMessage = '';
    } catch (e) {
      _state = RequestState.Error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  // Buscar policías
  void searchPolicias(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  // Aplicar filtros
  void _applyFilters() {
    if (_searchQuery.isEmpty) {
      _filteredPolicias = List.from(_policias);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredPolicias =
          _policias.where((policia) {
            return policia.nombre.toLowerCase().contains(query) ||
                policia.apellido.toLowerCase().contains(query) ||
                policia.telefono.contains(query) ||
                policia.numeroCip.toLowerCase().contains(query) ||
                policia.departamento.toLowerCase().contains(query) ||
                policia.unidad.toLowerCase().contains(query) ||
                policia.rango.toLowerCase().contains(query);
          }).toList();
    }
  }

  // Actualizar estadísticas
  void _updateStatistics() {
    _totalPolicias = _policias.length;
    _adminPolicias = _policias.where((p) => p.admin).length;
    _regularPolicias = _totalPolicias - _adminPolicias;
  }

  // Crear policía
  Future<void> createPolicia(Policia policia) async {
    _createState = RequestState.Loading;
    notifyListeners();

    try {
      await _createPoliciaUseCase(policia);
      _createState = RequestState.Loaded;
      _successMessage = 'Policía creado exitosamente';
      await loadPolicias(); // Recargar la lista
    } catch (e) {
      _createState = RequestState.Error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  // Actualizar policía
  Future<void> updatePolicia(Policia policia) async {
    _updateState = RequestState.Loading;
    notifyListeners();

    try {
      await _updatePoliciaUseCase(policia);
      _updateState = RequestState.Loaded;
      _successMessage = 'Policía actualizado exitosamente';
      await loadPolicias(); // Recargar la lista
    } catch (e) {
      _updateState = RequestState.Error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  // Eliminar policía
  Future<void> deletePolicia(String uid) async {
    _deleteState = RequestState.Loading;
    notifyListeners();

    try {
      await _deletePoliciaUseCase(uid);
      _deleteState = RequestState.Loaded;
      _successMessage = 'Policía eliminado exitosamente';
      await loadPolicias(); // Recargar la lista
    } catch (e) {
      _deleteState = RequestState.Error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  // Limpiar mensajes
  void clearMessages() {
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();
  }

  // Limpiar estados
  void clearStates() {
    _createState = RequestState.Empty;
    _updateState = RequestState.Error;
    _deleteState = RequestState.Empty;
    notifyListeners();
  }
}
