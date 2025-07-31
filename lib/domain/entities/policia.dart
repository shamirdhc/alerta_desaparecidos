import 'package:cloud_firestore/cloud_firestore.dart';

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
    );
  }

  String get nombreCompleto => '$nombre $apellido';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Policia && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() {
    return 'Policia(uid: $uid, nombre: $nombre, apellido: $apellido, telefono: $telefono, admin: $admin)';
  }
}