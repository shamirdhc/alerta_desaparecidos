import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';

class DatabaseHelper {
  static const String sqlFileName = 'ubigeo_peru.sql'; // Nombre del archivo SQL
  static const String dbName = 'ubigeo_peru.sqlite';   // Nombre de la base de datos SQLite
  static Database? _database;

  static const List<Map<String, dynamic>> _departamentosPeruWeb = [
    {'id': '01', 'name': 'AMAZONAS'},
    {'id': '02', 'name': 'ANCASH'},
    {'id': '03', 'name': 'APURIMAC'},
    {'id': '04', 'name': 'AREQUIPA'},
    {'id': '05', 'name': 'AYACUCHO'},
    {'id': '06', 'name': 'CAJAMARCA'},
    {'id': '07', 'name': 'CALLAO'},
    {'id': '08', 'name': 'CUSCO'},
    {'id': '09', 'name': 'HUANCAVELICA'},
    {'id': '10', 'name': 'HUANUCO'},
    {'id': '11', 'name': 'ICA'},
    {'id': '12', 'name': 'JUNIN'},
    {'id': '13', 'name': 'LA LIBERTAD'},
    {'id': '14', 'name': 'LAMBAYEQUE'},
    {'id': '15', 'name': 'LIMA'},
    {'id': '16', 'name': 'LORETO'},
    {'id': '17', 'name': 'MADRE DE DIOS'},
    {'id': '18', 'name': 'MOQUEGUA'},
    {'id': '19', 'name': 'PASCO'},
    {'id': '20', 'name': 'PIURA'},
    {'id': '21', 'name': 'PUNO'},
    {'id': '22', 'name': 'SAN MARTIN'},
    {'id': '23', 'name': 'TACNA'},
    {'id': '24', 'name': 'TUMBES'},
    {'id': '25', 'name': 'UCAYALI'},
  ];

  // Getter para inicializar o devolver la base de datos
  Future<Database?> get database async {
    if (kIsWeb) return null;
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
    if (db == null) {
      return _departamentosPeruWeb;
    }
    try {
      final departamentos = await db.query('ubigeo_peru_departments');
      return departamentos;
    } catch (e) {
      print('Error obteniendo departamentos: $e');
      return _departamentosPeruWeb;
    }
  }

  // Método para obtener las provincias de un departamento
  Future<List<Map<String, dynamic>>> getProvincias(String departmentId) async {
    final db = await database;
    if (db == null) {
      return [];
    }
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
    if (db == null) {
      return [];
    }
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