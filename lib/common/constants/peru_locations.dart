/// Lista de Departamentos y Provincias del Perú para registro ciudadano
class PeruLocations {
  static const Map<String, List<String>> departamentosYProvincias = {
    'AMAZONAS': [
      'Chachapoyas',
      'Bagua',
      'Bongará',
      'Condorcanqui',
      'Luya',
      'Rodríguez de Mendoza',
      'Utcubamba',
    ],
    'ÁNCASH': [
      'Huaraz',
      'Aija',
      'Antonio Raymondi',
      'Asunción',
      'Bolognesi',
      'Carhuaz',
      'Carlos Fermín Fitzcarrald',
      'Casma',
      'Corongo',
      'Huari',
      'Huarmey',
      'Huaylas',
      'Mariscal Luzuriaga',
      'Ocros',
      'Pallasca',
      'Pomabamba',
      'Recuay',
      'Santa',
      'Sihuas',
      'Yungay',
    ],
    'APURÍMAC': [
      'Abancay',
      'Andahuaylas',
      'Antabamba',
      'Aymaraes',
      'Cotabambas',
      'Chincheros',
      'Grau',
    ],
    'AREQUIPA': [
      'Arequipa',
      'Camaná',
      'Caravelí',
      'Castilla',
      'Caylloma',
      'Condesuyos',
      'Islay',
      'La Unión',
    ],
    'AYACUCHO': [
      'Huamanga',
      'Cangallo',
      'Huanca Sancos',
      'Huanta',
      'La Mar',
      'Lucanas',
      'Parinacochas',
      'Páucar del Sara Sara',
      'Sucre',
      'Víctor Fajardo',
      'Vilcas Huamán',
    ],
    'CAJAMARCA': [
      'Cajamarca',
      'Cajabamba',
      'Celendín',
      'Chota',
      'Contumazá',
      'Cutervo',
      'Hualgayoc',
      'Jaén',
      'San Ignacio',
      'San Marcos',
      'San Miguel',
      'San Pablo',
      'Santa Cruz',
    ],
    'CALLAO': [
      'Callao',
    ],
    'CUSCO': [
      'Cusco',
      'Acomayo',
      'Anta',
      'Calca',
      'Canas',
      'Canchis',
      'Chumbivilcas',
      'Espinar',
      'La Convención',
      'Paruro',
      'Paucartambo',
      'Quispicanchi',
      'Urubamba',
    ],
    'HUANCAVELICA': [
      'Huancavelica',
      'Acobamba',
      'Angaraes',
      'Castrovirreyna',
      'Churcampa',
      'Huaytará',
      'Tayacaja',
    ],
    'HUÁNUCO': [
      'Huánuco',
      'Ambo',
      'Dos de Mayo',
      'Huacaybamba',
      'Huamalíes',
      'Leoncio Prado',
      'Marañón',
      'Pachitea',
      'Puerto Inca',
      'Lauricocha',
      'Yarowilca',
    ],
    'ICA': [
      'Ica',
      'Chincha',
      'Nazca',
      'Palpa',
      'Pisco',
    ],
    'JUNÍN': [
      'Huancayo',
      'Concepción',
      'Chanchamayo',
      'Jauja',
      'Junín',
      'Satipo',
      'Tarma',
      'Yauli',
      'Chupaca',
    ],
    'LA LIBERTAD': [
      'Trujillo',
      'Ascope',
      'Bolívar',
      'Chepén',
      'Julcán',
      'Otuzco',
      'Pacasmayo',
      'Pataz',
      'Sánchez Carrión',
      'Santiago de Chuco',
      'Gran Chimú',
      'Virú',
    ],
    'LAMBAYEQUE': [
      'Chiclayo',
      'Ferreñafe',
      'Lambayeque',
    ],
    'LIMA': [
      'Lima',
      'Barranca',
      'Cajatambo',
      'Canta',
      'Cañete',
      'Huaral',
      'Huarochirí',
      'Huaura',
      'Oyón',
      'Yauyos',
    ],
    'LORETO': [
      'Maynas',
      'Alto Amazonas',
      'Loreto',
      'Mariscal Ramón Castilla',
      'Requena',
      'Ucayali',
      'Datem del Marañón',
      'Putumayo',
    ],
    'MADRE DE DIOS': [
      'Tambopata',
      'Manu',
      'Tahuamanu',
    ],
    'MOQUEGUA': [
      'Mariscal Nieto',
      'General Sánchez Cerro',
      'Ilo',
    ],
    'PASCO': [
      'Pasco',
      'Daniel Alcides Carrión',
      'Oxapampa',
    ],
    'PIURA': [
      'Piura',
      'Ayabaca',
      'Huancabamba',
      'Morropón',
      'Paita',
      'Sullana',
      'Talara',
      'Sechura',
    ],
    'PUNO': [
      'Puno',
      'Azángaro',
      'Carabaya',
      'Chucuito',
      'El Collao',
      'Huancané',
      'Lampa',
      'Melgar',
      'Moho',
      'San Antonio de Putina',
      'San Román',
      'Sandia',
      'Yunguyo',
    ],
    'SAN MARTÍN': [
      'Moyobamba',
      'Bellavista',
      'El Dorado',
      'Huallaga',
      'Lamas',
      'Mariscal Cáceres',
      'Picota',
      'Rioja',
      'San Martín',
      'Tocache',
    ],
    'TACNA': [
      'Tacna',
      'Candarave',
      'Jorge Basadre',
      'Tarata',
    ],
    'TUMBES': [
      'Tumbes',
      'Contralmirante Villar',
      'Zarumilla',
    ],
    'UCAYALI': [
      'Coronel Portillo',
      'Atalaya',
      'Padre Abad',
      'Purús',
    ],
  };

  static List<String> get departamentos => departamentosYProvincias.keys.toList();

  /// Normaliza texto removiendo acentos y pasando a mayúsculas
  static String normalize(String text) {
    var result = text.trim().toUpperCase();
    const map = {
      'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U',
      'á': 'A', 'é': 'E', 'í': 'I', 'ó': 'O', 'ú': 'U', 'ü': 'U',
    };
    map.forEach((k, v) => result = result.replaceAll(k, v));
    return result;
  }

  /// Retorna la lista de provincias para un departamento, tolerando variaciones con o sin acentos y mayúsculas
  static List<String> getProvincias(String departamento) {
    final trimmed = departamento.trim();
    if (departamentosYProvincias.containsKey(trimmed)) {
      return departamentosYProvincias[trimmed]!;
    }
    final norm = normalize(trimmed);
    for (final entry in departamentosYProvincias.entries) {
      if (normalize(entry.key) == norm) {
        return entry.value;
      }
    }
    return [];
  }

  /// Devuelve el nombre canónico (clave oficial en departamentosYProvincias) de un departamento
  static String? canonicalDepartment(String? dept) {
    if (dept == null) return null;
    var norm = normalize(dept);
    if (norm.isEmpty) return null;

    // Limpiar prefijos comunes
    norm = norm
        .replaceAll(RegExp(r'^DEPARTAMENTO\s+(DE\s+)?'), '')
        .replaceAll(RegExp(r'^REGION\s+(DE\s+)?'), '')
        .replaceAll(RegExp(r'^REGIONAL\s+(DE\s+)?'), '')
        .replaceAll(RegExp(r'^DPTO\.?\s+(DE\s+)?'), '')
        .replaceAll(RegExp(r'^GOBIERNO\s+REGIONAL\s+(DE\s+)?'), '')
        .replaceAll(RegExp(r'^PROVINCIA\s+CONSTITUCIONAL\s+(DEL?\s+)?'), '')
        .trim();

    // Casos especiales de Lima
    if (norm == 'LIMA METROPOLITANA' ||
        norm == 'LIMA PROVINCIAS' ||
        norm == 'MUNICIPALIDAD DE LIMA' ||
        norm == 'LIMA CIUDAD' ||
        norm == 'LIMA REGION' ||
        norm == 'REGION LIMA') {
      return 'LIMA';
    }

    // Coincidencia directa con las claves oficiales
    for (final key in departamentosYProvincias.keys) {
      if (normalize(key) == norm) {
        return key;
      }
    }

    // Coincidencia por palabra completa exacta (evita que "HUANCAVELICA" coincida con "ICA")
    for (final key in departamentosYProvincias.keys) {
      final keyNorm = normalize(key);
      final regex = RegExp(r'\b' + RegExp.escape(keyNorm) + r'\b');
      if (regex.hasMatch(norm)) {
        return key;
      }
    }

    return null;
  }

  /// Obtiene el departamento al que pertenece una provincia
  static String? getDepartmentForProvince(String? provincia) {
    if (provincia == null || provincia.trim().isEmpty) return null;
    final provNorm = normalize(provincia);

    for (final entry in departamentosYProvincias.entries) {
      for (final p in entry.value) {
        if (normalize(p) == provNorm) {
          return entry.key;
        }
      }
    }

    // Búsqueda tolerante por palabra completa
    for (final entry in departamentosYProvincias.entries) {
      for (final p in entry.value) {
        final pNorm = normalize(p);
        final regex = RegExp(r'\b' + RegExp.escape(pNorm) + r'\b');
        if (regex.hasMatch(provNorm)) {
          return entry.key;
        }
      }
    }

    return null;
  }

  /// Verifica si un caso pertenece a un departamento objetivo de forma rigurosa y sin falsos positivos.
  static bool matchesDepartment({
    required String? caseDept,
    required String targetDept,
    String? caseProv,
    String? caseDist,
  }) {
    final cleanTarget = targetDept.trim();
    if (cleanTarget.isEmpty ||
        cleanTarget.toLowerCase() == 'todos' ||
        cleanTarget.toLowerCase() == 'todos los departamentos') {
      return true;
    }

    final canonicalTarget = canonicalDepartment(cleanTarget);
    if (canonicalTarget == null) return true;

    // 1. Si el caso tiene departamento explícito, verificarlo con la forma canónica
    if (caseDept != null && caseDept.trim().isNotEmpty) {
      final canonicalCase = canonicalDepartment(caseDept);
      if (canonicalCase != null) {
        if (canonicalCase == canonicalTarget) return true;
        // Si el caso tiene un departamento canónico diferente al objetivo, NO PERTENECE.
        return false;
      }
    }

    // 2. Si el departamento del caso es nulo o ambiguo, deducirlo a partir de su provincia
    if (caseProv != null && caseProv.trim().isNotEmpty) {
      final deptFromProv = getDepartmentForProvince(caseProv);
      if (deptFromProv != null) {
        return deptFromProv == canonicalTarget;
      }
    }

    // 3. Si no hay departamento ni provincia válidos, no asignar a un departamento específico
    return false;
  }

  /// Verifica si un caso pertenece a una provincia objetivo de forma rigurosa (sin emparejamientos vacíos)
  static bool matchesProvince({
    required String? caseProv,
    String? caseDist,
    String? caseDetalles,
    required String targetProv,
  }) {
    final cleanTarget = targetProv.trim();
    if (cleanTarget.isEmpty ||
        cleanTarget == 'Todas las provincias' ||
        cleanTarget == 'Todas') {
      return true;
    }

    final targetNorm = normalize(cleanTarget);

    // 1. Coincidencia directa por provincia
    if (caseProv != null && caseProv.trim().isNotEmpty) {
      final pNorm = normalize(caseProv);
      if (pNorm == targetNorm || pNorm.contains(targetNorm) || targetNorm.contains(pNorm)) {
        return true;
      }
    }

    // 2. Coincidencia por distrito si la provincia no coincide o está vacía
    if (caseDist != null && caseDist.trim().isNotEmpty) {
      final dNorm = normalize(caseDist);
      if (dNorm == targetNorm || dNorm.contains(targetNorm) || targetNorm.contains(dNorm)) {
        return true;
      }
    }

    // 3. Coincidencia en detalles adicionales como último recurso por palabra completa
    if (caseDetalles != null && caseDetalles.trim().isNotEmpty) {
      final detNorm = normalize(caseDetalles);
      final regex = RegExp(r'\b' + RegExp.escape(targetNorm) + r'\b');
      if (regex.hasMatch(detNorm)) {
        return true;
      }
    }

    return false;
  }

  /// Busca la provincia oficial en la lista de provincias del departamento, tolerando mayúsculas y acentos.
  /// Si provincia es nula o vacía, retorna la primera provincia del departamento o 'Lima'.
  static String matchProvincia(String departamento, String? provincia) {
    final provList = getProvincias(departamento);
    final fallback = provList.isNotEmpty ? provList.first : 'Lima';
    if (provincia == null || provincia.trim().isEmpty) return fallback;

    final trimmed = provincia.trim();
    if (provList.contains(trimmed)) return trimmed;

    final norm = normalize(trimmed);
    for (final p in provList) {
      if (normalize(p) == norm) {
        return p;
      }
    }
    return trimmed;
  }
}
