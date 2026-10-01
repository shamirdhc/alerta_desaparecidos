import 'dart:math' as math;

enum TipoComisaria {
  comisaria, // Comisarías distritales y sectoriales
  depincri,  // DEPINCRI / Investigación Criminal
  familia,   // Comisarías y Módulos de Familia / MIMP
  transito,  // Tránsito, Seguridad Vial y Carreteras
  otras,     // Otras dependencias (Emergencias 105, USE, Halcones, Turismo, DIPROVE)
}

class MininterComisariaModel {
  final String id;
  final String nombre;
  final TipoComisaria tipo;
  final String departamento;
  final String provincia;
  final String distrito;
  final double latitud;
  final double longitud;
  final String? codigoUni;
  final String? codigoCpnp;
  final String? divpol;
  final String? telefono;
  final String? direccion;

  // Campos calculados respecto a la ubicación del usuario
  double? distanciaMetros;
  int? tiempoAutoMin;
  int? tiempoPieMin;

  MininterComisariaModel({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.departamento,
    required this.provincia,
    required this.distrito,
    required this.latitud,
    required this.longitud,
    this.codigoUni,
    this.codigoCpnp,
    this.divpol,
    this.telefono,
    this.direccion,
    this.distanciaMetros,
    this.tiempoAutoMin,
    this.tiempoPieMin,
  });

  bool get esFamilia => tipo == TipoComisaria.familia;
  bool get esDepincri => tipo == TipoComisaria.depincri;
  bool get esTransito => tipo == TipoComisaria.transito;
  bool get esOtras => tipo == TipoComisaria.otras;
  bool get esComisaria => tipo == TipoComisaria.comisaria;

  /// Etiqueta corta de la dependencia
  String get tipoEtiqueta {
    switch (tipo) {
      case TipoComisaria.comisaria:
        return 'COMISARÍA PNP';
      case TipoComisaria.depincri:
        return 'DEPINCRI';
      case TipoComisaria.familia:
        return 'FAMILIA';
      case TipoComisaria.transito:
        return 'TRÁNSITO';
      case TipoComisaria.otras:
        return 'DEPENDENCIA';
    }
  }

  /// Subtítulo descriptivo institucional
  String get tipoSubtitulo {
    switch (tipo) {
      case TipoComisaria.comisaria:
        return 'COMISARÍA POLICIAL';
      case TipoComisaria.depincri:
        return 'DEPINCRI / INVESTIGACIÓN';
      case TipoComisaria.familia:
        return 'CPNP DE FAMILIA';
      case TipoComisaria.transito:
        return 'TRÁNSITO Y SEGURIDAD VIAL';
      case TipoComisaria.otras:
        return 'DEPENDENCIA ESPECIALIZADA';
    }
  }

  String get formattedDistancia {
    if (distanciaMetros == null) return '--';
    if (distanciaMetros! < 1000) {
      return '${distanciaMetros!.round()} m';
    }
    final km = distanciaMetros! / 1000.0;
    return '${km.toStringAsFixed(1)} km';
  }

  String get formattedTiempoAuto {
    if (tiempoAutoMin == null) return '--';
    if (tiempoAutoMin! <= 1) return '1 min';
    return '$tiempoAutoMin min';
  }

  String get formattedTiempoPie {
    if (tiempoPieMin == null) return '--';
    if (tiempoPieMin! <= 1) return '1 min';
    return '$tiempoPieMin min';
  }

  String get googleMapsUrl =>
      'https://www.google.com/maps/dir/?api=1&destination=$latitud,$longitud&travelmode=driving';

  String get wazeUrl => 'https://waze.com/ul?ll=$latitud,$longitud&navigate=yes';

  factory MininterComisariaModel.fromArcgisFeature(
    Map<String, dynamic> feature, {
    bool esFamilia = false,
  }) {
    final attributes = (feature['attributes'] as Map<String, dynamic>?) ?? {};
    final geometry = (feature['geometry'] as Map<String, dynamic>?) ?? {};

    final double lng = (geometry['x'] as num?)?.toDouble() ?? 0.0;
    final double lat = (geometry['y'] as num?)?.toDouble() ?? 0.0;

    String nombre = '';
    String departamento = '';
    String provincia = '';
    String distrito = '';

    if (esFamilia) {
      nombre = (attributes['comisaria_familia'] as String?)?.trim() ??
          (attributes['comisaria'] as String?)?.trim() ??
          'Comisaría de Familia';
      departamento = (attributes['nombdep'] as String?)?.trim() ??
          (attributes['departamento'] as String?)?.trim() ??
          '';
      provincia = (attributes['nombprov'] as String?)?.trim() ??
          (attributes['provincia'] as String?)?.trim() ??
          '';
      distrito = (attributes['nombdist'] as String?)?.trim() ??
          (attributes['distrito'] as String?)?.trim() ??
          '';
    } else {
      nombre = (attributes['comisaria'] as String?)?.trim() ?? 'Comisaría PNP';
      departamento = (attributes['departamento'] as String?)?.trim() ?? '';
      provincia = (attributes['provincia'] as String?)?.trim() ?? '';
      distrito = (attributes['distrito'] as String?)?.trim() ?? '';
    }

    final id = attributes['objectid']?.toString() ??
        attributes['cod_cpnp']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    final divpol = (attributes['divpol_divopus'] as String?)?.trim() ??
        (attributes['regionpol'] as String?)?.trim();

    // Detección automática del tipo según el nombre o atributos
    final upperNom = nombre.toUpperCase();
    TipoComisaria detectedTipo;
    if (esFamilia || upperNom.contains('FAMILIA')) {
      detectedTipo = TipoComisaria.familia;
    } else if (upperNom.contains('DEPINCRI') ||
        upperNom.contains('DIVINCRI') ||
        upperNom.contains('INVESTIGACION') ||
        upperNom.contains('INVESTIGACIÓN')) {
      detectedTipo = TipoComisaria.depincri;
    } else if (upperNom.contains('TRANSITO') ||
        upperNom.contains('TRÁNSITO') ||
        upperNom.contains('SEGURIDAD VIAL') ||
        upperNom.contains('CARRETERAS')) {
      detectedTipo = TipoComisaria.transito;
    } else if (upperNom.contains('EMERGENCIA') ||
        upperNom.contains('HALCON') ||
        upperNom.contains('USE') ||
        upperNom.contains('TURISMO') ||
        upperNom.contains('DINOES') ||
        upperNom.contains('DIPROVE')) {
      detectedTipo = TipoComisaria.otras;
    } else {
      detectedTipo = TipoComisaria.comisaria;
    }

    return MininterComisariaModel(
      id: id,
      nombre: nombre,
      tipo: detectedTipo,
      departamento: departamento.toUpperCase(),
      provincia: provincia.toUpperCase(),
      distrito: distrito.toUpperCase(),
      latitud: lat,
      longitud: lng,
      codigoUni: attributes['cod_uni']?.toString(),
      codigoCpnp: attributes['cod_cpnp']?.toString(),
      divpol: divpol,
      telefono: '01 418-4030', // Central de emergencias PNP
      direccion: '$distrito, $provincia',
    );
  }

  void calcularMetricas(double userLat, double userLng) {
    distanciaMetros = _calcularHaversine(userLat, userLng, latitud, longitud);

    // Estimación vehicular urbana promedio (25 km/h ~ 416 m/min)
    const velocidadAutoMetrosPorMinuto = 416.0;
    tiempoAutoMin = math.max(1, (distanciaMetros! / velocidadAutoMetrosPorMinuto).round());

    // Estimación peatonal promedio (4.5 km/h ~ 75 m/min)
    const velocidadPieMetrosPorMinuto = 75.0;
    tiempoPieMin = math.max(1, (distanciaMetros! / velocidadPieMetrosPorMinuto).round());
  }

  static double _calcularHaversine(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0; // Radio de la Tierra en metros
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}
