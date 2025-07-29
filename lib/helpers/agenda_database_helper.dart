import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../data/models/comisaria_model.dart';

class AgendaDatabaseHelper {
  static final AgendaDatabaseHelper _instance = AgendaDatabaseHelper._internal();
  factory AgendaDatabaseHelper() => _instance;
  AgendaDatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'agenda_comisarias.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabla de comisarías
    await db.execute('''
      CREATE TABLE comisarias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        unidad TEXT NOT NULL,
        telefono TEXT NOT NULL,
        departamento TEXT NOT NULL,
        provincia TEXT NOT NULL,
        distrito TEXT NOT NULL,
        fecha_actualizacion INTEGER NOT NULL
      )
    ''');

    // Tabla de sincronización de departamentos
    await db.execute('''
      CREATE TABLE departamentos_sync (
        departamento TEXT PRIMARY KEY,
        ultima_actualizacion INTEGER NOT NULL,
        hash TEXT NOT NULL
      )
    ''');

    // Índices para mejorar el rendimiento
    await db.execute('CREATE INDEX idx_departamento ON comisarias(departamento)');
    await db.execute('CREATE INDEX idx_nombre ON comisarias(nombre)');
    await db.execute('CREATE INDEX idx_telefono ON comisarias(telefono)');
  }

  // CRUD para comisarías
  Future<int> insertComisaria(ComisariaModel comisaria) async {
    final db = await database;
    return await db.insert('comisarias', comisaria.toMap());
  }

  Future<List<int>> insertComisarias(List<ComisariaModel> comisarias) async {
    final db = await database;
    final batch = db.batch();
    
    for (ComisariaModel comisaria in comisarias) {
      batch.insert('comisarias', comisaria.toMap());
    }
    
    final results = await batch.commit();
    return results.cast<int>();
  }

  Future<List<ComisariaModel>> getComisariasByDepartamento(String departamento) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'comisarias',
      where: 'departamento = ?',
      whereArgs: [departamento.toUpperCase()],
      orderBy: 'nombre ASC',
    );

    return List.generate(maps.length, (i) {
      return ComisariaModel.fromMap(maps[i]);
    });
  }

  Future<List<String>> getDepartamentosDisponibles() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT DISTINCT departamento FROM comisarias ORDER BY departamento ASC'
    );

    return maps.map((map) => map['departamento'] as String).toList();
  }

  Future<List<ComisariaModel>> searchComisarias(String departamento, String query) async {
    final db = await database;
    final queryLower = query.toLowerCase();
    
    final List<Map<String, dynamic>> maps = await db.query(
      'comisarias',
      where: '''
        departamento = ? AND (
          LOWER(nombre) LIKE ? OR 
          LOWER(distrito) LIKE ? OR 
          LOWER(provincia) LIKE ? OR 
          LOWER(unidad) LIKE ? OR 
          telefono LIKE ?
        )
      ''',
      whereArgs: [
        departamento.toUpperCase(),
        '%$queryLower%',
        '%$queryLower%',
        '%$queryLower%',
        '%$queryLower%',
        '%$query%',
      ],
      orderBy: 'nombre ASC',
    );

    return List.generate(maps.length, (i) {
      return ComisariaModel.fromMap(maps[i]);
    });
  }

  Future<int> getComisariasCountByDepartamento(String departamento) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM comisarias WHERE departamento = ?',
      [departamento.toUpperCase()]
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteComisariasByDepartamento(String departamento) async {
    final db = await database;
    await db.delete(
      'comisarias',
      where: 'departamento = ?',
      whereArgs: [departamento.toUpperCase()],
    );
  }

  // CRUD para sincronización de departamentos
  Future<void> insertOrUpdateDepartamentoSync(DepartamentoSyncModel sync) async {
    final db = await database;
    await db.insert(
      'departamentos_sync',
      sync.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DepartamentoSyncModel?> getDepartamentoSync(String departamento) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'departamentos_sync',
      where: 'departamento = ?',
      whereArgs: [departamento.toUpperCase()],
    );

    if (maps.isNotEmpty) {
      return DepartamentoSyncModel.fromMap(maps.first);
    }
    return null;
  }

  Future<List<DepartamentoSyncModel>> getAllDepartamentosSync() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('departamentos_sync');

    return List.generate(maps.length, (i) {
      return DepartamentoSyncModel.fromMap(maps[i]);
    });
  }

  Future<void> deleteDepartamentoSync(String departamento) async {
    final db = await database;
    await db.delete(
      'departamentos_sync',
      where: 'departamento = ?',
      whereArgs: [departamento.toUpperCase()],
    );
  }

  // Utilidades
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('comisarias');
    await db.delete('departamentos_sync');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}