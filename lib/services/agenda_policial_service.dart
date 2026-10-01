import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../data/models/comisaria_model.dart';
import '../common/constants/peru_locations.dart';

class Comisaria {
  final int id;
  final String nombre;
  final String unidad;
  final String telefono;
  final String departamento;
  final String provincia;
  final String distrito;
  final String direccion;

  Comisaria({
    required this.id,
    required this.nombre,
    required this.unidad,
    required this.telefono,
    required this.departamento,
    required this.provincia,
    required this.distrito,
    this.direccion = '',
  });

  factory Comisaria.fromCsvRow(List<String> row) {
    return Comisaria(
      id: row.isNotEmpty ? int.tryParse(row[0].trim()) ?? 0 : 0,
      nombre: row.length > 1 ? row[1].trim() : '',
      unidad: row.length > 2 ? row[2].trim() : '',
      telefono: row.length > 3 ? row[3].trim() : '',
      departamento: row.length > 4 ? row[4].trim().toUpperCase() : '',
      provincia: row.length > 5 ? row[5].trim().toUpperCase() : '',
      distrito: row.length > 6 ? row[6].trim().toUpperCase() : '',
      direccion: row.length > 7 ? row[7].trim() : '',
    );
  }

  // Datos estáticos de Apurímac como respaldo de alta fidelidad
  static List<Comisaria> get apurimacData => [
    Comisaria(
      id: 1,
      nombre: 'UNIDAD DE ROBO DE VEHÍCULOS (UPROVE)',
      unidad: 'DIVOPUS ANDAHUAYLAS',
      telefono: '920020883',
      departamento: 'APURÍMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'ANDAHUAYLAS',
      direccion: 'Jr. Los Chankas S/N, Andahuaylas',
    ),
    Comisaria(
      id: 2,
      nombre: 'CENTRAL DE OPERACIONES 105 ANDAHUAYLAS',
      unidad: 'DIVOPUS ANDAHUAYLAS',
      telefono: '967831397',
      departamento: 'APURÍMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'ANDAHUAYLAS',
      direccion: 'Av. Perú 189, Andahuaylas',
    ),
    Comisaria(
      id: 3,
      nombre: 'UNIDAD DE SEGURIDAD VIAL (TRÁNSITO)',
      unidad: 'DIVOPUS ANDAHUAYLAS',
      telefono: '945277480',
      departamento: 'APURÍMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'ANDAHUAYLAS',
      direccion: 'Av. Perú 189, Andahuaylas',
    ),
    Comisaria(
      id: 4,
      nombre: 'ESCUADRÓN DE EMERGENCIA ANDAHUAYLAS',
      unidad: 'DIVOPUS ANDAHUAYLAS',
      telefono: '980122088',
      departamento: 'APURÍMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'ANDAHUAYLAS',
      direccion: 'Av. Perú 189, Andahuaylas',
    ),
    Comisaria(
      id: 5,
      nombre: 'DEPINCRI ANDAHUAYLAS',
      unidad: 'DIVINCRI APURÍMAC',
      telefono: '980122444',
      departamento: 'APURÍMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'ANDAHUAYLAS',
      direccion: 'Jr. Guillermo Cáceres 614, Andahuaylas 03701',
    ),
    Comisaria(
      id: 6,
      nombre: 'COMISARÍA SECTORIAL DE CHINCHEROS',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980122445',
      departamento: 'APURÍMAC',
      provincia: 'CHINCHEROS',
      distrito: 'CHINCHEROS',
      direccion: 'Plaza de Armas S/N, Chincheros',
    ),
    Comisaria(
      id: 7,
      nombre: 'COMISARÍA SECTORIAL DE ANDAHUAYLAS',
      unidad: 'DIVOPUS ANDAHUAYLAS',
      telefono: '980122027',
      departamento: 'APURÍMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'ANDAHUAYLAS',
      direccion: 'Av. Perú 189, Andahuaylas',
    ),
    Comisaria(
      id: 8,
      nombre: 'COMISARÍA DE ANDARAPA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980122385',
      departamento: 'APURÍMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'ANDARAPA',
      direccion: 'Plaza de Armas S/N, Andarapa - Andahuaylas',
    ),
    Comisaria(
      id: 9,
      nombre: 'CPNP DE FAMILIA ANDAHUAYLAS',
      unidad: 'DIVOPUS ANDAHUAYLAS',
      telefono: '957832971',
      departamento: 'APURÍMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'ANDAHUAYLAS',
      direccion: 'Av. Perú 189, Andahuaylas',
    ),
    Comisaria(
      id: 10,
      nombre: 'COMISARÍA DE HUACCANA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '952877411',
      departamento: 'APURÍMAC',
      provincia: 'CHINCHEROS',
      distrito: 'HUACCANA',
      direccion: 'Plaza Principal S/N, Huaccana - Chincheros',
    ),
    Comisaria(
      id: 11,
      nombre: 'COMISARÍA DE HUANCARAMA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '942118991',
      departamento: 'APURÍMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'HUANCARAMA',
      direccion: 'Jr. Grau S/N, Huancarama - Andahuaylas',
    ),
    Comisaria(
      id: 12,
      nombre: 'COMISARÍA DE KISHUARA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '957833499',
      departamento: 'APURÍMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'KISHUARA',
      direccion: 'Carretera Central S/N, Kishuara - Andahuaylas',
    ),
    Comisaria(
      id: 13,
      nombre: 'COMISARÍA DE OCOBAMBA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980121607',
      departamento: 'APURÍMAC',
      provincia: 'CHINCHEROS',
      distrito: 'OCOBAMBA',
      direccion: 'Jr. Comercio S/N, Ocobamba - Chincheros',
    ),
    Comisaria(
      id: 14,
      nombre: 'COMISARÍA DE ONGOY',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '964609892',
      departamento: 'APURÍMAC',
      provincia: 'CHINCHEROS',
      distrito: 'ONGOY',
      direccion: 'Plaza de Armas S/N, Ongoy - Chincheros',
    ),
    Comisaria(
      id: 15,
      nombre: 'COMISARÍA DE PACUCHA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '958893584',
      departamento: 'APURÍMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'PACUCHA',
      direccion: 'Plaza Principal S/N, Pacucha - Andahuaylas',
    ),
    Comisaria(
      id: 16,
      nombre: 'COMISARÍA DE RANRACANCHA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '957833492',
      departamento: 'APURÍMAC',
      provincia: 'CHINCHEROS',
      distrito: 'RANRACANCHA',
      direccion: 'Plaza Principal S/N, Ranracancha - Chincheros',
    ),
    Comisaria(
      id: 17,
      nombre: 'COMISARÍA DE S.A DE CACHI',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980121091',
      departamento: 'APURÍMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'SAN ANTONIO DE CACHI',
      direccion: 'Plaza Principal S/N, San Antonio de Cachi - Andahuaylas',
    ),
    Comisaria(
      id: 18,
      nombre: 'COMISARÍA DE SAN JERÓNIMO',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980122039',
      departamento: 'APURÍMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'SAN JERÓNIMO',
      direccion: 'Plaza de Armas S/N, San Jerónimo - Andahuaylas',
    ),
    Comisaria(
      id: 19,
      nombre: 'COMISARÍA DE S.M. DE CHICMO',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '943070460',
      departamento: 'APURÍMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'SAN MIGUEL DE CHICMO',
      direccion: 'Plaza de Armas S/N, Santa María de Chicmo - Andahuaylas',
    ),
    Comisaria(
      id: 20,
      nombre: 'COMISARÍA DE TALAVERA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980122026',
      departamento: 'APURÍMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'TALAVERA',
      direccion: 'Av. Confraternidad S/N, Talavera - Andahuaylas',
    ),
    Comisaria(
      id: 21,
      nombre: 'COMISARÍA DE URIPA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980121439',
      departamento: 'APURÍMAC',
      provincia: 'CHINCHEROS',
      distrito: 'URIPA',
      direccion: 'Av. Los Incas S/N, Uripa - Chincheros',
    ),
    Comisaria(
      id: 22,
      nombre: 'PAP "CHACCRAMPA"',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980122034',
      departamento: 'APURÍMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'CHACCRAMPA',
      direccion: 'Plaza Principal S/N, Chaccrampa - Andahuaylas',
    ),
    Comisaria(
      id: 23,
      nombre: 'COMISARÍA PNP ABANCAY "A"',
      unidad: 'DIVOPUS ABANCAY',
      telefono: '980122463',
      departamento: 'APURÍMAC',
      provincia: 'ABANCAY',
      distrito: 'ABANCAY',
      direccion: 'Jr. Lima 520, Abancay',
    ),
    Comisaria(
      id: 24,
      nombre: 'COMISARÍA PNP BELLAVISTA "B"',
      unidad: 'DIVOPUS ABANCAY',
      telefono: '980122029',
      departamento: 'APURÍMAC',
      provincia: 'ABANCAY',
      distrito: 'ABANCAY',
      direccion: 'Av. Arenas S/N, Bellavista - Abancay',
    ),
    Comisaria(
      id: 25,
      nombre: 'COMISARÍA PNP VILLA AMPAY "C"',
      unidad: 'DIVOPUS ABANCAY',
      telefono: '105 / 114',
      departamento: 'APURÍMAC',
      provincia: 'ABANCAY',
      distrito: 'ABANCAY',
      direccion: 'Av. Tamburco S/N, Villa Ampay - Abancay',
    ),
  ];

  @override
  String toString() {
    return 'Comisaria{id: $id, nombre: $nombre, unidad: $unidad, telefono: $telefono, departamento: $departamento, provincia: $provincia, distrito: $distrito, direccion: $direccion}';
  }
}

/// 🚔 Servicio moderno de Agenda Policial con diseño atractivo
class AgendaPolicialService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Database? _database;
  static List<ComisariaModel>? _comisariasCache;
  static DateTime? _lastCacheUpdate;
  static final ValueNotifier<SyncStatus> _syncStatusNotifier = ValueNotifier(
    SyncStatus.idle,
  );
  static final ValueNotifier<double> _progressNotifier = ValueNotifier(0.0);

  // 🎨 Colores modernos del tema policial
  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color backgroundGray = Color(0xFFF8FAFC);

  // Cache válido por 1 hora
  static const Duration _cacheDuration = Duration(hours: 1);

  /// 🚀 Estado de sincronización con diseño moderno
  static ValueNotifier<SyncStatus> get syncStatusNotifier =>
      _syncStatusNotifier;
  static ValueNotifier<double> get progressNotifier => _progressNotifier;

  /// 🎯 Inicializa la sincronización con feedback visual
  static Future<bool> inicializarSincronizacion({
    Function(String)? onStatusUpdate,
    Function(double)? onProgress,
  }) async {
    try {
      _syncStatusNotifier.value = SyncStatus.loading;
      _progressNotifier.value = 0.0;

      // 📱 Actualización de estado visual
      onStatusUpdate?.call('🔄 Iniciando sincronización...');
      await _updateProgress(0.1, onProgress);

      onStatusUpdate?.call('📄 Cargando datos desde CSV...');
      await _updateProgress(0.3, onProgress);

      // Cargar comisarías desde CSV
      final comisarias = await _cargarComisariasDesdeCSV(
        onProgress:
            (progress) => _updateProgress(0.3 + (progress * 0.5), onProgress),
      );

      if (comisarias.isNotEmpty) {
        onStatusUpdate?.call('💾 Guardando en cache...');
        await _updateProgress(0.8, onProgress);

        // Guardar en cache
        _comisariasCache = comisarias;
        _lastCacheUpdate = DateTime.now();

        onStatusUpdate?.call('🗄️ Persistiendo datos...');
        await _updateProgress(0.9, onProgress);

        // Opcional: guardar en BD local para persistencia
        await _guardarEnBDLocal(comisarias);

        onStatusUpdate?.call('✅ Sincronización completada');
        await _updateProgress(1.0, onProgress);

        _syncStatusNotifier.value = SyncStatus.success;

        // 🎉 Mostrar estadísticas
        final stats = await getEstadisticasDetalladas();
        onStatusUpdate?.call(
          '🎯 ${stats['total_comisarias']} comisarías en ${stats['total_departamentos']} departamentos',
        );

        return true;
      }

      _syncStatusNotifier.value = SyncStatus.error;
      return false;
    } catch (e) {
      _syncStatusNotifier.value = SyncStatus.error;
      onStatusUpdate?.call('❌ Error: ${e.toString()}');
      return false;
    }
  }

  /// 📊 Carga comisarías desde el catálogo oficial unificado (comisarias_nacional.json)
  static Future<List<ComisariaModel>> _cargarComisariasDesdeCSV({
    Function(double)? onProgress,
  }) async {
    try {
      // Cargar catálogo maestro unificado oficial desde assets
      final String jsonContent = await rootBundle.loadString(
        'assets/data/comisarias_nacional.json',
      );
      onProgress?.call(0.2);

      final List<dynamic> list = json.decode(jsonContent);
      final List<ComisariaModel> comisarias = [];
      final int total = list.length;

      for (int i = 0; i < total; i++) {
        final map = list[i] as Map<String, dynamic>;
        comisarias.add(ComisariaModel.fromMap(map));

        if (i % 60 == 0) {
          final progress = 0.3 + ((i / total) * 0.7);
          onProgress?.call(progress);
        }
      }

      debugPrint('✅ Catálogo unificado cargado en Agenda: ${comisarias.length} dependencias oficiales');
      return comisarias;
    } catch (e) {
      debugPrint('❌ Error cargando catálogo unificado: $e');
      // Respaldo de emergencia en memoria
      return Comisaria.apurimacData
          .map((c) => ComisariaModel(
                id: c.id,
                nombre: c.nombre,
                unidad: c.unidad,
                telefono: c.telefono,
                departamento: c.departamento,
                provincia: c.provincia,
                distrito: c.distrito,
                direccion: c.direccion,
              ))
          .toList();
    }
  }

  /// 🌍 Obtiene departamentos con información visual
  static Future<List<DepartamentoInfo>> getDepartamentosConInfo() async {
    try {
      final comisarias = await _getComisariasFromCache();
      final Map<String, int> conteos = {};

      for (final comisaria in comisarias) {
        conteos[comisaria.departamento] =
            (conteos[comisaria.departamento] ?? 0) + 1;
      }

      final departamentos =
          conteos.entries
              .map(
                (entry) => DepartamentoInfo(
                  nombre: entry.key,
                  totalComisarias: entry.value,
                  icono: _getIconoParaDepartamento(entry.key),
                  color: _getColorParaDepartamento(entry.key),
                ),
              )
              .toList();

      departamentos.sort((a, b) => a.nombre.compareTo(b.nombre));
      return departamentos;
    } catch (e) {
      debugPrint('❌ Error obteniendo departamentos: $e');
      return [];
    }
  }

  /// 🔍 Búsqueda inteligente con resultados destacados
  static Future<List<ComisariaModel>> buscarComisariasInteligente(
    String departamento,
    String query, {
    Function(SearchStats)? onStatsUpdate,
  }) async {
    try {
      if (query.isEmpty) {
        final comisarias = await cargarComisariasDepartamento(departamento);
        onStatsUpdate?.call(
          SearchStats(
            totalResultados: comisarias.length,
            tiempoBusqueda: 0,
            terminoBusqueda: '',
          ),
        );
        return comisarias;
      }

      final stopwatch = Stopwatch()..start();
      final comisariasDept = await cargarComisariasDepartamento(departamento);
      final queryUpper = query.toUpperCase();

      // Búsqueda con puntuación de relevancia
      final resultadosConPuntuacion =
          comisariasDept
              .map((comisaria) {
                int puntuacion = 0;

                // Coincidencia exacta en nombre (mayor puntuación)
                if (comisaria.nombre.toUpperCase().contains(queryUpper)) {
                  puntuacion += 100;
                  if (comisaria.nombre.toUpperCase().startsWith(queryUpper)) {
                    puntuacion += 50; // Bonus por comenzar con el término
                  }
                }

                // Coincidencias en otros campos
                if (comisaria.unidad.toUpperCase().contains(queryUpper)) {
                  puntuacion += 30;
                }
                if (comisaria.provincia.toUpperCase().contains(queryUpper)) {
                  puntuacion += 20;
                }
                if (comisaria.distrito.toUpperCase().contains(queryUpper)) {
                  puntuacion += 20;
                }
                if (comisaria.telefono.contains(query)) puntuacion += 10;

                return MapEntry(comisaria, puntuacion);
              })
              .where((entry) => entry.value > 0)
              .toList();

      // Ordenar por puntuación descendente
      resultadosConPuntuacion.sort((a, b) => b.value.compareTo(a.value));
      final resultados =
          resultadosConPuntuacion.map((entry) => entry.key).toList();

      stopwatch.stop();

      onStatsUpdate?.call(
        SearchStats(
          totalResultados: resultados.length,
          tiempoBusqueda: stopwatch.elapsedMilliseconds,
          terminoBusqueda: query,
        ),
      );

      return resultados;
    } catch (e) {
      debugPrint('❌ Error en búsqueda: $e');
      return [];
    }
  }

  /// 📊 Obtiene estadísticas detalladas
  static Future<Map<String, dynamic>> getEstadisticasDetalladas() async {
    try {
      final comisarias = await _getComisariasFromCache();
      final departamentos = comisarias.map((c) => c.departamento).toSet();
      final provincias = comisarias.map((c) => c.provincia).toSet();
      final distritos = comisarias.map((c) => c.distrito).toSet();

      // Análisis por departamento
      final Map<String, int> porDepartamento = {};
      for (final comisaria in comisarias) {
        porDepartamento[comisaria.departamento] =
            (porDepartamento[comisaria.departamento] ?? 0) + 1;
      }

      return {
        'total_comisarias': comisarias.length,
        'total_departamentos': departamentos.length,
        'total_provincias': provincias.length,
        'total_distritos': distritos.length,
        'por_departamento': porDepartamento,
        'ultima_actualizacion': _lastCacheUpdate?.toIso8601String(),
        'fuente_datos': 'CSV',
        'cache_valido': _isCacheValid(),
        'version': '2.0.0',
      };
    } catch (e) {
      return {'error': e.toString(), 'sincronizado': false};
    }
  }

  /// 🎨 Métodos auxiliares para diseño
  static IconData _getIconoParaDepartamento(String departamento) {
    switch (departamento.toUpperCase()) {
      case 'APURÍMAC':
        return Icons.landscape;
      case 'LIMA':
        return Icons.location_city;
      case 'CUSCO':
        return Icons.temple_hindu;
      case 'AREQUIPA':
        return Icons.volcano;
      case 'AMAZONAS':
        return Icons.forest;
      case 'ÁNCASH':
        return Icons.terrain;
      case 'AYACUCHO':
        return Icons.church;
      case 'CAJAMARCA':
        return Icons.agriculture;
      case 'CALLAO':
        return Icons.directions_boat;
      case 'HUANCAVELICA':
        return Icons.landscape_outlined;
      case 'HUÁNUCO':
        return Icons.park;
      case 'ICA':
        return Icons.wb_sunny;
      case 'JUNÍN':
        return Icons.water;
      case 'LA LIBERTAD':
        return Icons.beach_access;
      case 'LAMBAYEQUE':
        return Icons.waves;
      case 'LORETO':
        return Icons.nature;
      case 'MADRE DE DIOS':
        return Icons.eco;
      case 'MOQUEGUA':
        return Icons.local_florist;
      case 'PASCO':
        return Icons.diamond;
      case 'PIURA':
        return Icons.wb_sunny_outlined;
      case 'PUNO':
        return Icons.water_drop;
      case 'SAN MARTÍN':
        return Icons.forest_outlined;
      case 'TACNA':
        return Icons.flag;
      case 'TUMBES':
        return Icons.surfing;
      case 'UCAYALI':
        return Icons.nature_people;
      default:
        return Icons.place;
    }
  }

  static Color _getColorParaDepartamento(String departamento) {
    final colors = [primaryBlue, accentGold, successGreen, warningOrange];
    return colors[departamento.hashCode % colors.length];
  }

  static Future<void> _updateProgress(
    double progress,
    Function(double)? onProgress,
  ) async {
    _progressNotifier.value = progress;
    onProgress?.call(progress);
    await Future.delayed(const Duration(milliseconds: 100)); // Animación suave
  }

  /// 🔄 Métodos de cache y persistencia
  static Future<List<ComisariaModel>> _getComisariasFromCache() async {
    if (_isCacheValid()) {
      return _comisariasCache!;
    }

    List<ComisariaModel> comisarias = await _cargarComisariasDesdeCSV();

    // Fusionar con actualizaciones de Cloud Firestore en tiempo real
    try {
      final snapshot = await _firestore.collection('comisarias').get(
        const GetOptions(source: Source.serverAndCache),
      );
      if (snapshot.docs.isNotEmpty) {
        final Map<String, Map<String, dynamic>> firestoreUpdates = {};
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final key = data['id']?.toString() ?? doc.id;
          firestoreUpdates[key] = data;
          if (data['nombre'] != null) {
            firestoreUpdates[data['nombre'].toString().trim().toUpperCase()] = data;
          }
        }

        comisarias = comisarias.map((c) {
          final key = c.id?.toString() ?? '';
          final update = firestoreUpdates[key] ?? firestoreUpdates[c.nombre.trim().toUpperCase()];
          if (update != null) {
            return c.copyWith(
              telefono: update['telefono']?.toString() ?? c.telefono,
              direccion: update['direccion']?.toString() ?? c.direccion,
              unidad: update['unidad']?.toString() ?? c.unidad,
            );
          }
          return c;
        }).toList();
        debugPrint('🔄 Fusionadas ${snapshot.docs.length} actualizaciones en tiempo real desde Firestore.');
      }
    } catch (e) {
      debugPrint('ℹ️ Usando prontuario local (sin Firestore): $e');
    }

    _comisariasCache = comisarias;
    _lastCacheUpdate = DateTime.now();
    return comisarias;
  }

  /// ✏️ Actualiza el teléfono u otros datos de una comisaría en Firestore en tiempo real
  static Future<bool> actualizarComisaria(
    ComisariaModel comisaria, {
    String? nuevoTelefono,
    String? nuevaDireccion,
    String? actualizadoPor,
  }) async {
    try {
      final docId = comisaria.id?.toString() ?? comisaria.nombre.replaceAll(' ', '_').toLowerCase();
      final updatedData = {
        'id': comisaria.id,
        'nombre': comisaria.nombre,
        'unidad': comisaria.unidad,
        'telefono': nuevoTelefono ?? comisaria.telefono,
        'direccion': nuevaDireccion ?? comisaria.direccion,
        'departamento': comisaria.departamento,
        'provincia': comisaria.provincia,
        'distrito': comisaria.distrito,
        'ultima_actualizacion': FieldValue.serverTimestamp(),
        'actualizado_por': actualizadoPor ?? 'PNP',
      };

      await _firestore.collection('comisarias').doc(docId).set(
        updatedData,
        SetOptions(merge: true),
      );

      // Actualizar en el cache local en memoria inmediatamente
      if (_comisariasCache != null) {
        final idx = _comisariasCache!.indexWhere((c) => c.id == comisaria.id || c.nombre == comisaria.nombre);
        if (idx != -1) {
          _comisariasCache![idx] = comisaria.copyWith(
            telefono: nuevoTelefono ?? comisaria.telefono,
            direccion: nuevaDireccion ?? comisaria.direccion,
          );
        }
      }

      debugPrint('✅ Comisaría ${comisaria.nombre} actualizada en tiempo real en Firestore.');
      return true;
    } catch (e) {
      debugPrint('❌ Error actualizando comisaría en Firestore: $e');
      return false;
    }
  }

  static Future<List<ComisariaModel>> cargarComisariasDepartamento(
    String departamento,
  ) async {
    final comisarias = await _getComisariasFromCache();
    final target = PeruLocations.normalize(departamento);
    return comisarias
        .where(
          (c) => PeruLocations.normalize(c.departamento) == target,
        )
        .toList();
  }

  /// 🇵🇪 Obtiene todas las comisarías del Perú (Directorio Nacional Completo)
  static Future<List<ComisariaModel>> getTodasComisarias() async {
    return await _getComisariasFromCache();
  }

  /// 🔍 Búsqueda global omni-canal en todo el territorio peruano
  static Future<List<ComisariaModel>> buscarComisariasNacional(
    String query, {
    String? departamento,
    String? provincia,
    bool soloFamilia = false,
  }) async {
    final List<ComisariaModel> base = (departamento == null || departamento.isEmpty || departamento.toUpperCase() == 'TODAS')
        ? await _getComisariasFromCache()
        : await cargarComisariasDepartamento(departamento);

    var filtradas = base;
    if (provincia != null && provincia.isNotEmpty) {
      final pUpper = provincia.toUpperCase();
      filtradas = filtradas.where((c) => c.provincia.toUpperCase().contains(pUpper)).toList();
    }
    if (soloFamilia) {
      filtradas = filtradas.where((c) => c.nombre.toUpperCase().contains('FAMILIA') || c.unidad.toUpperCase().contains('FAMILIA')).toList();
    }

    if (query.trim().isEmpty) {
      return filtradas;
    }

    final queryUpper = query.trim().toUpperCase();
    final cleanQ = query.replaceAll(RegExp(r'[^0-9]'), '');

    final resultadosConPuntuacion = filtradas.map((comisaria) {
      int score = 0;
      final nom = comisaria.nombre.toUpperCase();
      final dis = comisaria.distrito.toUpperCase();
      final prov = comisaria.provincia.toUpperCase();
      final dep = comisaria.departamento.toUpperCase();
      final uni = comisaria.unidad.toUpperCase();
      final tel = comisaria.telefono.replaceAll(RegExp(r'[^0-9]'), '');

      // Coincidencias en nombre
      if (nom.startsWith(queryUpper)) {
        score += 150;
      } else if (nom.contains(queryUpper)) {
        score += 100;
      }

      // Coincidencias en distrito
      if (dis.startsWith(queryUpper)) {
        score += 80;
      } else if (dis.contains(queryUpper)) {
        score += 60;
      }

      // Coincidencias en provincia o departamento
      if (prov.contains(queryUpper)) score += 40;
      if (dep.contains(queryUpper)) score += 30;
      if (uni.contains(queryUpper)) score += 20;

      // Coincidencia telefónica
      if (cleanQ.isNotEmpty && tel.contains(cleanQ)) {
        score += 120;
      }

      return MapEntry(comisaria, score);
    }).where((e) => e.value > 0).toList();

    resultadosConPuntuacion.sort((a, b) => b.value.compareTo(a.value));
    return resultadosConPuntuacion.map((e) => e.key).toList();
  }

  /// Obtiene los departamentos disponibles (método original para compatibilidad)
  static Future<List<String>> getDepartamentosDisponibles() async {
    try {
      final comisarias = await _getComisariasFromCache();
      final departamentos =
          comisarias
              .map((c) => c.departamento)
              .where((d) => d.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      return departamentos;
    } catch (e) {
      debugPrint('❌ Error obteniendo departamentos: $e');
      return ['APURÍMAC']; // Fallback
    }
  }

  /// Busca comisarías (método original para compatibilidad)
  static Future<List<ComisariaModel>> buscarComisarias(
    String departamento,
    String query,
  ) async {
    return await buscarComisariasInteligente(departamento, query);
  }

  /// Obtiene el conteo de comisarías por departamento
  static Future<int> getComisariasCount(String departamento) async {
    try {
      final comisarias = await cargarComisariasDepartamento(departamento);
      return comisarias.length;
    } catch (e) {
      debugPrint('❌ Error obteniendo conteo: $e');
      return 0;
    }
  }

  /// Obtiene el estado de sincronización (método original para compatibilidad)
  static Future<Map<String, dynamic>> getEstadoSincronizacion() async {
    return await getEstadisticasDetalladas();
  }

  static bool _isCacheValid() {
    return _comisariasCache != null &&
        _lastCacheUpdate != null &&
        DateTime.now().difference(_lastCacheUpdate!) < _cacheDuration;
  }

  static Future<void> _guardarEnBDLocal(List<ComisariaModel> comisarias) async {
    if (kIsWeb) return;
    try {
      final db = await _getDatabase();
      if (db == null) return;

      await db.execute('''
        CREATE TABLE IF NOT EXISTS comisarias_csv (
          id TEXT PRIMARY KEY,
          nombre TEXT NOT NULL,
          unidad TEXT,
          telefono TEXT,
          departamento TEXT NOT NULL,
          provincia TEXT,
          distrito TEXT,
          direccion TEXT,
          latitud REAL,
          longitud REAL,
          fecha_actualizacion TEXT
        )
      ''');

      await db.delete('comisarias_csv');

      final batch = db.batch();
      for (final comisaria in comisarias) {
        batch.insert('comisarias_csv', {
          'id': comisaria.id?.toString() ?? '',
          'nombre': comisaria.nombre,
          'unidad': comisaria.unidad,
          'telefono': comisaria.telefono,
          'departamento': comisaria.departamento,
          'provincia': comisaria.provincia,
          'distrito': comisaria.distrito,
          'direccion': comisaria.direccion,
          'latitud': comisaria.latitud,
          'longitud': comisaria.longitud,
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        });
      }

      await batch.commit();
      debugPrint('💾 Comisarías guardadas en BD local: ${comisarias.length}');
    } catch (e) {
      debugPrint('⚠️ Error guardando en BD local: $e');
    }
  }

  static Future<Database?> _getDatabase() async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'agenda_policial.db');

    _database = await openDatabase(path, version: 1);
    return _database!;
  }
}

/// 🎯 Enums y clases para el diseño moderno
enum SyncStatus { idle, loading, success, error }

class DepartamentoInfo {
  final String nombre;
  final int totalComisarias;
  final IconData icono;
  final Color color;

  DepartamentoInfo({
    required this.nombre,
    required this.totalComisarias,
    required this.icono,
    required this.color,
  });
}

class SearchStats {
  final int totalResultados;
  final int tiempoBusqueda;
  final String terminoBusqueda;

  SearchStats({
    required this.totalResultados,
    required this.tiempoBusqueda,
    required this.terminoBusqueda,
  });
}
