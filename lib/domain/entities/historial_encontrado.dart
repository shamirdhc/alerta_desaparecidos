class HistorialEncontrado {
  final String id;
  final String desaparecidoId;
  final String desaparecidoNombre;
  final String desaparecidoDni;
  final String policiaId;
  final String policiaNombre;
  final String policiaRango;
  final String policiaDepartamento;
  final DateTime fechaAccion;
  final String detallesHallazgo;
  final String ubicacionHallazgo;
  final DateTime fechaCreacion;

  const HistorialEncontrado({
    required this.id,
    required this.desaparecidoId,
    required this.desaparecidoNombre,
    required this.desaparecidoDni,
    required this.policiaId,
    required this.policiaNombre,
    required this.policiaRango,
    required this.policiaDepartamento,
    required this.fechaAccion,
    required this.detallesHallazgo,
    required this.ubicacionHallazgo,
    required this.fechaCreacion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'desaparecidoId': desaparecidoId,
      'desaparecidoNombre': desaparecidoNombre,
      'desaparecidoDni': desaparecidoDni,
      'policiaId': policiaId,
      'policiaNombre': policiaNombre,
      'policiaRango': policiaRango,
      'policiaDepartamento': policiaDepartamento,
      'fechaAccion': fechaAccion.toIso8601String(),
      'detallesHallazgo': detallesHallazgo,
      'ubicacionHallazgo': ubicacionHallazgo,
      'fechaCreacion': fechaCreacion.toIso8601String(),
    };
  }

  factory HistorialEncontrado.fromMap(Map<String, dynamic> map) {
    return HistorialEncontrado(
      id: map['id'] ?? '',
      desaparecidoId: map['desaparecidoId'] ?? '',
      desaparecidoNombre: map['desaparecidoNombre'] ?? '',
      desaparecidoDni: map['desaparecidoDni'] ?? '',
      policiaId: map['policiaId'] ?? '',
      policiaNombre: map['policiaNombre'] ?? '',
      policiaRango: map['policiaRango'] ?? '',
      policiaDepartamento: map['policiaDepartamento'] ?? '',
      fechaAccion: DateTime.parse(map['fechaAccion']),
      detallesHallazgo: map['detallesHallazgo'] ?? '',
      ubicacionHallazgo: map['ubicacionHallazgo'] ?? '',
      fechaCreacion: DateTime.parse(map['fechaCreacion']),
    );
  }

  HistorialEncontrado copyWith({
    String? id,
    String? desaparecidoId,
    String? desaparecidoNombre,
    String? desaparecidoDni,
    String? policiaId,
    String? policiaNombre,
    String? policiaRango,
    String? policiaDepartamento,
    DateTime? fechaAccion,
    String? detallesHallazgo,
    String? ubicacionHallazgo,
    DateTime? fechaCreacion,
  }) {
    return HistorialEncontrado(
      id: id ?? this.id,
      desaparecidoId: desaparecidoId ?? this.desaparecidoId,
      desaparecidoNombre: desaparecidoNombre ?? this.desaparecidoNombre,
      desaparecidoDni: desaparecidoDni ?? this.desaparecidoDni,
      policiaId: policiaId ?? this.policiaId,
      policiaNombre: policiaNombre ?? this.policiaNombre,
      policiaRango: policiaRango ?? this.policiaRango,
      policiaDepartamento: policiaDepartamento ?? this.policiaDepartamento,
      fechaAccion: fechaAccion ?? this.fechaAccion,
      detallesHallazgo: detallesHallazgo ?? this.detallesHallazgo,
      ubicacionHallazgo: ubicacionHallazgo ?? this.ubicacionHallazgo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  @override
  String toString() {
    return 'HistorialEncontrado(id: $id, desaparecidoNombre: $desaparecidoNombre, policiaNombre: $policiaNombre, fechaAccion: $fechaAccion)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HistorialEncontrado && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}