import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/desaparecido.dart';
import '../../domain/enums.dart';
import '../../services/gps_location_service.dart';

class DesaparecidoLocalDataSource {
  static const String _dbName = 'desaparecidos_local.db';
  static const int _dbVersion = 1;
  static const String tableName = 'desaparecidos_local';
  static const String keyLastSync = 'desaparecidos_last_sync_timestamp';

  static Database? _database;

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id TEXT PRIMARY KEY,
        nombres TEXT NOT NULL,
        apellidos TEXT NOT NULL,
        sexo TEXT,
        dni TEXT,
        telefono_contacto TEXT,
        fecha_nacimiento INTEGER,
        fecha_desaparicion INTEGER NOT NULL,
        departamento TEXT NOT NULL,
        provincia TEXT,
        distrito TEXT,
        detalles_adicionales TEXT,
        estado TEXT NOT NULL DEFAULT 'activo',
        fecha_encontrado INTEGER,
        encontrado_detalles TEXT,
        foto_url TEXT,
        imagen_ficha_url TEXT,
        fecha_creacion INTEGER,
        fecha_actualizacion INTEGER,
        fecha_expiracion INTEGER,
        unidad_a_cargo TEXT,
        depitptim_id TEXT,
        depitptim_nombre TEXT,
        unidad_registradora TEXT,
        fecha_reasignacion_depitptim INTEGER
      )
    ''');

    // Índices para máxima velocidad de filtrado, paginación y ordenamiento
    await db.execute('CREATE INDEX idx_dl_fecha ON $tableName(fecha_desaparicion DESC)');
    await db.execute('CREATE INDEX idx_dl_estado_fecha ON $tableName(estado, fecha_desaparicion DESC)');
    await db.execute('CREATE INDEX idx_dl_depto_fecha ON $tableName(departamento, fecha_desaparicion DESC)');
    await db.execute('CREATE INDEX idx_dl_estado_depto ON $tableName(estado, departamento, fecha_desaparicion DESC)');
    await db.execute('CREATE INDEX idx_dl_expiracion ON $tableName(fecha_expiracion)');
  }

  Map<String, dynamic> _toMapDb(Desaparecido d) {
    return {
      'id': d.id,
      'nombres': d.nombres,
      'apellidos': d.apellidos,
      'sexo': d.sexo,
      'dni': d.dni,
      'telefono_contacto': d.telefonoContacto,
      'fecha_nacimiento': d.fechaNacimiento?.millisecondsSinceEpoch,
      'fecha_desaparicion': d.fechaDesaparicion?.millisecondsSinceEpoch ?? 0,
      'departamento': d.departamento ?? '',
      'provincia': d.provincia,
      'distrito': d.distrito,
      'detalles_adicionales': d.detallesAdicionales,
      'estado': d.estado ?? 'activo',
      'fecha_encontrado': d.fechaEncontrado?.millisecondsSinceEpoch,
      'encontrado_detalles': d.encontradoDetalles,
      'foto_url': d.fotoUrl,
      'imagen_ficha_url': d.imagenFichaUrl,
      'fecha_creacion': d.fechaCreacion?.millisecondsSinceEpoch,
      'fecha_actualizacion': d.fechaActualizacion?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      // 8 meses de vigencia estricta por regla de negocio
      'fecha_expiracion': d.fechaDesaparicion?.add(const Duration(days: 240)).millisecondsSinceEpoch,
      'unidad_a_cargo': d.unidadACargo,
      'depitptim_id': d.depitptimId,
      'depitptim_nombre': d.depitptimNombre,
      'unidad_registradora': d.unidadRegistradora,
      'fecha_reasignacion_depitptim': d.fechaReasignacionDepitptim?.millisecondsSinceEpoch,
    };
  }

  /// Guarda o actualiza un lote de desaparecidos en SQLite
  Future<void> saveDesaparecidosBatch(List<Desaparecido> list) async {
    if (kIsWeb || list.isEmpty) return;
    final db = await database;
    if (db == null) return;

    final batch = db.batch();
    for (final d in list) {
      if (d.id == null || d.id!.isEmpty) continue;
      batch.insert(
        tableName,
        _toMapDb(d),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Obtiene los casos de la base de datos local con filtros y paginación
  Future<List<Desaparecido>> getDesaparecidos({
    MissingFilter filter = MissingFilter.active,
    String? departamento,
    String? searchQuery,
    int limit = 30,
    int offset = 0,
  }) async {
    if (kIsWeb) return [];
    final db = await database;
    if (db == null) return [];

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    // 1. Filtro por estado
    if (filter == MissingFilter.found) {
      whereClauses.add("estado = 'encontrado'");
    } else if (filter == MissingFilter.active) {
      whereClauses.add("estado != 'encontrado'");
    }

    // 2. Filtro por departamento
    final cleanDept = departamento?.trim();
    if (cleanDept != null &&
        cleanDept.isNotEmpty &&
        cleanDept.toLowerCase() != 'todos' &&
        cleanDept.toLowerCase() != 'todos los departamentos') {
      final variants = GpsLocationService.getDepartmentVariants(cleanDept);
      if (variants.isNotEmpty) {
        final placeholders = List.filled(variants.length, '?').join(', ');
        whereClauses.add("departamento IN ($placeholders)");
        whereArgs.addAll(variants);
      } else {
        whereClauses.add("departamento = ?");
        whereArgs.add(cleanDept);
      }
    }

    // 3. Filtro por búsqueda de texto
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim().toUpperCase()}%';
      whereClauses.add("(UPPER(nombres) LIKE ? OR UPPER(apellidos) LIKE ? OR dni LIKE ?)");
      whereArgs.addAll([q, q, q]);
    }

    // 4. Regla estricta de 8 meses (240 días)
    final limiteOchoMesesMs = DateTime.now().subtract(const Duration(days: 240)).millisecondsSinceEpoch;
    if (filter == MissingFilter.active) {
      whereClauses.add("fecha_desaparicion >= ?");
      whereArgs.add(limiteOchoMesesMs);
    } else {
      whereClauses.add("(fecha_encontrado >= ? OR fecha_desaparicion >= ?)");
      whereArgs.addAll([limiteOchoMesesMs, limiteOchoMesesMs]);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    // Ordenamiento: Encontrados por fecha de hallazgo desc, activos por fecha de desaparición desc
    final orderBy = filter == MissingFilter.found
        ? "COALESCE(fecha_encontrado, fecha_desaparicion) DESC, id DESC"
        : "fecha_desaparicion DESC, id DESC";

    final rows = await db.query(
      tableName,
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );

    return rows.map((row) => Desaparecido.fromMap(row, row['id'] as String?)).toList();
  }

  /// Conteo total rápido de registros que coinciden con los filtros
  Future<int> getTotalCount({
    MissingFilter filter = MissingFilter.active,
    String? departamento,
    String? searchQuery,
  }) async {
    if (kIsWeb) return 0;
    final db = await database;
    if (db == null) return 0;

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (filter == MissingFilter.found) {
      whereClauses.add("estado = 'encontrado'");
    } else if (filter == MissingFilter.active) {
      whereClauses.add("estado != 'encontrado'");
    }

    final cleanDept = departamento?.trim();
    if (cleanDept != null &&
        cleanDept.isNotEmpty &&
        cleanDept.toLowerCase() != 'todos' &&
        cleanDept.toLowerCase() != 'todos los departamentos') {
      final variants = GpsLocationService.getDepartmentVariants(cleanDept);
      if (variants.isNotEmpty) {
        final placeholders = List.filled(variants.length, '?').join(', ');
        whereClauses.add("departamento IN ($placeholders)");
        whereArgs.addAll(variants);
      } else {
        whereClauses.add("departamento = ?");
        whereArgs.add(cleanDept);
      }
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim().toUpperCase()}%';
      whereClauses.add("(UPPER(nombres) LIKE ? OR UPPER(apellidos) LIKE ? OR dni LIKE ?)");
      whereArgs.addAll([q, q, q]);
    }

    final limiteOchoMesesMs = DateTime.now().subtract(const Duration(days: 240)).millisecondsSinceEpoch;
    if (filter == MissingFilter.active) {
      whereClauses.add("fecha_desaparicion >= ?");
      whereArgs.add(limiteOchoMesesMs);
    } else {
      whereClauses.add("(fecha_encontrado >= ? OR fecha_desaparicion >= ?)");
      whereArgs.addAll([limiteOchoMesesMs, limiteOchoMesesMs]);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as total FROM $tableName ${whereString != null ? 'WHERE $whereString' : ''}',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return Sqflite.firstIntValue(result) ?? 0;
    }
    return 0;
  }

  /// Total general de casos almacenados localmente
  Future<int> getLocalCount() async {
    if (kIsWeb) return 0;
    final db = await database;
    if (db == null) return 0;
    final result = await db.rawQuery('SELECT COUNT(*) as total FROM $tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Actualiza un caso a estado encontrado localmente
  Future<void> markAsFoundLocal(String id, DateTime fecha, String detalles) async {
    if (kIsWeb) return;
    final db = await database;
    if (db == null) return;
    await db.update(
      tableName,
      {
        'estado': 'encontrado',
        'fecha_encontrado': fecha.millisecondsSinceEpoch,
        'encontrado_detalles': detalles.toUpperCase(),
        'fecha_actualizacion': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Elimina casos que exceden los 8 meses (240 días)
  Future<int> purgeExpiredCases() async {
    if (kIsWeb) return 0;
    final db = await database;
    if (db == null) return 0;
    final limiteMs = DateTime.now().subtract(const Duration(days: 240)).millisecondsSinceEpoch;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    return await db.delete(
      tableName,
      where: 'fecha_desaparicion < ? OR (fecha_expiracion IS NOT NULL AND fecha_expiracion < ?)',
      whereArgs: [limiteMs, nowMs],
    );
  }

  /// Obtiene la marca de tiempo de la última sincronización con Firebase
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(keyLastSync);
    if (millis != null) {
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    return null;
  }

  /// Guarda la marca de tiempo de sincronización exitosa
  Future<void> setLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyLastSync, time.millisecondsSinceEpoch);
  }
}
