import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../common/constants/peru_locations.dart';

enum LocationSource {
  gpsSensor,
  userProfile,
  manualSelection,
  nationalDefault,
}

class GpsLocationResult {
  final String departamento;
  final String provincia;
  final double latitude;
  final double longitude;
  final bool isFromGps;
  final LocationSource source;
  final String statusMessage;

  const GpsLocationResult({
    required this.departamento,
    required this.provincia,
    required this.latitude,
    required this.longitude,
    this.isFromGps = true,
    this.source = LocationSource.gpsSensor,
    this.statusMessage = '',
  });

  @override
  String toString() =>
      'GpsLocationResult(dept: $departamento, prov: $provincia, lat: $latitude, lng: $longitude, source: $source)';
}

class GpsLocationService {
  static const String keyUserDept = 'user_departamento';
  static const String keyUserProv = 'user_provincia';

  /// Coordenadas de referencia de los departamentos del Perú (capital / centroide aproximado)
  static const Map<String, Map<String, dynamic>> _deptCentroids = {
    'AMAZONAS': {'lat': -6.2294, 'lng': -77.8728, 'prov': 'Chachapoyas'},
    'ÁNCASH': {'lat': -9.5278, 'lng': -77.5278, 'prov': 'Huaraz'},
    'ANCASH': {'lat': -9.5278, 'lng': -77.5278, 'prov': 'Huaraz'},
    'APURÍMAC': {'lat': -13.6339, 'lng': -72.8814, 'prov': 'Abancay'},
    'APURIMAC': {'lat': -13.6339, 'lng': -72.8814, 'prov': 'Abancay'},
    'AREQUIPA': {'lat': -16.4090, 'lng': -71.5375, 'prov': 'Arequipa'},
    'AYACUCHO': {'lat': -13.1588, 'lng': -74.2239, 'prov': 'Huamanga'},
    'CAJAMARCA': {'lat': -7.1638, 'lng': -78.5003, 'prov': 'Cajamarca'},
    'CALLAO': {'lat': -12.0566, 'lng': -77.1181, 'prov': 'Callao'},
    'CUSCO': {'lat': -13.5319, 'lng': -71.9675, 'prov': 'Cusco'},
    'HUANCAVELICA': {'lat': -12.7864, 'lng': -74.9727, 'prov': 'Huancavelica'},
    'HUÁNUCO': {'lat': -9.9306, 'lng': -76.2422, 'prov': 'Huánuco'},
    'HUANUCO': {'lat': -9.9306, 'lng': -76.2422, 'prov': 'Huánuco'},
    'ICA': {'lat': -14.0678, 'lng': -75.7286, 'prov': 'Ica'},
    'JUNÍN': {'lat': -12.0651, 'lng': -75.2049, 'prov': 'Huancayo'},
    'JUNIN': {'lat': -12.0651, 'lng': -75.2049, 'prov': 'Huancayo'},
    'LA LIBERTAD': {'lat': -8.1160, 'lng': -79.0300, 'prov': 'Trujillo'},
    'LAMBAYEQUE': {'lat': -6.7714, 'lng': -79.8409, 'prov': 'Chiclayo'},
    'LIMA': {'lat': -12.0464, 'lng': -77.0428, 'prov': 'Lima'},
    'LORETO': {'lat': -3.7437, 'lng': -73.2516, 'prov': 'Maynas'},
    'MADRE DE DIOS': {'lat': -12.5933, 'lng': -69.1891, 'prov': 'Tambopata'},
    'MOQUEGUA': {'lat': -17.1983, 'lng': -70.9357, 'prov': 'Mariscal Nieto'},
    'PASCO': {'lat': -10.6675, 'lng': -76.2567, 'prov': 'Pasco'},
    'PIURA': {'lat': -5.1945, 'lng': -80.6328, 'prov': 'Piura'},
    'PUNO': {'lat': -15.8422, 'lng': -70.0199, 'prov': 'Puno'},
    'SAN MARTÍN': {'lat': -6.0342, 'lng': -76.9717, 'prov': 'Moyobamba'},
    'SAN MARTIN': {'lat': -6.0342, 'lng': -76.9717, 'prov': 'Moyobamba'},
    'TACNA': {'lat': -18.0066, 'lng': -70.2463, 'prov': 'Tacna'},
    'TUMBES': {'lat': -3.5669, 'lng': -80.4515, 'prov': 'Tumbes'},
    'UCAYALI': {'lat': -8.3791, 'lng': -74.5539, 'prov': 'Coronel Portillo'},
  };

  /// Obtiene la ubicación actual del ciudadano usando GPS y resuelve departamento y provincia
  static Future<GpsLocationResult?> getCurrentLocation({bool requestPermission = true}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[GPS] Servicio de ubicación deshabilitado');
        return await getSavedLocation();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint('[GPS] Permiso de ubicación denegado: $permission');
        return await getSavedLocation();
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (posError) {
        debugPrint('[GPS] getCurrentPosition falló o demoró, probando getLastKnownPosition: $posError');
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        return await getSavedLocation();
      }

      final resolved = await _resolveDepartmentAndProvince(position.latitude, position.longitude);
      if (resolved != null) {
        // Guardar la lectura del sensor GPS y las coordenadas actualizadas
        await saveGpsSensorReading(resolved);
        await saveCoordinates(latitud: position.latitude, longitud: position.longitude);
        return resolved;
      }

      return GpsLocationResult(
        departamento: 'LIMA',
        provincia: 'Lima',
        latitude: position.latitude,
        longitude: position.longitude,
        isFromGps: true,
        source: LocationSource.gpsSensor,
      );
    } catch (e) {
      debugPrint('[GPS] Error capturando posición GPS: $e');
      return await getSavedLocation();
    }
  }

  /// Resuelve departamento y provincia a partir de coordenadas
  static Future<GpsLocationResult?> _resolveDepartmentAndProvince(double lat, double lng) async {
    // 1. Intentar reverse geocoding en línea mediante OpenStreetMap Nominatim
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=10&addressdetails=1',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'AlertaDesaparecidosPNP/2.0',
        'Accept-Language': 'es',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          String? rawState = address['state'] ?? address['region'] ?? address['province'];
          String? rawCounty = address['county'] ?? address['city'] ?? address['town'] ?? address['district'];

          final matched = _matchDepartmentAndProvince(rawState, rawCounty);
          if (matched != null) {
            return GpsLocationResult(
              departamento: matched['departamento']!,
              provincia: matched['provincia']!,
              latitude: lat,
              longitude: lng,
              isFromGps: true,
              source: LocationSource.gpsSensor,
              statusMessage: 'Ubicación GPS: ${matched['provincia']}, ${matched['departamento']}',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[GPS] Reverse geocoding online Nominatim falló: $e');
    }

    // 2. Fallback por proximidad geográfica a centroides departamentales del Perú
    String nearestDept = 'LIMA';
    String defaultProv = 'Lima';
    double minDistance = double.infinity;

    for (final entry in _deptCentroids.entries) {
      final cLat = (entry.value['lat'] as num).toDouble();
      final cLng = (entry.value['lng'] as num).toDouble();
      final dist = _calculateDistance(lat, lng, cLat, cLng);
      if (dist < minDistance) {
        minDistance = dist;
        nearestDept = entry.key;
        defaultProv = entry.value['prov'] as String? ?? 'Lima';
      }
    }

    return GpsLocationResult(
      departamento: nearestDept,
      provincia: defaultProv,
      latitude: lat,
      longitude: lng,
      isFromGps: true,
      source: LocationSource.gpsSensor,
      statusMessage: 'Ubicación GPS por proximidad: $defaultProv, $nearestDept',
    );
  }

  /// Normaliza y busca coincidencia exacta con PeruLocations
  static Map<String, String>? _matchDepartmentAndProvince(String? rawDept, String? rawProv) {
    if (rawDept == null && rawProv == null) return null;

    String cleanText(String s) {
      return s
          .toUpperCase()
          .replaceAll('DEPARTAMENTO DE ', '')
          .replaceAll('PROVINCIA DE ', '')
          .replaceAll('REGION ', '')
          .replaceAll('REGIÓN ', '')
          .replaceAll('Á', 'A')
          .replaceAll('É', 'E')
          .replaceAll('Í', 'I')
          .replaceAll('Ó', 'O')
          .replaceAll('Ú', 'U')
          .trim();
    }

    final targetDept = cleanText(rawDept ?? '');
    String? matchedDept;

    for (final dept in PeruLocations.departamentos) {
      final deptClean = cleanText(dept);
      if (targetDept.contains(deptClean) || deptClean.contains(targetDept)) {
        matchedDept = dept;
        break;
      }
    }

    matchedDept ??= 'LIMA';

    final provincias = PeruLocations.getProvincias(matchedDept);
    String matchedProv = provincias.isNotEmpty ? provincias.first : 'Lima';

    if (rawProv != null) {
      final targetProv = cleanText(rawProv);
      for (final p in provincias) {
        final pClean = cleanText(p);
        if (targetProv.contains(pClean) || pClean.contains(targetProv)) {
          matchedProv = p;
          break;
        }
      }
    }

    return {
      'departamento': matchedDept,
      'provincia': matchedProv,
    };
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Guarda la lectura del sensor GPS en claves separadas sin sobreescribir el perfil permanente del ciudadano
  static Future<void> saveGpsSensorReading(GpsLocationResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gps_departamento', result.departamento);
      await prefs.setString('gps_provincia', result.provincia);
      await prefs.setDouble('gps_latitude', result.latitude);
      await prefs.setDouble('gps_longitude', result.longitude);

      // Solo si el usuario nunca ha configurado su departamento de residencia, asignar inicial
      final existingDept = prefs.getString(keyUserDept) ?? prefs.getString('user_departamento');
      if (existingDept == null || existingDept.isEmpty) {
        await prefs.setString(keyUserDept, result.departamento);
        await prefs.setString('user_department', result.departamento);
        await prefs.setString(keyUserProv, result.provincia);
        await prefs.setString('user_provincia', result.provincia);
      }
    } catch (e) {
      debugPrint('[GPS] Error guardando lectura de sensor GPS: $e');
    }
  }

  /// Guarda directamente coordenadas geográficas actualizadas
  static Future<void> saveCoordinates({required double latitud, required double longitud}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('gps_latitude', latitud);
      await prefs.setDouble('gps_longitude', longitud);
    } catch (e) {
      debugPrint('[GPS] Error guardando coordenadas en caché: $e');
    }
  }

  /// Guarda la ubicación declarada del usuario en SharedPreferences y en Firestore si el usuario está autenticado
  static Future<void> saveLocation(String departamento, String provincia, {bool syncFirestore = true}) async {
    try {
      final canonicalDept = departamento.trim().toUpperCase();
      final canonicalProv = PeruLocations.matchProvincia(canonicalDept, provincia.trim());

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyUserDept, canonicalDept);
      await prefs.setString('user_department', canonicalDept);
      await prefs.setString('user_departamento', canonicalDept);
      await prefs.setString(keyUserProv, canonicalProv);
      await prefs.setString('user_provincia', canonicalProv);

      if (syncFirestore) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('ciudadanos').doc(user.uid).set({
            'departamento': canonicalDept,
            'provincia': canonicalProv,
            'fecha_actualizacion_ubicacion': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
      debugPrint('[GPS] Ubicación declarada guardada exitosamente: $canonicalDept - $canonicalProv');
    } catch (e) {
      debugPrint('[GPS] Error guardando ubicación declarada: $e');
    }
  }
  /// Normaliza texto removiendo acentos y pasando a mayúsculas para comparaciones precisas
  static String normalize(String text) {
    var result = text.trim().toUpperCase();
    const map = {
      '\u00C1': 'A', // Á
      '\u00C9': 'E', // É
      '\u00CD': 'I', // Í
      '\u00D3': 'O', // Ó
      '\u00DA': 'U', // Ú
      '\u00DC': 'U', // Ü
      '\u00E1': 'A', // á
      '\u00E9': 'E', // é
      '\u00ED': 'I', // í
      '\u00F3': 'O', // ó
      '\u00FA': 'U', // ú
      '\u00FC': 'U', // ü
    };
    map.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    return result;
  }

  /// Verifica si dos nombres de departamento o provincia coinciden tolerando acentos y variaciones
  static bool matches(String a, String b) {
    if (a.trim().isEmpty || b.trim().isEmpty) return false;
    final normA = normalize(a);
    final normB = normalize(b);
    return normA == normB || normA.contains(normB) || normB.contains(normA);
  }

  /// Genera todas las variantes válidas de un departamento (con y sin acentos, mayúsculas y minúsculas)
  /// para asegurar que las consultas en Firestore nunca queden vacías por problemas de tildes.
  static List<String> getDepartmentVariants(String? departamento) {
    if (departamento == null) return [];
    final clean = departamento.trim();
    if (clean.isEmpty ||
        clean.toLowerCase() == 'todos' ||
        clean.toLowerCase() == 'todos los departamentos') {
      return [];
    }

    final norm = normalize(clean);
    final Set<String> variants = {
      clean,
      clean.toUpperCase(),
      clean.toLowerCase(),
      norm,
      norm.toLowerCase(),
    };

    // Capitalized (ej. "Apurimac")
    if (clean.isNotEmpty) {
      variants.add(clean[0].toUpperCase() + clean.substring(1).toLowerCase());
    }
    if (norm.isNotEmpty) {
      variants.add(norm[0].toUpperCase() + norm.substring(1).toLowerCase());
    }

    // Mapa de departamentos peruanos con tildes oficiales
    const accentsMap = {
      'ANCASH': 'ÁNCASH',
      'APURIMAC': 'APURÍMAC',
      'HUANUCO': 'HUÁNUCO',
      'JUNIN': 'JUNÍN',
      'SAN MARTIN': 'SAN MARTÍN',
    };

    if (accentsMap.containsKey(norm)) {
      final accented = accentsMap[norm]!;
      variants.add(accented);
      variants.add(accented.toUpperCase());
      variants.add(accented.toLowerCase());
      variants.add(accented[0].toUpperCase() + accented.substring(1).toLowerCase());
    }

    for (final entry in accentsMap.entries) {
      if (entry.value == clean.toUpperCase() || entry.key == norm) {
        variants.add(entry.key);
        variants.add(entry.key.toLowerCase());
        variants.add(entry.value);
        variants.add(entry.value.toLowerCase());
      }
    }

    return variants.where((v) => v.isNotEmpty).toList();
  }

  /// Recupera la ubicación guardada localmente o desde Firestore (ciudadanos o policías)
  static Future<GpsLocationResult?> getSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? dept = prefs.getString('user_departamento') ??
          prefs.getString('user_department') ??
          prefs.getString(keyUserDept);
      String? prov = prefs.getString('user_provincia') ??
          prefs.getString(keyUserProv);

      if (dept == null || dept.isEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // 1. Intentar buscar en ciudadanos por UID
          final doc = await FirebaseFirestore.instance
              .collection('ciudadanos')
              .doc(user.uid)
              .get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            dept = data['departamento'] as String?;
            prov = data['provincia'] as String?;
          }

          // 2. Si no se encontró por UID, buscar en ciudadanos por teléfono
          if ((dept == null || dept.isEmpty) && user.phoneNumber != null) {
            final phoneQuery = await FirebaseFirestore.instance
                .collection('ciudadanos')
                .where('telefono', isEqualTo: user.phoneNumber)
                .limit(1)
                .get();
            if (phoneQuery.docs.isNotEmpty) {
              final data = phoneQuery.docs.first.data();
              dept = data['departamento'] as String?;
              prov = data['provincia'] as String?;
            }
          }

          // 3. Si no es ciudadano, buscar en policías por UID
          if (dept == null || dept.isEmpty) {
            final polDoc = await FirebaseFirestore.instance
                .collection('policias')
                .doc(user.uid)
                .get();
            if (polDoc.exists && polDoc.data() != null) {
              final polData = polDoc.data()!;
              dept = polData['departamento'] as String?;
              prov = polData['provincia'] as String?;
            }
          }

          // 4. Buscar en policías por teléfono
          if ((dept == null || dept.isEmpty) && user.phoneNumber != null) {
            final polPhoneQuery = await FirebaseFirestore.instance
                .collection('policias')
                .where('telefono', isEqualTo: user.phoneNumber)
                .limit(1)
                .get();
            if (polPhoneQuery.docs.isNotEmpty) {
              final polData = polPhoneQuery.docs.first.data();
              dept = polData['departamento'] as String?;
              prov = polData['provincia'] as String?;
            }
          }
        }
      }

      // Si encontramos datos válidos, persistirlos localmente para futuros accesos inmediatos
      if (dept != null && dept.isNotEmpty) {
        await prefs.setString(keyUserDept, dept);
        await prefs.setString('user_department', dept);
        await prefs.setString('user_departamento', dept);
        if (prov != null && prov.isNotEmpty) {
          await prefs.setString(keyUserProv, prov);
          await prefs.setString('user_provincia', prov);
        }
      }

      final bool hasSpecificProfile = dept != null &&
          dept.trim().isNotEmpty &&
          dept.toUpperCase() != 'TODOS' &&
          dept.toUpperCase() != 'TODAS' &&
          !dept.toUpperCase().contains('TODO');

      if (hasSpecificProfile) {
        final canonicalDept = PeruLocations.departamentos.firstWhere(
          (d) => PeruLocations.normalize(d) == PeruLocations.normalize(dept!),
          orElse: () => dept!.toUpperCase(),
        );
        final canonicalProv = PeruLocations.matchProvincia(canonicalDept, prov);
        final centroid = getCentroid(canonicalDept);

        return GpsLocationResult(
          departamento: canonicalDept,
          provincia: canonicalProv,
          latitude: (centroid['lat'] as num).toDouble(),
          longitude: (centroid['lng'] as num).toDouble(),
          isFromGps: false,
          source: LocationSource.userProfile,
          statusMessage: 'Ubicación basada en tu perfil ($canonicalDept)',
        );
      }

      // Si no hay perfil específico, revisar si existe una lectura previa de GPS en caché
      final cachedGpsDept = prefs.getString('gps_departamento');
      final cachedGpsProv = prefs.getString('gps_provincia');
      final cachedLat = prefs.getDouble('gps_latitude');
      final cachedLng = prefs.getDouble('gps_longitude');

      if (cachedGpsDept != null &&
          cachedGpsDept.isNotEmpty &&
          cachedGpsDept.toUpperCase() != 'TODOS' &&
          cachedLat != null &&
          cachedLng != null) {
        return GpsLocationResult(
          departamento: cachedGpsDept,
          provincia: cachedGpsProv ?? '',
          latitude: cachedLat,
          longitude: cachedLng,
          isFromGps: true,
          source: LocationSource.gpsSensor,
          statusMessage: 'Ubicación GPS registrada previamente',
        );
      }

      // Predeterminado nacional sin filtro estricto de departamento (Todo el Perú)
      return const GpsLocationResult(
        departamento: '',
        provincia: '',
        latitude: -12.0464,
        longitude: -77.0428,
        isFromGps: false,
        source: LocationSource.nationalDefault,
        statusMessage: 'Ubicación predeterminada (Nacional)',
      );
    } catch (e) {
      debugPrint('[GPS] Error recuperando ubicación guardada: $e');
      return const GpsLocationResult(
        departamento: '',
        provincia: '',
        latitude: -12.0464,
        longitude: -77.0428,
        isFromGps: false,
        source: LocationSource.nationalDefault,
        statusMessage: 'Ubicación predeterminada (Nacional)',
      );
    }
  }

  /// Obtiene el centroide de referencia para cualquier departamento
  static Map<String, dynamic> getCentroid(String departamento) {
    final norm = normalize(departamento);
    return _deptCentroids[norm] ?? _deptCentroids['LIMA']!;
  }

  /// Crea un GpsLocationResult a partir de una selección manual del ciudadano
  static GpsLocationResult fromManualSelection(String departamento, String provincia) {
    final canonicalDept = PeruLocations.departamentos.firstWhere(
      (d) => PeruLocations.normalize(d) == PeruLocations.normalize(departamento),
      orElse: () => departamento.toUpperCase(),
    );
    final canonicalProv = PeruLocations.matchProvincia(canonicalDept, provincia);
    final centroid = getCentroid(canonicalDept);

    return GpsLocationResult(
      departamento: canonicalDept,
      provincia: canonicalProv,
      latitude: (centroid['lat'] as num).toDouble(),
      longitude: (centroid['lng'] as num).toDouble(),
      isFromGps: false,
      source: LocationSource.manualSelection,
      statusMessage: 'Selección manual: $canonicalDept, $canonicalProv',
    );
  }
}