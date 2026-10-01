class ComisariaModel {
  final dynamic id;
  final String nombre;
  final String unidad;
  final String telefono;
  final String departamento;
  final String provincia;
  final String distrito;
  final String direccion;
  final double? latitud;
  final double? longitud;
  double? distanciaMetros;
  final String? codCpnp;
  final String? codInei;
  final String? tipo;

  ComisariaModel({
    this.id,
    required this.nombre,
    required this.unidad,
    required this.telefono,
    required this.departamento,
    required this.provincia,
    required this.distrito,
    this.direccion = '',
    this.latitud,
    this.longitud,
    this.distanciaMetros,
    this.codCpnp,
    this.codInei,
    this.tipo,
  });

  /// Formato legible de la distancia calculada respecto al usuario
  String get formattedDistancia {
    if (distanciaMetros == null) return '';
    if (distanciaMetros! < 1000) {
      return '${distanciaMetros!.round()} m';
    }
    return '${(distanciaMetros! / 1000.0).toStringAsFixed(1)} km';
  }

  factory ComisariaModel.fromMap(Map<String, dynamic> map) {
    return ComisariaModel(
      id: map['id'],
      nombre: map['nombre']?.toString() ?? '',
      unidad: map['unidad']?.toString() ?? '',
      telefono: map['telefono']?.toString() ?? '',
      departamento: map['departamento']?.toString() ?? '',
      provincia: map['provincia']?.toString() ?? '',
      distrito: map['distrito']?.toString() ?? '',
      direccion: map['direccion']?.toString() ?? '',
      latitud: (map['latitud'] as num?)?.toDouble() ?? (map['lat'] as num?)?.toDouble(),
      longitud: (map['longitud'] as num?)?.toDouble() ?? (map['lng'] as num?)?.toDouble(),
      distanciaMetros: (map['distanciaMetros'] as num?)?.toDouble(),
      codCpnp: map['cod_cpnp']?.toString(),
      codInei: map['cod_inei']?.toString(),
      tipo: map['tipo']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'unidad': unidad,
      'telefono': telefono,
      'departamento': departamento,
      'provincia': provincia,
      'distrito': distrito,
      'direccion': direccion,
      'latitud': latitud,
      'longitud': longitud,
      'distanciaMetros': distanciaMetros,
      'cod_cpnp': codCpnp,
      'cod_inei': codInei,
      'tipo': tipo,
    };
  }

  ComisariaModel copyWith({
    dynamic id,
    String? nombre,
    String? unidad,
    String? telefono,
    String? departamento,
    String? provincia,
    String? distrito,
    String? direccion,
    double? latitud,
    double? longitud,
    double? distanciaMetros,
    String? codCpnp,
    String? codInei,
    String? tipo,
  }) {
    return ComisariaModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      unidad: unidad ?? this.unidad,
      telefono: telefono ?? this.telefono,
      departamento: departamento ?? this.departamento,
      provincia: provincia ?? this.provincia,
      distrito: distrito ?? this.distrito,
      direccion: direccion ?? this.direccion,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      distanciaMetros: distanciaMetros ?? this.distanciaMetros,
      codCpnp: codCpnp ?? this.codCpnp,
      codInei: codInei ?? this.codInei,
      tipo: tipo ?? this.tipo,
    );
  }

  @override
  String toString() {
    return 'ComisariaModel{id: $id, nombre: $nombre, unidad: $unidad, telefono: $telefono, departamento: $departamento, provincia: $provincia, distrito: $distrito, direccion: $direccion, lat: $latitud, lng: $longitud, dist: $distanciaMetros}';
  }
}

class DepartamentoSyncModel {
  final String departamento;
  final DateTime ultimaActualizacion;
  final String hash;

  DepartamentoSyncModel({
    required this.departamento,
    required this.ultimaActualizacion,
    required this.hash,
  });

  Map<String, dynamic> toMap() {
    return {
      'departamento': departamento,
      'ultima_actualizacion': ultimaActualizacion.millisecondsSinceEpoch,
      'hash': hash,
    };
  }

  factory DepartamentoSyncModel.fromMap(Map<String, dynamic> map) {
    return DepartamentoSyncModel(
      departamento: map['departamento'] ?? '',
      ultimaActualizacion: DateTime.fromMillisecondsSinceEpoch(map['ultima_actualizacion']),
      hash: map['hash'] ?? '',
    );
  }
}
