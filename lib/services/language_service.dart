import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { es, qu }

class LanguageService extends ChangeNotifier {
  static const String _prefKey = 'app_language';
  AppLanguage _currentLanguage = AppLanguage.es;

  LanguageService() {
    _loadLanguagePreference();
  }

  AppLanguage get currentLanguage => _currentLanguage;
  bool get isQuechua => _currentLanguage == AppLanguage.qu;
  bool get isSpanish => _currentLanguage == AppLanguage.es;

  String get languageCode => _currentLanguage == AppLanguage.qu ? 'qu' : 'es';
  String get languageName => _currentLanguage == AppLanguage.qu ? 'Runasimi' : 'Español';

  Future<void> _loadLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey);
      if (savedCode == 'qu') {
        _currentLanguage = AppLanguage.qu;
        notifyListeners();
      } else {
        _currentLanguage = AppLanguage.es;
      }
    } catch (e) {
      debugPrint('Error cargando idioma de preferencia: $e');
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_currentLanguage == language) return;
    _currentLanguage = language;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language == AppLanguage.qu ? 'qu' : 'es');
    } catch (e) {
      debugPrint('Error guardando preferencia de idioma: $e');
    }
  }

  Future<void> toggleLanguage() async {
    final next = _currentLanguage == AppLanguage.es ? AppLanguage.qu : AppLanguage.es;
    await setLanguage(next);
  }
}
