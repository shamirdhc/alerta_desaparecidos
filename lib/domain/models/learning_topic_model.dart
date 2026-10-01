import 'package:flutter/material.dart';
import 'educational_video_model.dart';

export 'educational_video_model.dart';

/// Modelo de pregunta de trivia rápida para evaluar el aprendizaje de un subtema
class MiniTrivia {
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String feedbackExplanation;

  const MiniTrivia({
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.feedbackExplanation,
  });

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'correctOptionIndex': correctOptionIndex,
        'feedbackExplanation': feedbackExplanation,
      };
}

/// Modelo de un subtema específico dentro de una rama del árbol
class LearningSubtopic {
  final String id;
  final String title;
  final String shortDescription;
  final String fullContent;
  final String audienceTip; // Consejo específico para niños/jóvenes o padres
  final MiniTrivia trivia;
  final IconData icon;
  final int? relatedAppModuleTab; // Índice del tab en el app para acceso directo (ej. 1, 4, 5, 6)
  final String? relatedAppModuleLabel; // Etiqueta del botón de acceso directo
  final IconData? relatedAppModuleIcon;
  final EducationalVideo? video; // 🎬 Video institucional didáctico PNP

  const LearningSubtopic({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.fullContent,
    required this.audienceTip,
    required this.trivia,
    required this.icon,
    this.relatedAppModuleTab,
    this.relatedAppModuleLabel,
    this.relatedAppModuleIcon,
    this.video,
  });

  /// Indica si el subtema cuenta con un video oficial de apoyo
  bool get hasVideo => video != null;
}

/// Modelo de una de las 7 ramas maestras del árbol de aprendizaje
class LearningBranch {
  final int id;
  final String title;
  final String subtitle;
  final String iconEmoji;
  final IconData iconData;
  final Color color;
  final String overviewExplanation;
  final List<LearningSubtopic> subtopics;

  const LearningBranch({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconEmoji,
    required this.iconData,
    required this.color,
    required this.overviewExplanation,
    required this.subtopics,
  });
}

/// Catálogo oficial completo del Árbol del Saber Alerta (8 Ramas Maestras y 32 Hojas)
class LearningTopicsCatalog {
  static const List<LearningBranch> branches = [
    // RAMA 1: La Hora Dorada y Acción Inmediata
    LearningBranch(
      id: 1,
      title: 'La Hora Dorada y Acción Inmediata',
      subtitle: 'Mitos, tiempos y qué hacer en los primeros 60 minutos',
      iconEmoji: '⏱️',
      iconData: Icons.timer_rounded,
      color: Color(0xFFE11D48), // Rojo vibrante de emergencia
      overviewExplanation:
          '¡Los primeros minutos son los más valiosos de todos! En el Perú existe la ley D.L. 1428 que protege a las familias y prohíbe esperar. Aprenderás qué hacer de inmediato, qué documentos son vitales y cómo moverte con rapidez y serenidad.',
      subtopics: [
        LearningSubtopic(
          id: '1_1',
          title: 'El mito de las 24 o 48 horas',
          shortDescription: 'La ley prohíbe exigir esperas. La atención es de inmediato.',
          fullContent:
              'Durante años existió el mito de que se debía esperar un día o dos para denunciar. ¡Eso es falso y peligroso!\n\n'
              'Bajo el Decreto Legislativo N° 1428 y el D.S. N° 003-2019-IN, la atención policial es INMEDIATA y GRATUITA. '
              'Cualquier efectivo policial tiene la obligación legal de recibir la denuncia al instante, sin importar si pasaron solo 15 minutos o una hora desde que la persona no llega.',
          audienceTip: '👧 Para niños y jóvenes: Si no sabes de un amigo o familiar, avisa de inmediato a un adulto de confianza. Nunca hay que quedarse callados por vergüenza o miedo.',
          icon: Icons.gavel_rounded,
          trivia: MiniTrivia(
            question: '¿Cuántas horas debes esperar para denunciar que una persona no aparece?',
            options: [
              'Se deben esperar 24 horas obligatoriamente.',
              'Se deben esperar 48 horas si es menor de edad.',
              '¡Cero horas! La atención es inmediata y gratuita por ley.',
            ],
            correctOptionIndex: 2,
            feedbackExplanation:
                '¡Exacto! El Decreto Legislativo N° 1428 establece que la denuncia de desaparición se recibe de forma inmediata y sin costo alguno.',
          ),
          video: EducationalVideo(
            id: 'quick_guide',
            title: 'Guía Rápida PNP',
            subtitle: 'Pasos esenciales para denunciar (D.L. 1428)',
            description:
                'Todo lo que necesitas saber para actuar rápidamente ante una desaparición sin esperar 24 horas. Video oficial optimizado para móviles.',
            thumbnailUrl: 'assets/icons/missing-icon.png',
            videoUrl:
                'gs://alerta-desaparecidos-pnp.firebasestorage.app/recursos/videos/denunciar_mininter.mp4',
            duration: '2:30',
            orientation: VideoOrientation.vertical,
            category: VideoCategory.prevention,
            icon: Icons.flash_on,
            color: Color(0xFF4CAF50),
          ),
        ),
        LearningSubtopic(
          id: '1_2',
          title: 'Qué llevar a la mano: Foto, prendas e IMEI',
          shortDescription: 'Tres datos esenciales que aceleran la búsqueda en un 80%.',
          fullContent:
              'Cuando acudas o reportes una desaparición, no vayas con las manos vacías. Prepara estos 3 elementos clave:\n\n'
              '1. Una fotografía reciente y nítida: De preferencia a color, donde su rostro sea claro y sin filtros de redes sociales.\n'
              '2. Descripción de vestimenta: Qué ropa llevaba puesta (color de chompa, pantalón, zapatillas, mochila o accesorios).\n'
              '3. El número de celular y el código IMEI (se obtiene marcando *#06# en el teléfono): Permite rastrear la última antena telefónica conectada.\n\n'
              '💡 Consejo Preventivo: Puedes guardar todos estos datos con anticipación en el módulo "Mi Familia Segura" para tenerlos a mano.',
          audienceTip: '👨‍👩‍👧 Para padres: Tómale una foto a tus hijos con su ropa del día antes de ir a ferias, playas o eventos muy concurridos.',
          icon: Icons.photo_camera_rounded,
          relatedAppModuleTab: 4,
          relatedAppModuleLabel: 'Guardar datos en Mi Familia Segura',
          relatedAppModuleIcon: Icons.family_restroom_rounded,
          trivia: MiniTrivia(
            question: '¿Cuál de estas fotos es la más útil para una búsqueda oficial?',
            options: [
              'Una foto de hace 4 años con filtros de perrito o stickers.',
              'Una foto reciente, nítida, a color y con el rostro despejado.',
              'Una foto borrosa tomada de noche desde muy lejos.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Muy bien! Una fotografía reciente y sin filtros permite que la comunidad y las autoridades reconozcan sus rasgos reales rápidamente.',
          ),
          video: EducationalVideo(
            id: 'complete_guide',
            title: 'Guía Completa del Proceso',
            subtitle: 'Proceso detallado paso a paso y Portal Nacional',
            description:
                'Información completa sobre documentación, procedimientos de búsqueda y recursos del Estado para la localización de personas.',
            thumbnailUrl: 'assets/icons/reportar_desaparecido_icon.png',
            videoUrl:
                'gs://alerta-desaparecidos-pnp.firebasestorage.app/recursos/videos/denunciar_web.mp4',
            duration: '8:45',
            orientation: VideoOrientation.horizontal,
            category: VideoCategory.information,
            icon: Icons.info_outline,
            color: Color(0xFF2196F3),
          ),
        ),
        LearningSubtopic(
          id: '1_3',
          title: 'A quién avisar primero y qué evitar',
          shortDescription: 'Canales oficiales versus el riesgo de publicaciones desordenadas.',
          fullContent:
              'En el momento de desesperación, muchas personas publican en Facebook su número de celular personal pidiendo ayuda. ¡Cuidado! Eso atrae llamadas de estafadores y extorsionadores que se aprovechan del dolor.\n\n'
              'Lo correcto es:\n'
              '• Avisar a la Línea 114 (gratuita 24/7) y asentar la denuncia oficial.\n'
              '• Contactar a los amigos más cercanos y el colegio/universidad/trabajo.\n'
              '• Difundir únicamente afiches oficiales donde el teléfono de contacto sea la Línea 114 de la PNP.',
          audienceTip: '🛡️ Para todos: Nunca hagas depósitos de dinero a desconocidos que te llamen diciendo tener a tu familiar sin antes verificar con la policía.',
          icon: Icons.phone_callback_rounded,
          trivia: MiniTrivia(
            question: '¿Por qué NO se recomienda poner tu número personal en afiches de redes sociales?',
            options: [
              'Porque consume tus megas de internet.',
              'Porque personas inescrupulosas pueden llamar para estafar o extorsionar.',
              'Porque la ley prohíbe tener celulares.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Correcto! Los estafadores aprovechan los números personales en afiches para fingir secuestros. Usa siempre el canal oficial de la Línea 114.',
          ),
        ),
        LearningSubtopic(
          id: '1_4',
          title: 'Cámaras de videovigilancia (Ley 30120)',
          shortDescription: 'Solicitud urgente dentro de las primeras 24 horas antes de que se borren.',
          fullContent:
              'Las cámaras de seguridad de serenazgo municipal, comercios o vecinos graban las pistas más importantes del recorrido de una persona.\n\n'
              'La Ley N° 30120 obliga a las municipalidades y comercios a preservar las grabaciones de videovigilancia ciudadana. '
              'Sin embargo, muchas cámaras sobreescriben sus grabaciones después de 24 a 48 horas. Por ello, solicitar su preservación en el día 1 es una de las diligencias más críticas.',
          audienceTip: '💡 Para jóvenes y adultos: Anota la hora y las esquinas exactas por donde caminaba la persona para que la policía y serenazgo revisen esas cámaras.',
          icon: Icons.videocam_rounded,
          trivia: MiniTrivia(
            question: '¿Por qué es urgente pedir la revisión de cámaras en las primeras 24 horas?',
            options: [
              'Porque muchas cámaras borran o sobreescriben sus videos automáticamente.',
              'Porque las cámaras solo funcionan los fines de semana.',
              'Porque los videos cambian de color con el tiempo.',
            ],
            correctOptionIndex: 0,
            feedbackExplanation:
                '¡Excelente! Muchos sistemas de videovigilancia borran las grabaciones pasados pocos días. La Ley 30120 respalda preservarlas con urgencia.',
          ),
        ),
      ],
    ),

    // RAMA 2: Alerta Amber y Protocolos Oficiales
    LearningBranch(
      id: 2,
      title: 'Alerta Amber en el Perú',
      subtitle: 'Activación inmediata, menores de edad y personas vulnerables',
      iconEmoji: '🔴',
      iconData: Icons.notifications_active_rounded,
      color: Color(0xFFDC2626), // Rojo alerta
      overviewExplanation:
          'La Alerta Amber es el sistema de máxima difusión de emergencia en el Perú para encontrar a niñas, niños y adolescentes en peligro inminente. Descubre cómo funciona, sus últimas actualizaciones legales y su alcance masivo.',
      subtopics: [
        LearningSubtopic(
          id: '2_1',
          title: '¿Qué es la Alerta Amber y cuánto dura?',
          shortDescription: 'Difusión masiva en TV, radio y redes durante 72 horas clave.',
          fullContent:
              'La Alerta Amber Perú es una alerta roja de máxima prioridad. Se activa para difundir de forma masiva y urgente el rostro y datos de una persona vulnerable desaparecida.\n\n'
              'Durante un periodo de hasta 72 horas, la alerta se transmite en medios de comunicación (radio y televisión), '
              'pantallas en aeropuertos y terminales terrestres, redes sociales institucionales y sistemas de mensajería.',
          audienceTip: '📢 Para todos: Cuando veas una Alerta Amber en tu celular o TV, tómate 10 segundos para memorizar el rostro y mirar a tu alrededor.',
          icon: Icons.campaign_rounded,
          trivia: MiniTrivia(
            question: '¿Cuál es la duración máxima de difusión intensiva de una Alerta Amber?',
            options: [
              '12 horas.',
              'Hasta 72 horas.',
              '30 días continuos.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Correcto! La Alerta Amber despliega su máxima intensidad de difusión durante las primeras 72 horas de activación.',
          ),
          video: EducationalVideo(
            id: 'alerta_amber',
            title: 'Alerta Amber Perú',
            subtitle: 'Sistema de alerta temprana y búsqueda urgente',
            description:
                'Conoce cómo funciona el sistema de Alerta Amber en el Perú y cómo se articulan los medios y la ciudadanía ante menores en peligro.',
            thumbnailUrl: 'assets/icons/llamada_icon.png',
            videoUrl:
                'gs://alerta-desaparecidos-pnp.firebasestorage.app/recursos/videos/alerta_amber.mp4',
            duration: '5:15',
            orientation: VideoOrientation.vertical,
            category: VideoCategory.information,
            icon: Icons.warning_amber,
            color: Color(0xFFFF9800),
          ),
        ),
        LearningSubtopic(
          id: '2_2',
          title: 'Niños de 0 a 11 años: Activación directa',
          shortDescription: 'Regla especial del D.S. 010-2024-IN sin requisitos adicionales.',
          fullContent:
              'Gracias a la reforma del Decreto Supremo N° 010-2024-IN, para niñas y niños de 0 a 11 años la Alerta Amber se activa de forma DIRECTA.\n\n'
              'No es necesario probar que alguien se los llevó a la fuerza o que hay sospecha de delito grave. '
              'Basta con que el menor no sea ubicado y que la denuncia se siente dentro de las primeras 48 horas para que se dispare la Alerta Amber.',
          audienceTip: '👶 Para padres: Esta regla garantiza que ningún policía pueda dudar o demorar la emisión de la alerta en menores de 12 años.',
          icon: Icons.child_care_rounded,
          trivia: MiniTrivia(
            question: '¿Qué se necesita para activar la Alerta Amber en niños de 0 a 11 años según la ley peruana?',
            options: [
              'Demostrar que hubo testigos de un secuestro violento.',
              'Solo comprobar la edad y asentar la denuncia dentro de las 48 horas.',
              'Pagar una fianza administrativa al juzgado.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Así es! Para menores de 0 a 11 años la ley no exige supuestos adicionales; la protección es prioritaria e inmediata.',
          ),
        ),
        LearningSubtopic(
          id: '2_3',
          title: 'Personas con Autismo, TEA o discapacidad',
          shortDescription: 'Inclusión prioritaria según el Decreto Supremo N° 004-2026-IN.',
          fullContent:
              'Las personas dentro del Trastorno del Espectro Autista (TEA), con discapacidad intelectual o psicosocial requieren una búsqueda especializada.\n\n'
              'Pueden desorientarse con facilidad, no responder a su nombre si hay mucho ruido, o asustarse ante multitudes. '
              'La ley peruana contempla la activación inmediata de Alerta Amber para este grupo, activando cuadrantes de búsqueda silenciosa y paciente.',
          audienceTip: '🧩 Consejo empático: Si ves a una persona desorientada con autismo, no le grites ni lo toques bruscamente. Habla con calma y en tono suave.',
          icon: Icons.accessibility_new_rounded,
          trivia: MiniTrivia(
            question: '¿La Alerta Amber ampara a personas con Trastorno del Espectro Autista (TEA)?',
            options: [
              'No, solo aplica para adultos sanos.',
              'Sí, la ley peruana los protege como grupo prioritario de alta vulnerabilidad.',
              'Solo si tienen más de 30 años.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Excelente! La normativa vigente incluye expresamente a personas con TEA y discapacidad como prioridad absoluta.',
          ),
        ),
        LearningSubtopic(
          id: '2_4',
          title: 'Mensajes SISMATE y difusión masiva',
          shortDescription: 'Cómo la tecnología móvil avisa a miles de ciudadanos en segundos.',
          fullContent:
              'El Sistema de Mensajería de Alerta Temprana (SISMATE) permite enviar mensajes sonoros y de texto directos a los celulares de una zona específica.\n\n'
              'En casos graves de Alerta Amber, las autoridades pueden coordinar la emisión de alertas geolocalizadas '
              'para que todas las personas en un distrito o terminal de buses reciban la descripción del menor en sus teléfonos.',
          audienceTip: '📲 Para jóvenes: Si recibes una alerta SISMATE, compártela en tus grupos de WhatsApp de vecinos o del barrio.',
          icon: Icons.cell_tower_rounded,
          trivia: MiniTrivia(
            question: '¿Qué ventaja tiene el sistema de mensajería SISMATE ante una desaparición?',
            options: [
              'Descarga juegos gratis a los teléfonos.',
              'Llega a miles de celulares de la zona de inmediato sin necesidad de saldo ni megas.',
              'Borra el historial de llamadas del desaparecido.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Exacto! El sistema SISMATE es una vía masiva que alerta a todos los celulares de un sector determinado en segundos.',
          ),
        ),
      ],
    ),

    // RAMA 3: Ciberseguridad y Peligros Digitales
    LearningBranch(
      id: 3,
      title: 'Ciberseguridad y Peligros Digitales',
      subtitle: 'Redes sociales, videojuegos, engaños y rastreo de celulares',
      iconEmoji: '📱',
      iconData: Icons.security_rounded,
      color: Color(0xFF6366F1), // Índigo moderno
      overviewExplanation:
          'Hoy en día, muchas desapariciones de adolescentes y jóvenes no empiezan en la calle, sino en una pantalla: mediante ofertas falsas de trabajo, regalos en videojuegos o falsas amistades. Aquí aprenderás a detectar trampas y blindar tu privacidad.',
      subtopics: [
        LearningSubtopic(
          id: '3_1',
          title: 'Trampas de trabajo falso en TikTok y Facebook',
          shortDescription: 'Sueldos increíbles y sesiones de modelaje que ocultan redes de trata.',
          fullContent:
              '¿Te ofrecieron ganar 500 soles al día solo por contestar mensajes o te citaron para un "casting de modelaje" en un hotel o local desconocido?\n\n'
              '¡Cuidado rojo! Este es el método número 1 de las mafias de trata de personas para captar jovencitas y jóvenes. '
              'Nunca acudas a entrevistas de trabajo en lugares privados o casas solas, y jamás vayas sin avisar a tus padres con la dirección exacta.',
          audienceTip: '⚠️ Para jóvenes: Si una oferta suena demasiado buena para ser verdad, es un engaño. Investiga el RUC de la empresa en SUNAT.',
          icon: Icons.work_off_rounded,
          trivia: MiniTrivia(
            question: '¿Cuál es una señal clara de una oferta laboral falsa en redes sociales?',
            options: [
              'Te piden enviar tu CV por correo corporativo y te entrevistan en una oficina conocida.',
              'Te ofrecen sueldos altísimos sin pedir experiencia y te citan a solas en una casa o cuarto.',
              'Te solicitan tu carnet de vacunación.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Muy bien! Las ofertas que prometen dinero fácil y citan en lugares privados o alejados son típicas trampas de captación ilegal.',
          ),
        ),
        LearningSubtopic(
          id: '3_2',
          title: 'Grooming en juegos: Free Fire, Roblox y Discord',
          shortDescription: 'Regalos de skins y diamantes a cambio de citas secretas o fotos.',
          fullContent:
              'En los videojuegos en línea, personas adultas malintencionadas se hacen pasar por niños o jóvenes de la misma edad.\n\n'
              'Ganan su confianza regalando pases de batalla, diamantes o skins, y luego piden fotos personales o proponen "encontrarse en un parque para jugar juntos". '
              'Esta técnica se llama Grooming. La regla de oro es: los amigos del juego se quedan en el juego; jamás compartas tu dirección ni aceptes salidas a solas.',
          audienceTip: '🎮 Para niños y niñas: Si alguien en un juego te pide guardar secretos de tus papás, ¡cuéntaselo a tus papás al instante!',
          icon: Icons.sports_esports_rounded,
          trivia: MiniTrivia(
            question: '¿Qué debes hacer si un jugador desconocido te ofrece diamantes a cambio de tu dirección?',
            options: [
              'Dársela rápido para conseguir los regalos.',
              'Bloquearlo inmediatamente y avisar a tus padres o tutor de confianza.',
              'Citarte con él en un parque solitario para agradecerle.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Excelente respuesta! Jamás des datos privados en videojuegos; bloquea al usuario y cuéntaselo a tus padres.',
          ),
        ),
        LearningSubtopic(
          id: '3_3',
          title: 'Huella del celular: El código IMEI y antenas',
          shortDescription: 'Cómo la policía puede ubicar un teléfono incluso si está apagado.',
          fullContent:
              'Todos los teléfonos tienen una identificación única de 15 dígitos llamada IMEI (consíguelo marcando *#06# y guárdalo en un papel).\n\n'
              'Bajo el Decreto Supremo N° 010-2024-IN (Art. 10-A), la policía puede solicitar a las operadoras telefónicas '
              'la geolocalización en tiempo real del número y del IMEI. Si el móvil está apagado, se informa el radio de la última antena que captó su señal.',
          audienceTip: '📱 Para todos: Apunta el código IMEI de todos los celulares de tu casa en una libreta de notas familiar hoy mismo.',
          icon: Icons.pin_drop_rounded,
          trivia: MiniTrivia(
            question: '¿Para qué sirve tener guardado el código IMEI del celular ante una desaparición?',
            options: [
              'Para que la policía solicite a las operadoras la geolocalización de la última antena conectada.',
              'Para comprar saldo gratis.',
              'Para cambiar el color de la pantalla.',
            ],
            correctOptionIndex: 0,
            feedbackExplanation:
                '¡Correcto! El código IMEI permite rastrear legalmente a través de las antenas telefónicas dónde estuvo el aparato por última vez.',
          ),
        ),
        LearningSubtopic(
          id: '3_4',
          title: 'Palabra clave familiar secreta contra extorsiones',
          shortDescription: 'Una palabra mágica entre padres e hijos para desenmascarar llamadas falsas.',
          fullContent:
              'Los delincuentes suelen usar grabaciones, inteligencia artificial o llantos fingidos para llamar a los padres diciendo: *"¡Mamá, me tienen secuestrado, deposita dinero ya!"*.\n\n'
              'Para evitar caer en el pánico, crea una "Palabra Secreta Familiar" (por ejemplo: "GalletaAzul" o "Toby12"). '
              'Si alguna vez reciben una llamada sospechosa, se le pregunta a la supuesta víctima esa palabra. Si no la sabe, es una estafa al 100%.',
          audienceTip: '🔐 Para toda la familia: Elijan hoy en el almuerzo una palabra secreta que solo ustedes conozcan y no la publiquen en internet.',
          icon: Icons.key_rounded,
          trivia: MiniTrivia(
            question: '¿Cuál es la función de una "palabra clave familiar secreta"?',
            options: [
              'Desbloquear canales de televisión.',
              'Verificar si una llamada de emergencia o presunto secuestro es real o una estafa.',
              'Conectarse al WiFi del vecino.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Así es! Si quien llama no sabe la palabra secreta de la familia, sabes al instante que se trata de un engaño de extorsionadores.',
          ),
        ),
      ],
    ),

    // RAMA 4: Cuidado de Niñas, Niños y Jóvenes
    LearningBranch(
      id: 4,
      title: 'Cuidado de Niñas, Niños y Jóvenes',
      subtitle: 'Técnicas de memoria, ruta escolar y qué hacer si te pierdes',
      iconEmoji: '🛡️',
      iconData: Icons.family_restroom_rounded,
      color: Color(0xFF059669), // Verde protector
      overviewExplanation:
          'La prevención se entrena en el día a día como un juego en familia. Enseñar a los más pequeños a reaccionar ante una desorientación y crear rutas seguras es la mejor armadura para proteger su camino.',
      subtopics: [
        LearningSubtopic(
          id: '4_1',
          title: 'Memorizar teléfonos con el juego de las rimas',
          shortDescription: 'Un juego musical para que niños desde 5 años recuerden números de papá y mamá.',
          fullContent:
              'Si un niño se extravía, lo primero que los rescatistas preguntan es: *"¿Te sabes el número de tu mamá o papá?"*.\n\n'
              'La forma más divertida de enseñarlo no es haciéndolos repetir aburridamente, sino dividiendo el número en rimas de 3 en 3 con una canción conocida: '
              'ejemplo *"9-8-1 (un rico atún), 4-5-2 (me dio la tos), 7-8-3 (un rico pez)"*. En pocos días lo sabrán de memoria para toda la vida.',
          audienceTip: '🎵 Para niños: Practica cantar el teléfono de mamá o papá jugando con tus juguetes o aplaudiendo.',
          icon: Icons.music_note_rounded,
          trivia: MiniTrivia(
            question: '¿Por qué es fundamental que un niño sepa de memoria el teléfono de sus padres?',
            options: [
              'Para llamar a pedir pizza.',
              'Porque si se desorienta, cualquier autoridad o mamá de confianza puede llamar a su familia de inmediato.',
              'Para jugar en la tablet.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Excelente! Un niño que sabe el teléfono de memoria puede ser reunido con sus padres en cuestión de minutos.',
          ),
        ),
        LearningSubtopic(
          id: '4_2',
          title: 'Qué hacer si me pierdo en un centro comercial o mercado',
          shortDescription: 'La regla del árbol quieto y cómo identificar personas seguras.',
          fullContent:
              'Si un niño se separa de sus padres en una multitud, suele cometer el error de correr en círculos buscando, lo que lo aleja más.\n\n'
              'Enséñale dos reglas de oro:\n'
              '1. "Sé como un árbol": Quédate quieto en el lugar donde te diste cuenta de que estás solo, cerca a una tienda iluminada.\n'
              '2. ¿A quién pedir auxilio?: A una persona de uniforme (seguridad, policía) o a otra mamá que esté caminando con sus propios hijos.',
          audienceTip: '🌳 Para niños: Si no ves a tus papás, ¡planta tus pies como un árbol! No salgas a la calle ni te vayas con personas solas.',
          icon: Icons.storefront_rounded,
          trivia: MiniTrivia(
            question: 'Si un niño se pierde en una tienda, ¿qué es lo más seguro que debe hacer?',
            options: [
              'Salir corriendo a la calle a buscar el carro de sus papás.',
              'Quedarse quieto en un lugar seguro y pedir ayuda a un guardia de uniforme o a una mamá con niños.',
              'Esconderse debajo de una caja oscura.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Perfecto! La regla del árbol (quedarse quieto) y acudir a personas de uniforme o mamás con hijos es la más segura y efectiva.',
          ),
        ),
        LearningSubtopic(
          id: '4_3',
          title: 'La Ruta Escolar Segura y refugios del barrio',
          shortDescription: 'Caminar en grupo y ubicar las "bodegas amigas" en el camino a casa.',
          fullContent:
              'El trayecto entre el colegio y la casa debe ser predecible. Es vital fijar con los hijos una ruta fija y evitar callejones oscuros o atajos desolados.\n\n'
              'Además, enseñemos el concepto de "Puntos de Refugio del Barrio": bodegas, farmacias o librerías conocidas de confianza '
              'a donde el escolar puede entrar si siente que alguien sospechoso lo está siguiendo o mirando.\n\n'
              '💡 Consejo Preventivo: Puedes activar el módulo "Ruta Segura" en el aplicativo para monitorear el regreso a casa en vivo.',
          audienceTip: '🎒 Para escolares: Nunca tomes atajos desconocidos por ahorrar 5 minutos. Camina siempre por avenidas transitadas y con amigos.',
          icon: Icons.school_rounded,
          relatedAppModuleTab: 5,
          relatedAppModuleLabel: 'Conocer Ruta Segura en Vivo',
          relatedAppModuleIcon: Icons.route_rounded,
          trivia: MiniTrivia(
            question: '¿Qué es una "bodega o tienda refugio" en la ruta escolar?',
            options: [
              'Un lugar donde comprar dulces baratos.',
              'Un comercio conocido del barrio donde un escolar puede entrar si siente miedo o sospecha que lo siguen.',
              'Un paradero de autos clandestinos.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Así es! Identificar comercios amigos en el camino da tranquilidad y un punto seguro de auxilio inmediato.',
          ),
          video: EducationalVideo(
            id: 'consejos_desaparicion',
            title: 'Consejos de Prevención y Seguridad',
            subtitle: 'Medidas preventivas esenciales en la vía pública',
            description:
                'Consejos prácticos y protocolos de seguridad para evitar situaciones de desorientación o peligro en niñas, niños y jóvenes.',
            thumbnailUrl: 'assets/icons/search_icon.png',
            videoUrl:
                'gs://alerta-desaparecidos-pnp.firebasestorage.app/recursos/videos/consejos_desaparicion.mp4',
            duration: '6:30',
            orientation: VideoOrientation.vertical,
            category: VideoCategory.prevention,
            icon: Icons.security,
            color: Color(0xFF9C27B0),
          ),
        ),
        LearningSubtopic(
          id: '4_4',
          title: 'Escucha activa antes de fugas por bullying o conflicto',
          shortDescription: 'Muchas ausencias adolescentes son gritos de auxilio evitables con diálogo.',
          fullContent:
              'Un gran porcentaje de reportes de adolescentes desaparecidos corresponden a salidas impulsivas de casa '
              'tras discusiones fuertes, miedo a bajas calificaciones o acoso escolar (bullying) que no supieron cómo expresar.\n\n'
              'Escuchar sin juzgar, crear un ambiente seguro donde equivocarse no signifique castigos violentos, '
              'y mantener los canales de confianza abiertos es la prevención más poderosa dentro del hogar.',
          audienceTip: '❤️ Para padres: Ante una mala nota o problema, empieza diciendo: *"Estoy contigo para solucionarlo juntos"*. El amor previene la soledad.',
          icon: Icons.record_voice_over_rounded,
          trivia: MiniTrivia(
            question: '¿Cómo pueden los padres prevenir que un adolescente decida irse de casa por miedo?',
            options: [
              'Quitándole la comida y gritándole.',
              'Fomentando la confianza, escuchando sus preocupaciones y asegurándole que los problemas tienen solución en familia.',
              'Ignorando lo que siente.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Gran respuesta! El diálogo comprensivo y el apoyo emocional son el mejor escudo protector para los jóvenes.',
          ),
        ),
      ],
    ),

    // RAMA 5: Adultos Mayores y Salud Mental
    LearningBranch(
      id: 5,
      title: 'Adultos Mayores y Salud Mental',
      subtitle: 'Alzheimer, desorientación y redes de cuidado vecinal',
      iconEmoji: '👵',
      iconData: Icons.elderly_rounded,
      color: Color(0xFFD97706), // Ámbar cálido
      overviewExplanation:
          'Nuestros abuelitos y personas con pérdida de memoria o demencia senil merecen un cuidado especial. Un paseo habitual a la tienda puede convertirse en desorientación en segundos. Conoce las medidas que los mantienen a salvo.',
      subtopics: [
        LearningSubtopic(
          id: '5_1',
          title: 'Identificación discreta en ropa y pulseras QR',
          shortDescription: 'El parche en la casaca o accesorio que habla por ellos si olvidan su dirección.',
          fullContent:
              'Una persona mayor con Alzheimer puede olvidar de pronto su nombre, dónde vive o cómo regresar.\n\n'
              'Una medida muy sencilla y de gran amor es coser una etiqueta discreta dentro de sus casacas o chalecos con su nombre y el número de contacto de un familiar, '
              'o colocarles una pulsera con código QR o medalla grabada. Si alguien los encuentra desorientados, podrá llamar a sus hijos en segundos.\n\n'
              '💡 Consejo Preventivo: Genera su carnet preventivo en PDF con código QR desde el módulo "Mi Familia Segura".',
          audienceTip: '🧵 Consejo práctico: Revisa que la etiqueta no quede visible hacia desconocidos en la calle, sino en la solapa interior de la prenda.',
          icon: Icons.badge_rounded,
          relatedAppModuleTab: 4,
          relatedAppModuleLabel: 'Crear Carnet QR en Mi Familia Segura',
          relatedAppModuleIcon: Icons.badge_rounded,
          trivia: MiniTrivia(
            question: '¿Por qué ayuda coser una etiqueta con número telefónico en la ropa de un adulto mayor?',
            options: [
              'Para que la ropa no se confunda en la lavandería.',
              'Para que quien lo encuentre desorientado pueda comunicarse con su familia al instante.',
              'Para que la prenda cueste más dinero.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Excelente! Esa pequeña etiqueta ha permitido que cientos de adultos mayores regresen a casa el mismo día.',
          ),
        ),
        LearningSubtopic(
          id: '5_2',
          title: 'Salidas seguras y prevención en Alzheimer',
          shortDescription: 'Acompañamiento, rutinas y avisos en cobro de pensión.',
          fullContent:
              'Los días de cobro de pensión en bancos o visitas a postas médicas son momentos de alta vulnerabilidad.\n\n'
              'Procura que nunca salgan solos a cobrar dinero o trámites complicados. '
              'Si tienen costumbre de salir a caminar al parque, fija horarios regulares y dales un reloj sencillo o celular con teclas grandes configurado con marcado rápido.',
          audienceTip: '👴 Con cariño: No les quitemos su independencia con regaños; acompañémoslos como un paseo compartido.',
          icon: Icons.directions_walk_rounded,
          trivia: MiniTrivia(
            question: '¿Cuál es una medida adecuada cuando un adulto mayor con principio de desorientación desea salir a caminar?',
            options: [
              'Encerrarlo con llave todo el día.',
              'Acompañarlo afectuosamente o mantener paseos en rutas conocidas y con horarios definidos.',
              'Dejarlo salir solo a otra ciudad.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Correcto! El acompañamiento con afecto preserva su salud mental y garantiza su seguridad física en todo momento.',
          ),
        ),
        LearningSubtopic(
          id: '5_3',
          title: 'Protocolo de búsqueda comunitaria barrial',
          shortDescription: 'Lugares que frecuentan: parques, paraderos antiguos y templos.',
          fullContent:
              'Cuando un abuelito no regresa, su memoria suele guiarlo hacia lugares del pasado: el barrio donde vivió de joven, '
              'su antiguo centro de trabajo, la iglesia que visitaba o la estación de tren/bus de sus rutinas de hace 20 años.\n\n'
              'Al iniciar la búsqueda, además de denunciar, revisa de inmediato esos sitios nostálgicos y hospitales cercanos.',
          audienceTip: '🗺️ Para la familia: Haz una lista previa de los lugares favoritos o antiguos del adulto mayor para saber por dónde empezar.',
          icon: Icons.map_rounded,
          trivia: MiniTrivia(
            question: '¿Hacia qué lugares suele dirigirse con frecuencia una persona con pérdida de memoria que se desorienta?',
            options: [
              'A lugares nuevos y discotecas modernas.',
              'A lugares significativos de su pasado: iglesias, antiguos trabajos o barrios de juventud.',
              'A aeropuertos internacionales para viajar.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Así es! La memoria remota permanece activa, por lo que suelen caminar hacia sitios que frecuentaban años atrás.',
          ),
        ),
        LearningSubtopic(
          id: '5_4',
          title: 'Red de apoyo con bodegueros y vecinos',
          shortDescription: 'Los vecinos son los ojos protectores de tu cuadra.',
          fullContent:
              'El bodeguero de la esquina, el vigilante de la cuadra y los vecinos del barrio conocen a las familias.\n\n'
              'Presenta a tu abuelito con ellos y déjales tu número: *"Don José, si ve a mi papá caminando solo hacia la avenida principal, por favor llámeme de inmediato"*. '
              'La solidaridad vecinal es la red de alarma más rápida que existe.',
          audienceTip: '🤝 Para todos: La seguridad ciudadana se construye saludando y conversando con los vecinos de tu calle.',
          icon: Icons.handshake_rounded,
          trivia: MiniTrivia(
            question: '¿Cómo pueden los bodegueros y comerciantes del barrio ayudar a cuidar a los abuelitos?',
            options: [
              'Cobrándoles el doble por sus compras.',
              'Avisando a la familia si los ven caminando desorientados o solos hacia zonas peligrosas.',
              'Cerrando sus puertas cuando los ven pasar.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Muy bien! Los comerciantes locales son aliados de oro para la protección comunitaria en cada cuadra.',
          ),
        ),
      ],
    ),

    // RAMA 6: Difusión Responsable en Redes
    LearningBranch(
      id: 6,
      title: 'Difusión Responsable en Redes',
      subtitle: 'Afiches oficiales, evitar extorsiones y cuidar la dignidad',
      iconEmoji: '📢',
      iconData: Icons.share_rounded,
      color: Color(0xFF0284C7), // Azul cívico
      overviewExplanation:
          'Compartir en redes sociales puede ser una bendición para ubicar a alguien o una pesadilla si se hace mal. Aprende a crear y compartir afiches sin exponer a tu familia a delincuentes ni revictimizar a la persona.',
      subtopics: [
        LearningSubtopic(
          id: '6_1',
          title: 'El peligro de poner teléfonos personales en afiches',
          shortDescription: 'Por qué los delincuentes buscan afiches con celulares privados.',
          fullContent:
              'Cuando una familia desesperada coloca su número personal en una imagen pública de Facebook o TikTok, '
              'mafias penitenciarias y estafadores empiezan a llamar a los 20 minutos diciendo: *"Tengo a tu hija, deposita 2,000 soles a esta cuenta bancaria o no la ves más"*.\n\n'
              'En el 99% de los casos, esos delincuentes no tienen a la persona; solo vieron el afiche en internet. '
              'Por tu paz y seguridad, canaliza las llamadas únicamente a través del número oficial: Línea 114 de la PNP.',
          audienceTip: '🛡️ Consejo de oro: Si ya publicaste tu número y recibes amenazas de dinero, no deposites nada y denúncialo de inmediato a la policía.',
          icon: Icons.phonelink_erase_rounded,
          trivia: MiniTrivia(
            question: '¿Qué buscan las personas inescrupulosas que llaman a los números personales vistos en afiches de redes?',
            options: [
              'Entregar a la persona con amabilidad.',
              'Aprovechar la desesperación familiar para cobrar rescates falsos mediante engaños.',
              'Ofrecer empleo digno a la familia.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Exacto! Son extorsiones falsas aprovechándose de la vulnerabilidad. Nunca hagas depósitos apresurados.',
          ),
        ),
        LearningSubtopic(
          id: '6_2',
          title: 'Uso exclusivo de la Línea 114 y afiches validados',
          shortDescription: 'La Nota de Alerta oficial emitida por el sistema policial.',
          fullContent:
              'Cuando sientas la denuncia, la policía genera una Nota de Alerta oficial con el código SIDPOL/SIRDIC. '
              'Esa ficha contiene el membrete oficial del Estado Peruano y el número central 114 para recibir datos confidenciales.\n\n'
              'Ese afiche oficial es el que debes viralizar, ya que genera confianza y cualquier ciudadano con información verídica sabrá que llamará a detectives capacitados.\n\n'
              '💡 Consejo Preventivo: En el módulo "Central de Auxilio 360°" puedes consultar números de guardia oficiales y comisarías por GPS.',
          audienceTip: '📋 Para todos: La emisión de la Nota de Alerta oficial y su entrega impresa o digital es 100% gratuita.',
          icon: Icons.verified_rounded,
          relatedAppModuleTab: 6,
          relatedAppModuleLabel: 'Abrir Central de Auxilio y Comisarías',
          relatedAppModuleIcon: Icons.contact_phone_rounded,
          trivia: MiniTrivia(
            question: '¿Qué número oficial gratuito de asistencia debe figurar en los afiches de búsqueda en el Perú?',
            options: [
              'El teléfono de un banco privado.',
              'La Línea 114 de la Policía Nacional del Perú (gratuita las 24 horas).',
              'El número de una radio de música.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Excelente! La Línea 114 es el canal nacional oficial, gratuito y permanente para personas desaparecidas.',
          ),
        ),
        LearningSubtopic(
          id: '6_3',
          title: 'Cómo retirar los afiches cuando la persona aparece',
          shortDescription: 'Cuidar la intimidad y salud mental post-hallazgo.',
          fullContent:
              'Una vez que la persona es encontrada con bien, la labor solidaria no termina: ¡hay que retirar las publicaciones!\n\n'
              'Dejar la foto de una niña, joven o adulto circulando eternamente en internet como "desaparecido" afecta su dignidad, '
              'su vida escolar, laboral y psicológica. Publica un mensaje de agradecimiento cerrando el caso y elimina las fotos compartidas.',
          audienceTip: '🌱 Para la comunidad: Si compartiste un afiche en tu muro y la persona ya apareció, bórralo o actualízalo como ¡ENCONTRADO(A)!',
          icon: Icons.delete_sweep_rounded,
          relatedAppModuleTab: 2,
          relatedAppModuleLabel: 'Ver Personas Encontradas',
          relatedAppModuleIcon: Icons.verified_rounded,
          trivia: MiniTrivia(
            question: '¿Por qué es importante eliminar o actualizar los afiches una vez que la persona fue hallada?',
            options: [
              'Para liberar espacio en el disco duro de las redes.',
              'Para proteger la intimidad, reputación y bienestar emocional de la persona encontrada.',
              'Porque la policía cobra una multa si queda en Facebook.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Correcto! Proteger la privacidad y la salud mental de quien regresa a casa es un deber de respeto cívico.',
          ),
        ),
        LearningSubtopic(
          id: '6_4',
          title: 'Detectar noticias falsas y evitar el pánico colectivo',
          shortDescription: 'Audios alarmistas de WhatsApp: verifica antes de reenviar.',
          fullContent:
              'Con frecuencia circulan audios reenviados mil veces que dicen: *"¡Una camioneta blanca está secuestrando niños en tal colegio, avisen a todos!"*.\n\n'
              'El 99% de estas cadenas son bulos (Fake News) que generan histeria y bloquean las líneas de emergencia. '
              'Antes de reenviar un audio o foto alarmista, corrobora si proviene de una cuenta oficial de la PNP o medios serios. No seas cómplice del pánico.',
          audienceTip: '🔍 Para jóvenes y adultos: Si un mensaje dice "Reenvíalo a todos tus contactos urgente", duda de inmediato.',
          icon: Icons.fact_check_rounded,
          trivia: MiniTrivia(
            question: '¿Qué debes hacer al recibir una cadena de audio sobre presuntos secuestros masivos sin autor identificado?',
            options: [
              'Reenviarla a todos tus grupos para asustar a tus vecinos.',
              'Verificar en fuentes oficiales y no reenviarla si no está confirmada por la PNP.',
              'Llamar al 105 para insultar a la operadora.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Perfecto! Verificar la información antes de compartir frena el pánico y cuida la salud mental de la comunidad.',
          ),
        ),
      ],
    ),

    // RAMA 7: Soporte Emocional y Retorno a Casa
    LearningBranch(
      id: 7,
      title: 'Soporte Emocional y Retorno a Casa',
      subtitle: 'Primeros auxilios psicológicos y cómo recibir a quien vuelve',
      iconEmoji: '🤝',
      iconData: Icons.favorite_rounded,
      color: Color(0xFF8B5CF6), // Violeta empático y sanador
      overviewExplanation:
          'La desaparición de un ser querido genera una de las angustias más intensas del ser humano. Aprender a sostener la mente en calma para tomar buenas decisiones, y saber cómo abrazar y sanar cuando la persona regresa, completa el círculo de protección.',
      subtopics: [
        LearningSubtopic(
          id: '7_1',
          title: 'Calmar la mente en las primeras horas críticas',
          shortDescription: 'Técnicas de respiración para evitar paralizarse por la angustia.',
          fullContent:
              'El pánico paraliza o hace tomar decisiones impulsivas que complican la búsqueda. '
              'Cuando sientas que el pecho se cierra por la incertidumbre, aplica la regla 4x4: inhala en 4 segundos, mantén 4 segundos, exhala en 4 segundos y espera 4 segundos.\n\n'
              'Designa roles en la familia: una persona se encarga de las llamadas con la policía, otra de revisar fotos y ropa, y otra de cuidar a los niños pequeños.',
          audienceTip: '🧘 Para todos: La calma no significa falta de amor; significa lucidez para buscar mejor.',
          icon: Icons.spa_rounded,
          trivia: MiniTrivia(
            question: '¿Por qué ayuda organizarse y mantener la serenidad durante las primeras horas de búsqueda?',
            options: [
              'Porque permite pensar con claridad, coordinar con la policía y no caer en trampas de estafadores.',
              'Porque así se gasta menos batería del teléfono.',
              'Porque a la policía no le gusta la gente triste.',
            ],
            correctOptionIndex: 0,
            feedbackExplanation:
                '¡Muy bien! Una mente tranquila y organizada toma mejores decisiones y actúa con mucha mayor eficacia.',
          ),
        ),
        LearningSubtopic(
          id: '7_2',
          title: 'Recibimiento en casa: Abrazo sin juzgar',
          shortDescription: 'Por qué los gritos y reproches al volver provocan nuevas fugas.',
          fullContent:
              'Cuando una persona desaparecida regresa a casa, el instinto de muchos familiares furiosos por el susto es gritar: *"¿Dónde estabas? ¡Mira lo que nos hiciste pasar!"*.\n\n'
              '¡Error gravísimo! La persona puede haber sido víctima de un delito grave, estar en shock o con miedo. '
              'El primer paso debe ser un abrazo contenedor: *"Qué alivio que estés aquí, estás a salvo"*, seguido de una revisión médica y psicológica.',
          audienceTip: '🫂 Para padres: Primero asegúrate de su salud y hazlo sentir amado. Habrá tiempo después para conversar con calma.',
          icon: Icons.volunteer_activism_rounded,
          trivia: MiniTrivia(
            question: '¿Cuál debe ser la primera reacción al reencontrarse con un familiar que estuvo desaparecido?',
            options: [
              'Gritarle, insultarlo y castigarlo en la puerta de la casa.',
              'Brindarle un abrazo seguro, verificar su estado de salud físico y emocional y hacerlo sentir a salvo.',
              'Llamar a los vecinos para hacerle un juicio popular.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Excelente! La contención emocional y la revisión de su estado de salud son prioritarias para su recuperación.',
          ),
        ),
        LearningSubtopic(
          id: '7_3',
          title: 'Apoyo gratuito del CEM y psicólogos del MIMP',
          shortDescription: 'Centros Emergencia Mujer y Unidades de Protección Especial.',
          fullContent:
              'En el Perú, el Ministerio de la Mujer y Poblaciones Vulnerables (MIMP) cuenta con los Centros Emergencia Mujer (CEM) '
              'y la Línea 100, con abogados, trabajadoras sociales y psicólogos especializados.\n\n'
              'Si la persona desaparecida sufrió violencia, acoso o fue víctima de captación, la atención psicológica y legal es '
              'completamente GRATUITA. Nunca estás solo en el proceso de sanación.',
          audienceTip: '👩‍⚕️ Para todos: Llamar a la Línea 100 es gratuito desde cualquier teléfono fijo o celular en todo el país.',
          icon: Icons.support_agent_rounded,
          relatedAppModuleTab: 6,
          relatedAppModuleLabel: 'Directorio CEM en Central 360°',
          relatedAppModuleIcon: Icons.favorite_rounded,
          trivia: MiniTrivia(
            question: '¿Qué servicios gratuitos brinda el Centro Emergencia Mujer (CEM) o la Línea 100?',
            options: [
              'Venta de boletos de viaje.',
              'Apoyo legal, psicológico y social gratuito para víctimas y sus familias.',
              'Préstamos de dinero para compras.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Así es! El CEM brinda respaldo profesional interdisciplinario gratuito a las familias en todo el territorio nacional.',
          ),
        ),
        LearningSubtopic(
          id: '7_4',
          title: 'Plan familiar de resiliencia post-hallazgo',
          shortDescription: 'Reconstruir la armonía y acuerdos para un hogar más seguro.',
          fullContent:
              'Tras superar la tormenta de una desaparición, la familia debe reunirse para sanar las raíces que provocaron el hecho.\n\n'
              'Establecer nuevos pactos de convivencia, mejorar los horarios de regreso, '
              'fortalecer la confianza y buscar ayuda profesional si hubo traumas permite que el hogar salga fortalecido y mucho más unido.',
          audienceTip: '🏡 Para toda la familia: Cada dificultad superada juntos es una oportunidad para aprender a cuidarse mejor.',
          icon: Icons.home_rounded,
          trivia: MiniTrivia(
            question: '¿Cuál es el objetivo de un plan de resiliencia familiar tras un caso de desaparición?',
            options: [
              'Vender la casa e irse a otro país.',
              'Sanar las causas profundas, fortalecer la comunicación y evitar que se repita una situación de riesgo.',
              'Olvidar todo y no volver a hablar del tema nunca más.',
            ],
            correctOptionIndex: 1,
            feedbackExplanation:
                '¡Maravilloso! El aprendizaje y la comunicación asertiva transforman las crisis en protección duradera.',
          ),
          video: EducationalVideo(
            id: 'consejos_desaparicion2',
            title: 'Consejos Avanzados de Seguridad',
            subtitle: 'Estrategias de seguridad familiar y protocolos',
            description:
                'Estrategias avanzadas de seguridad familiar, prevención y protocolos de comunicación para mantener protegidos a los seres queridos.',
            thumbnailUrl: 'assets/icons/profile_icon.png',
            videoUrl:
                'gs://alerta-desaparecidos-pnp.firebasestorage.app/recursos/videos/consejos_desaparicion2.mp4',
            duration: '7:45',
            orientation: VideoOrientation.vertical,
            category: VideoCategory.prevention,
            icon: Icons.family_restroom,
            color: Color(0xFF607D8B),
          ),
        ),
      ],
    ),
  ];

  /// Obtiene una rama por su ID
  static LearningBranch? getBranchById(int id) {
    try {
      return branches.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Obtiene un subtema por su ID (ej. '1_1')
  static LearningSubtopic? getSubtopicById(String id) {
    for (final branch in branches) {
      for (final sub in branch.subtopics) {
        if (sub.id == id) return sub;
      }
    }
    return null;
  }

  /// Encuentra el siguiente subtema en el camino de aprendizaje
  static LearningSubtopic? getNextSubtopic(String currentSubtopicId) {
    final allSubtopics = <LearningSubtopic>[];
    for (final b in branches) {
      allSubtopics.addAll(b.subtopics);
    }
    final index = allSubtopics.indexWhere((s) => s.id == currentSubtopicId);
    if (index >= 0 && index < allSubtopics.length - 1) {
      return allSubtopics[index + 1];
    }
    return null;
  }

  /// Encuentra el subtema anterior en el camino de aprendizaje
  static LearningSubtopic? getPreviousSubtopic(String currentSubtopicId) {
    final allSubtopics = <LearningSubtopic>[];
    for (final b in branches) {
      allSubtopics.addAll(b.subtopics);
    }
    final index = allSubtopics.indexWhere((s) => s.id == currentSubtopicId);
    if (index > 0) {
      return allSubtopics[index - 1];
    }
    return null;
  }

  /// Retorna el índice 1-based del subtema dentro de su rama (ej. 2 de 4)
  static int getSubtopicIndexInBranch(String subtopicId) {
    for (final b in branches) {
      final idx = b.subtopics.indexWhere((s) => s.id == subtopicId);
      if (idx >= 0) return idx + 1;
    }
    return 1;
  }

  /// Encuentra la rama correspondiente a un subtema
  static LearningBranch? getBranchForSubtopic(String subtopicId) {
    for (final b in branches) {
      for (final s in b.subtopics) {
        if (s.id == subtopicId) return b;
      }
    }
    return null;
  }

  /// Total de subtemas en el catálogo (7 x 4 = 28)
  static int get totalSubtopicsCount => branches.fold(0, (acc, b) => acc + b.subtopics.length);

  /// Obtiene todos los subtemas que cuentan con video educativo oficial PNP
  static List<LearningSubtopic> get subtopicsWithVideo {
    final list = <LearningSubtopic>[];
    for (final b in branches) {
      for (final s in b.subtopics) {
        if (s.hasVideo) list.add(s);
      }
    }
    return list;
  }
}
