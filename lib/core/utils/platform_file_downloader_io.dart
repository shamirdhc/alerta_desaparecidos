import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> platformDownloadFile(Uint8List bytes, String filename) async {
  try {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    }
    dir ??= await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);

    // En móviles nativos, abrir diálogo de compartir para guardar o enviar
    final xFile = XFile(file.path, mimeType: 'application/pdf', name: filename);
    await Share.shareXFiles([xFile]);
  } catch (e) {
    debugPrint('Error guardando archivo IO: $e');
    final xFile = XFile.fromData(bytes, mimeType: 'application/pdf', name: filename);
    await Share.shareXFiles([xFile]);
  }
}

Future<bool> platformShareFile(
  Uint8List bytes,
  String filename, {
  String? subject,
  String? text,
}) async {
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
    return result.status == ShareResultStatus.success;
  } catch (e) {
    debugPrint('Error en platformShareFile (IO): $e');
    return false;
  }
}
