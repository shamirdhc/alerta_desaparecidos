// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

Future<void> platformDownloadFile(Uint8List bytes, String filename) async {
  try {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  } catch (e) {
    debugPrint('Error en platformDownloadFile (Web): $e');
    rethrow;
  }
}

Future<bool> platformShareFile(
  Uint8List bytes,
  String filename, {
  String? subject,
  String? text,
}) async {
  // 1. Intentar Web Share API nativa vía share_plus si el navegador móvil la soporta
  try {
    final xFile = XFile.fromData(
      bytes,
      mimeType: 'application/pdf',
      name: filename,
    );
    final result = await Share.shareXFiles(
      [xFile],
      subject: subject,
      text: text,
    );
    if (result.status == ShareResultStatus.success) {
      return true;
    }
  } catch (e) {
    debugPrint('Share.shareXFiles no disponible o cancelado en Web: $e');
  }

  // 2. Fallback garantizado en Web: Descargar el archivo directamente al dispositivo
  await platformDownloadFile(bytes, filename);
  return false;
}
