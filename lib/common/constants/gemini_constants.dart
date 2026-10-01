/// Constantes de configuración para la integración con Google Gemini AI
class GeminiConstants {
  /// Clave de API de Google Gemini vinculada a la cuenta del usuario
  static const String apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AQ.Ab8RN6I-6JijqmRvCOoQ7z1XMLFuVrln5voIRp1dLD0FQfBk1g',
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