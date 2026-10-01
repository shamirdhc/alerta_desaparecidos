import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../common/constants/gemini_constants.dart';

/// Datos estructurados extraídos automáticamente de una Nota de Alerta Policial PNP
class ExtractedNotaAlerta {
  final String? nombres;
  final String? apellidos;
  final String? dni;
  final String? sexo;
  final DateTime? fechaNacimiento;
  final int? edad;
  final DateTime? fechaDesaparicion;
  final String? horaDesaparicion;
  final String? departamento;
  final String? provincia;
  final String? distrito;
  final String? direccionDetalle;
  final String? caracteristicas;
  final String? vestimenta;
  final String? circunstancias;
  final String? dependenciaPolicial;
  final String? numeroDenuncia;

  ExtractedNotaAlerta({
    this.nombres,
    this.apellidos,
    this.dni,
    this.sexo,
    this.fechaNacimiento,
    this.edad,
    this.fechaDesaparicion,
    this.horaDesaparicion,
    this.departamento,
    this.provincia,
    this.distrito,
    this.direccionDetalle,
    this.caracteristicas,
    this.vestimenta,
    this.circunstancias,
    this.dependenciaPolicial,
    this.numeroDenuncia,
  });

  /// Construye un bloque completo de detalles adicionales combinando rasgos y circunstancias
  String get resumenDetalles {
    final List<String> partes = [];
    if (caracteristicas != null && caracteristicas!.isNotEmpty) {
      partes.add('CARACTERÍSTICAS FÍSICAS: $caracteristicas');
    }
    if (vestimenta != null && vestimenta!.isNotEmpty) {
      partes.add('VESTIMENTA: $vestimenta');
    }
    if (circunstancias != null && circunstancias!.isNotEmpty) {
      partes.add('CIRCUNSTANCIAS: $circunstancias');
    }
    if (direccionDetalle != null && direccionDetalle!.isNotEmpty) {
      partes.add('DIRECCIÓN/REFERENCIA: $direccionDetalle');
    }
    if (dependenciaPolicial != null && dependenciaPolicial!.isNotEmpty) {
      partes.add('DEPENDENCIA POLICIAL: $dependenciaPolicial');
    }
    if (numeroDenuncia != null && numeroDenuncia!.isNotEmpty) {
      partes.add('N° DENUNCIA: $numeroDenuncia');
    }
    return partes.join('\n\n');
  }

  factory ExtractedNotaAlerta.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is String && d.isNotEmpty) {
        try {
          if (d.contains('/')) {
            final parts = d.split('/');
            if (parts.length == 3) {
              return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
            }
          }
          return DateTime.tryParse(d);
        } catch (_) {}
      }
      return null;
    }

    int? parseEdad(dynamic e) {
      if (e == null) return null;
      if (e is int) return e;
      final s = e.toString();
      final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(digits);
    }

    return ExtractedNotaAlerta(
      nombres: json['nombres'] as String?,
      apellidos: json['apellidos'] as String?,
      dni: json['dni'] as String?,
      sexo: json['sexo'] as String?,
      fechaNacimiento: parseDate(json['fechaNacimiento']),
      edad: parseEdad(json['edad']),
      fechaDesaparicion: parseDate(json['fechaDesaparicion']),
      horaDesaparicion: json['horaDesaparicion'] as String?,
      departamento: json['departamento'] as String?,
      provincia: json['provincia'] as String?,
      distrito: json['distrito'] as String?,
      direccionDetalle: json['direccionDetalle'] as String?,
      caracteristicas: json['caracteristicas'] as String?,
      vestimenta: json['vestimenta'] as String?,
      circunstancias: json['circunstancias'] as String?,
      dependenciaPolicial: json['dependenciaPolicial'] as String?,
      numeroDenuncia: json['numeroDenuncia'] as String?,
    );
  }
}

/// Servicio que interactúa con Google Gemini para digitalizar Notas de Alerta PNP
class GeminiExtractorService {
  static const String prefKey = 'gemini_api_key';

  /// Obtiene la clave de API configurada
  static Future<String?> getSavedApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefKey);
      if (saved != null && saved.trim().isNotEmpty) {
        return saved.trim();
      }
    } catch (_) {}
    if (GeminiConstants.apiKey.isNotEmpty) {
      return GeminiConstants.apiKey;
    }
    return null;
  }

  /// Guarda una nueva clave de API en SharedPreferences
  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, key.trim());
  }

  /// Verifica si ya existe una clave configurada
  static Future<bool> hasApiKey() async {
    final key = await getSavedApiKey();
    return key != null && key.isNotEmpty;
  }

  static Future<ExtractedNotaAlerta?> extractFromImageBytes(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
    String? customApiKey,
  }) async {
    final key = customApiKey?.isNotEmpty == true
        ? customApiKey!
        : (await getSavedApiKey() ?? '');

    if (key.isEmpty) {
      throw Exception(
        'Clave API de Gemini no configurada.',
      );
    }

    const promptText = '''
Eres un asistente policial especializado en documentos de la Policía Nacional del Perú (PNP), específicamente en NOTAS DE ALERTA de personas desaparecidas emitidas por la División de Investigación y Búsqueda de Personas Desaparecidas.

Analiza minuciosamente el documento adjunto y extrae todos los datos de la persona desaparecida en un único objeto JSON válido con las siguientes claves:
{
  "nombres": "Nombres de la persona (en mayúsculas)",
  "apellidos": "Apellidos de la persona (en mayúsculas)",
  "dni": "Número de DNI si figura, o null",
  "sexo": "MASCULINO o FEMENINO",
  "fechaNacimiento": "Fecha de nacimiento en formato DD/MM/YYYY",
  "edad": 23,
  "fechaDesaparicion": "Fecha del hecho o desaparición en formato DD/MM/YYYY",
  "horaDesaparicion": "Hora del hecho en formato HH:MM (ej. 05:09)",
  "departamento": "Nombre del departamento o región del Perú en mayúsculas (ej. LAMBAYEQUE, LIMA, CUSCO)",
  "provincia": "Nombre de la provincia en mayúsculas (ej. CHICLAYO)",
  "distrito": "Nombre del distrito en mayúsculas (ej. CHICLAYO)",
  "direccionDetalle": "Dirección exacta, calle, avenida o referencia del lugar del hecho",
  "caracteristicas": "Resumen de tez, fenotipo, ojos, sangre, boca, nariz, cabello, estatura y contextura",
  "vestimenta": "Ropa que vestía o SE DESCONOCE",
  "circunstancias": "Texto de las circunstancias de la desaparición",
  "dependenciaPolicial": "Nombre de la comisaría o dependencia policial",
  "numeroDenuncia": "Número de la denuncia policial"
}

Reglas estrictas:
- Devuelve únicamente el objeto JSON sin markdown adicional.
- En "LUGAR DEL HECHO", separa con exactitud el Departamento, Provincia y Distrito peruano.
''';

    // Intentar con el modelo principal y los de respaldo si hay 503
    Exception? lastException;
    for (final modelName in GeminiConstants.fallbackModels) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: key,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
        );

        final content = [
          Content.multi([
            TextPart(promptText),
            DataPart(mimeType, imageBytes),
          ]),
        ];

        final response = await model.generateContent(content).timeout(
          const Duration(seconds: 15),
        );
        final responseText = response.text;
        if (responseText != null && responseText.trim().isNotEmpty) {
          String raw = responseText.trim();
          if (raw.startsWith('`json')) {
            raw = raw.substring(7);
          } else if (raw.startsWith('`')) {
            raw = raw.substring(3);
          }
          if (raw.endsWith('`')) {
            raw = raw.substring(0, raw.length - 3);
          }
          raw = raw.trim();
          final dynamic parsedJson = jsonDecode(raw);
          if (parsedJson is Map<String, dynamic>) {
            return ExtractedNotaAlerta.fromJson(parsedJson);
          }
        }
      } catch (e) {
        debugPrint('GeminiExtractorService [$modelName] error: $e');
        lastException = Exception(e.toString());
      }
    }

    if (lastException != null) {
      throw lastException;
    }
    return null;
  }
}

