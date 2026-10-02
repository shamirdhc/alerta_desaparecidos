import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FamiliarProfile {
  final String id;
  final String nombreCompleto;
  final String parentesco; // Hijo, Hija, Padre, Madre, Abuelo/a, Hermano/a, Pareja, Mascota / Otro
  final int edad;
  final String dni; // Documento Nacional de Identidad
  final String? fotoBase64;
  final DateTime fechaActualizacionFoto;
  
  // Rasgos físicos seleccionables y rápidos
  final String estatura; // Ej: 1.20 m, 1.65 m
  final String contextura; // Delgada, Regular, Robusta
  final String colorPiel; // Clara, Trigueña, Morena
  final String colorCabello; // Negro, Castaño, Rubio, Canoso
  final String senasParticulares; // Lunares, cicatrices, tatuajes
  
  // Salud y contacto
  final String datosMedicos; // Alergias, medicación
  final String tipoSangre; // O+, A+, B+, AB+, etc.
  final String condicionEspecial; // Ninguna, Alzheimer, Autismo/TEA, etc.
  final String telefonoContacto; // Teléfono del tutor / familiar
  
  final String estiloCarnet; // 'auto', 'nino', 'nina'
  
  // Vestimenta dinámica
  final String ropaDelDia; // Ropa que lleva puesta hoy
  final DateTime fechaActualizacionRopa;

  FamiliarProfile({
    required this.id,
    required this.nombreCompleto,
    required this.parentesco,
    required this.edad,
    this.dni = '',
    this.fotoBase64,
    DateTime? fechaActualizacionFoto,
    this.estatura = '',
    this.contextura = 'Regular',
    this.colorPiel = 'Trigueña',
    this.colorCabello = 'Negro',
    this.senasParticulares = '',
    this.datosMedicos = '',
    this.tipoSangre = 'O+',
    this.condicionEspecial = 'Ninguna',
    this.telefonoContacto = '',
    this.estiloCarnet = 'auto',
    this.ropaDelDia = '',
    DateTime? fechaActualizacionRopa,
  })  : fechaActualizacionFoto = fechaActualizacionFoto ?? DateTime.now(),
        fechaActualizacionRopa = fechaActualizacionRopa ?? DateTime.now();

  bool get esFemenino {
    if (estiloCarnet == 'nina') return true;
    if (estiloCarnet == 'nino') return false;
    final p = parentesco.toLowerCase();
    final n = nombreCompleto.toLowerCase();
    return p.contains('hija') ||
        p.contains('niña') ||
        p.contains('madre') ||
        p.contains('abuela') ||
        p.contains('hermana') ||
        p.contains('prima') ||
        p.contains('tia') ||
        p.contains('tía') ||
        p.contains('sobrina') ||
        n.endsWith('a ') ||
        n.endsWith('a');
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombreCompleto': nombreCompleto,
        'parentesco': parentesco,
        'edad': edad,
        'dni': dni,
        'fotoBase64': fotoBase64,
        'fechaActualizacionFoto': fechaActualizacionFoto.toIso8601String(),
        'estatura': estatura,
        'contextura': contextura,
        'colorPiel': colorPiel,
        'colorCabello': colorCabello,
        'senasParticulares': senasParticulares,
        'datosMedicos': datosMedicos,
        'tipoSangre': tipoSangre,
        'condicionEspecial': condicionEspecial,
        'telefonoContacto': telefonoContacto,
        'estiloCarnet': estiloCarnet,
        'ropaDelDia': ropaDelDia,
        'fechaActualizacionRopa': fechaActualizacionRopa.toIso8601String(),
      };

  factory FamiliarProfile.fromMap(Map<String, dynamic> map) {
    return FamiliarProfile(
      id: map['id'] ?? '',
      nombreCompleto: map['nombreCompleto'] ?? '',
      parentesco: map['parentesco'] ?? 'Familiar',
      edad: (map['edad'] as num?)?.toInt() ?? 0,
      dni: map['dni'] ?? '',
      fotoBase64: map['fotoBase64'],
      fechaActualizacionFoto: map['fechaActualizacionFoto'] != null
          ? DateTime.tryParse(map['fechaActualizacionFoto']) ?? DateTime.now()
          : DateTime.now(),
      estatura: map['estatura'] ?? '',
      contextura: map['contextura'] ?? 'Regular',
      colorPiel: map['colorPiel'] ?? 'Trigueña',
      colorCabello: map['colorCabello'] ?? 'Negro',
      senasParticulares: map['senasParticulares'] ?? map['caracteristicas'] ?? '',
      datosMedicos: map['datosMedicos'] ?? '',
      tipoSangre: map['tipoSangre'] ?? 'O+',
      condicionEspecial: map['condicionEspecial'] ?? 'Ninguna',
      telefonoContacto: map['telefonoContacto'] ?? '',
      estiloCarnet: map['estiloCarnet'] ?? 'auto',
      ropaDelDia: map['ropaDelDia'] ?? '',
      fechaActualizacionRopa: map['fechaActualizacionRopa'] != null
          ? DateTime.tryParse(map['fechaActualizacionRopa']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  FamiliarProfile copyWith({
    String? nombreCompleto,
    String? parentesco,
    int? edad,
    String? dni,
    String? fotoBase64,
    DateTime? fechaActualizacionFoto,
    String? estatura,
    String? contextura,
    String? colorPiel,
    String? colorCabello,
    String? senasParticulares,
    String? datosMedicos,
    String? tipoSangre,
    String? condicionEspecial,
    String? telefonoContacto,
    String? estiloCarnet,
    String? ropaDelDia,
    DateTime? fechaActualizacionRopa,
  }) {
    return FamiliarProfile(
      id: id,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      parentesco: parentesco ?? this.parentesco,
      edad: edad ?? this.edad,
      dni: dni ?? this.dni,
      fotoBase64: fotoBase64 ?? this.fotoBase64,
      fechaActualizacionFoto: fechaActualizacionFoto ?? this.fechaActualizacionFoto,
      estatura: estatura ?? this.estatura,
      contextura: contextura ?? this.contextura,
      colorPiel: colorPiel ?? this.colorPiel,
      colorCabello: colorCabello ?? this.colorCabello,
      senasParticulares: senasParticulares ?? this.senasParticulares,
      datosMedicos: datosMedicos ?? this.datosMedicos,
      tipoSangre: tipoSangre ?? this.tipoSangre,
      condicionEspecial: condicionEspecial ?? this.condicionEspecial,
      telefonoContacto: telefonoContacto ?? this.telefonoContacto,
      estiloCarnet: estiloCarnet ?? this.estiloCarnet,
      ropaDelDia: ropaDelDia ?? this.ropaDelDia,
      fechaActualizacionRopa: fechaActualizacionRopa ?? this.fechaActualizacionRopa,
    );
  }

  /// Retorna un resumen legible de los rasgos físicos
  String get resumenRasgosFisicos {
    final list = <String>[];
    if (estatura.isNotEmpty) list.add('Estatura: $estatura');
    if (contextura.isNotEmpty) list.add('Contextura: $contextura');
    if (colorPiel.isNotEmpty) list.add('Piel: $colorPiel');
    if (colorCabello.isNotEmpty) list.add('Cabello: $colorCabello');
    if (senasParticulares.isNotEmpty) list.add('Señas: $senasParticulares');
    return list.join(' | ');
  }
}

class MiFamiliaService extends ChangeNotifier {
  static const String _storageKey = 'mi_familia_segura_profiles_v3';
  List<FamiliarProfile> _familiares = [];
  bool _isLoaded = false;

  List<FamiliarProfile> get familiares => List.unmodifiable(_familiares);
  bool get isLoaded => _isLoaded;

  MiFamiliaService() {
    loadFamiliares();
  }

  Future<void> loadFamiliares() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var jsonStr = prefs.getString(_storageKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        jsonStr = prefs.getString('mi_familia_segura_profiles_v2') ?? prefs.getString('mi_familia_segura_profiles_v1');
      }

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _familiares = decoded.map((m) => FamiliarProfile.fromMap(m)).toList();
      } else {
        _familiares = [];
      }
    } catch (e) {
      debugPrint('Error cargando familiares: $e');
      _familiares = [];
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> saveFamiliar(FamiliarProfile profile) async {
    final index = _familiares.indexWhere((f) => f.id == profile.id);
    if (index >= 0) {
      _familiares[index] = profile;
    } else {
      _familiares.add(profile);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> updateFoto(String id, String fotoBase64) async {
    final index = _familiares.indexWhere((f) => f.id == id);
    if (index >= 0) {
      _familiares[index] = _familiares[index].copyWith(
        fotoBase64: fotoBase64,
        fechaActualizacionFoto: DateTime.now(),
      );
      await _persist();
      notifyListeners();
    }
  }

  Future<void> updateRopaDelDia(String id, String ropa) async {
    final index = _familiares.indexWhere((f) => f.id == id);
    if (index >= 0) {
      _familiares[index] = _familiares[index].copyWith(
        ropaDelDia: ropa,
        fechaActualizacionRopa: DateTime.now(),
      );
      await _persist();
      notifyListeners();
    }
  }

  Future<void> deleteFamiliar(String id) async {
    _familiares.removeWhere((f) => f.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_familiares.map((f) => f.toMap()).toList());
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('Error guardando familiares: $e');
    }
  }

  /// Genera texto de alerta inmediata para WhatsApp / Redes Sociales
  String generarTextoAlertaInmediata(FamiliarProfile f, {String? ubicacionActual}) {
    final buffer = StringBuffer();
    buffer.writeln('🚨 *¡ALERTA URGENTE DE EXTRAVÍO!* 🚨');
    buffer.writeln('Por favor ayúdanos a encontrar a: *${f.nombreCompleto.toUpperCase()}*');
    buffer.writeln('👤 *Parentesco:* ${f.parentesco}');
    buffer.writeln('🎂 *Edad:* ${f.edad} años');
    if (f.condicionEspecial.isNotEmpty && f.condicionEspecial != 'Ninguna') {
      buffer.writeln('🩺 *Condición Especial:* ${f.condicionEspecial}');
    }
    if (f.ropaDelDia.isNotEmpty) {
      buffer.writeln('👕 *Vestimenta de hoy:* ${f.ropaDelDia}');
    }
    final rasgos = f.resumenRasgosFisicos;
    if (rasgos.isNotEmpty) {
      buffer.writeln('🔍 *Rasgos físicos:* $rasgos');
    }
    if (f.datosMedicos.isNotEmpty) {
      buffer.writeln('⚠️ *Datos Médicos:* ${f.datosMedicos}');
    }
    if (f.telefonoContacto.isNotEmpty) {
      buffer.writeln('📞 *Contacto Familia/Tutor:* ${f.telefonoContacto}');
    }
    if (ubicacionActual != null && ubicacionActual.isNotEmpty) {
      buffer.writeln('📍 *Última zona conocida / Punto de alerta:* $ubicacionActual');
    }
    buffer.writeln('\n📞 *Líneas de Auxilio Inmediato:*');
    buffer.writeln('• Central Policía: *105*');
    buffer.writeln('• Desaparecidos PNP: *114*');
    buffer.writeln('• Plataforma Ciudadana: https://pnpalerta.web.app');
    buffer.writeln('\n_Generado con Alerta Desaparecidos - Kit Familiar Seguro_');
    return buffer.toString();
  }
}
