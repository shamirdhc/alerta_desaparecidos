import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../data/models/cem_model.dart';
import '../common/constants/peru_locations.dart';

class CemService {
  static List<CemModel> _cache = [];
  static bool _cargando = false;

  /// Carga inicial del directorio nacional de CEM desde assets/data/directorio_cem.json
  static Future<List<CemModel>> inicializar() async {
    if (_cache.isNotEmpty) return _cache;
    if (_cargando) {
      while (_cargando) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _cache;
    }

    _cargando = true;
    try {
      final jsonString = await rootBundle.loadString('assets/data/directorio_cem.json');
      final List<dynamic> list = jsonDecode(jsonString);
      _cache = list.map((item) => CemModel.fromJson(item as Map<String, dynamic>)).toList();
      debugPrint('✅ [CEM] Cargados ${_cache.length} Centros Emergencia Mujer a nivel nacional');
    } catch (e) {
      debugPrint('⚠️ [CEM] Error al cargar directorio_cem.json: $e');
    } finally {
      _cargando = false;
    }

    return _cache;
  }

  /// Retorna todos los CEM registrados
  static Future<List<CemModel>> getTodos() async {
    if (_cache.isEmpty) {
      await inicializar();
    }
    return List.unmodifiable(_cache);
  }

  /// Retorna la lista ordenada de departamentos disponibles
  static Future<List<String>> getDepartamentos() async {
    final todos = await getTodos();
    final depts = todos.map((c) => c.departamento).where((d) => d.isNotEmpty).toSet().toList();
    depts.sort((a, b) => a.compareTo(b));
    return depts;
  }

  /// Retorna las provincias asociadas a un departamento
  static Future<List<String>> getProvincias(String departamento) async {
    final todos = await getTodos();
    final provs = todos
        .where((c) => c.departamento.toUpperCase() == departamento.toUpperCase())
        .map((c) => c.provincia)
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();
    provs.sort((a, b) => a.compareTo(b));
    return provs;
  }

  /// Conteo de CEMs por departamento
  static Future<Map<String, int>> getConteosPorDepartamento() async {
    final todos = await getTodos();
    final Map<String, int> conteos = {};
    for (final c in todos) {
      conteos[c.departamento] = (conteos[c.departamento] ?? 0) + 1;
    }
    return conteos;
  }

  /// Búsqueda y filtrado compuesto por texto, departamento y provincia
  static Future<List<CemModel>> buscar({
    String? query,
    String? departamento,
    String? provincia,
  }) async {
    final todos = await getTodos();

    return todos.where((cem) {
      // 1. Filtro Departamento
      if (departamento != null && departamento.isNotEmpty) {
        if (PeruLocations.normalize(cem.departamento) != PeruLocations.normalize(departamento)) {
          return false;
        }
      }

      // 2. Filtro Provincia
      if (provincia != null && provincia.isNotEmpty) {
        if (PeruLocations.normalize(cem.provincia) != PeruLocations.normalize(provincia)) {
          return false;
        }
      }

      // 3. Filtro Query de texto
      if (query != null && query.trim().isNotEmpty) {
        final q = PeruLocations.normalize(query.trim());
        final matchNombre = PeruLocations.normalize(cem.nombre).contains(q);
        final matchCem = PeruLocations.normalize(cem.cem).contains(q);
        final matchDistrito = PeruLocations.normalize(cem.distrito).contains(q);
        final matchProvincia = PeruLocations.normalize(cem.provincia).contains(q);
        final matchDireccion = PeruLocations.normalize(cem.direccion).contains(q);
        final matchCoordinador = PeruLocations.normalize(cem.coordinador).contains(q);
        final matchTelefono = cem.telefono.contains(q) || cem.telefonos.any((t) => t.contains(q));

        if (!matchNombre &&
            !matchCem &&
            !matchDistrito &&
            !matchProvincia &&
            !matchDireccion &&
            !matchCoordinador &&
            !matchTelefono) {
          return false;
        }
      }

      return true;
    }).toList();
  }
}
