import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lottie/lottie.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../data/models/comisaria_model.dart';

class Comisaria {
  final int id;
  final String nombre;
  final String unidad;
  final String telefono;
  final String departamento;
  final String provincia;
  final String distrito;

  Comisaria({
    required this.id,
    required this.nombre,
    required this.unidad,
    required this.telefono,
    required this.departamento,
    required this.provincia,
    required this.distrito,
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
    );
  }

  // Datos estáticos de Apurímac como respaldo
  static List<Comisaria> get apurimacData => [
    Comisaria(
      id: 1,
      nombre: 'UNIDAD DE ROBO DE VEHÍCULOS',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '920020883',
      departamento: 'APURIMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'ANDAHUAYLAS',
    ),
    Comisaria(
      id: 2,
      nombre: 'CENTRAL DE OPERACIONES ANDAHUAYLAS',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '967831397',
      departamento: 'APURIMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'ANDAHUAYLAS',
    ),
    Comisaria(
      id: 3,
      nombre: 'UNIDAD DE SEGURIDAD VIAL (TRÁNSITO)',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '945277480',
      departamento: 'APURIMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'ANDAHUAYLAS',
    ),
    Comisaria(
      id: 4,
      nombre: 'ESCUADRÓN DE EMERGENCIA ANDAHUAYLAS',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980122088',
      departamento: 'APURIMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'ANDAHUAYLAS',
    ),
    Comisaria(
      id: 5,
      nombre: 'DEPINCRI ANDAHUAYLAS',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980122444',
      departamento: 'APURIMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'ANDAHUAYLAS',
    ),
    Comisaria(
      id: 6,
      nombre: 'COMISARÍA SECTORIAL DE CHINCHEROS',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980122445',
      departamento: 'APURIMAC',
      provincia: 'CHINCHEROS',
      distrito: 'CHINCHEROS',
    ),
    Comisaria(
      id: 7,
      nombre: 'COMISARÍA SECTORIAL DE ANDAHUAYLAS',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980122027',
      departamento: 'APURIMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'ANDAHUAYLAS',
    ),
    Comisaria(
      id: 8,
      nombre: 'COMISARÍA DE ANDARAPA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980122385',
      departamento: 'APURIMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'ANDARAPA',
    ),
    Comisaria(
      id: 9,
      nombre: 'COMISARÍA DE FAMILIA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '957832971',
      departamento: 'APURIMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'ANDAHUAYLAS',
    ),
    Comisaria(
      id: 10,
      nombre: 'COMISARÍA DE HUACCANA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '952877411',
      departamento: 'APURIMAC',
      provincia: 'CHINCHEROS',
      distrito: 'HUACCANA',
    ),
    Comisaria(
      id: 11,
      nombre: 'COMISARÍA DE HUANCARAMA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '942118991',
      departamento: 'APURIMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'HUANCARAMA',
    ),
    Comisaria(
      id: 12,
      nombre: 'COMISARÍA DE KISHUARA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '957833499',
      departamento: 'APURIMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'KISHUARA',
    ),
    Comisaria(
      id: 13,
      nombre: 'COMISARÍA DE OCOBAMBA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980121607',
      departamento: 'APURIMAC',
      provincia: 'CHINCHEROS',
      distrito: 'OCOBAMBA',
    ),
    Comisaria(
      id: 14,
      nombre: 'COMISARÍA DE ONGOY',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '964609892',
      departamento: 'APURIMAC',
      provincia: 'CHINCHEROS',
      distrito: 'ONGOY',
    ),
    Comisaria(
      id: 15,
      nombre: 'COMISARÍA DE PACUCHA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '958893584',
      departamento: 'APURIMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'PACUCHA',
    ),
    Comisaria(
      id: 16,
      nombre: 'COMISARÍA DE RANRACANCHA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '957833492',
      departamento: 'APURIMAC',
      provincia: 'CHINCHEROS',
      distrito: 'RANRACANCHA',
    ),
    Comisaria(
      id: 17,
      nombre: 'COMISARÍA DE S.A DE CACHI',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980121091',
      departamento: 'APURIMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'SAN ANTONIO DE CACHI',
    ),
    Comisaria(
      id: 18,
      nombre: 'COMISARÍA DE SAN JERÓNIMO',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980122039',
      departamento: 'APURIMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'SAN JERÓNIMO',
    ),
    Comisaria(
      id: 19,
      nombre: 'COMISARÍA DE S.M. DE CHICMO',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '943070460',
      departamento: 'APURIMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'SAN MIGUEL DE CHICMO',
    ),
    Comisaria(
      id: 20,
      nombre: 'COMISARÍA DE TALAVERA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980122026',
      departamento: 'APURIMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'TALAVERA',
    ),
    Comisaria(
      id: 21,
      nombre: 'COMISARÍA DE URIPA',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980121439',
      departamento: 'APURIMAC',
      provincia: 'CHINCHEROS',
      distrito: 'URIPA',
    ),
    Comisaria(
      id: 22,
      nombre: 'PAP "CHACCRAMPA"',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980122034',
      departamento: 'APURIMAC',
      provincia: 'ANDAHUAYLAS',
      distrito: 'CHACCRAMPA',
    ),
    Comisaria(
      id: 23,
      nombre: 'DIVINCRI PNP ABANCAY',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '949649710',
      departamento: 'APURIMAC',
      provincia: 'ABANCAY',
      distrito: 'ABANCAY',
    ),
    Comisaria(
      id: 24,
      nombre: 'DIVOPUS PNP ABANCAY',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '964603380',
      departamento: 'APURIMAC',
      provincia: 'ABANCAY',
      distrito: 'ABANCAY',
    ),
    Comisaria(
      id: 25,
      nombre: 'TRÁNSITO PNP ABANCAY',
      unidad: 'REGIÓN POLICIAL APURÍMAC',
      telefono: '980122443',
      departamento: 'APURIMAC',
      provincia: 'ABANCAY',
      distrito: 'ABANCAY',
    ),
  ];

  @override
  String toString() {
    return 'Comisaria{id: $id, nombre: $nombre, unidad: $unidad, telefono: $telefono, departamento: $departamento, provincia: $provincia, distrito: $distrito}';
  }
}

/// 🚔 Servicio moderno de Agenda Policial con diseño atractivo
class AgendaPolicialService {
  static Database? _database;
  static List<ComisariaModel>? _comisariasCache;
  static DateTime? _lastCacheUpdate;
  static ValueNotifier<SyncStatus> _syncStatusNotifier = ValueNotifier(
    SyncStatus.idle,
  );
  static ValueNotifier<double> _progressNotifier = ValueNotifier(0.0);

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

  /// 📊 Carga comisarías desde CSV con progreso visual
  static Future<List<ComisariaModel>> _cargarComisariasDesdeCSV({
    Function(double)? onProgress,
  }) async {
    try {
      // Cargar el archivo CSV desde assets
      final String csvContent = await rootBundle.loadString(
        'assets/PRONTUARIO.csv',
      );
      onProgress?.call(0.2);

      // Dividir en líneas
      final List<String> lines = csvContent.split('\n');

      if (lines.isEmpty) {
        throw Exception('📄 El archivo CSV está vacío');
      }

      // Obtener headers (primera línea)
      final String headerLine = lines[0].trim();
      final List<String> headers = headerLine.split(';');
      onProgress?.call(0.3);

      // Validar headers esperados
      final expectedHeaders = [
        'id_comisaria',
        'nombre',
        'unidad',
        'telefono',
        'departamento',
        'provincia',
        'distrito',
      ];
      for (String expected in expectedHeaders) {
        if (!headers.contains(expected)) {
          debugPrint('⚠️ Header faltante: $expected');
        }
      }

      final List<ComisariaModel> comisarias = [];
      final int totalLines = lines.length - 1; // Excluir header

      // Procesar cada línea de datos con progreso
      for (int i = 1; i < lines.length; i++) {
        final String line = lines[i].trim();
        if (line.isEmpty) continue;

        try {
          // Dividir por punto y coma
          final List<String> values = line.split(';');

          if (values.length >= 7) {
            // Limpiar comillas si existen
            for (int j = 0; j < values.length; j++) {
              values[j] = values[j].trim();
              if (values[j].startsWith('"') && values[j].endsWith('"')) {
                values[j] = values[j].substring(1, values[j].length - 1);
              }
            }

            final comisaria = ComisariaModel.fromMap({
              'id': int.tryParse(values[0]) ?? i,
              'nombre': values[1],
              'unidad': values[2],
              'telefono': values[3],
              'departamento': values[4].toUpperCase(),
              'provincia': values[5].toUpperCase(),
              'distrito': values[6].toUpperCase(),
            });

            // Validar datos mínimos
            if (comisaria.nombre.isNotEmpty &&
                comisaria.departamento.isNotEmpty) {
              comisarias.add(comisaria);
            }
          }

          // Actualizar progreso
          final progress = 0.3 + ((i / totalLines) * 0.7);
          onProgress?.call(progress);
        } catch (e) {
          debugPrint('❌ Error procesando línea $i: $e');
        }
      }

      debugPrint('✅ CSV procesado: ${comisarias.length} comisarías válidas');
      return comisarias;
    } catch (e) {
      debugPrint('❌ Error cargando CSV: $e');
      throw Exception('No se pudo cargar el archivo CSV: $e');
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
                if (comisaria.unidad.toUpperCase().contains(queryUpper))
                  puntuacion += 30;
                if (comisaria.provincia.toUpperCase().contains(queryUpper))
                  puntuacion += 20;
                if (comisaria.distrito.toUpperCase().contains(queryUpper))
                  puntuacion += 20;
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

    final comisarias = await _cargarComisariasDesdeCSV();
    _comisariasCache = comisarias;
    _lastCacheUpdate = DateTime.now();
    return comisarias;
  }

  static Future<List<ComisariaModel>> cargarComisariasDepartamento(
    String departamento,
  ) async {
    final comisarias = await _getComisariasFromCache();
    return comisarias
        .where(
          (c) => c.departamento.toUpperCase() == departamento.toUpperCase(),
        )
        .toList();
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
    try {
      final db = await _getDatabase();

      await db.execute('''
        CREATE TABLE IF NOT EXISTS comisarias_csv (
          id INTEGER PRIMARY KEY,
          nombre TEXT NOT NULL,
          unidad TEXT,
          telefono TEXT,
          departamento TEXT NOT NULL,
          provincia TEXT,
          distrito TEXT,
          fecha_actualizacion TEXT
        )
      ''');

      await db.delete('comisarias_csv');

      final batch = db.batch();
      for (final comisaria in comisarias) {
        batch.insert('comisarias_csv', {
          'id': comisaria.id,
          'nombre': comisaria.nombre,
          'unidad': comisaria.unidad,
          'telefono': comisaria.telefono,
          'departamento': comisaria.departamento,
          'provincia': comisaria.provincia,
          'distrito': comisaria.distrito,
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        });
      }

      await batch.commit();
      debugPrint('💾 Comisarías guardadas en BD local: ${comisarias.length}');
    } catch (e) {
      debugPrint('⚠️ Error guardando en BD local: $e');
    }
  }

  static Future<Database> _getDatabase() async {
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
