import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../common/constants/gemini_constants.dart';
import '../data/models/comisaria_model.dart';
import 'gemini_extractor_service.dart';

/// Resultado del matching y resolución de comisaría territorial
class ComisariaMatchResult {
  final String nombreOficial;
  final String telefono;
  final String telefonoLimpio;
  final bool tieneTelefonoDirecto;
  final String direccion;
  final String distrito;
  final String provincia;
  final String departamento;
  final String unidadPolicial;
  final String tipoCoincidencia;
  final String? explicacionIa;

  const ComisariaMatchResult({
    required this.nombreOficial,
    required this.telefono,
    required this.telefonoLimpio,
    required this.tieneTelefonoDirecto,
    required this.direccion,
    required this.distrito,
    required this.provincia,
    required this.departamento,
    required this.unidadPolicial,
    required this.tipoCoincidencia,
    this.explicacionIa,
  });

  /// Teléfono formateado para mostrar en UI
  String get telefonoDisplay {
    if (!tieneTelefonoDirecto) {
      return 'Central 105 / Línea 114';
    }
    return telefono;
  }

  /// Mensaje de orientación si no tiene teléfono
  String get textoAvisoLlamada {
    if (!tieneTelefonoDirecto) {
      return 'Esta dependencia no registra celular directo. Se comunicará con la Línea 114 PNP.';
    }
    return 'Llamando a la guardia de $nombreOficial...';
  }
}

/// Servicio singleton de resolución inteligente de comisarías con IA Gemini y catálogo nacional oficial
class ComisariaMatcherService {
  static List<ComisariaModel>? _catalogoComisarias;
  static bool _isLoading = false;

  /// Cache en memoria de resoluciones para 0ms de latencia en peticiones repetidas
  static final Map<String, ComisariaMatchResult> _cacheResoluciones = {};

  /// Lista exhaustiva de unidades policiales especiales y divisiones que NO son comisarías territoriales
  static final List<String> _unidadesNoTerritoriales = [
    'DIVOPUS',
    'DIVPOL',
    'DIRITPTIM',
    'DIVINTRAP',
    'DIRCTPTIM',
    'DEPINCRI',
    'DIVINCRI',
    'SECINCRI',
    'DIVINRAP',
    'DIVBUS',
    'DIRINCRI',
    'FAMILIA',
    'TRANSITO',
    'TRÁNSITO',
    'VIAL',
    'ROBO DE VEHICULOS',
    'ROBO DE VEHÍCULOS',
    'DIROVE',
    'DEPROVE',
    'EMERGENCIA',
    'ESCUADRON DE EMERGENCIA',
    'ESCUADRÓN DE EMERGENCIA',
    'TURISMO',
    'OPERACIONES',
    'CENTRAL DE OPERACIONES',
    'RADIO PATRULLA',
    'MEDIO AMBIENTE',
    'EXTRANJERIA',
    'EXTRANJERÍA',
    'SEGURIDAD DEL ESTADO',
    'ANTIDROGAS',
    'DEPANDRO',
    'DIRANDRO',
    'CARRETERAS',
    'DESPRCAR',
  ];

  static const List<String> _departamentosPeru = [
    'MADRE DE DIOS', 'SAN MARTIN', 'LA LIBERTAD', 'AMAZONAS', 'ANCASH',
    'APURIMAC', 'AREQUIPA', 'AYACUCHO', 'CAJAMARCA', 'CALLAO', 'CUSCO',
    'HUANCAVELICA', 'HUANUCO', 'ICA', 'JUNIN', 'LAMBAYEQUE', 'LIMA',
    'LORETO', 'MOQUEGUA', 'PASCO', 'PIURA', 'PUNO', 'TACNA', 'TUMBES', 'UCAYALI'
  ];

  static const Set<String> _stopwords = {
    'DE', 'DEL', 'LA', 'EL', 'LOS', 'LAS', 'Y', 'EN', 'SAN', 'SANTA', 'SANTO',
    'NUEVA', 'NUEVO', 'ALTO', 'BAJO', 'CENTRO', 'NORTE', 'SUR', 'ESTE', 'OESTE',
    'GRAN', 'VILLA'
  };

  /// Carga inicial e indexación en memoria del catálogo oficial
  static Future<void> inicializar() async {
    if (_catalogoComisarias != null) return;
    if (_isLoading) return;
    _isLoading = true;

    try {
      final jsonString = await rootBundle.loadString('assets/data/comisarias_nacional.json');
      final List<dynamic> list = json.decode(jsonString);
      _catalogoComisarias = list
          .map((item) => ComisariaModel.fromMap(item as Map<String, dynamic>))
          .toList();
      debugPrint('👮 [ComisariaMatcherService] ${_catalogoComisarias!.length} comisarías oficiales indexadas a nivel nacional');
    } catch (e) {
      debugPrint('⚠️ [ComisariaMatcherService] Error cargando catálogo de comisarías: $e');
      _catalogoComisarias = [];
    } finally {
      _isLoading = false;
    }
  }

  /// Retorna el catálogo completo cargado
  static List<ComisariaModel> get catalogoComisarias => _catalogoComisarias ?? [];

  /// Calcula la distancia matemática geodésica (Haversine) entre dos coordenadas en metros
  static double calcularDistanciaMetros(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742000 * math.asin(math.sqrt(a)); // 2 * R (6371000 m)
  }

  /// Búsqueda geoespacial por coordenadas GPS del usuario (comisarías más cercanas reales)
  static Future<List<ComisariaModel>> buscarComisariasMasCercanas({
    required double userLat,
    required double userLng,
    int limit = 3,
  }) async {
    await inicializar();
    final list = _catalogoComisarias ?? [];
    if (list.isEmpty) return [];

    final List<ComisariaModel> conDistancia = [];

    for (final c in list) {
      if (c.latitud == null || c.longitud == null) continue;
      // Excluir dependencias no territoriales
      if (!esComisariaTerritorialValida(c)) continue;

      final dist = calcularDistanciaMetros(userLat, userLng, c.latitud!, c.longitud!);
      // Crear copia con distancia asignada
      final item = c.copyWith(distanciaMetros: dist);
      item.distanciaMetros = dist;
      conDistancia.add(item);
    }

    conDistancia.sort((a, b) => (a.distanciaMetros ?? double.infinity).compareTo(b.distanciaMetros ?? double.infinity));
    return conDistancia.take(limit).toList();
  }

  /// Búsqueda inteligente de comisarías por texto para el asistente conversacional
  static Future<List<ComisariaModel>> buscarComisariasPorTexto(String query, {int limit = 4, double? userLat, double? userLng}) async {
    await inicializar();
    if (query.trim().isEmpty) return [];

    // Limpiar palabras funcionales y de consulta
    String qLimpia = query.replaceAll(
      RegExp(r'\b(comisaria|comisaría|cpnp|pnp|delegacion|delegación|estacion|estación|donde|dónde|queda|ubicada|direccion|dirección|telefono|teléfono|de|del|la|el|en|cual|cuál|es|por|favor)\b', caseSensitive: false),
      ' ',
    ).trim();

    if (qLimpia.isEmpty) {
      qLimpia = query;
    }

    final q = normalizar(qLimpia);
    final tokens = q.split(RegExp(r'[^A-Z0-9]+')).where((t) => t.length > 2 && !_stopwords.contains(t)).toList();
    if (tokens.isEmpty && q.length < 3) return [];

    final list = _catalogoComisarias ?? [];
    final scored = <MapEntry<ComisariaModel, int>>[];

    for (final c in list) {
      final nom = normalizar(c.nombre);
      final dist = normalizar(c.distrito);
      final prov = normalizar(c.provincia);
      final dep = normalizar(c.departamento);
      final dir = normalizar(c.direccion);

      int score = 0;
      if (nom.contains(q)) score += 120;
      if (dist == q || dist.contains(q)) score += 90;
      if (prov == q || prov.contains(q)) score += 50;

      for (final t in tokens) {
        if (nom.contains(t)) score += 40;
        if (dist.contains(t)) score += 35;
        if (prov.contains(t)) score += 20;
        if (dep.contains(t)) score += 10;
        if (dir.contains(t)) score += 15;
      }

      if (score >= 40) {
        // Calcular distancia si tenemos coordenadas del usuario
        if (userLat != null && userLng != null && c.latitud != null && c.longitud != null) {
          c.distanciaMetros = calcularDistanciaMetros(userLat, userLng, c.latitud!, c.longitud!);
        }
        scored.add(MapEntry(c, score));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
  }

  /// Verifica si una dependencia es estrictamente una comisaría territorial
  static bool esComisariaTerritorialValida(ComisariaModel c) {
    final nom = normalizar(c.nombre);
    if (nom.contains('ALGARROBOS')) return true; // Salvaguarda Comisaría Los Algarrobos
    for (final bad in _unidadesNoTerritoriales) {
      if (nom.contains(normalizar(bad))) {
        return false;
      }
    }
    return true;
  }

  /// Remueve tildes, caracteres diacríticos y homologa variantes de ortografía nacional (Nazca/Nasca, Cuzco/Cusco)
  static String normalizar(String? text) {
    if (text == null || text.trim().isEmpty) return '';
    var s = text.toUpperCase().trim();
    const withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÌÍÎÏìíîïÙÚÛÜùúûüÑñÇç';
    const withoutDia = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeIIIIiiiiUUUUuuuuNnCc';
    for (int i = 0; i < withDia.length; i++) {
      s = s.replaceAll(withDia[i], withoutDia[i]);
    }
    s = s.replaceAll(RegExp(r'\bNAZCA\b'), 'NASCA');
    s = s.replaceAll(RegExp(r'\bCUZCO\b'), 'CUSCO');
    return s;
  }

  /// Expande abreviaturas policiales y territoriales habituales
  static String expandirAbreviaturas(String? text) {
    if (text == null || text.trim().isEmpty) return '';
    var s = normalizar(text);
    s = s.replaceAll(RegExp(r'\bS\.?M\.?\b|\bS\s+M\b'), 'SANTA MARIA SAN MIGUEL');
    s = s.replaceAll(RegExp(r'\bS\.?J\.?\b|\bS\s+J\b'), 'SAN JUAN');
    s = s.replaceAll(RegExp(r'\bS\.?A\.?\b|\bS\s+A\b'), 'SAN ANTONIO');
    s = s.replaceAll(RegExp(r'\bS\.?P\.?\b|\bS\s+P\b'), 'SAN PEDRO');
    s = s.replaceAll(RegExp(r'\bS\.?F\.?\b|\bS\s+F\b'), 'SAN FRANCISCO');
    s = s.replaceAll(RegExp(r'\bSTA\.?\b'), 'SANTA');
    s = s.replaceAll(RegExp(r'\bSTO\.?\b'), 'SANTO');
    s = s.replaceAll(RegExp(r'\bSN\.?\b'), 'SAN');
    return s;
  }

  /// Detecta si el texto de la unidad nombra explícitamente un departamento policial (ej. REGPOL - MADRE DE DIOS)
  static String? detectarDepartamentoUnidad(String? unidad) {
    if (unidad == null || unidad.trim().isEmpty) return null;
    final u = normalizar(unidad);
    for (final dep in _departamentosPeru) {
      if (RegExp(r'\b' + RegExp.escape(dep) + r'\b').hasMatch(u)) {
        return dep;
      }
    }
    if (u.contains('LIMA CENTRO') ||
        u.contains('LIMA NORTE') ||
        u.contains('LIMA SUR') ||
        u.contains('LIMA ESTE') ||
        u.contains('DIVPOL CENTRO') ||
        u.contains('DIVPOL SUR') ||
        u.contains('DIVPOL NORTE') ||
        u.contains('DIVPOL OESTE')) {
      return 'LIMA';
    }
    return null;
  }

  /// Extrae con alta fidelidad todos los tokens significativos de una comisaría
  static Set<String> extraerTodosTokensComisaria(String? text) {
    if (text == null || text.trim().isEmpty) return {};
    final s = expandirAbreviaturas(text);
    final match = RegExp(r'\b(?:COMISARIA|COMISARÍA|CPNP)\s+(.+)', caseSensitive: false).firstMatch(s);
    var sub = match != null ? match.group(1)! : s;
    // Solo remover la categoría/letra [A-E] al final del texto o comillas finales
    sub = sub.replaceAll(RegExp(r'[\s"\x27]+[A-E]["\x27]?\s*$'), '');
    sub = sub.replaceAll(
      RegExp(r'\b(SEC|SECTORIAL|SUBURBANA|RURAL|URBANA|DIVPOL|REGPOL|DIVOPUS|REGION|POLICIAL|PNP)\b'),
      ' ',
    );
    sub = sub.replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ');
    return sub
        .split(' ')
        .where((t) => t.length >= 3 && !_stopwords.contains(t))
        .toSet();
  }

  /// Extrae el nombre de la comisaría si está explícitamente nombrada en la unidad o reporte
  static String extraerNombreComisariaEspecifica(String? text) {
    final tokens = extraerTodosTokensComisaria(text);
    return tokens.join(' ');
  }

  /// Extrae tokens léxicos significativos de la comisaría
  static Set<String> extraerTokens(String? text) {
    return extraerTodosTokensComisaria(text);
  }

  /// Resuelve la comisaría territorial a cargo combinando IA Gemini con fallback determinístico ultra robusto
  static Future<ComisariaMatchResult?> resolverComisaria({
    required String? unidadACargo,
    String? departamento,
    String? provincia,
    String? distrito,
    String? detallesAdicionales,
    bool usarIaSiDisponible = true,
  }) async {
    await inicializar();
    if (_catalogoComisarias == null || _catalogoComisarias!.isEmpty) {
      return null;
    }

    final cacheKey =
        '${unidadACargo ?? ""}|${departamento ?? ""}|${provincia ?? ""}|${distrito ?? ""}|${detallesAdicionales ?? ""}';
    if (_cacheResoluciones.containsKey(cacheKey)) {
      return _cacheResoluciones[cacheKey];
    }

    // 1. Catálogo filtrado ESTRICTAMENTE por comisarías territoriales
    final List<ComisariaModel> candidatosValidos =
        _catalogoComisarias!.where(esComisariaTerritorialValida).toList();

    if (candidatosValidos.isEmpty) {
      return null;
    }

    // 2. Extraer unidad real de detalles adicionales si unidadACargo viene genérica
    String targetUnidad = unidadACargo ?? '';
    if (targetUnidad.isEmpty ||
        targetUnidad.toLowerCase().contains('policía nacional') ||
        targetUnidad.toLowerCase().contains('policia nacional') ||
        targetUnidad.toLowerCase().contains('división de búsqueda')) {
      if (detallesAdicionales != null && detallesAdicionales.isNotEmpty) {
        final regExpCom = RegExp(r'Comisar[ií]a:\s*([^.\n]+)', caseSensitive: false);
        final matchCom = regExpCom.firstMatch(detallesAdicionales);
        if (matchCom != null && matchCom.group(1)?.trim().isNotEmpty == true) {
          targetUnidad = matchCom.group(1)!.trim();
        } else {
          final regExpJur = RegExp(r'Jurisdicci[oó]n:\s*([^.\n]+)', caseSensitive: false);
          final matchJur = regExpJur.firstMatch(detallesAdicionales);
          if (matchJur != null && matchJur.group(1)?.trim().isNotEmpty == true) {
            targetUnidad = matchJur.group(1)!.trim();
          }
        }
      }
    }

    // 3. Resolución determinística de alta precisión con jerarquía de nota de alerta
    final deterministaResult = _resolverDeterminista(
      candidatos: candidatosValidos,
      targetUnidad: targetUnidad,
      departamento: departamento,
      provincia: provincia,
      distrito: distrito,
    );

    // 4. Integración con IA Gemini para desambiguación si no hubo match de máxima certeza
    if (usarIaSiDisponible &&
        deterministaResult != null &&
        deterministaResult.tipoCoincidencia != 'exacta_nombre_reporte') {
      try {
        final iaResult = await _resolverConGeminiAI(
          unidadACargo: targetUnidad,
          departamento: departamento,
          provincia: provincia,
          distrito: distrito,
          detallesAdicionales: detallesAdicionales,
          candidatosValidos: candidatosValidos,
          fallbackDeterminista: deterministaResult,
        );
        if (iaResult != null) {
          _cacheResoluciones[cacheKey] = iaResult;
          return iaResult;
        }
      } catch (e) {
        debugPrint('⚠️ [ComisariaMatcherService] Gemini AI fallback a determinista: $e');
      }
    }

    if (deterministaResult != null) {
      _cacheResoluciones[cacheKey] = deterministaResult;
    }
    return deterministaResult;
  }

  /// Evalúa un subconjunto de candidatos calculando puntuación por tokens y cercanía geográfica
  static (ComisariaModel?, int) _evaluarCandidatos({
    required List<ComisariaModel> candidatos,
    required Set<String> tokensTarget,
    required bool tieneComisariaExplicita,
    required String distNorm,
    required String provNorm,
  }) {
    ComisariaModel? mejor;
    int mejorScore = -999;

    for (final c in candidatos) {
      int score = 0;
      final cTokens = extraerTodosTokensComisaria(c.nombre);
      final cDistNorm = expandirAbreviaturas(c.distrito);
      final cProvNorm = normalizar(c.provincia);

      if (tieneComisariaExplicita) {
        final comunes = tokensTarget.intersection(cTokens);
        if (comunes.isNotEmpty) {
          if (tokensTarget.length == cTokens.length && comunes.length == tokensTarget.length) {
            score += 500;
          } else if (cTokens.every(tokensTarget.contains) || tokensTarget.every(cTokens.contains)) {
            score += 400;
          } else {
            score += 250;
          }
        }

        for (final t in comunes) {
          if (t.length >= 5) {
            score += 120;
          } else if (t.length >= 4) {
            score += 80;
          } else {
            score += 40;
          }
        }

        if (distNorm.isNotEmpty && cDistNorm == expandirAbreviaturas(distNorm)) {
          score += 40;
        }
        if (provNorm.isNotEmpty && provNorm == cProvNorm) {
          score += 20;
        }
      } else {
        if (distNorm.isNotEmpty) {
          final distExp = expandirAbreviaturas(distNorm);
          if (cDistNorm == distExp) {
            score += 150;
          } else if (cDistNorm.contains(distExp) || distExp.contains(cDistNorm)) {
            score += 100;
          }
        }

        if (provNorm.isNotEmpty && provNorm == cProvNorm) {
          score += 40;
          if (normalizar(c.nombre).contains('SECTORIAL')) {
            score += 30;
          }
        }
      }

      if (score > mejorScore) {
        mejorScore = score;
        mejor = c;
      }
    }

    return (mejor, mejorScore);
  }

  /// Motor determinístico ponderado en cascada nacional:
  /// Nivel 1: Búsqueda en departamento detectado en la propia unidad policial del reporte
  /// Nivel 2: Búsqueda en departamento de desaparición
  /// Nivel 3: Búsqueda a escala nacional si la nota de alerta nombra comisaría explícita
  /// Nivel 4: Asignación territorial distrital / provincial si no había comisaría explícita
  static ComisariaMatchResult? _resolverDeterminista({
    required List<ComisariaModel> candidatos,
    required String targetUnidad,
    String? departamento,
    String? provincia,
    String? distrito,
  }) {
    final depUnidad = detectarDepartamentoUnidad(targetUnidad);
    final depDesap = normalizar(departamento);
    final provNorm = normalizar(provincia);
    final distNorm = normalizar(distrito);

    final tokensTarget = extraerTodosTokensComisaria(targetUnidad);
    final bool esNoTerritorial = _unidadesNoTerritoriales.any(
      (bad) => normalizar(targetUnidad).contains(normalizar(bad)),
    );
    final bool tieneComisariaExplicita = tokensTarget.isNotEmpty &&
        (normalizar(targetUnidad).contains('COMISARIA') ||
            normalizar(targetUnidad).contains('COMISARÍA') ||
            normalizar(targetUnidad).contains('CPNP')) &&
        !esNoTerritorial;

    // 1. Probar primero con el departamento detectado de la unidad a cargo
    if (depUnidad != null && depUnidad.isNotEmpty) {
      final candsUnidad = candidatos.where((c) {
        final cDep = normalizar(c.departamento);
        if (cDep == depUnidad || depUnidad.contains(cDep) || cDep.contains(depUnidad)) return true;
        if ((depUnidad == 'LIMA' || depUnidad == 'CALLAO') && (cDep == 'LIMA' || cDep == 'CALLAO')) return true;
        return false;
      }).toList();

      if (candsUnidad.isNotEmpty) {
        final (cand1, score1) = _evaluarCandidatos(
          candidatos: candsUnidad,
          tokensTarget: tokensTarget,
          tieneComisariaExplicita: tieneComisariaExplicita,
          distNorm: distNorm,
          provNorm: provNorm,
        );
        if (tieneComisariaExplicita && score1 >= 350 && cand1 != null) {
          return _crearResultado(cand1, 'exacta_nombre_reporte');
        }
      }
    }

    // 2. Probar con el departamento de desaparición
    if (depDesap.isNotEmpty) {
      final candsDesap = candidatos.where((c) {
        final cDep = normalizar(c.departamento);
        if (cDep == depDesap || depDesap.contains(cDep) || cDep.contains(depDesap)) return true;
        if ((depDesap == 'LIMA' || depDesap == 'CALLAO') && (cDep == 'LIMA' || cDep == 'CALLAO')) return true;
        return false;
      }).toList();

      if (candsDesap.isNotEmpty) {
        final (cand2, score2) = _evaluarCandidatos(
          candidatos: candsDesap,
          tokensTarget: tokensTarget,
          tieneComisariaExplicita: tieneComisariaExplicita,
          distNorm: distNorm,
          provNorm: provNorm,
        );
        if (tieneComisariaExplicita && score2 >= 350 && cand2 != null) {
          return _crearResultado(cand2, 'exacta_nombre_reporte');
        }
        if (!tieneComisariaExplicita && cand2 != null && score2 >= 50) {
          return _crearResultado(
            cand2,
            score2 >= 100 ? 'exacta_distrital_score' : 'territorial_provincia',
          );
        }
      }
    }

    // 3. Si tiene comisaría explícita y no se encontró a nivel regional, buscar a nivel nacional
    if (tieneComisariaExplicita) {
      final (candNac, scoreNac) = _evaluarCandidatos(
        candidatos: candidatos,
        tokensTarget: tokensTarget,
        tieneComisariaExplicita: true,
        distNorm: distNorm,
        provNorm: provNorm,
      );
      if (scoreNac >= 350 && candNac != null) {
        return _crearResultado(candNac, 'exacta_nombre_reporte');
      }
    }

    // 4. Fallbacks distritales / provinciales
    final candsFallback = depDesap.isNotEmpty
        ? candidatos.where((c) => normalizar(c.departamento) == depDesap).toList()
        : candidatos;

    if (distNorm.isNotEmpty) {
      for (final c in candsFallback) {
        if (normalizar(c.distrito) == distNorm) {
          return _crearResultado(c, 'distrito_jurisdiccional');
        }
      }
    }
    if (provNorm.isNotEmpty) {
      for (final c in candsFallback) {
        if (normalizar(c.provincia) == provNorm) {
          return _crearResultado(c, 'provincia_fallback');
        }
      }
    }
    return _crearResultado(
      candsFallback.isNotEmpty ? candsFallback.first : candidatos.first,
      'departamento_fallback',
    );
  }

  /// Consulta con IA Gemini para identificar la comisaría territorial precisa de la jurisdicción
  static Future<ComisariaMatchResult?> _resolverConGeminiAI({
    required String? unidadACargo,
    required String? departamento,
    required String? provincia,
    required String? distrito,
    required String? detallesAdicionales,
    required List<ComisariaModel> candidatosValidos,
    required ComisariaMatchResult fallbackDeterminista,
  }) async {
    final apiKey = await GeminiExtractorService.getSavedApiKey() ?? GeminiConstants.apiKey;
    if (apiKey.isEmpty) {
      return fallbackDeterminista;
    }

    final depNorm = normalizar(departamento);
    final provNorm = normalizar(provincia);
    final distNorm = normalizar(distrito);

    // Filtrar candidatos para enviar a Gemini (solo dependencias de la región/provincia)
    List<ComisariaModel> candidatosRegion = candidatosValidos.where((c) {
      if (depNorm.isNotEmpty) {
        final cDep = normalizar(c.departamento);
        return cDep.contains(depNorm) || depNorm.contains(cDep);
      }
      return true;
    }).toList();

    if (candidatosRegion.isEmpty) {
      candidatosRegion = candidatosValidos;
    }

    // Ordenar candidatos dando prioridad a los de la misma provincia y distrito
    candidatosRegion.sort((a, b) {
      int scoreA = 0;
      int scoreB = 0;
      if (distNorm.isNotEmpty && normalizar(a.distrito) == distNorm) scoreA += 10;
      if (distNorm.isNotEmpty && normalizar(b.distrito) == distNorm) scoreB += 10;
      if (provNorm.isNotEmpty && normalizar(a.provincia) == provNorm) scoreA += 5;
      if (provNorm.isNotEmpty && normalizar(b.provincia) == provNorm) scoreB += 5;
      return scoreB.compareTo(scoreA);
    });

    // Limitar a máximo 20 candidatos para una respuesta ultrarrápida
    final int takeCount = candidatosRegion.length > 20 ? 20 : candidatosRegion.length;
    final compactCandidates = candidatosRegion.sublist(0, takeCount).map((c) => {
      'id': c.id.toString(),
      'nombre': c.nombre,
      'distrito': c.distrito,
      'provincia': c.provincia,
    }).toList();

    final prompt = '''
Eres el oficial de guardia superior de la Policía Nacional del Perú (PNP), máxima autoridad en asignación territorial de casos.
Tu tarea es emparejar con absoluta precisión qué COMISARÍA TERRITORIAL oficial está a cargo de este caso de desaparición o cuál es la más cercana a la jurisdicción del hecho.

DATOS DE LA DENUNCIA:
- Unidad a cargo reportada: "${unidadACargo ?? 'No especificada'}"
- Ubicación del hecho: Distrito: "$distrito", Provincia: "$provincia", Departamento: "$departamento"
- Detalles / Dirección: "${detallesAdicionales ?? 'Sin detalles adicionales'}"

CATÁLOGO DE COMISARÍAS TERRITORIALES OFICIALES DISPONIBLES:
${json.encode(compactCandidates)}

REGLAS DE ORO OBLIGATORIAS:
1. DEBES elegir EXCLUSIVAMENTE una de las comisarías del catálogo listado arriba.
2. NUNCA selecciones DEPINCRI, ni Comisaría de Familia, ni Tránsito, ni Emergencias.
3. Si la unidad reportada menciona una Comisaría específica, elige ESA comisaría. Si no menciona comisaría o es una unidad de rescate/trata (DIVINTRAP/DIRITPTIM), elige la COMISARÍA TERRITORIAL del distrito o la más cercana de la provincia donde ocurrió el hecho.
4. Devuelve ÚNICAMENTE un objeto JSON válido con este formato:
{"id": "<id exacto del catálogo>", "nombre": "<nombre oficial>", "motivo": "<explicación breve>"}
''';

    for (final modelName in GeminiConstants.fallbackModels) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.1,
          ),
        );

        final response = await model.generateContent([
          Content.text(prompt),
        ]).timeout(const Duration(milliseconds: 3800));

        final text = response.text?.trim() ?? '';
        if (text.isNotEmpty) {
          String cleanJson = text;
          if (cleanJson.startsWith('```json')) {
            cleanJson = cleanJson.substring(7);
          }
          if (cleanJson.endsWith('```')) {
            cleanJson = cleanJson.substring(0, cleanJson.length - 3);
          }
          final decoded = json.decode(cleanJson.trim());
          final String? idRes = decoded['id']?.toString();
          final String? nomRes = decoded['nombre']?.toString();
          final String? motivo = decoded['motivo']?.toString();

          ComisariaModel? elegida;
          if (idRes != null && idRes.isNotEmpty) {
            elegida = candidatosRegion.firstWhere(
              (c) => c.id.toString() == idRes,
              orElse: () => candidatosRegion.firstWhere(
                (c) => normalizar(c.nombre) == normalizar(nomRes),
                orElse: () => candidatosRegion.first,
              ),
            );
          }

          if (elegida != null && esComisariaTerritorialValida(elegida)) {
            debugPrint('🤖 [ComisariaMatcherService] Gemini IA seleccionó: ${elegida.nombre} ($motivo)');
            return _crearResultado(elegida, 'ia_gemini_territorial', explicacion: motivo);
          }
        }
        break;
      } catch (e) {
        debugPrint('⚠️ [ComisariaMatcherService] Modelo $modelName falló o timeout: $e');
        if (e.toString().contains('FormatException') ||
            e.toString().contains('SocketException') ||
            e.toString().contains('ClientException') ||
            e.toString().contains('HandshakeException')) {
          break;
        }
      }
    }

    return fallbackDeterminista;
  }

  /// Limpia un número telefónico removiendo símbolos y tomando el primer número disponible
  static String limpiarTelefono(String? tel) {
    if (tel == null) return '';
    final primerNum = tel.split(RegExp(r'[/,;]')).first;
    return primerNum.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static ComisariaMatchResult _crearResultado(
    ComisariaModel c,
    String tipo, {
    String? explicacion,
  }) {
    final telLimpio = limpiarTelefono(c.telefono);
    final tieneTel = telLimpio.length >= 6;

    return ComisariaMatchResult(
      nombreOficial: c.nombre,
      telefono: c.telefono.trim(),
      telefonoLimpio: telLimpio,
      tieneTelefonoDirecto: tieneTel,
      direccion: c.direccion.trim().isNotEmpty
          ? c.direccion.trim()
          : 'Jurisdicción Policial de ${c.distrito}',
      distrito: c.distrito,
      provincia: c.provincia,
      departamento: c.departamento,
      unidadPolicial: c.unidad,
      tipoCoincidencia: tipo,
      explicacionIa: explicacion,
    );
  }
}
