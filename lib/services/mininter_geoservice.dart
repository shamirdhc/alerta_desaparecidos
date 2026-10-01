import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import '../data/models/mininter_comisaria_model.dart';
import 'comisaria_matcher_service.dart';

class PasoRuta {
  final String instruccion;
  final double distanciaMetros;
  final String nombreCalle;

  PasoRuta({
    required this.instruccion,
    required this.distanciaMetros,
    required this.nombreCalle,
  });

  String get formattedDistancia {
    if (distanciaMetros < 1000) {
      return '${distanciaMetros.round()} m';
    }
    return '${(distanciaMetros / 1000.0).toStringAsFixed(1)} km';
  }
}

class RutaCallejeraModel {
  final List<LatLng> puntos;
  final double distanciaMetros;
  final double duracionSegundos;
  final String viasPrincipales;
  final List<PasoRuta> pasos;

  RutaCallejeraModel({
    required this.puntos,
    required this.distanciaMetros,
    required this.duracionSegundos,
    this.viasPrincipales = '',
    this.pasos = const [],
  });

  String get formattedDistancia {
    if (distanciaMetros < 1000) {
      return '${distanciaMetros.round()} m';
    }
    return '${(distanciaMetros / 1000.0).toStringAsFixed(1)} km';
  }

  String get formattedDuracion {
    final minutos = (duracionSegundos / 60.0).round();
    if (minutos <= 1) return '1 min';
    return '$minutos min';
  }
}


class MininterGeoservice {
  static const String _baseUrl =
      'https://seguridadciudadana.mininter.gob.pe/arcgis/rest/services/servicios_ogc/policia_nacional_peru/MapServer';

  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AlertaDesaparecidos/1.0',
  };

  /// Consulta comisarías y dependencias policiales cercanas a una coordenada GPS (lat, lng)
  /// dentro de un radio urbano en metros (por defecto 5,000 m = 5 KM).
  static Future<List<MininterComisariaModel>> getComisariasCercanas({
    required double lat,
    required double lng,
    double radioMetros = 5000,
    TipoComisaria? filtroTipo,
  }) async {
    final List<MininterComisariaModel> result = [];

    // 1. Incorporar primero el catálogo nacional oficial offline (1,330+ comisarías y DEPINCRIs)
    try {
      await ComisariaMatcherService.inicializar();
      final catalogoLocal = ComisariaMatcherService.catalogoComisarias;
      for (final c in catalogoLocal) {
        if (c.latitud == null || c.longitud == null) continue;
        final dist = ComisariaMatcherService.calcularDistanciaMetros(lat, lng, c.latitud!, c.longitud!);
        if (dist <= radioMetros * 1.2) {
          final upperNom = c.nombre.toUpperCase();
          TipoComisaria detectedTipo = TipoComisaria.comisaria;
          if (upperNom.contains('FAMILIA')) {
            detectedTipo = TipoComisaria.familia;
          } else if (upperNom.contains('DEPINCRI') || upperNom.contains('DIVINCRI')) {
            detectedTipo = TipoComisaria.depincri;
          } else if (upperNom.contains('TRANSITO') || upperNom.contains('TRÁNSITO')) {
            detectedTipo = TipoComisaria.transito;
          }

          result.add(MininterComisariaModel(
            id: 'local_${c.id}',
            nombre: c.nombre,
            tipo: detectedTipo,
            departamento: c.departamento,
            provincia: c.provincia,
            distrito: c.distrito,
            latitud: c.latitud!,
            longitud: c.longitud!,
            telefono: c.telefono.isNotEmpty ? c.telefono : '105',
            direccion: c.direccion.isNotEmpty ? c.direccion : '${c.distrito}, ${c.provincia}',
            distanciaMetros: dist,
          ));
        }
      }
    } catch (err) {
      debugPrint('⚠️ [MININTER-GEO] Error cargando catálogo local: $err');
    }

    // 2. Consultar en paralelo capas espaciales de ArcGIS si hay conexión
    final bool buscarComisarias = filtroTipo == null || filtroTipo == TipoComisaria.comisaria;
    final bool buscarFamilia = filtroTipo == null || filtroTipo == TipoComisaria.familia;

    final List<Future<List<MininterComisariaModel>>> requests = [];

    if (buscarComisarias) {
      requests.add(_querySpatialLayer(layerId: 5, lat: lat, lng: lng, radioMetros: radioMetros, esFamilia: false));
    }
    if (buscarFamilia) {
      requests.add(_querySpatialLayer(layerId: 7, lat: lat, lng: lng, radioMetros: radioMetros, esFamilia: true));
    }

    try {
      if (requests.isNotEmpty) {
        try {
          final responses = await Future.wait(requests).timeout(const Duration(seconds: 4));
          for (final list in responses) {
            result.addAll(list);
          }
        } catch (_) {}
      }

      // 3. Incorporar dependencias especializadas (DEPINCRI, Tránsito, Familia, Emergencias)
      final especializadas = _getDependenciasEspecializadasCercanas(
        lat: lat,
        lng: lng,
        radioMetros: radioMetros,
        filtroTipo: filtroTipo,
      );
      result.addAll(especializadas);

      // Excluir dependencias inexistentes o formatos incorrectos (sólo es válido CPNP DE FAMILIA ANDAHUAYLAS)
      result.removeWhere((c) {
        final upper = c.nombre.toUpperCase().trim();
        return upper == 'COMISARÍA DE FAMILIA ANDAHUAYLAS' ||
               upper == 'COMISARIA DE FAMILIA ANDAHUAYLAS';
      });

      // Calcular métricas de distancia y tiempo para cada dependencia policial
      for (final c in result) {
        c.calcularMetricas(lat, lng);
      }

      // Deduplicar unidades por proximidad física (distancia <= 40m o misma dirección) priorizando comisarías territoriales
      List<MininterComisariaModel> filtradas = deduplicarPorProximidadEspacial(result);

      // Aplicar filtro estricto por tipo si fue seleccionado
      if (filtroTipo != null) {
        filtradas = filtradas.where((c) => c.tipo == filtroTipo).toList();
      }

      // Filtrar dependencias estrictamente dentro del radio urbano solicitado
      final enRadio = filtradas.where((c) => (c.distanciaMetros ?? 0) <= radioMetros).toList();

      // Ordenar por distancia ascendente (la más cercana primero)
      enRadio.sort((a, b) => (a.distanciaMetros ?? 0).compareTo(b.distanciaMetros ?? 0));

      return enRadio;
    } catch (e) {
      debugPrint('⚠️ [MININTER-GEO] Error en consulta espacial: $e');
      final deduplicadas = deduplicarPorProximidadEspacial(result);
      final enRadio = deduplicadas.where((c) => (c.distanciaMetros ?? 0) <= radioMetros).toList();
      enRadio.sort((a, b) => (a.distanciaMetros ?? 0).compareTo(b.distanciaMetros ?? 0));
      if (enRadio.isNotEmpty) return enRadio;
      return _getFallbackComisarias(userLat: lat, userLng: lng, filtroTipo: filtroTipo);
    }
  }

  /// Deduplica unidades policiales que marcan el mismo lugar físico (distancia <= 40m o misma dirección),
  /// priorizando comisarías territoriales/sectoriales sobre comisarías de familia, tránsito, emergencias u otras.
  static List<MininterComisariaModel> deduplicarPorProximidadEspacial(List<MininterComisariaModel> comisarias) {
    if (comisarias.isEmpty) return [];

    int calcularPrioridad(MininterComisariaModel c) {
      final nom = c.nombre.toUpperCase();
      final tel = c.telefono ?? '';
      final dir = c.direccion ?? '';
      int score = 0;

      // 1. Jerarquía por función y tipo de dependencia
      if (c.tipo == TipoComisaria.comisaria) {
        if (!nom.contains('FAMILIA') &&
            !nom.contains('TURISMO') &&
            !nom.contains('TRANSITO') &&
            !nom.contains('TRÁNSITO') &&
            !nom.contains('CARRETERAS') &&
            !nom.contains('AEROPUERTO') &&
            !nom.contains('EMERGENCIA') &&
            !nom.contains('ESCUADRON') &&
            !nom.contains('ESCUADRÓN') &&
            !nom.contains('RADIO PATRULLA')) {
          score += 1000;
          if (nom.contains('SECTORIAL')) score += 120;
          if (nom.contains('"A"') || nom.contains('TIPO A')) score += 90;
          if (nom.contains('"B"') || nom.contains('TIPO B')) score += 70;
          if (nom.contains('"C"') || nom.contains('TIPO C')) score += 50;
          if (nom.contains('URBANA')) score += 30;
        } else if (nom.contains('TURISMO')) {
          score += 450;
        } else {
          score += 550;
        }
      } else if (c.tipo == TipoComisaria.depincri || nom.contains('DEPINCRI') || nom.contains('DIVINCRI')) {
        score += 650;
      } else if (c.tipo == TipoComisaria.familia || nom.contains('FAMILIA')) {
        score += 500;
      } else if (c.tipo == TipoComisaria.transito || nom.contains('TRANSITO') || nom.contains('TRÁNSITO')) {
        score += 350;
      } else {
        score += 200;
      }

      // 2. Calidad de los datos de contacto y dirección
      if (tel.isNotEmpty && tel != '105' && tel != '114' && tel != '105 / 114') {
        score += 60;
      }
      if (dir.isNotEmpty && !dir.toUpperCase().startsWith('JURISDICCI')) {
        score += 40;
      }

      return score;
    }

    final List<MininterComisariaModel> resultado = [];
    final List<MininterComisariaModel> pendientes = List.from(comisarias);

    while (pendientes.isNotEmpty) {
      final base = pendientes.removeAt(0);
      final List<MininterComisariaModel> grupoMismoLugar = [base];

      pendientes.removeWhere((c) {
        // Distancia geodésica entre coordenadas
        final dist = ComisariaMatcherService.calcularDistanciaMetros(
          base.latitud,
          base.longitud,
          c.latitud,
          c.longitud,
        );

        final mismaUbicacion = dist <= 40.0 ||
            ((base.latitud - c.latitud).abs() < 0.00035 &&
             (base.longitud - c.longitud).abs() < 0.00035);

        final baseDir = (base.direccion ?? '').toUpperCase().trim();
        final cDir = (c.direccion ?? '').toUpperCase().trim();
        final baseDistrito = base.distrito.toUpperCase().trim();
        final cDistrito = c.distrito.toUpperCase().trim();

        final mismaDireccion = baseDistrito.isNotEmpty &&
            baseDistrito == cDistrito &&
            baseDir.isNotEmpty &&
            baseDir == cDir &&
            !baseDir.startsWith('JURISDICCI');

        if (mismaUbicacion || mismaDireccion) {
          grupoMismoLugar.add(c);
          return true;
        }
        return false;
      });

      // Ordenar por prioridad descendente y conservar únicamente la de mayor rango
      grupoMismoLugar.sort((a, b) => calcularPrioridad(b).compareTo(calcularPrioridad(a)));
      resultado.add(grupoMismoLugar.first);
    }

    return resultado;
  }

  /// Catálogo nacional de dependencias policiales especializadas (DEPINCRI, Tránsito, Familia, Otras)
  static List<MininterComisariaModel> _getDependenciasEspecializadasCercanas({
    required double lat,
    required double lng,
    required double radioMetros,
    TipoComisaria? filtroTipo,
  }) {
    final List<MininterComisariaModel> catalogo = [
      // ================= DEPINCRI / INVESTIGACIÓN =================
      MininterComisariaModel(
        id: 'dep_cercado',
        nombre: 'DEPINCRI CERCADO DE LIMA',
        tipo: TipoComisaria.depincri,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'CERCADO DE LIMA',
        latitud: -12.0545,
        longitud: -77.0375,
        direccion: 'Jr. Chota 1420',
        telefono: '01 431-8134',
      ),
      MininterComisariaModel(
        id: 'dep_brena',
        nombre: 'DEPINCRI BREÑA - PUEBLO LIBRE',
        tipo: TipoComisaria.depincri,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'BREÑA',
        latitud: -12.0583,
        longitud: -77.0452,
        direccion: 'Av. Bolivia 650',
        telefono: '01 424-0012',
      ),
      MininterComisariaModel(
        id: 'dep_miraflores',
        nombre: 'DEPINCRI MIRAFLORES - SAN ISIDRO',
        tipo: TipoComisaria.depincri,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'MIRAFLORES',
        latitud: -12.1221,
        longitud: -77.0289,
        direccion: 'Calle Manuel Bonilla 115',
        telefono: '01 445-5680',
      ),
      MininterComisariaModel(
        id: 'dep_sanborja',
        nombre: 'DEPINCRI SAN BORJA - SURCO',
        tipo: TipoComisaria.depincri,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'SANTIAGO DE SURCO',
        latitud: -12.1120,
        longitud: -76.9940,
        direccion: 'Av. Primavera 1230',
        telefono: '01 372-6800',
      ),
      MininterComisariaModel(
        id: 'dep_sjl',
        nombre: 'DEPINCRI SAN JUAN DE LURIGANCHO 1',
        tipo: TipoComisaria.depincri,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'SAN JUAN DE LURIGANCHO',
        latitud: -11.9862,
        longitud: -77.0051,
        direccion: 'Av. Canto Grande s/n',
        telefono: '01 388-3444',
      ),
      MininterComisariaModel(
        id: 'dep_losolivos',
        nombre: 'DEPINCRI LOS OLIVOS',
        tipo: TipoComisaria.depincri,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'LOS OLIVOS',
        latitud: -11.9925,
        longitud: -77.0710,
        direccion: 'Av. Antúnez de Mayolo 890',
        telefono: '01 521-4455',
      ),
      MininterComisariaModel(
        id: 'dep_comas',
        nombre: 'DEPINCRI COMAS',
        tipo: TipoComisaria.depincri,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'COMAS',
        latitud: -11.9380,
        longitud: -77.0540,
        direccion: 'Av. Túpac Amaru Km 11',
        telefono: '01 542-1010',
      ),
      MininterComisariaModel(
        id: 'dep_smp',
        nombre: 'DEPINCRI SAN MARTÍN DE PORRES',
        tipo: TipoComisaria.depincri,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'SAN MARTIN DE PORRES',
        latitud: -12.0315,
        longitud: -77.0720,
        direccion: 'Av. Perú Cdra. 23',
        telefono: '01 568-1234',
      ),
      MininterComisariaModel(
        id: 'dep_callao',
        nombre: 'DEPINCRI CALLAO',
        tipo: TipoComisaria.depincri,
        departamento: 'CALLAO',
        provincia: 'CALLAO',
        distrito: 'CALLAO',
        latitud: -12.0620,
        longitud: -77.1430,
        direccion: 'Av. Sáenz Peña 850',
        telefono: '01 429-1122',
      ),
      MininterComisariaModel(
        id: 'dep_andahuaylas',
        nombre: 'DEPINCRI ANDAHUAYLAS',
        tipo: TipoComisaria.depincri,
        departamento: 'APURIMAC',
        provincia: 'ANDAHUAYLAS',
        distrito: 'ANDAHUAYLAS',
        latitud: -13.6542162,
        longitud: -73.3885275,
        direccion: 'Jr. Guillermo Cáceres 614, Andahuaylas 03701',
        telefono: '980122444',
      ),
      MininterComisariaModel(
        id: 'dep_abancay',
        nombre: 'DEPINCRI ABANCAY',
        tipo: TipoComisaria.depincri,
        departamento: 'APURIMAC',
        provincia: 'ABANCAY',
        distrito: 'ABANCAY',
        latitud: -13.6360,
        longitud: -72.8814,
        direccion: 'Jr. Lima 520, Abancay',
        telefono: '083 321155',
      ),
      MininterComisariaModel(
        id: 'dep_arequipa',
        nombre: 'DEPINCRI AREQUIPA',
        tipo: TipoComisaria.depincri,
        departamento: 'AREQUIPA',
        provincia: 'AREQUIPA',
        distrito: 'AREQUIPA',
        latitud: -16.4020,
        longitud: -71.5350,
        direccion: 'Calle San Juan de Dios 312',
        telefono: '054 212020',
      ),
      MininterComisariaModel(
        id: 'dep_trujillo',
        nombre: 'DEPINCRI TRUJILLO',
        tipo: TipoComisaria.depincri,
        departamento: 'LA LIBERTAD',
        provincia: 'TRUJILLO',
        distrito: 'TRUJILLO',
        latitud: -8.1120,
        longitud: -79.0310,
        direccion: 'Av. España 1050',
        telefono: '044 233180',
      ),
      MininterComisariaModel(
        id: 'dep_cusco',
        nombre: 'DEPINCRI CUSCO',
        tipo: TipoComisaria.depincri,
        departamento: 'CUSCO',
        provincia: 'CUSCO',
        distrito: 'CUSCO',
        latitud: -13.5140,
        longitud: -71.9810,
        direccion: 'Calle Saphy 420',
        telefono: '084 224411',
      ),

      // ================= TRÁNSITO Y SEGURIDAD VIAL =================
      MininterComisariaModel(
        id: 'tra_lima_centro',
        nombre: 'DIVISIÓN DE TRÁNSITO Y SEGURIDAD VIAL LIMA CENTRO',
        tipo: TipoComisaria.transito,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'LIMA',
        latitud: -12.0665,
        longitud: -77.0345,
        direccion: 'Av. 28 de Julio con Petit Thouars',
        telefono: '01 433-4411',
      ),
      MininterComisariaModel(
        id: 'tra_lima_norte',
        nombre: 'COMISARÍA DE TRÁNSITO LIMA NORTE',
        tipo: TipoComisaria.transito,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'INDEPENDENCIA',
        latitud: -11.9930,
        longitud: -77.0540,
        direccion: 'Av. Túpac Amaru Cdra. 38',
        telefono: '01 528-7711',
      ),
      MininterComisariaModel(
        id: 'tra_lima_sur',
        nombre: 'COMISARÍA DE TRÁNSITO LIMA SUR',
        tipo: TipoComisaria.transito,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'SANTIAGO DE SURCO',
        latitud: -12.1450,
        longitud: -77.0120,
        direccion: 'Av. Paseo de la República s/n',
        telefono: '01 448-9011',
      ),
      MininterComisariaModel(
        id: 'tra_carreteras',
        nombre: 'DIVISIÓN DE PROTECCIÓN DE CARRETERAS PNP (CENTRAL)',
        tipo: TipoComisaria.transito,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'LIMA',
        latitud: -12.0660,
        longitud: -77.0340,
        direccion: 'Av. 28 de Julio 1111',
        telefono: '01 431-3040',
      ),
      MininterComisariaModel(
        id: 'tra_andahuaylas',
        nombre: 'UNIDAD DE SEGURIDAD VIAL Y TRÁNSITO ANDAHUAYLAS',
        tipo: TipoComisaria.transito,
        departamento: 'APURIMAC',
        provincia: 'ANDAHUAYLAS',
        distrito: 'ANDAHUAYLAS',
        latitud: -13.656552,
        longitud: -73.384747,
        direccion: 'Av. Perú 189, Andahuaylas',
        telefono: '945277480',
      ),
      MininterComisariaModel(
        id: 'tra_arequipa',
        nombre: 'COMISARÍA DE TRÁNSITO AREQUIPA',
        tipo: TipoComisaria.transito,
        departamento: 'AREQUIPA',
        provincia: 'AREQUIPA',
        distrito: 'AREQUIPA',
        latitud: -16.3950,
        longitud: -71.5360,
        direccion: 'Calle Santa Catalina 115',
        telefono: '054 282830',
      ),

      // ================= FAMILIA ESPECIALIZADAS =================
      MininterComisariaModel(
        id: 'fam_mimp',
        nombre: 'COMISARÍA PNP FAMILIA DEL MINISTERIO DE LA MUJER',
        tipo: TipoComisaria.familia,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'CERCADO DE LIMA',
        latitud: -12.046374,
        longitud: -77.042793,
        direccion: 'Jr. Camaná 616 (Sede MIMP)',
        telefono: '01 626-1600',
      ),
      MininterComisariaModel(
        id: 'fam_andahuaylas',
        nombre: 'CPNP DE FAMILIA ANDAHUAYLAS',
        tipo: TipoComisaria.familia,
        departamento: 'APURIMAC',
        provincia: 'ANDAHUAYLAS',
        distrito: 'ANDAHUAYLAS',
        latitud: -13.656552,
        longitud: -73.384747,
        direccion: 'Av. Perú 189, Andahuaylas',
        telefono: '957832971',
      ),

      // ================= OTRAS DEPENDENCIAS (Emergencias, USE, Turismo, DIPROVE) =================
      MininterComisariaModel(
        id: 'otr_105_lima',
        nombre: 'CENTRAL 105 - ESCUADRÓN DE EMERGENCIA PNP',
        tipo: TipoComisaria.otras,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'CERCADO DE LIMA',
        latitud: -12.0565,
        longitud: -77.0385,
        direccion: 'Av. España 323',
        telefono: '105',
      ),
      MininterComisariaModel(
        id: 'otr_terna',
        nombre: 'ESCUADRÓN VERDE / GRUPO TERNA PNP',
        tipo: TipoComisaria.otras,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'CERCADO DE LIMA',
        latitud: -12.0580,
        longitud: -77.0341,
        direccion: 'Jr. Cotabambas 330',
        telefono: '01 428-1111',
      ),
      MininterComisariaModel(
        id: 'otr_use',
        nombre: 'UNIDAD DE SERVICIOS ESPECIALES (USE PNP)',
        tipo: TipoComisaria.otras,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'LA VICTORIA',
        latitud: -12.0670,
        longitud: -77.0350,
        direccion: 'Av. 28 de Julio 1250',
        telefono: '01 431-5080',
      ),
      MininterComisariaModel(
        id: 'otr_turismo',
        nombre: 'POLICÍA DE TURISMO LIMA',
        tipo: TipoComisaria.otras,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'CERCADO DE LIMA',
        latitud: -12.0450,
        longitud: -77.0290,
        direccion: 'Jr. Carabaya 460',
        telefono: '01 460-1060',
      ),
      MininterComisariaModel(
        id: 'otr_diprove',
        nombre: 'DIPROVE - UNIDAD DE PREVENCIÓN E INVESTIGACIÓN DE ROBO DE VEHÍCULOS',
        tipo: TipoComisaria.otras,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'LA VICTORIA',
        latitud: -12.0655,
        longitud: -77.0335,
        direccion: 'Av. 28 de Julio con Iquitos',
        telefono: '01 328-0573',
      ),
      MininterComisariaModel(
        id: 'otr_eme_andahuaylas',
        nombre: 'ESCUADRÓN DE EMERGENCIA ANDAHUAYLAS',
        tipo: TipoComisaria.otras,
        departamento: 'APURIMAC',
        provincia: 'ANDAHUAYLAS',
        distrito: 'ANDAHUAYLAS',
        latitud: -13.656552,
        longitud: -73.384747,
        direccion: 'Av. Perú 189, Andahuaylas',
        telefono: '980122088',
      ),
    ];

    final List<MininterComisariaModel> result = [];
    for (final c in catalogo) {
      if (filtroTipo != null && c.tipo != filtroTipo) continue;
      c.calcularMetricas(lat, lng);
      // Radio con tolerancia para urbes cercanas
      if (c.distanciaMetros != null && c.distanciaMetros! <= (radioMetros * 1.25)) {
        result.add(c);
      }
    }

    return result;
  }

  /// Consulta espacial interna a una capa específica del MapServer de MININTER
  static Future<List<MininterComisariaModel>> _querySpatialLayer({
    required int layerId,
    required double lat,
    required double lng,
    required double radioMetros,
    required bool esFamilia,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/$layerId/query?'
      'geometry=$lng,$lat&'
      'geometryType=esriGeometryPoint&'
      'inSR=4326&'
      'spatialRel=esriSpatialRelIntersects&'
      'distance=$radioMetros&'
      'units=esriSRUnit_Meter&'
      'outFields=*&'
      'outSR=4326&'
      'f=pjson',
    );

    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final features = (data['features'] as List<dynamic>?) ?? [];

      return features
          .map((f) => MininterComisariaModel.fromArcgisFeature(
                f as Map<String, dynamic>,
                esFamilia: esFamilia,
              ))
          .toList();
    } else {
      throw Exception('HTTP ${response.statusCode} en capa $layerId');
    }
  }

  static String _normalizarTexto(String? text) {
    if (text == null || text.trim().isEmpty) return '';
    var s = text.toUpperCase().trim();
    const withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÌÍÎÏìíîïÙÚÛÜùúûüÑñÇç';
    const withoutDia = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeIIIIiiiiUUUUuuuuNnCc';
    for (int i = 0; i < withDia.length; i++) {
      s = s.replaceAll(withDia[i], withoutDia[i]);
    }
    return s;
  }

  /// Búsqueda inteligente por texto con tokenización, soporte de abreviaturas y ArcGIS MapServer
  static Future<List<MininterComisariaModel>> buscarPorTexto(
    String query, {
    String? departamento,
    String? distrito,
    double? userLat,
    double? userLng,
  }) async {
    final rawNorm = _normalizarTexto(query);
    if (rawNorm.isEmpty && (distrito == null || distrito.isEmpty)) return [];

    var clean = rawNorm;
    clean = clean.replaceAll(RegExp(r'\bS\.?M\.?\b|\bS\s+M\b'), 'SANTA MARIA');
    clean = clean.replaceAll(RegExp(r'\bS\.?J\.?\b|\bS\s+J\b'), 'SAN JUAN');
    clean = clean.replaceAll(RegExp(r'\b(COMISARIA|COMISARÍA|CPNP|PNP|SEC|SECTORIAL|FAMILIA|DEPINCRI|DIVPOL|REGPOL|SUBURBANA|TURISMO|RURAL|URBANA|DE|DEL|LA|EL|LOS|LAS)\b'), ' ');
    clean = clean.replaceAll(RegExp(r'\s+["\x27]?[A-E]["\x27]?$'), '');
    clean = clean.replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ');
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();

    final tokens = clean.split(' ').where((w) => w.length >= 4).toList();

    List<MininterComisariaModel> coms = [];

    // Helper interno para consultar ArcGIS MapServer
    Future<List<MininterComisariaModel>> queryArcgis(String term) async {
      if (term.trim().isEmpty) return [];
      final encoded = Uri.encodeComponent(term.trim().toUpperCase());
      final whereClause = "UPPER(comisaria) LIKE '%$encoded%' OR UPPER(distrito) LIKE '%$encoded%'";
      final url = Uri.parse(
        '$_baseUrl/5/query?'
        'where=$whereClause&'
        'outFields=*&'
        'outSR=4326&'
        'resultRecordCount=25&'
        'f=pjson',
      );
      try {
        final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final features = (data['features'] as List<dynamic>?) ?? [];
          return features
              .map((f) => MininterComisariaModel.fromArcgisFeature(
                    f as Map<String, dynamic>,
                    esFamilia: false,
                  ))
              .where((c) {
                final upper = c.nombre.toUpperCase().trim();
                return upper != 'COMISARÍA DE FAMILIA ANDAHUAYLAS' &&
                       upper != 'COMISARIA DE FAMILIA ANDAHUAYLAS';
              })
              .toList();
        }
      } catch (e) {
        debugPrint('⚠️ [MININTER-GEO] Error buscando término "$term": $e');
      }
      return [];
    }

    // 1. Intento por término limpio completo
    if (clean.isNotEmpty) {
      coms = await queryArcgis(clean);
    }

    // 2. Si no hubo resultados, probar con los tokens distintivos principales (ej. "CHICMO")
    if (coms.isEmpty && tokens.isNotEmpty) {
      for (final t in tokens.reversed) {
        coms = await queryArcgis(t);
        if (coms.isNotEmpty) break;
      }
    }

    // 3. Si aún no hay resultados y viene distrito
    if (coms.isEmpty && distrito != null && distrito.trim().isNotEmpty) {
      final distTokens = _normalizarTexto(distrito)
          .replaceAll(RegExp(r'\b(DISTRITO|DE|DEL|LA|EL|SAN|SANTA)\b'), ' ')
          .replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .split(' ')
          .where((t) => t.length >= 4);
      for (final dt in distTokens) {
        coms = await queryArcgis(dt);
        if (coms.isNotEmpty) break;
      }
    }

    // 4. Si se especificó departamento, ordenar priorizando el departamento correcto
    if (departamento != null && departamento.trim().isNotEmpty) {
      final depNorm = _normalizarTexto(departamento);
      coms.sort((a, b) {
        final aMatch = _normalizarTexto(a.departamento).contains(depNorm) ? 0 : 1;
        final bMatch = _normalizarTexto(b.departamento).contains(depNorm) ? 0 : 1;
        return aMatch.compareTo(bMatch);
      });
    }

    if (userLat != null && userLng != null) {
      for (final c in coms) {
        c.calcularMetricas(userLat, userLng);
      }
      if (departamento == null || departamento.trim().isEmpty) {
        coms.sort((a, b) => (a.distanciaMetros ?? 0).compareTo(b.distanciaMetros ?? 0));
      }
    }

    return deduplicarPorProximidadEspacial(coms);
  }

  /// Consulta comisarías por Departamento (Modo fallback o sin GPS)
  static Future<List<MininterComisariaModel>> buscarPorDepartamento(
    String departamento, {
    double? userLat,
    double? userLng,
  }) async {
    final clean = departamento.trim().toUpperCase();
    final whereClause = Uri.encodeComponent("UPPER(departamento)='$clean'");

    final url = Uri.parse(
      '$_baseUrl/5/query?'
      'where=$whereClause&'
      'outFields=*&'
      'outSR=4326&'
      'resultRecordCount=50&'
      'f=pjson',
    );

    try {
      final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final features = (data['features'] as List<dynamic>?) ?? [];

        final coms = features
            .map((f) => MininterComisariaModel.fromArcgisFeature(
                  f as Map<String, dynamic>,
                  esFamilia: false,
                ))
            .where((c) {
              final upper = c.nombre.toUpperCase().trim();
              return upper != 'COMISARÍA DE FAMILIA ANDAHUAYLAS' &&
                     upper != 'COMISARIA DE FAMILIA ANDAHUAYLAS';
            })
            .toList();

        if (userLat != null && userLng != null) {
          for (final c in coms) {
            c.calcularMetricas(userLat, userLng);
          }
          coms.sort((a, b) => (a.distanciaMetros ?? 0).compareTo(b.distanciaMetros ?? 0));
        }

        return deduplicarPorProximidadEspacial(coms);
      }
    } catch (e) {
      debugPrint('⚠️ [MININTER-GEO] Error buscando por departamento: $e');
    }
    return [];
  }

  /// Comisarías de respaldo para garantizar que el usuario nunca vea la pantalla vacía
  static List<MininterComisariaModel> _getFallbackComisarias({
    double? userLat,
    double? userLng,
    TipoComisaria? filtroTipo,
  }) {
    final fallbacks = [
      MininterComisariaModel(
        id: 'fb_1',
        nombre: 'CPNP ALFONSO UGARTE',
        tipo: TipoComisaria.comisaria,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'CERCADO DE LIMA',
        latitud: -12.057039,
        longitud: -77.041554,
        direccion: 'Av. Alfonso Ugarte Cdra. 13',
        telefono: '01 423-1808',
      ),
      MininterComisariaModel(
        id: 'fb_depincri',
        nombre: 'DEPINCRI CERCADO DE LIMA',
        tipo: TipoComisaria.depincri,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'CERCADO DE LIMA',
        latitud: -12.0545,
        longitud: -77.0375,
        direccion: 'Jr. Chota 1420',
        telefono: '01 431-8134',
      ),
      MininterComisariaModel(
        id: 'fb_fam',
        nombre: 'CPNP FAMILIA DEL MINISTERIO DE LA MUJER',
        tipo: TipoComisaria.familia,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'CERCADO DE LIMA',
        latitud: -12.046374,
        longitud: -77.042793,
        direccion: 'Jr. Camaná 616 (MIMP)',
        telefono: '01 626-1600',
      ),
      MininterComisariaModel(
        id: 'fb_transito',
        nombre: 'DIVISIÓN DE TRÁNSITO Y SEGURIDAD VIAL PNP LIMA',
        tipo: TipoComisaria.transito,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'LIMA',
        latitud: -12.0665,
        longitud: -77.0345,
        direccion: 'Av. 28 de Julio con Petit Thouars',
        telefono: '01 433-4411',
      ),
      MininterComisariaModel(
        id: 'fb_emergencia',
        nombre: 'CENTRAL 105 - ESCUADRÓN DE EMERGENCIA PNP',
        tipo: TipoComisaria.otras,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'CERCADO DE LIMA',
        latitud: -12.0565,
        longitud: -77.0385,
        direccion: 'Av. España 323',
        telefono: '105',
      ),
      MininterComisariaModel(
        id: 'fb_4',
        nombre: 'CPNP MIRAFLORES',
        tipo: TipoComisaria.comisaria,
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'MIRAFLORES',
        latitud: -12.121544,
        longitud: -77.029851,
        direccion: 'Calle Gral. Borgoño 1065',
        telefono: '01 445-5680',
      ),
    ];

    List<MininterComisariaModel> result = fallbacks;
    if (filtroTipo != null) {
      result = result.where((c) => c.tipo == filtroTipo).toList();
    }

    if (userLat != null && userLng != null) {
      for (final c in result) {
        c.calcularMetricas(userLat, userLng);
      }
      result.sort((a, b) => (a.distanciaMetros ?? 0).compareTo(b.distanciaMetros ?? 0));
    }

    return deduplicarPorProximidadEspacial(result.isNotEmpty ? result : fallbacks);
  }

  /// Consulta el trazado de recorrido real por calles, esquinas y avenidas (OSRM Routing)
  static Future<RutaCallejeraModel?> obtenerRutaPorCalles({
    required double latOrigen,
    required double lngOrigen,
    required double latDestino,
    required double lngDestino,
    bool modoAuto = true,
  }) async {
    final perfil = modoAuto ? 'driving' : 'foot';
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/$perfil/'
      '$lngOrigen,$latOrigen;$lngDestino,$latDestino'
      '?overview=full&geometries=geojson&steps=true',
    );

    try {
      final response = await http
          .get(url, headers: {'User-Agent': 'AlertaDesaparecidosPNP/1.0'})
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if (data['code'] == 'Ok') {
          final routes = data['routes'] as List<dynamic>?;
          if (routes != null && routes.isNotEmpty) {
            final route = routes.first as Map<String, dynamic>;
            final geometry = route['geometry'] as Map<String, dynamic>?;
            final coordinates = (geometry?['coordinates'] as List<dynamic>?) ?? [];

            final List<LatLng> puntos = [];
            for (final coord in coordinates) {
              if (coord is List && coord.length >= 2) {
                final lng = (coord[0] as num).toDouble();
                final lat = (coord[1] as num).toDouble();
                puntos.add(LatLng(lat, lng));
              }
            }

            final dist = (route['distance'] as num?)?.toDouble() ?? 0.0;
            final dur = (route['duration'] as num?)?.toDouble() ?? 0.0;

            String vias = '';
            final List<PasoRuta> pasos = [];
            final legs = route['legs'] as List<dynamic>?;
            if (legs != null && legs.isNotEmpty) {
              final leg = legs.first as Map<String, dynamic>;
              vias = (leg['summary'] as String?) ?? '';
              final stepsList = (leg['steps'] as List<dynamic>?) ?? [];
              for (final s in stepsList) {
                if (s is Map<String, dynamic>) {
                  final sName = (s['name'] as String?) ?? '';
                  final sDist = (s['distance'] as num?)?.toDouble() ?? 0.0;
                  final maneuver = s['maneuver'] as Map<String, dynamic>?;
                  final mType = maneuver?['type'] as String? ?? '';
                  final mMod = maneuver?['modifier'] as String? ?? '';

                  String instr;
                  if (mType == 'depart') {
                    instr = sName.isNotEmpty ? 'Inicia en $sName' : 'Inicia tu recorrido';
                  } else if (mType == 'arrive') {
                    instr = 'Llegada a la comisaría';
                  } else if (mType == 'turn') {
                    if (mMod.contains('left')) {
                      instr = 'Gira a la izquierda en ${sName.isNotEmpty ? sName : 'la calle'}';
                    } else if (mMod.contains('right')) {
                      instr = 'Gira a la derecha en ${sName.isNotEmpty ? sName : 'la calle'}';
                    } else {
                      instr = 'Gira en ${sName.isNotEmpty ? sName : 'la esquina'}';
                    }
                  } else if (mType.contains('rotary') || mType.contains('roundabout')) {
                    instr = 'En la rotonda toma la salida hacia ${sName.isNotEmpty ? sName : 'la avenida'}';
                  } else {
                    instr = sName.isNotEmpty ? 'Continúa por $sName' : 'Continúa recto';
                  }

                  if (sDist > 5 || mType == 'arrive') {
                    pasos.add(PasoRuta(
                      instruccion: instr,
                      distanciaMetros: sDist,
                      nombreCalle: sName,
                    ));
                  }
                }
              }
            }

            if (puntos.isNotEmpty) {
              return RutaCallejeraModel(
                puntos: puntos,
                distanciaMetros: dist,
                duracionSegundos: dur,
                viasPrincipales: vias,
                pasos: pasos,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [RUTEO-CALLES] No se pudo obtener ruta detallada por calles: $e');
    }
    return null;
  }
}

