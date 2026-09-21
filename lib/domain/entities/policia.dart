class Policia {
  final String uid;
  final String nombre;
  final String apellido;
  final String telefono;
  final String departamento;
  final String unidad;
  final String rango;
  final String numeroCip;
  final String rol;
  final bool admin;
  final DateTime fechaRegistro;
  final String? tipoUnidad; // 'DEPITPTIM' | 'COMISARIA'
  final String? depitptimPadreId;
  final String? depitptimPadreNombre;

  const Policia({
    required this.uid,
    required this.nombre,
    required this.apellido,
    required this.telefono,
    required this.departamento,
    required this.unidad,
    required this.rango,
    required this.numeroCip,
    required this.rol,
    required this.admin,
    required this.fechaRegistro,
    this.tipoUnidad,
    this.depitptimPadreId,
    this.depitptimPadreNombre,
  });

  factory Policia.fromMap(Map<String, dynamic> map) {
    return Policia(
      uid: map['uid'] ?? '',
      nombre: map['nombre'] ?? '',
      apellido: map['apellido'] ?? '',
      telefono: map['telefono'] ?? '',
      departamento: map['departamento'] ?? '',
      unidad: map['unidad'] ?? '',
      rango: map['rango'] ?? '',
      numeroCip: map['numero_cip'] ?? '',
      rol: map['rol'] ?? '',
      admin: map['admin'] ?? false,
      fechaRegistro: _parseFechaRegistro(map['fecha_registro']),
      tipoUnidad: map['tipo_unidad'],
      depitptimPadreId: map['depitptim_padre_id'],
      depitptimPadreNombre: map['depitptim_padre_nombre'],
    );
  }

  // Método auxiliar para manejar diferentes tipos de fecha
  static DateTime _parseFechaRegistro(dynamic fechaRegistro) {
    if (fechaRegistro == null) {
      return DateTime.now();
    }
    
    // Si tiene el método toDate() (Timestamp de Firestore)
    try {
      if (fechaRegistro.runtimeType.toString().contains('Timestamp')) {
        return fechaRegistro.toDate();
      }
    } catch (e) {
      // Continuar con otros intentos
    }
    
    // Si es un String (formato ISO)
    if (fechaRegistro is String) {
      try {
        return DateTime.parse(fechaRegistro);
      } catch (e) {
        return DateTime.now();
      }
    }
    
    // Si ya es un DateTime
    if (fechaRegistro is DateTime) {
      return fechaRegistro;
    }
    
    // Fallback
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nombre': nombre.toUpperCase(),
      'apellido': apellido.toUpperCase(),
      'telefono': telefono,
      'departamento': departamento.toUpperCase(),
      'unidad': unidad.toUpperCase(),
      'rango': rango.toUpperCase(),
      'numero_cip': numeroCip.toUpperCase(),
      'rol': rol,
      'admin': admin,
      'fecha_registro': fechaRegistro.toIso8601String(),
      'tipo_unidad': tipoUnidad ?? (isDepitptim ? 'DEPITPTIM' : 'COMISARIA'),
      'depitptim_padre_id': depitptimPadreId,
      'depitptim_padre_nombre': depitptimPadreNombre,
    };
  }

  Policia copyWith({
    String? uid,
    String? nombre,
    String? apellido,
    String? telefono,
    String? departamento,
    String? unidad,
    String? rango,
    String? numeroCip,
    String? rol,
    bool? admin,
    DateTime? fechaRegistro,
    String? tipoUnidad,
    String? depitptimPadreId,
    String? depitptimPadreNombre,
  }) {
    return Policia(
      uid: uid ?? this.uid,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      telefono: telefono ?? this.telefono,
      departamento: departamento ?? this.departamento,
      unidad: unidad ?? this.unidad,
      rango: rango ?? this.rango,
      numeroCip: numeroCip ?? this.numeroCip,
      rol: rol ?? this.rol,
      admin: admin ?? this.admin,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      tipoUnidad: tipoUnidad ?? this.tipoUnidad,
      depitptimPadreId: depitptimPadreId ?? this.depitptimPadreId,
      depitptimPadreNombre: depitptimPadreNombre ?? this.depitptimPadreNombre,
    );
  }

  String get nombreCompleto => '$nombre $apellido';

  /// Indica si la unidad del policía es una DEPITPTIM especializada
  bool get isDepitptim =>
      tipoUnidad == 'DEPITPTIM' ||
      unidad.toUpperCase().contains('DEPITPTIM') ||
      rol == 'admin_depitptim' ||
      admin;

  /// Indica si la unidad es una comisaría de apoyo sectorial
  bool get isComisaria => !isDepitptim;

  /// Determina si tiene privilegios para administrar y autorizar comisarías
  bool get canManageComisarias => isDepitptim || admin;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Policia && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() {
    return 'Policia(uid: $uid, nombre: $nombre, apellido: $apellido, unidad: $unidad, tipoUnidad: $tipoUnidad, admin: $admin)';
  }
}