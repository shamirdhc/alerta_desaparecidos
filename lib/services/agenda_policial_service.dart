import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
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

  factory Comisaria.fromCsvRow(List<String> row, String departamento) {
    return Comisaria(
      id: row.isNotEmpty ? int.tryParse(row[0].trim()) ?? 0 : 0,
      nombre: row.length > 1 ? row[1].trim() : '',
      unidad: row.length > 2 ? row[2].trim() : '',
      telefono: row.length > 3 ? row[3].trim() : '',
      departamento: departamento,
      provincia: row.length > 4 ? row[4].trim() : '',
      distrito: row.length > 5 ? row[5].trim() : '',
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

class AgendaPolicialService {
  static Database? _database;
  static const String _databaseName = 'PRONTUARIO.sqlite';
  
  // Lista de todos los departamentos disponibles
  static const List<String> departamentos = [
    'AMAZONAS',
    'ANCASH',
    'APURIMAC',
    'AREQUIPA',
    'AYACUCHO',
    'CAJAMARCA',
    'CALLAO',
    'CUSCO',
    'HUANCAVELICA',
    'HUANUCO',
    'ICA',
    'JUNIN',
    'LA LIBERTAD',
    'LAMBAYEQUE',
    'LIMA',
    'LORETO',
    'MADRE DE DIOS',
    'MOQUEGUA',
    'PASCO',
    'PIURA',
    'PUNO',
    'SAN MARTIN',
    'TACNA',
    'TUMBES',
    'UCAYALI',
  ];

  /// Inicializa la base de datos copiando desde assets
  static Future<Database> _initDatabase() async {
    if (_database != null) return _database!;

    try {
      // Obtener el directorio de documentos de la aplicación
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _databaseName);

      // Verificar si la base de datos ya existe
      final exists = await File(path).exists();
      
      if (!exists) {
        print('Copiando base de datos desde assets...');
        
        // Cargar la base de datos desde assets
        final data = await rootBundle.load('assets/$_databaseName');
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        
        // Escribir la base de datos en el directorio de documentos
        await File(path).writeAsBytes(bytes);
        print('Base de datos copiada exitosamente');
      }

      // Abrir la base de datos sin modo de solo lectura
      _database = await openDatabase(
        path,
        version: 1,
        // Removido readOnly: true para permitir operaciones necesarias
        onOpen: (db) async {
          // Configurar la base de datos después de abrirla
          await db.execute('PRAGMA foreign_keys = ON');
          print('Base de datos configurada correctamente');
        },
      );

      print('Base de datos inicializada: $path');
      return _database!;
      
    } catch (e) {
      print('Error al inicializar base de datos: $e');
      throw Exception('No se pudo inicializar la base de datos: $e');
    }
  }

  /// Obtiene la lista de tablas disponibles en la base de datos
  static Future<List<String>> _getTableNames() async {
    final db = await _initDatabase();
    
    try {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
      );
      
      return result.map((row) => row['name'].toString()).toList();
    } catch (e) {
      print('Error al obtener nombres de tablas: $e');
      return [];
    }
  }

  /// Obtiene la estructura de una tabla específica
  static Future<List<Map<String, dynamic>>> _getTableInfo(String tableName) async {
    final db = await _initDatabase();
    
    try {
      final result = await db.rawQuery("PRAGMA table_info($tableName)");
      return result;
    } catch (e) {
      print('Error al obtener información de tabla $tableName: $e');
      return [];
    }
  }

  /// Detecta automáticamente la tabla y columnas correctas
  static Future<Map<String, String>> _detectTableStructure() async {
    final tables = await _getTableNames();
    print('Tablas disponibles: $tables');
    
    // Buscar tabla que contenga datos de comisarías
    for (String tableName in tables) {
      final tableInfo = await _getTableInfo(tableName);
      
      // Extraer nombres de columnas correctamente
      List<String> columnNames = [];
      for (var col in tableInfo) {
        final name = col['name'].toString();
        // No convertir a minúsculas aquí, mantener el nombre original
        columnNames.add(name);
      }
      
      print('Tabla: $tableName, Columnas originales: $columnNames');
      
      // Verificar si tiene columnas relacionadas con comisarías (comparación case-insensitive)
      bool hasComisariaColumns = columnNames.any((col) => 
        col.toLowerCase().contains('nombre') || 
        col.toLowerCase().contains('comisaria') || 
        col.toLowerCase().contains('unidad')
      );
      
      bool hasDepartamentoColumn = columnNames.any((col) => 
        col.toLowerCase().contains('departamento') || 
        col.toLowerCase().contains('region')
      );
      
      if (hasComisariaColumns && hasDepartamentoColumn) {
        // Mapear columnas comunes usando nombres exactos
        Map<String, String> columnMapping = {
          'table': tableName,
        };
        
        // Buscar columnas específicas manteniendo nombres exactos
        for (String col in columnNames) {
          final colLower = col.toLowerCase();
          if (colLower.contains('nombre') && !columnMapping.containsKey('nombre')) {
            columnMapping['nombre'] = col;
          } else if (colLower.contains('unidad') && !columnMapping.containsKey('unidad')) {
            columnMapping['unidad'] = col;
          } else if (colLower.contains('telefono') || colLower.contains('phone')) {
            columnMapping['telefono'] = col;
          } else if (colLower.contains('departamento') || colLower.contains('region')) {
            columnMapping['departamento'] = col;
          } else if (colLower.contains('provincia')) {
            columnMapping['provincia'] = col;
          } else if (colLower.contains('distrito')) {
            columnMapping['distrito'] = col;
          }
        }
        
        print('Estructura detectada: $columnMapping');
        
        // Verificar que tenemos las columnas esenciales
        if (columnMapping.containsKey('nombre') && columnMapping.containsKey('departamento')) {
          return columnMapping;
        }
      }
    }
    
    throw Exception('No se pudo detectar la estructura de la tabla de comisarías');
  }

  /// Obtiene los departamentos disponibles en la base de datos
  static Future<List<String>> getDepartamentosDisponibles() async {
    try {
      final structure = await _detectTableStructure();
      final db = await _initDatabase();
      
      final tableName = structure['table']!;
      final departamentoColumn = structure['departamento']!;
      
      print('🔍 [DEBUG] Ejecutando consulta: SELECT DISTINCT $departamentoColumn FROM $tableName');
      
      final result = await db.rawQuery(
        'SELECT DISTINCT "$departamentoColumn" FROM "$tableName" WHERE "$departamentoColumn" IS NOT NULL AND "$departamentoColumn" != "" ORDER BY "$departamentoColumn"'
      );
      
      final departamentosDB = result
          .map((row) => row[departamentoColumn].toString().toUpperCase().trim())
          .where((dept) => dept.isNotEmpty)
          .toSet()
          .toList();
      
      print('Departamentos encontrados en BD: $departamentosDB');
      return departamentosDB;
      
    } catch (e) {
      print('Error al obtener departamentos: $e');
      return departamentos; // Fallback a lista predefinida
    }
  }

  /// Carga las comisarías de un departamento específico
  static Future<List<ComisariaModel>> cargarComisariasDepartamento(String departamento) async {
    try {
      final structure = await _detectTableStructure();
      final db = await _initDatabase();
      
      final tableName = structure['table']!;
      final nombreColumn = structure['nombre'] ?? 'nombre';
      final unidadColumn = structure['unidad'] ?? 'unidad';
      final telefonoColumn = structure['telefono'] ?? 'telefono';
      final departamentoColumn = structure['departamento']!;
      final provinciaColumn = structure['provincia'] ?? 'provincia';
      final distritoColumn = structure['distrito'] ?? 'distrito';
      
      final result = await db.rawQuery('''
        SELECT 
          $nombreColumn as nombre,
          $unidadColumn as unidad,
          $telefonoColumn as telefono,
          $departamentoColumn as departamento,
          $provinciaColumn as provincia,
          $distritoColumn as distrito
        FROM $tableName 
        WHERE UPPER($departamentoColumn) = ? 
        AND $nombreColumn IS NOT NULL 
        AND $nombreColumn != ""
        ORDER BY $nombreColumn
      ''', [departamento.toUpperCase()]);
      
      final comisarias = result.map((row) => ComisariaModel.fromMap(row)).toList();
      
      print('Comisarías encontradas para $departamento: ${comisarias.length}');
      return comisarias;
      
    } catch (e) {
      print('Error al cargar comisarías de $departamento: $e');
      throw Exception('No se pudieron cargar los datos de $departamento: $e');
    }
  }

  /// Busca comisarías por texto en un departamento específico
  static Future<List<ComisariaModel>> buscarComisarias(String departamento, String query) async {
    try {
      if (query.isEmpty) {
        return await cargarComisariasDepartamento(departamento);
      }

      final structure = await _detectTableStructure();
      final db = await _initDatabase();
      
      final tableName = structure['table']!;
      final nombreColumn = structure['nombre'] ?? 'nombre';
      final unidadColumn = structure['unidad'] ?? 'unidad';
      final telefonoColumn = structure['telefono'] ?? 'telefono';
      final departamentoColumn = structure['departamento']!;
      final provinciaColumn = structure['provincia'] ?? 'provincia';
      final distritoColumn = structure['distrito'] ?? 'distrito';
      
      final searchTerm = '%${query.toUpperCase()}%';
      
      final result = await db.rawQuery('''
        SELECT 
          $nombreColumn as nombre,
          $unidadColumn as unidad,
          $telefonoColumn as telefono,
          $departamentoColumn as departamento,
          $provinciaColumn as provincia,
          $distritoColumn as distrito
        FROM $tableName 
        WHERE UPPER($departamentoColumn) = ? 
        AND (
          UPPER($nombreColumn) LIKE ? OR 
          UPPER($unidadColumn) LIKE ? OR 
          UPPER($provinciaColumn) LIKE ? OR 
          UPPER($distritoColumn) LIKE ?
        )
        AND $nombreColumn IS NOT NULL 
        AND $nombreColumn != ""
        ORDER BY $nombreColumn
      ''', [departamento.toUpperCase(), searchTerm, searchTerm, searchTerm, searchTerm]);
      
      final comisarias = result.map((row) => ComisariaModel.fromMap(row)).toList();
      
      print('Búsqueda "$query" en $departamento: ${comisarias.length} resultados');
      return comisarias;
      
    } catch (e) {
      print('Error al buscar comisarías: $e');
      return [];
    }
  }

  /// Obtiene el conteo de comisarías por departamento
  static Future<int> getComisariasCount(String departamento) async {
    try {
      final structure = await _detectTableStructure();
      final db = await _initDatabase();
      
      final tableName = structure['table']!;
      final nombreColumn = structure['nombre'] ?? 'nombre';
      final departamentoColumn = structure['departamento']!;
      
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM $tableName 
        WHERE UPPER($departamentoColumn) = ? 
        AND $nombreColumn IS NOT NULL 
        AND $nombreColumn != ""
      ''', [departamento.toUpperCase()]);
      
      return result.first['count'] as int;
      
    } catch (e) {
      print('Error al obtener conteo de comisarías: $e');
      return 0;
    }
  }

  /// Inicializa el servicio (para compatibilidad con código existente)
  static Future<void> inicializarSincronizacion() async {
    try {
      print('Inicializando servicio de agenda policial...');
      await _initDatabase();
      
      // Verificar estructura de la base de datos
      await _detectTableStructure();
      
      final departamentosDisponibles = await getDepartamentosDisponibles();
      print('Servicio inicializado. Departamentos disponibles: ${departamentosDisponibles.length}');
      
    } catch (e) {
      print('Error al inicializar servicio: $e');
      throw Exception('No se pudo inicializar el servicio de agenda policial: $e');
    }
  }

  /// Obtiene información del estado del servicio
  static Future<Map<String, dynamic>> getEstadoSincronizacion() async {
    try {
      final departamentosDisponibles = await getDepartamentosDisponibles();
      
      return {
        'departamentos_locales': departamentosDisponibles.length,
        'fuente': 'SQLite Local (assets)',
        'departamentos_disponibles': departamentosDisponibles,
        'inicializado': _database != null,
      };
    } catch (e) {
      print('Error al obtener estado: $e');
      return {
        'error': e.toString(),
        'inicializado': false,
      };
    }
  }

  /// Cierra la conexión a la base de datos
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
