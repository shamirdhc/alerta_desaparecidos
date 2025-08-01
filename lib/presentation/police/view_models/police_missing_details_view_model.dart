import 'package:flutter/material.dart';
import '../../../common/state_enum.dart';
import '../../../domain/entities/desaparecido.dart';
import '../../../domain/entities/policia.dart';
import '../../../domain/use_cases/marcar_como_encontrado_con_verificacion_use_case.dart';
import '../../../domain/repositories/policia_repository.dart';

class PoliceMissingDetailsViewModel extends ChangeNotifier {
  final MarcarComoEncontradoConVerificacionUseCase _marcarComoEncontradoConVerificacionUseCase;
  final PoliciaRepository _policiaRepository;

  Desaparecido _desaparecido;
  Desaparecido get desaparecido => _desaparecido;

  RequestState _actionState = RequestState.Empty;
  RequestState get actionState => _actionState;

  String _actionMessage = '';
  String get actionMessage => _actionMessage;

  // Nuevo estado para manejar errores de jurisdicción
  bool _isJurisdictionError = false;
  bool get isJurisdictionError => _isJurisdictionError;

  // Información del policía actual
  Policia? _currentPolicia;
  Policia? get currentPolicia => _currentPolicia;

  List<String> _investigationNotes = [];
  List<String> get investigationNotes => List.unmodifiable(_investigationNotes);

  List<CaseUpdate> _caseUpdates = [];
  List<CaseUpdate> get caseUpdates => List.unmodifiable(_caseUpdates);

  PoliceMissingDetailsViewModel(
    this._marcarComoEncontradoConVerificacionUseCase,
    this._policiaRepository,
    this._desaparecido,
  ) {
    _initializeCaseData();
  }

  void _initializeCaseData() async {
    // Inicializar datos del caso
    _loadInvestigationNotes();
    _loadCaseUpdates();
    await _loadCurrentPolicia();
  }

  Future<void> _loadCurrentPolicia() async {
    try {
      _currentPolicia = await _policiaRepository.getCurrentPolicia();
      notifyListeners();
    } catch (e) {
      print('Error al cargar información del policía: $e');
    }
  }

  void _loadInvestigationNotes() {
    // Cargar notas de investigación desde la base de datos
    // Por ahora, datos de ejemplo
    _investigationNotes = [
      'Caso reportado por familiar directo',
      'Última ubicación confirmada en centro comercial',
      'Testigos reportan haber visto a la persona en la zona',
    ];
  }

  void _loadCaseUpdates() {
    // Cargar actualizaciones del caso
    _caseUpdates = [
      CaseUpdate(
        id: '1',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        description: 'Caso reportado inicialmente',
        officer: 'Oficial Rodriguez',
        type: CaseUpdateType.created,
      ),
      CaseUpdate(
        id: '2',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        description: 'Investigación iniciada',
        officer: 'Oficial Martinez',
        type: CaseUpdateType.investigation,
      ),
    ];
  }

  Future<void> markAsFound({
    DateTime? fechaEncontrado,
    String? detallesEncontrado,
    String? ubicacionEncontrado,
  }) async {
    _actionState = RequestState.Loading;
    _isJurisdictionError = false;
    notifyListeners();

    try {
      final result = await _marcarComoEncontradoConVerificacionUseCase.execute(
        _desaparecido.id!, // parámetro posicional
        fechaEncontrado: fechaEncontrado ?? DateTime.now(),
        encontradoDetalles: detallesEncontrado ?? '', // Corregido: era 'detallesEncontrado'
      );

      result.fold(
        (failure) {
          _actionMessage = failure.message;
          _actionState = RequestState.Error;
          
          // Verificar si es un error de jurisdicción
          if (failure is JurisdictionFailure) {
            _isJurisdictionError = true;
          }
        },
        (success) {
          _actionMessage = 'Caso marcado como encontrado exitosamente';
          _actionState = RequestState.Loaded;

          // Actualizar el estado local
          _desaparecido = _desaparecido.copyWith(
            estado: 'encontrado',
            fechaEncontrado: fechaEncontrado ?? DateTime.now(),
            encontradoDetalles: detallesEncontrado,
          );

          // Agregar actualización al timeline
          _addCaseUpdate(
            'Persona encontrada',
            'Sistema',
            CaseUpdateType.found,
            detallesEncontrado,
          );
        },
      );
    } catch (e) {
      _actionMessage = 'Error inesperado al marcar caso como encontrado';
      _actionState = RequestState.Error;
      _isJurisdictionError = false;
    }

    notifyListeners();
  }

  void addInvestigationNote(String note) {
    if (note.trim().isNotEmpty) {
      _investigationNotes.add(note.trim());

      // Agregar al timeline
      _addCaseUpdate(
        'Nota de investigación agregada',
        'Oficial Actual', // En producción, obtener del usuario actual
        CaseUpdateType.note,
        note,
      );

      notifyListeners();
    }
  }

  void _addCaseUpdate(
    String description,
    String officer,
    CaseUpdateType type, [
    String? details,
  ]) {
    final update = CaseUpdate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      description: description,
      officer: officer,
      type: type,
      details: details,
    );

    _caseUpdates.insert(
      0,
      update,
    ); // Agregar al inicio para mostrar más recientes primero
    notifyListeners();
  }

  void updateCaseStatus(String status, String notes) {
    _addCaseUpdate(
      'Estado actualizado a: $status',
      'Oficial Actual',
      CaseUpdateType.statusChange,
      notes,
    );
  }

  void resetActionState() {
    _actionState = RequestState.Empty;
    _actionMessage = '';
    _isJurisdictionError = false;
    notifyListeners();
  }

  int calculatePriority() {
    if (_desaparecido.fechaDesaparicion == null) return 1;

    final daysSinceDisappearance =
        DateTime.now().difference(_desaparecido.fechaDesaparicion!).inDays;

    if (daysSinceDisappearance > 30) return 4; // Urgente
    if (daysSinceDisappearance > 14) return 3; // Alta
    if (daysSinceDisappearance > 7) return 2; // Media
    return 1; // Baja
  }

  String getPriorityText() {
    final priority = calculatePriority();
    switch (priority) {
      case 4:
        return 'Urgente';
      case 3:
        return 'Alta';
      case 2:
        return 'Media';
      default:
        return 'Baja';
    }
  }

  Color getPriorityColor() {
    final priority = calculatePriority();
    switch (priority) {
      case 4:
        return Colors.red;
      case 3:
        return Colors.orange;
      case 2:
        return Colors.yellow[700]!;
      default:
        return Colors.green;
    }
  }
}

class CaseUpdate {
  final String id;
  final DateTime timestamp;
  final String description;
  final String officer;
  final CaseUpdateType type;
  final String? details;

  CaseUpdate({
    required this.id,
    required this.timestamp,
    required this.description,
    required this.officer,
    required this.type,
    this.details,
  });
}

enum CaseUpdateType {
  created,
  investigation,
  note,
  statusChange,
  found,
  archived,
}
