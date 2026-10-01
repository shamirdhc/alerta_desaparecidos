import 'dart:typed_data';

Future<void> platformDownloadFile(Uint8List bytes, String filename) async {
  throw UnsupportedError('Plataforma no soportada para descarga de archivos');
}

Future<bool> platformShareFile(
  Uint8List bytes,
  String filename, {
  String? subject,
  String? text,
}) async {
  throw UnsupportedError('Plataforma no soportada para compartir archivos');
}
