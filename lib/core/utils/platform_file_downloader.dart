import 'dart:typed_data';
import 'platform_file_downloader_stub.dart'
    if (dart.library.html) 'platform_file_downloader_web.dart'
    if (dart.library.io) 'platform_file_downloader_io.dart';

/// Utilidad multiplataforma definitiva para descargar y compartir archivos PDF
/// tanto en Web PWA como en Android e iOS, sin depender de MethodChannels ausentes.
class PlatformFileDownloader {
  /// Descarga el archivo PDF directamente al dispositivo / navegador
  static Future<void> downloadPdf({
    required Uint8List bytes,
    required String filename,
  }) async {
    await platformDownloadFile(bytes, filename);
  }

  /// Comparte el archivo PDF usando la hoja nativa o descarga directa con aviso
  static Future<bool> sharePdf({
    required Uint8List bytes,
    required String filename,
    String? subject,
    String? text,
  }) async {
    return await platformShareFile(
      bytes,
      filename,
      subject: subject,
      text: text,
    );
  }
}
