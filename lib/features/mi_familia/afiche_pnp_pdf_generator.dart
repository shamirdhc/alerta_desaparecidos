import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generador del Afiche Oficial de Búsqueda A4 de EXACTAMENTE UNA (01) PÁGINA.
/// Cumple la regla estricta: Usa tipografía estándar Helvetica/Arial (evita caracteres corruptos en Android/WPS).
/// Incluye código QR dinámico directo al caso en pnpalerta.web.app y teléfonos de emergencia oficiales PNP.
class AficheBusquedaPdfGenerator {
  static Future<Uint8List> generarAficheUnicaPaginaA4({
    required String nombreCompleto,
    required String edadTexto,
    required String fechaLugarDesaparicion,
    required String vestimenta,
    required String rasgosFisicosYSenas,
    required String condicionEspecial,
    required String unidadPolicialCargo,
    required String telefonoContactoUnidad,
    required String casoId,
    Uint8List? fotoBytes,
  }) async {
    final pdf = pw.Document(
      title: 'Alerta Desaparecidos PNP - $nombreCompleto',
      author: 'Alerta Desaparecidos PNP (pnpalerta.web.app)',
    );

    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final urlCaso = 'https://pnpalerta.web.app/?caso=$casoId';

    String truncar(String txt, int max) =>
        txt.length <= max ? txt : '${txt.substring(0, max - 3)}...';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.red800, width: 3),
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // 1. ENCABEZADO DE EMERGENCIA (Centrado, contraste alto)
                pw.Container(
                  color: PdfColors.red800,
                  padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        '¡AYÚDANOS A ENCONTRARLO(A)! — ALERTA DE BÚSQUEDA',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 18,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'RED NACIONAL Y COMUNITARIA DE BÚSQUEDA TEMPRANA • CHINKASQAKUNA ALERTA',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: PdfColors.amber100,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. FOTOGRAFÍA CENTRAL Y DATOS FILIATORIOS
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 12),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Container(
                          width: 210,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey800, width: 1.5),
                            color: PdfColors.grey200,
                          ),
                          child: fotoBytes != null
                              ? pw.Image(pw.MemoryImage(fotoBytes), fit: pw.BoxFit.cover)
                              : pw.Center(
                                  child: pw.Text(
                                    'FOTOGRAFÍA RECIENTE',
                                    style: pw.TextStyle(font: fontBold, fontSize: 11),
                                  ),
                                ),
                        ),
                        pw.SizedBox(width: 16),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                            children: [
                              pw.Text(
                                truncar(nombreCompleto.toUpperCase(), 65),
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 17,
                                  color: PdfColors.blue900,
                                ),
                              ),
                              _campoFicha(fontBold, fontRegular, 'EDAD:', edadTexto),
                              _campoFicha(
                                fontBold,
                                fontRegular,
                                'FECHA Y LUGAR:',
                                truncar(fechaLugarDesaparicion, 110),
                              ),
                              _campoFicha(
                                fontBold,
                                fontRegular,
                                'VESTIMENTA AL SALIR:',
                                truncar(vestimenta, 140),
                              ),
                              _campoFicha(
                                fontBold,
                                fontRegular,
                                'RASGOS Y SEÑAS:',
                                truncar(rasgosFisicosYSenas, 140),
                              ),
                              _campoFicha(
                                fontBold,
                                fontRegular,
                                'CONDICIÓN ESPECIAL:',
                                truncar(condicionEspecial, 100),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. PIE DE PÁGINA CON TELÉFONOS DE EMERGENCIA Y CÓDIGO QR DIRECTO
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue900, width: 1.5),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'SI TIENES INFORMACIÓN O LO(A) HAS VISTO, COMUNÍCATE DE INMEDIATO:',
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 10,
                                color: PdfColors.red800,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'LÍNEA GRATUITA PNP: 114 (24 HORAS)  |  CENTRAL: 105',
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 14,
                                color: PdfColors.blue900,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Unidad Policial a cargo: ${truncar(unidadPolicialCargo, 65)} • Tel: $telefonoContactoUnidad',
                              style: pw.TextStyle(font: fontRegular, fontSize: 9.5),
                            ),
                            pw.Text(
                              'Aporta una pista confidencial escaneando el QR o en: https://pnpalerta.web.app',
                              style: pw.TextStyle(font: fontBold, fontSize: 9.5),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Container(
                        width: 72,
                        height: 72,
                        padding: const pw.EdgeInsets.all(4),
                        color: PdfColors.white,
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: urlCaso,
                        ),
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

  static pw.Widget _campoFicha(
    pw.Font fontBold,
    pw.Font fontRegular,
    String titulo,
    String valor,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$titulo ',
              style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColors.black),
            ),
            pw.TextSpan(
              text: valor.isEmpty ? 'No especificado' : valor,
              style: pw.TextStyle(font: fontRegular, fontSize: 10.5, color: PdfColors.grey900),
            ),
          ],
        ),
      ),
    );
  }
}
