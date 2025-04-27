import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class Desaparecido extends Equatable {
  final String? id;
  // final String nombreCompleto; // Eliminado
  final String nombres; // Nuevo campo
  final String apellidos; // Nuevo campo
  final String? sexo;
  final String? dni;
  final String? telefonoContacto;
  final DateTime? fechaDesaparicion;
  final String? departamento; // Cambiado de GeoPoint a campos específicos
  final String? provincia;
  final String? distrito;
  final String? detallesAdicionales;
  final String? _estado;
  final DateTime? fechaEncontrado;
  final String? fotoUrl;
  final String? imagenFichaUrl;
  final DateTime? fechaCreacion;
  final DateTime? fechaActualizacion;

  const Desaparecido({
    this.id,
    // required this.nombreCompleto, // Eliminado
    required this.nombres, // Nuevo campo
    required this.apellidos, // Nuevo campo
    this.sexo,
    this.dni,
    this.telefonoContacto,
    this.fechaDesaparicion,
    this.departamento, // Nuevo campo
    this.provincia,    // Nuevo campo
    this.distrito,     // Nuevo campo
    this.detallesAdicionales,
    String? estado,
    this.fechaEncontrado,
    this.fotoUrl,
    this.imagenFichaUrl,
    this.fechaCreacion,
    this.fechaActualizacion,
  }) : _estado = estado ?? 'activo';

  String? get estado => _estado;

  Desaparecido copyWith({
    String? id,
    // String? nombreCompleto, // Eliminado
    String? nombres, // Nuevo campo
    String? apellidos, // Nuevo campo
    String? sexo,
    String? dni,
    String? telefonoContacto,
    DateTime? fechaDesaparicion,
    String? departamento,
    String? provincia,
    String? distrito,
    String? detallesAdicionales,
    String? estado,
    DateTime? fechaEncontrado,
    String? fotoUrl,
    String? imagenFichaUrl,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
  }) {
    return Desaparecido(
      id: id ?? this.id,
      // nombreCompleto: nombreCompleto ?? this.nombreCompleto, // Eliminado
      nombres: nombres ?? this.nombres, // Nuevo campo
      apellidos: apellidos ?? this.apellidos, // Nuevo campo
      sexo: sexo ?? this.sexo,
      dni: dni ?? this.dni,
      telefonoContacto: telefonoContacto ?? this.telefonoContacto,
      fechaDesaparicion: fechaDesaparicion ?? this.fechaDesaparicion,
      departamento: departamento ?? this.departamento,
      provincia: provincia ?? this.provincia,
      distrito: distrito ?? this.distrito,
      detallesAdicionales: detallesAdicionales ?? this.detallesAdicionales,
      estado: estado ?? _estado,
      fechaEncontrado: fechaEncontrado ?? this.fechaEncontrado,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      imagenFichaUrl: imagenFichaUrl ?? this.imagenFichaUrl,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      // 'nombre_completo': nombreCompleto, // Eliminado
      'nombres': nombres, // Nuevo campo
      'apellidos': apellidos, // Nuevo campo
      'sexo': sexo,
      'dni': dni,
      'telefono_contacto': telefonoContacto,
      'fecha_desaparicion': fechaDesaparicion != null
          ? Timestamp.fromDate(fechaDesaparicion!)
          : null,
      'departamento': departamento, // Nuevo campo
      'provincia': provincia,       // Nuevo campo
      'distrito': distrito,         // Nuevo campo
      'detalles_adicionales': detallesAdicionales,
      'estado': _estado,
      'fecha_encontrado':
      fechaEncontrado != null ? Timestamp.fromDate(fechaEncontrado!) : null,
      'foto_url': fotoUrl,
      'imagen_ficha_url': imagenFichaUrl,
      'fecha_creacion':
      fechaCreacion != null ? Timestamp.fromDate(fechaCreacion!) : null,
      'fecha_actualizacion': fechaActualizacion != null
          ? Timestamp.fromDate(fechaActualizacion!)
          : null,
    };
  }

  factory Desaparecido.fromMap(Map<String, dynamic> map, String? id) {
    return Desaparecido(
      id: id,
      // nombreCompleto: map['nombre_completo'] ?? '', // Eliminado
      nombres: map['nombres'] ?? '', // Nuevo campo
      apellidos: map['apellidos'] ?? '', // Nuevo campo
      sexo: map['sexo'],
      dni: map['dni'],
      telefonoContacto: map['telefono_contacto'],
      fechaDesaparicion: map['fecha_desaparicion'] != null
          ? (map['fecha_desaparicion'] as Timestamp).toDate()
          : null,
      departamento: map['departamento'], // Nuevo campo
      provincia: map['provincia'],       // Nuevo campo
      distrito: map['distrito'],         // Nuevo campo
      detallesAdicionales: map['detalles_adicionales'],
      estado: map['estado'],
      fechaEncontrado: map['fecha_encontrado'] != null
          ? (map['fecha_encontrado'] as Timestamp).toDate()
          : null,
      fotoUrl: map['foto_url'],
      imagenFichaUrl: map['imagen_ficha_url'],
      fechaCreacion: map['fecha_creacion'] != null
          ? (map['fecha_creacion'] as Timestamp).toDate()
          : null,
      fechaActualizacion: map['fecha_actualizacion'] != null
          ? (map['fecha_actualizacion'] as Timestamp).toDate()
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    // nombreCompleto, // Eliminado
    nombres, // Nuevo campo
    apellidos, // Nuevo campo
    sexo,
    dni,
    telefonoContacto,
    fechaDesaparicion,
    departamento,
    provincia,
    distrito,
    detallesAdicionales,
    _estado,
    fechaEncontrado,
    fotoUrl,
    imagenFichaUrl,
    fechaCreacion,
    fechaActualizacion,
  ];
}