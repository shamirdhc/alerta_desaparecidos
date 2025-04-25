import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';

class DatabaseHelper {
  static const String sqlFileName = 'ubigeo_peru.sql'; // Nombre del archivo SQL
  static const String dbName = 'ubigeo_peru.sqlite';   // Nombre de la base de datos SQLite
  static Database? _database;

  // Getter para inicializar o devolver la base de datos
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Método para inicializar la base de datos
  Future<Database> _initDatabase() async {
    // Obtiene la ruta para almacenar la base de datos
    final String dbPath = await getDatabasesPath();
    final String path = join(dbPath, dbName);

    // Verifica si la base de datos ya existe
    final bool exists = await databaseExists(path);
    if (!exists) {
      print('La base de datos no existe. Creando nueva base de datos...');

      try {
        // Crea la base de datos y ejecuta el archivo SQL
        final db = await openDatabase(
          path,
          version: 1,
          onCreate: (db, version) async {
            final String sqlScript = await rootBundle.loadString('assets/$sqlFileName');
            final List<String> sqlCommands = sqlScript.split(';');

            for (var command in sqlCommands) {
              if (command.trim().isNotEmpty) {
                try {
                  print('Ejecutando comando SQL: $command');
                  await db.execute(command);
                  print('Comando ejecutado correctamente.');
                } catch (e) {
                  print('Error ejecutando el comando SQL: $command');
                  print('Mensaje de error: $e');
                  throw Exception('Error ejecutando el comando: $command\n$e');
                }
              }
            }
          },
        );
        print('Base de datos creada exitosamente.');
        return db;
      } catch (e) {
        print('Error al crear la base de datos: $e');
        throw Exception(e.toString());
      }
    }

    print('La base de datos ya existe. Abriendo...');
    return await openDatabase(path, version: 1);
  }

  // Método para obtener los departamentos
  Future<List<Map<String, dynamic>>> getDepartamentos() async {
    final db = await database;
    try {
      final departamentos = await db.query('ubigeo_peru_departments');
      print('Departamentos cargados: $departamentos'); // Agrega un log para revisar los datos
      return departamentos;
    } catch (e) {
      print('Error obteniendo departamentos: $e');
      return [];
    }
  }

  // Método para obtener las provincias de un departamento
  Future<List<Map<String, dynamic>>> getProvincias(String departmentId) async {
    final db = await database;
    try {
      return await db.query(
        'ubigeo_peru_provinces', // Nombre correcto de la tabla
        where: 'department_id = ?',
        whereArgs: [departmentId],
      );
    } catch (e) {
      print('Error obteniendo provincias: $e');
      return [];
    }
  }

  // Método para obtener los distritos de una provincia
  Future<List<Map<String, dynamic>>> getDistritos(String provinceId) async {
    final db = await database;
    try {
      return await db.query(
        'ubigeo_peru_districts', // Nombre correcto de la tabla
        where: 'province_id = ?',
        whereArgs: [provinceId],
      );
    } catch (e) {
      print('Error obteniendo distritos: $e');
      return [];
    }
  }
}