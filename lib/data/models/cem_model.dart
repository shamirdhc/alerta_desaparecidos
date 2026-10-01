class CemModel {
  final int id;
  final String nombre;
  final String cem;
  final String departamento;
  final String provincia;
  final String distrito;
  final String direccion;
  final String coordinador;
  final String telefono;
  final String telefonoPrincipal;
  final List<String> telefonos;
  final String lineaEmergencia;

  const CemModel({
    required this.id,
    required this.nombre,
    required this.cem,
    required this.departamento,
    required this.provincia,
    required this.distrito,
    required this.direccion,
    required this.coordinador,
    required this.telefono,
    required this.telefonoPrincipal,
    required this.telefonos,
    this.lineaEmergencia = '100',
  });

  factory CemModel.fromJson(Map<String, dynamic> json) {
    final rawTelefonos = json['telefonos'];
    List<String> listTelefonos = [];
    if (rawTelefonos is List) {
      listTelefonos = rawTelefonos.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }

    final telPrincipal = json['telefonoPrincipal']?.toString().trim() ??
        (listTelefonos.isNotEmpty ? listTelefonos.first : '');

    return CemModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nombre: json['nombre']?.toString().trim() ?? '',
      cem: json['cem']?.toString().trim() ?? '',
      departamento: json['departamento']?.toString().trim().toUpperCase() ?? '',
      provincia: json['provincia']?.toString().trim() ?? '',
      distrito: json['distrito']?.toString().trim() ?? '',
      direccion: json['direccion']?.toString().trim() ?? '',
      coordinador: json['coordinador']?.toString().trim() ?? '',
      telefono: json['telefono']?.toString().trim() ?? '',
      telefonoPrincipal: telPrincipal,
      telefonos: listTelefonos,
      lineaEmergencia: json['lineaEmergencia']?.toString().trim() ?? '100',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'cem': cem,
      'departamento': departamento,
      'provincia': provincia,
      'distrito': distrito,
      'direccion': direccion,
      'coordinador': coordinador,
      'telefono': telefono,
      'telefonoPrincipal': telefonoPrincipal,
      'telefonos': telefonos,
      'lineaEmergencia': lineaEmergencia,
    };
  }

  bool get tieneTelefono => telefonos.isNotEmpty || (telefonoPrincipal.isNotEmpty && telefonoPrincipal != '0');

  bool get tieneCelular => telefonos.any((t) => t.length == 9 && t.startsWith('9'));

  String get primerCelular => telefonos.firstWhere(
        (t) => t.length == 9 && t.startsWith('9'),
        orElse: () => telefonoPrincipal.length == 9 && telefonoPrincipal.startsWith('9') ? telefonoPrincipal : '',
      );

  String get googleMapsUrl {
    final query = '$nombre, $direccion, $distrito, $departamento, Peru';
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
  }

  String get wazeUrl {
    final query = '$nombre, $direccion, $distrito, Peru';
    return 'https://waze.com/ul?q=${Uri.encodeComponent(query)}&navigate=yes';
  }

  String get mensajeCompartir {
    final sb = StringBuffer();
    sb.writeln('🟣 *CENTRO EMERGENCIA MUJER (CEM) - MIMP*');
    sb.writeln('🏢 *$nombre*');
    sb.writeln('📍 *Ubicación:* $distrito, $provincia ($departamento)');
    if (direccion.isNotEmpty) {
      sb.writeln('🏠 *Dirección:* $direccion');
    }
    if (coordinador.isNotEmpty) {
      sb.writeln('👤 *Coordinador/a:* $coordinador');
    }
    if (telefono.isNotEmpty) {
      sb.writeln('📞 *Teléfono:* $telefono');
    }
    sb.writeln('🚨 *Línea Gratuita de Emergencia:* 100 (Atención 24/7)');
    sb.writeln('🗺️ *Ver en Google Maps:* $googleMapsUrl');
    return sb.toString();
  }
}
