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
