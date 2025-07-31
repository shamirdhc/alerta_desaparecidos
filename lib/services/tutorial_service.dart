import '../domain/entities/tutorial.dart';

class TutorialService {
  static final TutorialService _instance = TutorialService._internal();
  factory TutorialService() => _instance;
  TutorialService._internal();

  List<Tutorial> getAllTutorials() {
    return [
      Tutorial(
        id: 'protocolo_desaparecidos_ds002',
        title: 'Protocolo Interinstitucional DS 002-2020',
        description: 'Decreto Supremo que establece el protocolo oficial para la búsqueda de personas desaparecidas. Procedimientos obligatorios para todo el personal PNP.',
        fileName: 'DS 002-2020 PROTOCOLO INTERINSTITUCIONAL PARA PERSONAS DESAPARECIDAS.pdf',
        category: 'Decretos Supremos',
        iconName: 'gavel',
        lastUpdated: DateTime(2020, 3, 15),
        estimatedReadTime: 45,
        tags: ['protocolo', 'interinstitucional', 'búsqueda', 'legal'],
        isRequired: true,
        priority: 1,
      ),
      Tutorial(
        id: 'protocolo_actualizado_ds010',
        title: 'Protocolo Actualizado DS 010-2024-IN',
        description: 'Última actualización del protocolo de atención con nuevos procedimientos y directivas operativas para casos de desaparición.',
        fileName: 'DS-010-2024-IN PROTOCOLO.pdf',
        category: 'Decretos Supremos',
        iconName: 'update',
        lastUpdated: DateTime(2024, 1, 10),
        estimatedReadTime: 35,
        tags: ['protocolo', 'actualización', '2024', 'normativa'],
        isRequired: true,
        priority: 1,
      ),
      Tutorial(
        id: 'alerta_emergencia_mujeres',
        title: 'Activación Alerta de Emergencia - Mujeres',
        description: 'Procedimientos específicos para activación inmediata de alertas en casos críticos de mujeres desaparecidas. Protocolo de respuesta rápida.',
        fileName: 'activacion_alerta_emergencia_mujeres.pdf',
        category: 'Procedimientos Críticos',
        iconName: 'warning',
        lastUpdated: DateTime(2023, 8, 20),
        estimatedReadTime: 25,
        tags: ['alerta', 'emergencia', 'mujeres', 'crítico'],
        isRequired: true,
        priority: 1,
      ),
      Tutorial(
        id: 'manual_sirdic',
        title: 'Manual Operativo SIRDIC',
        description: 'Guía técnica para el registro correcto de casos en el Sistema de Registro de Desaparecidos. Incluye códigos y clasificaciones.',
        fileName: 'manual_registro_desaparecidos_sirdic.pdf',
        category: 'Manuales Técnicos',
        iconName: 'computer',
        lastUpdated: DateTime(2023, 11, 5),
        estimatedReadTime: 60,
        tags: ['sirdic', 'registro', 'sistema', 'técnico'],
        isRequired: false,
        priority: 2,
      ),
      Tutorial(
        id: 'protocolo_atencion_general',
        title: 'Protocolo General de Atención',
        description: 'Procedimientos estándar para la atención inicial de casos de personas desaparecidas. Incluye entrevistas y primeras diligencias.',
        fileName: 'protocolo_atencion_personas_desaparecidas.pdf',
        category: 'Protocolos Generales',
        iconName: 'people',
        lastUpdated: DateTime(2023, 6, 12),
        estimatedReadTime: 40,
        tags: ['protocolo', 'atención', 'procedimientos', 'general'],
        isRequired: false,
        priority: 2,
      ),
    ];
  }

  Tutorial? getTutorialById(String id) {
    try {
      return getAllTutorials().firstWhere((tutorial) => tutorial.id == id);
    } catch (e) {
      return null;
    }
  }
}