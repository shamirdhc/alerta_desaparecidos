import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Sanitizador DevSecOps para campos de entrada y prevención de XSS e inyecciones.
class SecuritySanitizer {
  static final RegExp _xssPattern = RegExp(
    r'(<script|javascript:|onerror=|onload=|<iframe|<object|<embed)',
    caseSensitive: false,
  );
  static final RegExp _controlChars = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
  static final RegExp _dniRegex = RegExp(r'^\d{8}$');
  static final RegExp _cipRegex = RegExp(r'^\d{8,9}$');

  /// Limpia texto libre de etiquetas HTML/XSS y recorta a longitud máxima segura.
  static String sanitizeText(String? raw, {int maxLength = 500}) {
    if (raw == null) return '';
    String cleaned = raw
        .replaceAll(_controlChars, '')
        .replaceAll('<', '‹')
        .replaceAll('>', '›')
        .trim();
    if (_xssPattern.hasMatch(cleaned)) {
      cleaned = cleaned.replaceAll(_xssPattern, '[FILTRADO]');
    }
    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength);
    }
    return cleaned;
  }

  static bool isValidDni(String dni) => _dniRegex.hasMatch(dni.trim());
  static bool isValidCip(String cip) => _cipRegex.hasMatch(cip.trim());

  /// Verifica que las coordenadas GPS estén dentro del territorio nacional del Perú
  static bool isValidPeruGps(double? lat, double? lng) {
    if (lat == null || lng == null || lat.isNaN || lng.isNaN) return false;
    return lat >= -18.5 && lat <= 0.1 && lng >= -81.5 && lng <= -68.5;
  }
}

/// Subidor resiliente de fotografías con compresión WebP y reintentos exponenciales para redes 3G rurales.
class ResilientImageUploader {
  /// Comprime la fotografía a formato WebP (máx 1080px, calidad 78%) antes de subir
  static Future<Uint8List> compressToWebP(Uint8List rawBytes) async {
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        rawBytes,
        minWidth: 1080,
        minHeight: 1080,
        quality: 78,
        format: CompressFormat.webp,
      );
      return compressed;
    } catch (_) {
      // Si el navegador o entorno no soporta WebP directo, retorna el buffer original
      return rawBytes;
    }
  }

  /// Sube imagen a Firebase Storage con reintentos exponenciales (ideal para señal 3G rural)
  static Future<String> uploadWithRetry({
    required Reference storageRef,
    required Uint8List imageBytes,
    int maxRetries = 3,
  }) async {
    final webpBytes = await compressToWebP(imageBytes);
    if (webpBytes.lengthInBytes > 5 * 1024 * 1024) {
      throw Exception('La imagen supera el límite máximo permitido de 5 MB.');
    }

    int attempt = 0;
    while (true) {
      try {
        attempt++;
        final metadata = SettableMetadata(
          contentType: 'image/webp',
          cacheControl: 'public, max-age=31536000, immutable',
        );
        final uploadTask = storageRef.putData(webpBytes, metadata);
        final snapshot = await uploadTask.timeout(const Duration(seconds: 25));
        return await snapshot.ref.getDownloadURL();
      } catch (e) {
        if (attempt >= maxRetries) rethrow;
        await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
      }
    }
  }
}
