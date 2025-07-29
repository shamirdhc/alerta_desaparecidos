class ComisariaModel {
  final int? id;
  final String nombre;
  final String unidad;
  final String telefono;
  final String departamento;
  final String provincia;
  final String distrito;

  ComisariaModel({
    this.id,
    required this.nombre,
    required this.unidad,
    required this.telefono,
    required this.departamento,
    required this.provincia,
    required this.distrito,
  });

  factory ComisariaModel.fromMap(Map<String, dynamic> map) {
    return ComisariaModel(
      id: map['id'] as int?,
      nombre: map['nombre']?.toString() ?? '',
      unidad: map['unidad']?.toString() ?? '',
      telefono: map['telefono']?.toString() ?? '',
      departamento: map['departamento']?.toString() ?? '',
      provincia: map['provincia']?.toString() ?? '',
      distrito: map['distrito']?.toString() ?? '',
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
    };
  }

  @override
  String toString() {
    return 'ComisariaModel{id: $id, nombre: $nombre, unidad: $unidad, telefono: $telefono, departamento: $departamento, provincia: $provincia, distrito: $distrito}';
  }
}

class DepartamentoSyncModel {
  final String departamento;
  final DateTime ultimaActualizacion;
  final String hash; // Para detectar cambios en el archivo

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