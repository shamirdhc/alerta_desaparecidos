// lib/domain/enums.dart

enum MissingFilter { active, all }

enum EstadoDesaparecido {
  activo,
  encontrado,
  // Puedes añadir otros estados si los necesitas, por ejemplo:
  // archivado,
  // en investigación,
}

enum SortOption {
  newest,    // Más recientes
  oldest,    // Más antiguos
  priority,  // Por prioridad
  alphabetical, // Alfabético
}
