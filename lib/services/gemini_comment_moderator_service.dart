import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../common/constants/gemini_constants.dart';
import 'gemini_extractor_service.dart';

/// Resultado del análisis de moderación instantáneo de un comentario
class ModerationResult {
  final bool aprobado;
  final String motivo;

  const ModerationResult({
    required this.aprobado,
    required this.motivo,
  });

  factory ModerationResult.approved() => const ModerationResult(
        aprobado: true,
        motivo: '',
      );

  factory ModerationResult.rejected(String motivo) => ModerationResult(
        aprobado: false,
        motivo: motivo,
      );
}

/// Servicio de moderación instantánea de comentarios ciudadanos con Google Gemini AI
class GeminiCommentModeratorService {
  /// Lista básica local de palabras prohibidas/insultos como salvaguarda en caso de timeout
  static final List<String> _localProfanityList = [
    'hdp', 'mierda', 'puta', 'puto', 'conchetumadre', 'ctm', 'chucha',
    'maricon', 'imbecil', 'estupido', 'cojudo', 'tarado', 'malnacido',
    'muerete', 'perra', 'carajo', 'pendejo', 'webon', 'huevon'
  ];

  /// Modera un comentario usando Gemini AI con criterio equilibrado (permisivo con pistas, estricto contra insultos y groserías)
  static Future<ModerationResult> moderateComment(String commentText) async {
    final text = commentText.trim();
    if (text.isEmpty) {
      return ModerationResult.rejected('El comentario no puede estar vacío.');
    }

    try {
      final apiKey = await GeminiExtractorService.getSavedApiKey() ?? GeminiConstants.apiKey;

      if (apiKey.isEmpty) {
        // Fallback local si no hay API key
        return _fallbackLocalCheck(text);
      }

      final modelsToTry = [
        GeminiConstants.defaultModel,
        ...GeminiConstants.fallbackModels.where((m) => m != GeminiConstants.defaultModel),
      ];

      for (final modelName in modelsToTry) {
        try {
          final model = GenerativeModel(
            model: modelName,
            apiKey: apiKey,
            generationConfig: GenerationConfig(
              temperature: 0.1,
              responseMimeType: 'application/json',
            ),
          );

          const prompt = '''
Eres un moderador de contenido para una plataforma ciudadana colaborativa de búsqueda y localización de personas desaparecidas.

Tu función es revisar en tiempo real el comentario enviado por un ciudadano sobre un caso de desaparición.

CRITERIO DE MODERACIÓN (MODERADO / NO ESTRICTO):
- ACEPTAR (aprobado = true):
  * Pistas, avistamientos, lugares, fechas y detalles sobre la persona desaparecida.
  * Mensajes de apoyo, aliento o solidaridad hacia la familia ("Dios los ayude", "mucha fuerza", "compartido").
  * Preguntas constructivas o dudas sobre la descripción.
  * Errores ortográficos, lenguaje coloquial peruano o frases en Quechua.

- RECHAZAR ÚNICAMENTE (aprobado = false):
  * Insultos directos o ataques verbales.
  * Palabras groseras, soeces, vulgaridades o lenguaje obsceno.
  * Burlas crueles o denigrantes hacia la persona desaparecida o sus familiares.
  * Amenazas de agresión o violencia.

Responde ÚNICAMENTE un objeto JSON válido con este formato:
{
  "aprobado": true,
  "motivo": ""
}
Si es rechazado, incluye en "motivo" una explicación corta y respetuosa (máximo 15 palabras).
''';

          final content = [
            Content.text(prompt),
            Content.text('Comentario a moderar:\n"""\n$text\n"""'),
          ];

          final response = await model.generateContent(content).timeout(
            const Duration(seconds: 7),
          );

          final responseText = response.text?.trim() ?? '';
          if (responseText.isNotEmpty) {
            final cleanJson = responseText
                .replaceAll('```json', '')
                .replaceAll('```', '')
                .trim();
            final parsed = jsonDecode(cleanJson) as Map<String, dynamic>;
            final aprobado = parsed['aprobado'] == true;
            final motivo = parsed['motivo']?.toString() ?? '';

            return ModerationResult(
              aprobado: aprobado,
              motivo: aprobado ? '' : (motivo.isNotEmpty ? motivo : 'Contiene lenguaje no permitido u ofensivo.'),
            );
          }
        } catch (modelError) {
          debugPrint('⚠️ Error con modelo $modelName en moderación: $modelError');
          continue; // Probar siguiente modelo de respaldo
        }
      }

      // Si todos los modelos fallaron por timeout o red, aplicar filtro local
      return _fallbackLocalCheck(text);
    } catch (e) {
      debugPrint('⚠️ Error en GeminiCommentModeratorService: $e');
      return _fallbackLocalCheck(text);
    }
  }

  /// Verificación local de respaldo para que el sistema nunca quede bloqueado si no hay internet
  static ModerationResult _fallbackLocalCheck(String text) {
    final lower = text.toLowerCase();
    for (final badWord in _localProfanityList) {
      final pattern = RegExp(r'\b' + RegExp.escape(badWord) + r'\b', caseSensitive: false);
      if (pattern.hasMatch(lower) || lower.contains(badWord)) {
        return ModerationResult.rejected('El comentario contiene palabras no permitidas.');
      }
    }
    return ModerationResult.approved();
  }
}
