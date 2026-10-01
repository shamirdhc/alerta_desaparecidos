import 'package:flutter/material.dart';

/// Orientación de reproducción recomendada para el video didáctico
enum VideoOrientation { vertical, horizontal }

/// Categoría del video didáctico institucional
enum VideoCategory { prevention, information }

/// Modelo oficial de video educativo para la academia ciudadana
class EducationalVideo {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String thumbnailUrl;
  final String videoUrl;
  final String duration;
  final VideoOrientation orientation;
  final VideoCategory category;
  final IconData icon;
  final Color color;

  const EducationalVideo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.duration,
    required this.orientation,
    required this.category,
    required this.icon,
    required this.color,
  });

  /// Determina si el video está alojado en Firebase Storage
  bool get isFirebaseStorage => videoUrl.startsWith('gs://');

  /// Texto legible de la orientación para el usuario
  String get orientationLabel => orientation == VideoOrientation.vertical ? 'Móvil' : 'Panorámico';

  /// Icono asociado a la orientación
  IconData get orientationIcon =>
      orientation == VideoOrientation.vertical ? Icons.smartphone_rounded : Icons.desktop_windows_rounded;

  /// Categoría en texto amigable
  String get categoryLabel => category == VideoCategory.prevention ? 'Prevención' : 'Procedimientos';
}
