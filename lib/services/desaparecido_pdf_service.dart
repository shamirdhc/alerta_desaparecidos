import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';

import '../core/utils/platform_file_downloader.dart';
import '../domain/entities/desaparecido.dart';
import '../presentation/common/widgets/branded_loading_dialog.dart';
import '../presentation/common/widgets/pdf_viewer_modal.dart';
import 'comisaria_matcher_service.dart';

/// Servicio generador de la NOTA DE ALERTA OFICIAL PNP (Formato A4 1:1)
/// Fiel al diseño oficial de la División de Investigación y Búsqueda de Personas Desaparecidas
class DesaparecidoPdfService {
  /// Genera los bytes del PDF de la Nota de Alerta Oficial PNP en formato A4
  static Future<Uint8List> construirAficheBytes(
    Desaparecido desaparecido, {
    ComisariaMatchResult? comisariaInfo,
  }) async {
    final pdf = pw.Document(
      title: 'Nota de Alerta PNP - ${desaparecido.nombres} ${desaparecido.apellidos}',
      author: 'Policía Nacional del Perú',
      subject: 'Alerta de Búsqueda y Localización',
    );

    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    final logoPnpBytes = await _obtenerLogoPnpBytes();
    final fotoBytes = await _obtenerFotoBytes(desaparecido.fotoUrl);

    final comisaria = comisariaInfo ??
        await ComisariaMatcherService.resolverComisaria(
          unidadACargo: desaparecido.unidadACargo,
          departamento: desaparecido.departamento,
          provincia: desaparecido.provincia,
          distrito: desaparecido.distrito,
          detallesAdicionales: desaparecido.detallesAdicionales,
        );

    final edadStr = _sanitizarTextoPdf(
      desaparecido.edadCalculada != null
          ? '${desaparecido.edadCalculada} AÑOS'
          : (desaparecido.detallesAdicionales != null &&
                  desaparecido.detallesAdicionales!.contains('Edad:')
              ? desaparecido.detallesAdicionales!
              : 'NO ESPECIFICADA'),
    );

    final fechaDesap = desaparecido.fechaDesaparicion != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(desaparecido.fechaDesaparicion!)
        : 'Fecha no precisada';

    final fechaNac = desaparecido.fechaNacimiento != null
        ? DateFormat('dd/MM/yyyy').format(desaparecido.fechaNacimiento!)
        : 'NO REGISTRA';

    final ubicacion = _sanitizarTextoPdf([
      if (desaparecido.distrito != null && desaparecido.distrito!.isNotEmpty)
        desaparecido.distrito,
      if (desaparecido.provincia != null && desaparecido.provincia!.isNotEmpty)
        desaparecido.provincia,
      if (desaparecido.departamento != null && desaparecido.departamento!.isNotEmpty)
        desaparecido.departamento,
    ].join(' - ').toUpperCase());

    final qrUrl = 'https://pnpalerta.web.app/?id=${desaparecido.id ?? ""}';
    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final bool isEncontrado = (desaparecido.estado ?? '').trim().toLowerCase() == 'encontrado';

    // Extracción de rasgos desde detalles_adicionales
    final rasgos = _extraerRasgos(desaparecido.detallesAdicionales);

    // Paleta oficial de la Nota de Alerta PNP
    final colorRojoTitulo = PdfColor.fromHex('#C00000');
    final colorAzulSeccion = PdfColor.fromHex('#174E75');
    final colorFondoBarra = PdfColor.fromHex('#D9D9D9');
    final colorBordeGris = PdfColor.fromHex('#949393');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: colorBordeGris, width: 1.5),
            ),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ==============================================================
                // 1. CABECERA INSTITUCIONAL: ESCUDO PNP + TÍTULOS DIVINBUS
                // ==============================================================
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: colorBordeGris, width: 1.2),
                  ),
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Escudo Oficial PNP
                      pw.Container(
                        width: 75,
                        height: 95,
                        child: logoPnpBytes != null
                            ? pw.Image(pw.MemoryImage(logoPnpBytes), fit: pw.BoxFit.contain)
                            : pw.Center(
                                child: pw.Text('PNP', style: pw.TextStyle(font: fontBold, fontSize: 18)),
                              ),
                      ),
                      pw.SizedBox(width: 14),
                      // Títulos oficiales
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              'NOTA DE ALERTA',
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 26,
                                color: colorRojoTitulo,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'POLICÍA NACIONAL DEL PERÚ',
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 13.5,
                                color: PdfColors.black,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              'DIRECCIÓN CONTRA LA TRATA DE PERSONAS Y TRÁFICO ILÍCITO DE MIGRANTES',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 8.5,
                                color: PdfColors.grey800,
                              ),
                            ),
                            pw.Text(
                              'DIVISIÓN DE INVESTIGACIÓN Y BÚSQUEDA DE PERSONAS DESAPARECIDAS',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 8.5,
                                color: PdfColors.grey800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),

                // ==============================================================
                // BANNER CONDICIONAL SI LA PERSONA YA FUE UBICADA CON VIDA
                // ==============================================================
                if (isEncontrado) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#047857'),
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'LOCALIZADA CON VIDA - CASO RESUELTO PNP',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10.5,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                ],

                // ==============================================================
                // 2. SECCIÓN: DATOS DE LA DEPENDENCIA Y DENUNCIA POLICIAL
                // ==============================================================
                _buildSectionHeader('DATOS DE LA DEPENDENCIA Y DENUNCIA POLICIAL', colorFondoBarra, colorAzulSeccion, fontBold),
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: colorBordeGris, width: 1.0),
                  ),
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Dependencia Policial : ', style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.black)),
                          pw.Expanded(
                            child: pw.Text(
                              _sanitizarTextoPdf(comisaria?.nombreOficial ?? (desaparecido.unidadACargo ?? 'COMISARÍA PNP DE LA JURISDICCIÓN')),
                              style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: colorAzulSeccion),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('N° de la Denuncia : ', style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.black)),
                          pw.Text(
                            _sanitizarTextoPdf(desaparecido.dni ?? 'REGISTRO OFICIAL'),
                            style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: colorAzulSeccion),
                          ),
                          pw.Spacer(),
                          pw.Text('Fecha de Registro : ', style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.black)),
                          pw.Text(fechaDesap, style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: colorAzulSeccion)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),

                // ==============================================================
                // 3. SECCIÓN: DATOS DE LA PERSONA DESAPARECIDA
                // ==============================================================
                _buildSectionHeader('DATOS DE LA PERSONA DESAPARECIDA', colorFondoBarra, colorAzulSeccion, fontBold),
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: colorBordeGris, width: 1.0),
                  ),
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Marco de Foto Oficial (Estilo Web PNP)
                      pw.Container(
                        width: 145,
                        height: 185,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: colorBordeGris, width: 1.2),
                          color: PdfColors.grey100,
                        ),
                        child: fotoBytes != null
                            ? pw.Image(pw.MemoryImage(fotoBytes), fit: pw.BoxFit.cover)
                            : pw.Center(
                                child: pw.Column(
                                  mainAxisAlignment: pw.MainAxisAlignment.center,
                                  children: [
                                    pw.Text('FOTOGRAFÍA', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.grey700)),
                                    pw.SizedBox(height: 4),
                                    pw.Text('OFICIAL PNP', style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColors.grey600)),
                                  ],
                                ),
                              ),
                      ),
                      pw.SizedBox(width: 12),
                      // Datos de Identidad
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildDataRow('APELLIDOS :', desaparecido.apellidos.toUpperCase(), colorAzulSeccion, fontBold, fontRegular),
                            _buildDataRow('NOMBRES :', desaparecido.nombres.toUpperCase(), colorAzulSeccion, fontBold, fontRegular),
                            pw.Row(
                              children: [
                                pw.Expanded(
                                  child: _buildDataRow('EDAD :', edadStr, colorAzulSeccion, fontBold, fontRegular),
                                ),
                                pw.Expanded(
                                  child: _buildDataRow('F./ NACIMIENTO :', fechaNac, colorAzulSeccion, fontBold, fontRegular),
                                ),
                              ],
                            ),
                            _buildDataRow('PAÍS DE NACIMIENTO :', 'PERÚ', colorAzulSeccion, fontBold, fontRegular),
                            _buildDataRow('FECHA DEL HECHO :', fechaDesap, colorAzulSeccion, fontBold, fontRegular),
                            _buildDataRow(
                              'LUGAR DEL HECHO :',
                              ubicacion.isNotEmpty ? ubicacion : 'JURISDICCIÓN NACIONAL',
                              colorAzulSeccion,
                              fontBold,
                              fontRegular,
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),

                // ==============================================================
                // 4. SECCIÓN: CARACTERÍSTICAS FÍSICAS Y CIRCUNSTANCIAS
                // ==============================================================
                _buildSectionHeader('CARACTERÍSTICAS FÍSICAS Y SEÑAS PARTICULARES', colorFondoBarra, colorAzulSeccion, fontBold),
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: colorBordeGris, width: 1.0),
                  ),
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Expanded(child: _buildTrait('ESTATURA :', rasgos['estatura'] ?? 'NO INDICA', fontBold, fontRegular)),
                          pw.Expanded(child: _buildTrait('CONTEXTURA :', rasgos['contextura'] ?? 'NO INDICA', fontBold, fontRegular)),
                          pw.Expanded(child: _buildTrait('TEZ :', rasgos['tez'] ?? 'NO INDICA', fontBold, fontRegular)),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        children: [
                          pw.Expanded(child: _buildTrait('OJOS :', rasgos['ojos'] ?? 'NO INDICA', fontBold, fontRegular)),
                          pw.Expanded(child: _buildTrait('CABELLO :', rasgos['cabello'] ?? 'NO INDICA', fontBold, fontRegular)),
                          pw.Expanded(child: _buildTrait('SEXO :', (desaparecido.sexo ?? 'NO INDICA').toUpperCase(), fontBold, fontRegular)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Divider(color: PdfColors.grey300, thickness: 0.8),
                      pw.SizedBox(height: 2),
                      _buildTrait(
                        'VESTIMENTA :',
                        _sanitizarTextoPdf(rasgos['vestimenta'] ?? 'No especificada en la denuncia preliminar.'),
                        fontBold,
                        fontRegular,
                        maxLines: 2,
                      ),
                      pw.SizedBox(height: 2),
                      _buildTrait(
                        'CIRCUNSTANCIAS :',
                        _sanitizarTextoPdf(
                          desaparecido.detallesAdicionales != null && desaparecido.detallesAdicionales!.trim().isNotEmpty
                              ? desaparecido.detallesAdicionales!
                              : 'Denuncia por desaparición en investigación por la unidad policial interviniente.',
                        ),
                        fontBold,
                        fontRegular,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                pw.Spacer(),

                // ==============================================================
                // 5. PIE INSTITUCIONAL: LÍNEA 114, CENTRAL 105 Y QR DE PISTAS
                // ==============================================================
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: colorBordeGris, width: 1.0),
                    color: PdfColors.grey50,
                  ),
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // QR interactivo para escanear y entrar directo al Conversatorio de Pistas
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          border: pw.Border.all(color: PdfColors.grey400),
                        ),
                        child: pw.BarcodeWidget(
                          data: qrUrl,
                          barcode: pw.Barcode.qrCode(),
                          width: 58,
                          height: 58,
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      // Texto de atención y emergencia
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'LÍNEA ÚNICA DE ATENCIÓN DE CASOS DE DESAPARICIÓN DE PERSONAS: LÍNEA 114 (24 HORAS)',
                              style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: colorRojoTitulo),
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              'Central de Emergencia PNP: 105  |  División de Búsqueda de Personas: Av. España N° 323, Cercado de Lima 1er piso',
                              style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: PdfColors.grey800),
                            ),
                            if (comisaria != null && comisaria.tieneTelefonoDirecto) ...[
                              pw.SizedBox(height: 1),
                              pw.Text(
                                'Comisaría a cargo: ${comisaria.nombreOficial}  |  Teléfono Directo: ${comisaria.telefono}',
                                style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: colorAzulSeccion),
                              ),
                            ],
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Escanea el código QR para aportar pistas anónimas y geolocalizadas en: https://pnpalerta.web.app',
                              style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey700),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      // Verificación oficial
                      pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: colorAzulSeccion, width: 0.8),
                          borderRadius: pw.BorderRadius.circular(2),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text('DOCUMENTO OFICIAL', style: pw.TextStyle(font: fontBold, fontSize: 6.5, color: colorAzulSeccion)),
                            pw.Text(nowStr, style: pw.TextStyle(font: fontRegular, fontSize: 6, color: PdfColors.grey800)),
                          ],
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

  // ============================================================================
  // ACCIONES INTERACTIVAS EN LA APLICACIÓN
  // ============================================================================

  /// Abre el visor in-app del PDF oficial de la Nota de Alerta PNP
  static Future<void> abrirNotaAlertaPdf(
    BuildContext context,
    Desaparecido desaparecido, {
    ComisariaMatchResult? comisariaInfo,
  }) async {
    BrandedLoadingOverlay.show(
      context,
      message: 'Generando Nota de Alerta Oficial...',
      submessage: 'Formato institucional de la Policía Nacional del Perú',
    );
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      final nombreLimpio = '${desaparecido.nombres}_${desaparecido.apellidos}'.replaceAll(' ', '_');
      await PdfViewerModal.mostrar(
        context,
        title: 'Nota de Alerta: ${desaparecido.nombres} ${desaparecido.apellidos}',
        docGenerator: () => construirAficheBytes(desaparecido, comisariaInfo: comisariaInfo),
        filename: 'Nota_de_Alerta_PNP_$nombreLimpio.pdf',
        icon: Icons.shield_rounded,
      );
    } finally {
      BrandedLoadingOverlay.hide();
    }
  }

  /// Descarga o comparte directamente el PDF de la Nota de Alerta Oficial
  static Future<void> compartirNotaAlertaPdf(
    BuildContext context,
    Desaparecido desaparecido, {
    ComisariaMatchResult? comisariaInfo,
  }) async {
    try {
      BrandedLoadingOverlay.show(
        context,
        message: 'Preparando Nota de Alerta Oficial...',
        submessage: 'Generando PDF en alta definición A4',
      );

      final bytes = await construirAficheBytes(desaparecido, comisariaInfo: comisariaInfo);
      BrandedLoadingOverlay.hide();

      final nombreCompleto = '${desaparecido.nombres} ${desaparecido.apellidos}'.trim();
      final filename = 'Nota_de_Alerta_PNP_${nombreCompleto.replaceAll(' ', '_')}.pdf';

      final shared = await PlatformFileDownloader.sharePdf(
        bytes: bytes,
        filename: filename,
        subject: '🚨 NOTA DE ALERTA PNP: $nombreCompleto',
        text: 'Por favor ayúdanos a compartir la Nota de Alerta Oficial de la PNP de $nombreCompleto. '
            'Si tienes información comunícate a la Línea 114 o aporta pistas en: https://pnpalerta.web.app/?id=${desaparecido.id ?? ""}',
      );

      if (!shared && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Nota de Alerta PDF descargada con éxito en tu dispositivo.'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      BrandedLoadingOverlay.hide();
      debugPrint('❌ Error al compartir Nota de Alerta PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al preparar Nota de Alerta: $e')),
        );
      }
    }
  }

  /// Abre la página web oficial del caso directamente en el servidor de la PNP
  static Future<void> abrirPortalOficialPnp(BuildContext context, Desaparecido desaparecido) async {
    final url = desaparecido.urlNotaAlertaOficial;
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo abrir el portal oficial: $url')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error abriendo portal PNP: $e');
    }
  }

  // ============================================================================
  // HELPERS DE RENDERIZADO VISUAL
  // ============================================================================

  static pw.Widget _buildSectionHeader(String title, PdfColor bg, PdfColor text, pw.Font fontBold) {
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 8),
      child: pw.Center(
        child: pw.Text(
          title,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 10,
            color: text,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildDataRow(
    String label,
    String value,
    PdfColor colorValor,
    pw.Font fontBold,
    pw.Font fontRegular, {
    int maxLines = 1,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.black),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              _sanitizarTextoPdf(value),
              style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: colorValor),
              maxLines: maxLines,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTrait(
    String label,
    String value,
    pw.Font fontBold,
    pw.Font fontRegular, {
    int maxLines = 1,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.black)),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: pw.Text(
            _sanitizarTextoPdf(value),
            style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColors.grey900),
            maxLines: maxLines,
          ),
        ),
      ],
    );
  }

  static Map<String, String> _extraerRasgos(String? detalles) {
    final result = <String, String>{};
    if (detalles == null || detalles.isEmpty) return result;

    final regexes = {
      'estatura': RegExp(r'Estatura:\s*([^.\n;]+)', caseSensitive: false),
      'contextura': RegExp(r'Contextura:\s*([^.\n;]+)', caseSensitive: false),
      'tez': RegExp(r'Tez:\s*([^.\n;]+)', caseSensitive: false),
      'ojos': RegExp(r'Ojos:\s*([^.\n;]+)', caseSensitive: false),
      'cabello': RegExp(r'Cabello:\s*([^.\n;]+)', caseSensitive: false),
      'vestimenta': RegExp(r'Vestimenta:\s*([^.\n;]+)', caseSensitive: false),
    };

    regexes.forEach((key, re) {
      final m = re.firstMatch(detalles);
      if (m != null) {
        result[key] = m.group(1)!.trim();
      }
    });

    return result;
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

  static Future<Uint8List?> _obtenerLogoPnpBytes() async {
    final candidates = [
      'assets/icons/emblema_pnp.png',
      'assets/icons/logo_pnp_policia.png',
      'assets/icons/icon_police.png',
    ];
    for (final path in candidates) {
      try {
        final byteData = await rootBundle.load(path);
        return byteData.buffer.asUint8List();
      } catch (_) {}
    }
    return null;
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
      debugPrint('⚠️ Error descargando foto oficial: $e');
    }
    return null;
  }
}
