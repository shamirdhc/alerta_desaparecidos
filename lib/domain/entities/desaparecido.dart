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
  final DateTime? fechaNacimiento; // <<< ASEGÚRATE DE TENER ESTA LÍNEA
  final DateTime? fechaDesaparicion;
  final String? departamento; // Cambiado de GeoPoint a campos específicos
  final String? provincia;
  final String? distrito;
  final String? detallesAdicionales;
  final String? _estado;
  final DateTime? fechaEncontrado;
  final String? encontradoDetalles; // NUEVO CAMPO AGREGADO
  final String? fotoUrl;
  final String? imagenFichaUrl;
  final DateTime? fechaCreacion;
  final DateTime? fechaActualizacion;
  // Campos de Jerarquía Policial y Unidad a Cargo
  final String? unidadACargo;
  final String? depitptimId;
  final String? depitptimNombre;
  final String? unidadRegistradora;
  final DateTime? fechaReasignacionDepitptim;

  const Desaparecido({
    this.id,
    // required this.nombreCompleto, // Eliminado
    required this.nombres, // Nuevo campo
    required this.apellidos, // Nuevo campo
    this.sexo,
    this.dni,
    this.telefonoContacto,
    this.fechaNacimiento,
    this.fechaDesaparicion,
    this.departamento, // Nuevo campo
    this.provincia, // Nuevo campo
    this.distrito, // Nuevo campo
    this.detallesAdicionales,
    String? estado,
    this.fechaEncontrado,
    this.encontradoDetalles, // NUEVO CAMPO AGREGADO
    this.fotoUrl,
    this.imagenFichaUrl,
    this.fechaCreacion,
    this.fechaActualizacion,
    this.unidadACargo,
    this.depitptimId,
    this.depitptimNombre,
    this.unidadRegistradora,
    this.fechaReasignacionDepitptim,
  }) : _estado = estado ?? 'activo';

  String? get estado => _estado;

  /// Retorna la edad calculada ya sea desde fechaNacimiento o extrayéndola
  /// automáticamente desde detallesAdicionales ("Edad: XX años").
  int? get edadCalculada {
    if (fechaNacimiento != null) {
      final now = DateTime.now();
      int age = now.year - fechaNacimiento!.year;
      if (now.month < fechaNacimiento!.month ||
          (now.month == fechaNacimiento!.month && now.day < fechaNacimiento!.day)) {
        age--;
      }
      if (age >= 0 && age <= 120) return age;
    }
    if (detallesAdicionales != null && detallesAdicionales!.isNotEmpty) {
      final match = RegExp(r'Edad:\s*(\d+)', caseSensitive: false).firstMatch(detallesAdicionales!);
      if (match != null) {
        final parsed = int.tryParse(match.group(1)!);
        if (parsed != null && parsed >= 0 && parsed <= 120) return parsed;
      }
    }
    return null;
  }

  Desaparecido copyWith({
    String? id,
    // String? nombreCompleto, // Eliminado
    String? nombres, // Nuevo campo
    String? apellidos, // Nuevo campo
    String? sexo,
    String? dni,
    String? telefonoContacto,
    DateTime? fechaNacimiento,
    DateTime? fechaDesaparicion,
    String? departamento,
    String? provincia,
    String? distrito,
    String? detallesAdicionales,
    String? estado,
    DateTime? fechaEncontrado,
    String? encontradoDetalles, // NUEVO CAMPO AGREGADO
    String? fotoUrl,
    String? imagenFichaUrl,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    String? unidadACargo,
    String? depitptimId,
    String? depitptimNombre,
    String? unidadRegistradora,
    DateTime? fechaReasignacionDepitptim,
  }) {
    return Desaparecido(
      id: id ?? this.id,
      // nombreCompleto: nombreCompleto ?? this.nombreCompleto, // Eliminado
      nombres: nombres ?? this.nombres, // Nuevo campo
      apellidos: apellidos ?? this.apellidos, // Nuevo campo
      sexo: sexo ?? this.sexo,
      dni: dni ?? this.dni,
      telefonoContacto: telefonoContacto ?? this.telefonoContacto,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      fechaDesaparicion: fechaDesaparicion ?? this.fechaDesaparicion,
      departamento: departamento ?? this.departamento,
      provincia: provincia ?? this.provincia,
      distrito: distrito ?? this.distrito,
      detallesAdicionales: detallesAdicionales ?? this.detallesAdicionales,
      estado: estado ?? _estado,
      fechaEncontrado: fechaEncontrado ?? this.fechaEncontrado,
      encontradoDetalles:
          encontradoDetalles ?? this.encontradoDetalles, // NUEVO CAMPO AGREGADO
      fotoUrl: fotoUrl ?? this.fotoUrl,
      imagenFichaUrl: imagenFichaUrl ?? this.imagenFichaUrl,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      unidadACargo: unidadACargo ?? this.unidadACargo,
      depitptimId: depitptimId ?? this.depitptimId,
      depitptimNombre: depitptimNombre ?? this.depitptimNombre,
      unidadRegistradora: unidadRegistradora ?? this.unidadRegistradora,
      fechaReasignacionDepitptim:
          fechaReasignacionDepitptim ?? this.fechaReasignacionDepitptim,
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
      'fecha_nacimiento':
          fechaNacimiento != null ? Timestamp.fromDate(fechaNacimiento!) : null,
      'fecha_desaparicion':
          fechaDesaparicion != null
              ? Timestamp.fromDate(fechaDesaparicion!)
              : null,
      'departamento': departamento, // Nuevo campo
      'provincia': provincia, // Nuevo campo
      'distrito': distrito, // Nuevo campo
      'detalles_adicionales': detallesAdicionales,
      'estado': _estado,
      'fecha_encontrado':
          fechaEncontrado != null ? Timestamp.fromDate(fechaEncontrado!) : null,
      'encontrado_detalles': encontradoDetalles, // NUEVO CAMPO AGREGADO
      'foto_url': fotoUrl,
      'imagen_ficha_url': imagenFichaUrl,
      'fecha_creacion':
          fechaCreacion != null ? Timestamp.fromDate(fechaCreacion!) : null,
      'fecha_actualizacion':
          fechaActualizacion != null
              ? Timestamp.fromDate(fechaActualizacion!)
              : null,
      'unidad_a_cargo': unidadACargo,
      'depitptim_id': depitptimId,
      'depitptim_nombre': depitptimNombre,
      'unidad_registradora': unidadRegistradora,
      'fecha_reasignacion_depitptim':
          fechaReasignacionDepitptim != null
              ? Timestamp.fromDate(fechaReasignacionDepitptim!)
              : null,
    };
  }

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String && val.trim().isNotEmpty) {
      return DateTime.tryParse(val.trim());
    }
    if (val is int) {
      return DateTime.fromMillisecondsSinceEpoch(val);
    }
    return null;
  }

  static String? _parseString(dynamic val) {
    if (val == null) return null;
    final str = val.toString().trim();
    return str.isEmpty ? null : str;
  }

  factory Desaparecido.fromMap(Map<String, dynamic> map, String? id) {
    final rawFoto = map['foto_url'] ?? map['fotoUrl'] ?? map['foto'];
    final rawFicha = map['imagen_ficha_url'] ?? map['imagenFichaUrl'] ?? map['imagenFicha'];
    final parsedFoto = _parseString(rawFoto);
    String? parsedFicha = _parseString(rawFicha);

    // Salvaguarda reforzada: Si la ficha es idéntica o comparte el mismo nombre de archivo que la foto de rostro, anularla
    if (parsedFoto != null && parsedFicha != null) {
      final baseFoto = parsedFoto.split('?').first.trim().toLowerCase();
      final baseFicha = parsedFicha.split('?').first.trim().toLowerCase();
      final fileFoto = Uri.decodeComponent(baseFoto).split('/').last.trim();
      final fileFicha = Uri.decodeComponent(baseFicha).split('/').last.trim();

      if (baseFoto == baseFicha ||
          (!fileFicha.contains('_nota') && fileFoto.isNotEmpty && fileFoto == fileFicha)) {
        parsedFicha = null;
      }
    }

    // Normalización de unidad a cargo para garantizar comisaría territorial y evitar DEPINCRI, Familia, etc.
    final rawComisariaOficial = _parseString(map['comisaria_oficial'] ?? map['comisariaOficial']);
    String? parsedUnidad = rawComisariaOficial ?? _parseString(map['unidad_a_cargo'] ?? map['unidadACargo']);
    final rawDetalles = _parseString(map['detalles_adicionales'] ?? map['detallesAdicionales']);
    final rawDistrito = _parseString(map['distrito']);

    if (parsedUnidad != null) {
      final uUp = parsedUnidad.toUpperCase();
      final bool esNoTerritorial = uUp.contains('DIVOPUS') ||
          uUp.contains('DIVPOL') ||
          uUp.contains('DIRITPTIM') ||
          uUp.contains('DIVINTRAP') ||
          uUp.contains('DIRCTPTIM') ||
          uUp.contains('DEPINCRI') ||
          uUp.contains('DIVINCRI') ||
          uUp.contains('SECINCRI') ||
          uUp.contains('DIVINRAP') ||
          uUp.contains('DIVBUS') ||
          uUp.contains('FAMILIA') ||
          uUp.contains('TRANSITO') ||
          uUp.contains('TRÁNSITO') ||
          uUp.contains('VIAL') ||
          uUp.contains('EMERGENCIA') ||
          uUp.contains('OPERACIONES') ||
          uUp.contains('DIRINCRI') ||
          uUp.contains('DIROVE') ||
          uUp.contains('DEPROVE') ||
          (uUp.contains('ROBO') && !uUp.contains('ALGARROBOS'));

      if (esNoTerritorial) {
        if (rawDistrito != null && rawDistrito.trim().isNotEmpty) {
          parsedUnidad = 'COMISARÍA PNP ${rawDistrito.trim().toUpperCase()}';
        } else if (map['provincia'] != null && map['provincia'].toString().trim().isNotEmpty) {
          parsedUnidad = 'COMISARÍA PNP ${map['provincia'].toString().trim().toUpperCase()}';
        } else {
          parsedUnidad = 'Comisaría PNP de la Jurisdicción';
        }
      }
    }

    if (parsedUnidad == null ||
        parsedUnidad.trim().isEmpty ||
        parsedUnidad.trim().toLowerCase() == 'policía nacional del perú' ||
        parsedUnidad.trim().toLowerCase() == 'policia nacional del peru' ||
        parsedUnidad.trim().toLowerCase() == 'dirctptim - pnp' ||
        parsedUnidad.trim().toLowerCase() == 'dirctptim') {
      if (rawDetalles != null && rawDetalles.isNotEmpty) {
        final regExpCom = RegExp(r'Comisar[ií]a:\s*([^.\n]+)', caseSensitive: false);
        final matchCom = regExpCom.firstMatch(rawDetalles);
        if (matchCom != null && matchCom.group(1)?.trim().isNotEmpty == true) {
          parsedUnidad = 'COMISARÍA PNP ${matchCom.group(1)!.trim().toUpperCase()}';
        } else {
          final regExpJur = RegExp(r'Jurisdicci[oó]n:\s*([^.\n]+)', caseSensitive: false);
          final matchJur = regExpJur.firstMatch(rawDetalles);
          if (matchJur != null && matchJur.group(1)?.trim().isNotEmpty == true) {
            parsedUnidad = 'COMISARÍA PNP ${matchJur.group(1)!.trim().toUpperCase()}';
          }
        }
      }
      if (parsedUnidad == null ||
          parsedUnidad.toLowerCase().contains('policía nacional') ||
          parsedUnidad.toLowerCase().contains('policia nacional') ||
          parsedUnidad.toLowerCase().contains('dirctptim')) {
        if (rawDistrito != null && rawDistrito.trim().isNotEmpty) {
          parsedUnidad = 'COMISARÍA PNP ${rawDistrito.trim().toUpperCase()}';
        } else {
          parsedUnidad = 'División de Búsqueda PNP (Línea 114)';
        }
      }
    }

    return Desaparecido(
      id: id,
      nombres: (map['nombres'] ?? map['nombre'] ?? '').toString().trim(),
      apellidos: (map['apellidos'] ?? '').toString().trim(),
      sexo: _parseString(map['sexo']),
      dni: _parseString(map['dni'] ?? map['documentoIdentidad']),
      telefonoContacto: _parseString(map['telefono_contacto'] ?? map['telefonoContacto']),
      fechaNacimiento: _parseDateTime(map['fecha_nacimiento'] ?? map['fechaNacimiento']),
      fechaDesaparicion: _parseDateTime(map['fecha_desaparicion'] ?? map['fechaDesaparicion']),
      departamento: _parseString(map['departamento']),
      provincia: _parseString(map['provincia']),
      distrito: _parseString(map['distrito']),
      detallesAdicionales: _parseString(map['detalles_adicionales'] ?? map['detallesAdicionales']),
      estado: _parseString(map['estado']) ?? 'activo',
      fechaEncontrado: _parseDateTime(map['fecha_encontrado'] ?? map['fechaEncontrado'] ?? map['fecha_aparicion']),
      encontradoDetalles: _parseString(map['encontrado_detalles'] ?? map['encontradoDetalles'] ?? map['origen_ubicacion']),
      fotoUrl: parsedFoto,
      imagenFichaUrl: parsedFicha,
      fechaCreacion: _parseDateTime(map['fecha_creacion'] ?? map['fechaCreacion']),
      fechaActualizacion: _parseDateTime(map['fecha_actualizacion'] ?? map['fechaActualizacion']),
      unidadACargo: parsedUnidad,
      depitptimId: _parseString(map['depitptim_id'] ?? map['depitptimId']),
      depitptimNombre: _parseString(map['depitptim_nombre'] ?? map['depitptimNombre']),
      unidadRegistradora: _parseString(map['unidad_registradora'] ?? map['unidadRegistradora']),
      fechaReasignacionDepitptim: _parseDateTime(map['fecha_reasignacion_depitptim'] ?? map['fechaReasignacionDepitptim']),
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
    fechaNacimiento,
    fechaDesaparicion,
    departamento,
    provincia,
    distrito,
    detallesAdicionales,
    _estado,
    fechaEncontrado,
    encontradoDetalles, // NUEVO CAMPO AGREGADO
    fotoUrl,
    imagenFichaUrl,
    fechaCreacion,
    fechaActualizacion,
    unidadACargo,
    depitptimId,
    depitptimNombre,
    unidadRegistradora,
    fechaReasignacionDepitptim,
  ];
}
