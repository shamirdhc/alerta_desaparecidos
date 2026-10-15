/// Constantes de configuración para la integración con Google Gemini AI
class GeminiConstants {
  /// Clave de API de Google Gemini vinculada a la cuenta del usuario
  static const String apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Modelo de visión multimodal oficial optimizado por velocidad y precisión
  static const String defaultModel = 'gemini-3.5-flash';

  /// Modelos de respaldo en caso de alta demanda o saturación
  static const List<String> fallbackModels = [
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-flash-lite-latest',
  ];
}