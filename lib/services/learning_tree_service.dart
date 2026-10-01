import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/learning_topic_model.dart';

/// Servicio de persistencia y seguimiento del progreso del Árbol del Saber Alerta.
/// 
/// Funciona de forma 100% offline mediante SharedPreferences, manteniendo la lista
/// de subtemas completados, cálculo del porcentaje de floración del árbol,
/// desbloqueo de rangos cívicos y notificaciones reactivas.
class LearningTreeService extends ChangeNotifier {
  static const String _storageKey = 'learning_tree_completed_subtopics';

  static final LearningTreeService _instance = LearningTreeService._internal();
  factory LearningTreeService() => _instance;
  LearningTreeService._internal();

  final Set<String> _completedSubtopicIds = {};
  bool _isInitialized = false;

  Set<String> get completedSubtopicIds => Set.unmodifiable(_completedSubtopicIds);
  bool get isInitialized => _isInitialized;

  /// Inicializa el servicio cargando los datos guardados en disco
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedList = prefs.getStringList(_storageKey) ?? [];
      _completedSubtopicIds.clear();
      _completedSubtopicIds.addAll(savedList);
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ [LearningTreeService] Error al inicializar preferencias: $e');
      _isInitialized = true;
    }
  }

  /// Verifica si un subtema específico ya fue completado
  bool isSubtopicCompleted(String subtopicId) {
    return _completedSubtopicIds.contains(subtopicId);
  }

  /// Marca un subtema como completado. Retorna true si era nuevo y se registró.
  Future<bool> completeSubtopic(String subtopicId) async {
    if (_completedSubtopicIds.contains(subtopicId)) {
      return false; // Ya estaba completado
    }

    _completedSubtopicIds.add(subtopicId);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, _completedSubtopicIds.toList());
      return true;
    } catch (e) {
      debugPrint('⚠️ [LearningTreeService] Error al guardar subtema: $e');
      return true;
    }
  }

  /// Cantidad total de subtemas completados
  int get completedCount => _completedSubtopicIds.length;

  /// Total de subtemas en el catálogo (28)
  int get totalCount => LearningTopicsCatalog.totalSubtopicsCount;

  /// Porcentaje de progreso global (0.0 a 1.0)
  double get overallProgress {
    if (totalCount == 0) return 0.0;
    return (_completedSubtopicIds.length / totalCount).clamp(0.0, 1.0);
  }

  /// Porcentaje formateado en texto (ej. "45%")
  String get overallProgressPercentageString {
    return '${(overallProgress * 100).toInt()}%';
  }

  /// Cantidad de subtemas completados dentro de una rama específica
  int getBranchCompletedCount(int branchId) {
    final branch = LearningTopicsCatalog.getBranchById(branchId);
    if (branch == null) return 0;
    return branch.subtopics.where((s) => _completedSubtopicIds.contains(s.id)).length;
  }

  /// Porcentaje completado de una rama específica (0.0 a 1.0)
  double getBranchProgress(int branchId) {
    final branch = LearningTopicsCatalog.getBranchById(branchId);
    if (branch == null || branch.subtopics.isEmpty) return 0.0;
    return getBranchCompletedCount(branchId) / branch.subtopics.length;
  }

  /// Indica si todos los 4 subtemas de la rama fueron completados
  bool isBranchCompleted(int branchId) {
    final branch = LearningTopicsCatalog.getBranchById(branchId);
    if (branch == null || branch.subtopics.isEmpty) return false;
    return getBranchCompletedCount(branchId) == branch.subtopics.length;
  }

  /// Rango cívico actual según el progreso en el árbol
  String get currentRankTitle {
    final count = completedCount;
    if (count == 0) return 'Semilla de Guardián 🌱';
    if (count <= 7) return 'Observador Alerta 🥉';
    if (count <= 18) return 'Defensor Familiar 🥈';
    if (count < 28) return 'Guardián Comunitario 🥇';
    return 'Maestro Protector Alerta Desaparecidos 👑';
  }

  /// Descripción motivacional del rango actual
  String get currentRankDescription {
    final count = completedCount;
    if (count == 0) {
      return '¡Comienza hoy tu camino! Explora una de las 7 ramas para empezar a florecer tu árbol.';
    }
    if (count <= 7) {
      return '¡Buen comienzo! Conoces las pautas básicas de la Hora Dorada, primeros auxilios y cómo reaccionar.';
    }
    if (count <= 18) {
      return '¡Imparable! Tienes conocimientos sólidos en ciberseguridad, redes sociales, prevención y Alerta Amber.';
    }
    if (count < 28) {
      return '¡Gran sabiduría cívica! Estás muy cerca de completar todas las 7 ramas del saber protector.';
    }
    return '¡Árbol 100% Florecido! Posees la preparación cívico-legal máxima y eres un Guardián Protector de la comunidad.';
  }

  /// Restablece el progreso (útil para pruebas o reiniciar)
  Future<void> resetProgress() async {
    _completedSubtopicIds.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }
}
