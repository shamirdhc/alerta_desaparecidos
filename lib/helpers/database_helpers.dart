import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';

/// Helper multiplataforma de Ubigeo Perú.
/// Soporta Web y Safari parseando en memoria 'assets/ubigeo_peru.sql',
/// y en Android/iOS nativo ejecuta un Batch transaccional optimizado.
class DatabaseHelper {
  static const String sqlFileName = 'ubigeo_peru.sql';
  static const String dbName = 'ubigeo_peru.sqlite';
  static Database? _database;

  static List<Map<String, dynamic>>? _webDepartmentsCache;
  static List<Map<String, dynamic>>? _webProvincesCache;
  static List<Map<String, dynamic>>? _webDistrictsCache;

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> _ensureWebMemoryCache() async {
    if (_webDepartmentsCache != null) return;
    _webDepartmentsCache = [];
    _webProvincesCache = [];
    _webDistrictsCache = [];

    try {
      final String sqlScript = await rootBundle.loadString('assets/$sqlFileName');
      final RegExp tupleRegex = RegExp(r"\('([^']*)',\s*'([^']*)'(?:,\s*'([^']*)')?(?:,\s*'([^']*)')?\)");

      for (final rawLine in sqlScript.split(';')) {
        final line = rawLine.trim();
        if (line.contains('ubigeo_peru_departments')) {
          for (final m in tupleRegex.allMatches(line)) {
            _webDepartmentsCache!.add({
              'id': m.group(1) ?? '',
              'name': m.group(2) ?? '',
            });
          }
        } else if (line.contains('ubigeo_peru_provinces')) {
          for (final m in tupleRegex.allMatches(line)) {
            _webProvincesCache!.add({
              'id': m.group(1) ?? '',
              'name': m.group(2) ?? '',
              'department_id': m.group(3) ?? '',
            });
          }
        } else if (line.contains('ubigeo_peru_districts')) {
          for (final m in tupleRegex.allMatches(line)) {
            _webDistrictsCache!.add({
              'id': m.group(1) ?? '',
              'name': m.group(2) ?? '',
              'province_id': m.group(3) ?? '',
              'department_id': m.group(4) ?? '',
            });
          }
        }
      }
      print('✅ [UbigeoWeb] Departamentos: ${_webDepartmentsCache!.length}, Provincias: ${_webProvincesCache!.length}, Distritos: ${_webDistrictsCache!.length}');
    } catch (e) {
      debugPrint('[UbigeoMemory] Error cargando ubigeo en memoria: $e');
    }
  }

  Future<Database> _initDatabase() async {
    final String dbPath = await getDatabasesPath();
    final String path = join(dbPath, dbName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        final String sqlScript = await rootBundle.loadString('assets/$sqlFileName');
        final List<String> sqlCommands = sqlScript.split(';');
        final Batch batch = db.batch();
        for (final command in sqlCommands) {
          if (command.trim().isNotEmpty) {
            batch.execute(command.trim());
          }
        }
        await batch.commit(noResult: true);
      },
    );
  }

  Future<List<Map<String, dynamic>>> getDepartamentos() async {
    if (kIsWeb) {
      await _ensureWebMemoryCache();
      return _webDepartmentsCache ?? [];
    }
    try {
      final db = await database;
      return await db!.query('ubigeo_peru_departments');
    } catch (_) {
      await _ensureWebMemoryCache();
      return _webDepartmentsCache ?? [];
    }
  }

  Future<List<Map<String, dynamic>>> getProvincias(String departmentId) async {
    if (kIsWeb) {
      await _ensureWebMemoryCache();
      return (_webProvincesCache ?? [])
          .where((p) => p['department_id'] == departmentId)
          .toList();
    }
    try {
      final db = await database;
      return await db!.query(
        'ubigeo_peru_provinces',
        where: 'department_id = ?',
        whereArgs: [departmentId],
      );
    } catch (_) {
      await _ensureWebMemoryCache();
      return (_webProvincesCache ?? [])
          .where((p) => p['department_id'] == departmentId)
          .toList();
    }
  }

  Future<List<Map<String, dynamic>>> getDistritos(String provinceId) async {
    if (kIsWeb) {
      await _ensureWebMemoryCache();
      return (_webDistrictsCache ?? [])
          .where((d) => d['province_id'] == provinceId)
          .toList();
    }
    try {
      final db = await database;
      return await db!.query(
        'ubigeo_peru_districts',
        where: 'province_id = ?',
        whereArgs: [provinceId],
      );
    } catch (_) {
      await _ensureWebMemoryCache();
      return (_webDistrictsCache ?? [])
          .where((d) => d['province_id'] == provinceId)
          .toList();
    }
  }
}