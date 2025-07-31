import 'package:flutter/foundation.dart';
import '../../../domain/entities/tutorial.dart';
import '../../../services/tutorial_service.dart';

class TutorialViewModel extends ChangeNotifier {
  final TutorialService _tutorialService = TutorialService();
  
  List<Tutorial> _tutorials = [];
  List<Tutorial> _filteredTutorials = [];
  bool _showOnlyRequired = false;
  
  List<Tutorial> get tutorials => _filteredTutorials;
  bool get showOnlyRequired => _showOnlyRequired;

  TutorialViewModel() {
    _loadTutorials();
  }

  void _loadTutorials() {
    _tutorials = _tutorialService.getAllTutorials();
    _applyFilters();
  }

  void toggleShowOnlyRequired() {
    _showOnlyRequired = !_showOnlyRequired;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filteredTutorials = _tutorials;

    // Filtrar solo requeridos
    if (_showOnlyRequired) {
      _filteredTutorials = _filteredTutorials
          .where((tutorial) => tutorial.isRequired)
          .toList();
    }

    // Ordenar por prioridad y luego por título
    _filteredTutorials.sort((a, b) {
      if (a.priority != b.priority) {
        return a.priority.compareTo(b.priority);
      }
      return a.title.compareTo(b.title);
    });
  }
}