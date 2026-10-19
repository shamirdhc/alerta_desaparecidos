import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/entities/desaparecido.dart';
import 'comisaria_matcher_service.dart';

/// Servicio generador de Afiche Oficial A4 de Búsqueda para Personas Desaparecidas
class DesaparecidoPdfService {
  /// Genera los bytes del Afiche Oficial de Búsqueda en formato A4
  static Future<Uint8List> construirAficheBytes(
    Desaparecido desaparecido, {
    ComisariaMatchResult? comisariaInfo,
  }) async {
    final pdf = pw.Document();

    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    final logoAppBytes = await _obtenerLogoAppBytes();
    final fotoBytes = await _obtenerFotoBytes(desaparecido.fotoUrl);

    final comisaria = comisariaInfo ??
        await ComisariaMatcherService.resolverComisaria(
          unidadACargo: desaparecido.unidadACargo,
          departamento: desaparecido.departamento,
          provincia: desaparecido.provincia,
          distrito: desaparecido.distrito,
          detallesAdicionales: desaparecido.detallesAdicionales,
        );

    final nombreCompleto = _sanitizarTextoPdf('${desaparecido.nombres} ${desaparecido.apellidos}'.trim().toUpperCase());
    final edad = _sanitizarTextoPdf(desaparecido.edadCalculada != null
        ? '${desaparecido.edadCalculada} AÑOS'
        : (desaparecido.detallesAdicionales != null && desaparecido.detallesAdicionales!.contains('Edad:')
            ? desaparecido.detallesAdicionales!
            : 'NO ESPECIFICADA'));

    final fechaDesap = desaparecido.fechaDesaparicion != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(desaparecido.fechaDesaparicion!)
        : 'Fecha no precisada';

    final ubicacion = _sanitizarTextoPdf([
      if (desaparecido.distrito != null && desaparecido.distrito!.isNotEmpty) desaparecido.distrito,
      if (desaparecido.provincia != null && desaparecido.provincia!.isNotEmpty) desaparecido.provincia,
      if (desaparecido.departamento != null && desaparecido.departamento!.isNotEmpty) desaparecido.departamento,
    ].join(' - ').toUpperCase());

    final qrUrl = 'https://pnpalerta.web.app/?id=${desaparecido.id ?? ""}';
    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.red800, width: 3.5),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. Cabecera Institucional y Urgente
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.red800,
                    borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoAppBytes != null)
                        pw.Container(
                          width: 44,
                          height: 44,
                          padding: const pw.EdgeInsets.all(2),
                          decoration: pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            color: PdfColors.white,
                            border: pw.Border.all(color: PdfColors.amber400, width: 2),
                          ),
                          child: pw.ClipOval(
                            child: pw.Image(pw.MemoryImage(logoAppBytes), fit: pw.BoxFit.contain),
                          ),
                        )
                      else
                        pw.SizedBox(width: 44),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: pw.Column(
                          children: [
                            pw.Text(
                              '¡AYÚDANOS A ENCONTRARLE!',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(font: fontBold, fontSize: 21, color: PdfColors.white),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.amber400,
                                borderRadius: pw.BorderRadius.circular(3),
                              ),
                              child: pw.Text(
                                'ALERTA DE BUSQUEDA Y LOCALIZACION - DIFUSION CIUDADANA',
                                style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.blueGrey900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      // URL limpia
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blueGrey900,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: PdfColors.amber400, width: 1),
                        ),
                        child: pw.Text(
                          'pnpalerta.web.app',
                          style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.amber300),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Nombre Grande y Destacado
                pw.Container(
                  color: PdfColors.blueGrey900,
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: pw.Text(
                    nombreCompleto,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.amber300),
                    maxLines: 2,
                  ),
                ),

                // 3. Cuerpo Central: Foto y Datos Clave
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(12),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Fotografía con Marco de Alerta
                        pw.Container(
                          width: 190,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey200,
                            borderRadius: pw.BorderRadius.circular(8),
                            border: pw.Border.all(color: PdfColors.red800, width: 2.5),
                          ),
                          child: fotoBytes != null
                              ? pw.ClipRRect(
                                  horizontalRadius: 6,
                                  verticalRadius: 6,
                                  child: pw.Image(
                                    pw.MemoryImage(fotoBytes),
                                    fit: pw.BoxFit.cover,
                                  ),
                                )
                              : pw.Center(
                                  child: pw.Padding(
                                    padding: const pw.EdgeInsets.all(20),
                                    child: pw.Column(
                                      mainAxisAlignment: pw.MainAxisAlignment.center,
                                      children: [
                                        pw.Text('FOTO OFICIAL', style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.grey700)),
                                        pw.SizedBox(height: 6),
                                        pw.Text('EN NOTA DE ALERTA', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey600)),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                        pw.SizedBox(width: 14),

                        // Datos de Identificación y Hechos
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildItemRow('EDAD:', edad, fontBold, fontRegular, color: PdfColors.red800),
                              if (desaparecido.sexo != null && desaparecido.sexo!.isNotEmpty)
                                _buildItemRow('SEXO:', desaparecido.sexo!.toUpperCase(), fontBold, fontRegular),
                              if (desaparecido.dni != null && desaparecido.dni!.isNotEmpty)
                                _buildItemRow('DNI:', desaparecido.dni!, fontBold, fontRegular),
                              _buildItemRow('FECHA:', fechaDesap, fontBold, fontRegular, color: PdfColors.blue800),
                              if (ubicacion.isNotEmpty)
                                _buildItemRow('LUGAR:', ubicacion, fontBold, fontRegular),

                              pw.SizedBox(height: 6),
                              pw.Divider(color: PdfColors.grey300, thickness: 1),
                              pw.SizedBox(height: 4),

                              // Rasgos y vestimenta
                              pw.Text('CIRCUNSTANCIAS Y SEÑALES PARTICULARES:', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.red900)),
                              pw.SizedBox(height: 3),
                              pw.Container(
                                width: double.infinity,
                                padding: const pw.EdgeInsets.all(6),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.grey100,
                                  borderRadius: pw.BorderRadius.circular(4),
                                  border: pw.Border.all(color: PdfColors.grey300),
                                ),
                                child: pw.Text(
                                  _sanitizarTextoPdf(
                                    desaparecido.detallesAdicionales != null && desaparecido.detallesAdicionales!.trim().isNotEmpty
                                        ? desaparecido.detallesAdicionales!
                                        : 'Ver Nota de Alerta Oficial adjunta en el portal o consultar con la dependencia policial.',
                                  ),
                                  style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColors.grey800),
                                  maxLines: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. Bloque de Contacto Directo con la Comisaría a Cargo
                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blueGrey50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.blueGrey300, width: 1.5),
                  ),
                  child: pw.Row(
                    children: [
                      // QR interactivo para escanear en la vía pública
                      pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: PdfColors.grey400),
                        ),
                        child: pw.BarcodeWidget(
                          data: qrUrl,
                          barcode: pw.Barcode.qrCode(),
                          width: 68,
                          height: 68,
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      // Datos de la Comisaría y Centrales
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'DEPENDENCIA POLICIAL A CARGO DE LA BÚSQUEDA:',
                              style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.grey700),
                            ),
                            pw.Text(
                              _sanitizarTextoPdf(comisaria?.nombreOficial ?? (desaparecido.unidadACargo ?? 'COMISARÍA PNP DEL SECTOR')),
                              style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColors.blue900),
                            ),
                            if (comisaria != null && comisaria.direccion.isNotEmpty) ...[
                              pw.SizedBox(height: 1),
                              pw.Text(
                                _sanitizarTextoPdf('Dirección: ${comisaria.direccion}'),
                                style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: PdfColors.grey800),
                              ),
                            ],
                            pw.SizedBox(height: 3),
                            pw.Row(
                              children: [
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: pw.BoxDecoration(
                                    color: comisaria != null && comisaria.tieneTelefonoDirecto ? PdfColors.green700 : PdfColors.amber700,
                                    borderRadius: pw.BorderRadius.circular(3),
                                  ),
                                  child: pw.Text(
                                    comisaria != null && comisaria.tieneTelefonoDirecto
                                        ? 'TEL. COMISARIA: ${_sanitizarTextoPdf(comisaria.telefono)}'
                                        : 'TEL. COMISARIA: CENTRAL 105',
                                    style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.white),
                                  ),
                                ),
                                pw.SizedBox(width: 8),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.red800,
                                    borderRadius: pw.BorderRadius.circular(3),
                                  ),
                                  child: pw.Text(
                                    'LINEA GRATUITA: 114 PNP',
                                    style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 5. Pie de Página Institucional y Legal
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.red800,
                    borderRadius: pw.BorderRadius.vertical(bottom: pw.Radius.circular(4)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Si tienes información sobre su paradero, llama de inmediato. Tu llamada es confidencial y gratuita.',
                        style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.white),
                      ),
                      pw.Text(
                        'Emision: $nowStr | pnpalerta.web.app',
                        style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.amber300),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildItemRow(
    String label,
    String value,
    pw.Font fontBold,
    pw.Font fontRegular, {
    PdfColor color = PdfColors.black,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 75,
            child: pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.grey800)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: color)),
          ),
        ],
      ),
    );
  }

  static String _sanitizarTextoPdf(String? texto) {
    if (texto == null) return '';
    return texto
        .replaceAll('•', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2600}-\u{26FF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2700}-\u{27BF}]', unicode: true), '')
        .trim();
  }

  static Future<Uint8List?> _obtenerLogoAppBytes() async {
    try {
      final byteData = await rootBundle.load('assets/icons/icon_police.png');
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('⚠️ Error cargando logo institucional: $e');
      return null;
    }
  }

  static Future<Uint8List?> _obtenerFotoBytes(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('⚠️ Error descargando foto del desaparecido: $e');
    }
    return null;
  }
}
