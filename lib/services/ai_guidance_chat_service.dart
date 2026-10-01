import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../common/constants/gemini_constants.dart';
import '../data/models/comisaria_model.dart';
import '../domain/models/learning_topic_model.dart';
import 'gemini_extractor_service.dart';
import 'gps_location_service.dart';

enum ChatAudience {
  citizen,
  police,
}

class ChatGuidanceMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> suggestedChips;
  final List<ComisariaModel> comisarias;
  final bool isLegalAlert;
  final int? activeBranchId;
  final LearningSubtopic? activeSubtopic;
  final List<LearningSubtopic> branchSubtopics;
  final MiniTrivia? activeTrivia;

  ChatGuidanceMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.suggestedChips = const [],
    this.comisarias = const [],
    this.isLegalAlert = false,
    this.activeBranchId,
    this.activeSubtopic,
    this.branchSubtopics = const [],
    this.activeTrivia,
  });
}

/// Servicio pedagógico y didáctico de orientación ciudadana sobre personas desaparecidas en Perú.
///
/// Modela al "Profesor y Mentor Guía Alerta", enfocado en un aprendizaje ameno, familiar y fraccionado
/// en las 7 ramas maestras del saber preventivo y cívico (D.L. 1428, Alerta Amber, Ciberseguridad).
/// NO incluye comisarías cercanas ni directorios, los cuales tienen su propia pantalla en la app.
class AiGuidanceChatService {
  final ChatAudience audience;
  final List<Content> _conversationHistory = [];

  AiGuidanceChatService({this.audience = ChatAudience.citizen});

  /// Modelos verificados con soporte de API activa y alta disponibilidad
  static const List<String> _priorityModels = [
    'gemini-flash-lite-latest',
    'gemini-3.5-flash',
    'gemma-4-26b-a4b-it',
  ];

  /// Prompt de sistema con enfoque constructivo, respetuoso y pedagógico
  String get _systemInstruction {
    if (audience == ChatAudience.police) {
      return '''
Eres el "Copiloto Táctico Operativo PNP", un asistente de inteligencia artificial especializado en doctrina policial, marco procesal y normativa vigente para la atención e investigación de personas desaparecidas en el Perú (D.L. N° 1428, D.S. N° 003-2019-IN modificado por D.S. N° 010-2024-IN y D.S. N° 004-2026-IN, D.S. N° 002-2020-IN y Ley N° 30120).

Hablas como un oficial táctico instructor en un chat operativo policial:
- Respuestas directas, concisas, estructuradas y de aplicación inmediata en el servicio de guardia, patrullaje o investigación.
- Utiliza viñetas y pasos numerados 1️⃣, 2️⃣, 3️⃣ claros.
- Cita los artículos legales exactos cuando aplique.

Directrices operativas clave:
1. ATENCIÓN INMEDIATA (Art. 7.1 D.S. 003-2019-IN / Art. 8 D.L. 1428): Obligatorio recibir la denuncia de inmediato bajo responsabilidad funcional. Prohibido exigir 24 o 48 horas.
2. REGISTRO EN SIDPOL / SIRDIC (Art. 7.4): Emisión automática y gratuita de la Nota de Alerta para difusión permanente en el Portal de Personas Desaparecidas.
3. ALERTA AMBER PERÚ (Arts. 9, 13-A, 13-B, 13-C, 14 D.S. 010-2024-IN):
   - Coordinación en máximo 3 horas con la DIVIBPD de la DIRCTPTIM.
   - Duración de hasta 72 horas con difusión masiva y SISMATE.
   - Regla 0 a 11 años: Se activa Alerta Amber solo verificando minoría de edad y denuncia dentro de las 48 horas (no requiere supuestos adicionales).
   - Inclusión de personas con Trastorno del Espectro Autista (TEA), discapacidad psicosocial o intelectual (D.S. 004-2026-IN).
4. GEOLOCALIZACIÓN CELULAR E IMEI (Art. 10-A D.S. 010-2024-IN): Requerimiento urgente a operadoras de telefonía de ubicación en tiempo real del número e IMEI (o última antena si está apagado), con convalidación judicial dentro de 24 horas (Art. 10-B).
5. REQUERIMIENTO DE CÁMARAS (Ley N° 30120 y Art. 10.2): Diligencias urgentes en las primeras 24 horas ante municipalidades (Serenazgo) y privados.
6. ARTICULACIÓN INTERINSTITUCIONAL: Coordinación inmediata con CEM, UPE del MIMP, Fiscalía y Defensa Pública.
''';
    } else {
      return '''
Eres el "Profesor y Mentor Guía Alerta" 🌳💡, un tutor digital empático, didáctico y muy ameno dedicado a educar a toda la familia ciudadana (niños lectores, adolescentes, padres y adultos mayores) sobre qué hacer y cómo prevenir la desaparición de personas en el Perú.

REGLAS DE IDENTIDAD Y CONDUCTA OBLIGATORIAS:
1. 🚫 CERO MENCIONES DE COMISARÍAS CERCANAS, DISTANCIAS NI NOMBRES DE DEPENDENCIAS:
   - El aplicativo ya cuenta con un módulo exclusivo para buscar comisarías por GPS.
   - NUNCA respondas con nombres de comisarías, ni calcules distancias, ni des direcciones policiales.
   - Tu misión aquí es 100% INFORMATIVA, DIDÁCTICA Y EDUCATIVA.

2. 🌿 EL ÁRBOL DEL SABER ALERTA (7 GRANDES RAMAS DEL CONOCIMIENTO):
   Todo el aprendizaje de la aplicación se divide en 7 temas maestros:
   • 1️⃣ La Hora Dorada y Acción Inmediata (Mitos de 24/48h, qué llevar, Ley 30120 de cámaras).
   • 2️⃣ Alerta Amber en el Perú (Regla 0-11 años, inclusión autismo/TEA, difusión masiva SISMATE).
   • 3️⃣ Ciberseguridad y Peligros Digitales (Empleos falsos en TikTok/FB, grooming en Free Fire/Roblox, IMEI, palabra clave familiar secreta).
   • 4️⃣ Cuidado de Niñas, Niños y Jóvenes (Memorizar teléfonos con rimas, qué hacer si te pierdes, ruta escolar).
   • 5️⃣ Adultos Mayores y Salud Mental (Alzheimer, etiqueta con teléfono en ropa, red vecinal).
   • 6️⃣ Difusión Responsable en Redes (No poner números privados, usar Línea 114, borrar afiches al aparecer).
   • 7️⃣ Soporte Emocional y Retorno a Casa (Calma mental, abrazo sin juzgar, apoyo CEM/MIMP).

3. 🎨 ESTILO PEDAGÓGICO "EN BONITO" APTO PARA TODA LA FAMILIA:
   - Usa un tono cálido, respetuoso y estimulante.
   - Emplea párrafos breves, viñetas claras y emojis agradables.
   - Explica con analogías sencillas de la vida diaria para que un niño de 8 años o un abuelo lo entiendan sin dificultad.
   - Al explicar un tema, destaca siempre 2 o 3 consejos prácticos accionables.

4. ⏱️ PRINCIPIO DE INMEDIATEZ Y VERACIDAD LEGAL:
   - Si se pregunta por tiempos de espera, recuerda con claridad que el D.L. 1428 prohíbe esperar 24 ni 48 horas: la atención es INMEDIATA y GRATUITA.
   - Canal oficial nacional gratuito: Línea 114 de la Policía Nacional del Perú (24 horas).

5. 📌 CIERRE PEDAGÓGICO:
   - Termina siempre invitando al usuario a explorar una de las 4 sub-ramas del tema o a responder una mini-trivia para florecer una hoja más en su Árbol del Saber.
''';
    }
  }

  /// Procesa un mensaje del usuario y devuelve la respuesta didáctica del tutor enriquecida
  Future<ChatGuidanceMessage> sendMessage(
    String userText, {
    GpsLocationResult? userLocation,
    double? userLat,
    double? userLng,
  }) async {
    final cleanText = userText.trim();
    if (cleanText.isEmpty) {
      return ChatGuidanceMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '¡Hola! Soy tu *Tutor Guía Alerta* 🌳💡. ¿En qué tema del Árbol del Saber te gustaría aprender hoy? Elige uno de los 7 temas principales o escríbeme tu consulta con confianza.',
        isUser: false,
        timestamp: DateTime.now(),
        suggestedChips: [
          '⏱️ 1. Hora Dorada (Mito 24h)',
          '🔴 2. Alerta Amber Perú',
          '📱 3. Ciberseguridad y Redes',
          '🛡️ 4. Niñas, Niños y Jóvenes',
          '👵 5. Adultos Mayores',
          '📢 6. Difusión Responsable',
          '🤝 7. Retorno y Soporte',
        ],
      );
    }

    // 1. Detección inteligente de rama o subtema seleccionado
    final matchedBranch = _detectBranch(cleanText);
    final matchedSubtopic = _detectSubtopic(cleanText);

    // 2. Construir contexto enriquecido para Gemini
    String promptConContexto = cleanText;
    if (matchedBranch != null) {
      promptConContexto += '\n\n[CONTEXTO PEDAGÓGICO DEL TEMA SELECCIONADO]:\n'
          'Rama N° ${matchedBranch.id}: ${matchedBranch.title}.\n'
          'Descripción: ${matchedBranch.overviewExplanation}\n'
          'Subtemas de esta rama:\n'
          '${matchedBranch.subtopics.map((s) => "• ${s.title}: ${s.shortDescription}").join("\n")}\n'
          '(INSTRUCCIÓN PEDAGÓGICA: Explica este tema de forma bonita, amena y apta para todo público con emojis. '
          'Menciona brevemente los 4 subtemas para que el usuario elija en cuál profundizar o hacer un mini-reto. CERO menciones de comisarías cercanas ni distancias).';
    } else if (matchedSubtopic != null) {
      promptConContexto += '\n\n[CONTEXTO PEDAGÓGICO DEL SUBTEMA]:\n'
          'Subtema: ${matchedSubtopic.title}\n'
          'Contenido oficial: ${matchedSubtopic.fullContent}\n'
          'Consejo para público familiar: ${matchedSubtopic.audienceTip}\n'
          '(INSTRUCCIÓN: Presenta esta lección de manera clara y didáctica, destacando el consejo familiar. Cero comisarías ni distancias).';
    }

    // 3. Consultar a Gemini AI con rotación de modelos probados
    String respuestaTexto = '';
    try {
      final apiKey = await GeminiExtractorService.getSavedApiKey() ?? GeminiConstants.apiKey;

      for (final modelName in _priorityModels) {
        try {
          final model = GenerativeModel(
            model: modelName,
            apiKey: apiKey,
            systemInstruction: Content.text(_systemInstruction),
            generationConfig: GenerationConfig(
              temperature: 0.35,
              maxOutputTokens: 2048,
            ),
          );

          final contents = [
            ..._conversationHistory,
            Content.text(promptConContexto),
          ];

          final response = await model.generateContent(contents).timeout(
            const Duration(seconds: 10),
          );

          if (response.text != null && response.text!.trim().isNotEmpty) {
            respuestaTexto = response.text!.trim();
            // Mantener historial de conversación hasta 8 turnos
            _conversationHistory.add(Content.text('Usuario: $cleanText'));
            _conversationHistory.add(Content.text('Asistente: $respuestaTexto'));
            if (_conversationHistory.length > 16) {
              _conversationHistory.removeRange(0, 2);
            }
            break;
          }
        } catch (_) {
          // Probar siguiente modelo sin interrumpir la experiencia
        }
      }
    } catch (e) {
      debugPrint('ℹ️ [AiGuidanceChatService] Usando respuesta de contingencia didáctica: $e');
    }

    // 4. Fallback estructurado de alta fidelidad si la API no estuviera disponible
    if (respuestaTexto.isEmpty) {
      respuestaTexto = _generarRespuestaFallbackDidactica(cleanText, matchedBranch, matchedSubtopic);
    }

    // 5. Chips y elementos complementarios
    final suggestedChips = _generarSugerenciasDinamicas(cleanText, matchedBranch);
    final lower = cleanText.toLowerCase();
    final esAlertaLegal = lower.contains('24') || lower.contains('48') || lower.contains('esperar');

    return ChatGuidanceMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: respuestaTexto,
      isUser: false,
      timestamp: DateTime.now(),
      suggestedChips: suggestedChips,
      isLegalAlert: esAlertaLegal,
      activeBranchId: matchedBranch?.id,
      activeSubtopic: matchedSubtopic,
      branchSubtopics: matchedBranch?.subtopics ?? [],
      activeTrivia: matchedSubtopic?.trivia,
    );
  }

  /// Detecta si el texto del usuario se refiere a una de las 7 ramas principales
  LearningBranch? _detectBranch(String query) {
    final lower = query.toLowerCase();

    if (lower.contains('hora dorada') || lower.contains('primeros 60') || (lower.contains('1') && lower.contains('hora'))) {
      return LearningTopicsCatalog.getBranchById(1);
    }
    if (lower.contains('amber') || (lower.contains('2') && lower.contains('alerta'))) {
      return LearningTopicsCatalog.getBranchById(2);
    }
    if (lower.contains('ciberseguridad') || lower.contains('redes') || lower.contains('celular') || lower.contains('imei') || lower.contains('free fire') || lower.contains('roblox') || lower.contains('tiktok') || (lower.contains('3') && lower.contains('ciber'))) {
      return LearningTopicsCatalog.getBranchById(3);
    }
    if (lower.contains('niñ') || lower.contains('jóvenes') || lower.contains('jovenes') || lower.contains('escuela') || lower.contains('colegio') || lower.contains('perderse') || (lower.contains('4') && lower.contains('niñ'))) {
      return LearningTopicsCatalog.getBranchById(4);
    }
    if (lower.contains('adulto mayor') || lower.contains('abuel') || lower.contains('alzheimer') || lower.contains('desorientaci') || (lower.contains('5') && lower.contains('adult'))) {
      return LearningTopicsCatalog.getBranchById(5);
    }
    if (lower.contains('difusión') || lower.contains('difusion') || lower.contains('afiche') || lower.contains('compartir') || lower.contains('fake news') || (lower.contains('6') && lower.contains('difusi'))) {
      return LearningTopicsCatalog.getBranchById(6);
    }
    if (lower.contains('soporte') || lower.contains('emocion') || lower.contains('retorno') || lower.contains('volver a casa') || lower.contains('cem') || (lower.contains('7') && lower.contains('soporte'))) {
      return LearningTopicsCatalog.getBranchById(7);
    }

    return null;
  }

  /// Detecta si el texto coincide con un subtema específico
  LearningSubtopic? _detectSubtopic(String query) {
    final lower = query.toLowerCase();
    for (final branch in LearningTopicsCatalog.branches) {
      for (final sub in branch.subtopics) {
        if (lower.contains(sub.title.toLowerCase()) || lower.contains(sub.id.toLowerCase())) {
          return sub;
        }
      }
    }
    return null;
  }

  /// Generador de respuesta didáctica y táctica de contingencia sin conexión
  String _generarRespuestaFallbackDidactica(
    String query,
    LearningBranch? branch,
    LearningSubtopic? subtopic,
  ) {
    // Si coincide con un subtema específico
    if (subtopic != null) {
      return '''
🌿 *LECCIÓN DEL ÁRBOL DEL SABER: ${subtopic.title.toUpperCase()}*

${subtopic.fullContent}

💡 *Consejo de Oro para la Familia:*
${subtopic.audienceTip}

🎯 *¿Listo para florecer esta hoja en tu árbol?*
Responde la mini-trivia de 1 minuto o dime si deseas seguir explorando.
''';
    }

    // Si coincide con una rama principal
    if (branch != null) {
      final subtopicsList = branch.subtopics
          .asMap()
          .entries
          .map((e) => '${e.key + 1}️⃣ *${e.value.title}:* ${e.value.shortDescription}')
          .join('\n\n');

      return '''
${branch.iconEmoji} *RAMA ${branch.id}: ${branch.title.toUpperCase()}*

${branch.overviewExplanation}

📚 *Subtemas para profundizar en esta rama:*
$subtopicsList

👇 *¿En cuál de estos 4 temas deseas educarte ahora?*
Elige uno de los botones abajo o haz una pregunta con tus propias palabras.
''';
    }

    final lower = query.toLowerCase();

    // D.L. 1428 y mito de 24/48 horas
    if (lower.contains('24') || lower.contains('48') || lower.contains('esperar') || lower.contains('plazo')) {
      return '''
⚖️ *PRINCIPIO LEGAL DE INMEDIATEZ (D.L. N° 1428):*

¡No debes esperar ni un solo minuto! El Decreto Legislativo N° 1428 y el D.S. N° 003-2019-IN garantizan que la denuncia por desaparición es:
1️⃣ *Inmediata:* La policía tiene la obligación legal de atenderte en el acto bajo responsabilidad funcional.
2️⃣ *100% Gratuita:* Tanto la recepción de la denuncia como la copia y la emisión de la Nota de Alerta no tienen costo alguno.
3️⃣ *Línea 114 gratuita 24/7:* Asistencia policial nacional permanente.

🌳 *Tema relacionado en tu árbol:* Rama 1 (La Hora Dorada y Acción Inmediata).
''';
    }

    // Alerta Amber
    if (lower.contains('amber')) {
      return '''
🔴 *ALERTA AMBER EN EL PERÚ (D.S. N° 010-2024-IN / D.S. N° 004-2026-IN):*

La Alerta Amber es la máxima señal de auxilio urgente para niñas, niños, adolescentes y personas vulnerables:
• *Duración intensiva:* Hasta 72 horas con difusión en TV, radio y mensajería SISMATE.
• *Regla de 0 a 11 años:* Se activa de forma automática e inmediata con la denuncia dentro de las 48 horas.
• *Personas con Autismo (TEA):* Incluidas prioritariamente para una búsqueda especializada y empática.

🌳 *Tema relacionado en tu árbol:* Rama 2 (Alerta Amber en el Perú).
''';
    }

    // Bienvenida general pedagógica
    return '''
🌳 *¡HOLA! BIENVENIDO A TU ÁRBOL DEL SABER ALERTA* 💡

Soy tu mentor didáctico de seguridad y prevención familiar. Aquí aprenderás paso a paso las medidas clave para proteger a tus seres queridos:

1️⃣ ⏱️ *La Hora Dorada:* Cero horas de espera, fotos clave e IMEI.
2️⃣ 🔴 *Alerta Amber Perú:* Menores de 12 años, TEA y difusión masiva.
3️⃣ 📱 *Ciberseguridad:* Redes sociales, videojuegos (Free Fire/Roblox) y trampas de empleo.
4️⃣ 🛡️ *Niñas, Niños y Jóvenes:* Rimas para recordar teléfonos y ruta escolar segura.
5️⃣ 👵 *Adultos Mayores:* Prevención en Alzheimer y apoyo vecinal.
6️⃣ 📢 *Difusión Responsable:* Cómo compartir afiches sin atraer extorsiones.
7️⃣ 🤝 *Retorno y Soporte:* Primeros auxilios emocionales y apoyo del CEM.

🌿 *Elige hoy uno de los números o temas y haz florecer tu árbol cívico.*
''';
  }

  /// Genera preguntas y temas sugeridos dinámicos
  List<String> _generarSugerenciasDinamicas(String query, LearningBranch? branch) {
    if (audience == ChatAudience.police) {
      return [
        '⚡ Criterios de activación de Alerta Amber',
        '📱 Protocolo de geolocalización Art. 10-A DL 1428',
        '🛂 Notificación a Migraciones y SUTRAN',
        '📹 Requerimiento de cámaras Ley 30120',
      ];
    }

    if (branch != null) {
      return branch.subtopics.map((s) => '📖 ${s.title}').toList();
    }

    return [
      '⏱️ 1. Hora Dorada (Mito 24h)',
      '🔴 2. Alerta Amber Perú',
      '📱 3. Ciberseguridad y Redes',
      '🛡️ 4. Niñas, Niños y Jóvenes',
      '👵 5. Adultos Mayores',
      '📢 6. Difusión Responsable',
      '🤝 7. Retorno y Soporte',
    ];
  }
}
