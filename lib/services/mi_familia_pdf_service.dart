import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart' hide BoxDecoration, Border, Image, EdgeInsets, Alignment, TextStyle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../services/mi_familia_service.dart';
import '../presentation/common/widgets/branded_loading_dialog.dart';
import '../presentation/common/widgets/pdf_viewer_modal.dart';
import '../presentation/citizen/widgets/afiche_visual_preview_widget.dart';
import '../presentation/citizen/widgets/carnet_visual_preview_widget.dart';
import '../core/utils/platform_file_downloader.dart';

class MiFamiliaPdfService {
  /// Carga de manera segura los bytes del logotipo oficial del aplicativo para incrustarlo en los PDFs
  static Future<Uint8List?> _obtenerLogoAppBytes() async {
    try {
      final byteData = await rootBundle.load('assets/icons/icon_police.png');
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('ℹ️ Logo policial no disponible en este runtime/test: $e');
      return null;
    }
  }

  /// Carga de manera segura cualquier asset de imagen como bytes
  static Future<Uint8List?> _obtenerAssetBytes(String path) async {
    try {
      final byteData = await rootBundle.load(path);
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('ℹ️ Asset $path no disponible: $e');
      return null;
    }
  }

  /// Genera los bytes del AFICHE OFICIAL DE BÚSQUEDA A4 CON DISEÑO DE MÁXIMO IMPACTO
  /// Inspirado en los mejores estándares internacionales (AMBER Alert, NCMEC, Interpol y PNP Desaparecidos):
  /// - Foto central gigante y nítida (el elemento #1 de identificación visual rápida).
  /// - Cabecera de máxima visibilidad en rojo y amarillo reflectante con Logo Oficial y URL limpia.
  /// - Nombre de la persona en tipografía destacada con edad y DNI.
  /// - Ficha estructurada en 3 columnas que llena armónicamente todo el A4.
  /// - Tarjeta de vestimenta del día y zona de extravío resaltada.
  /// - Código QR inteligente de contacto inmediato por WhatsApp.
  /// - Números de emergencia prioritarios: Familia, Central PNP 105 y Línea 114 Desaparecidos.
  static Future<Uint8List> construirAficheBytes(FamiliarProfile familiar, {String? ultimaUbicacion}) async {
    final pdf = pw.Document();

    final fontTitle = pw.Font.helveticaBold();
    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    final logoAppBytes = await _obtenerLogoAppBytes();

    Uint8List? fotoBytes;
    if (familiar.fotoBase64 != null && familiar.fotoBase64!.isNotEmpty) {
      try {
        fotoBytes = base64Decode(familiar.fotoBase64!);
      } catch (e) {
        debugPrint('⚠️ Error decodificando foto base64: $e');
      }
    }

    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // Preparar enlace de auxilio rápido para el QR
    final telSanitized = familiar.telefonoContacto.replaceAll(RegExp(r'[^0-9]'), '');
    final waNumber = telSanitized.length == 9 ? '51$telSanitized' : telSanitized;
    final qrData = telSanitized.isNotEmpty
        ? 'https://wa.me/$waNumber?text=${Uri.encodeComponent('🚨 ALERTA CIUDADANA: Tengo pistas/información sobre ${familiar.nombreCompleto}, quien figura como desaparecido(a) en el Afiche Oficial.')}'
        : 'ALERTA DE DESAPARECIDO(A)\nNombre: ${familiar.nombreCompleto}\nEdad: ${familiar.edad} anos\nCentral Policia Nacional: 105\nLinea Desaparecidos: 114';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.red800, width: 3.5),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. Cabecera Urgente de Alto Impacto con Logo Oficial y URL limpia
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.red800,
                    borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Logotipo Oficial de la Aplicación
                      if (logoAppBytes != null)
                        pw.Container(
                          width: 38,
                          height: 38,
                          padding: const pw.EdgeInsets.all(2),
                          decoration: pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            color: PdfColors.white,
                            border: pw.Border.all(color: PdfColors.amber400, width: 1.5),
                          ),
                          child: pw.ClipOval(
                            child: pw.Image(pw.MemoryImage(logoAppBytes), fit: pw.BoxFit.contain),
                          ),
                        )
                      else
                        pw.SizedBox(width: 38),
                      pw.SizedBox(width: 8),
                      // Título Central
                      pw.Expanded(
                        child: pw.Column(
                          children: [
                            pw.Text(
                              '¡AYÚDANOS A ENCONTRARLO(A)!',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(font: fontTitle, fontSize: 20.5, color: PdfColors.white),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.amber400,
                                borderRadius: pw.BorderRadius.circular(3),
                              ),
                              child: pw.Text(
                                'ALERTA NACIONAL DE BÚSQUEDA Y DIFUSIÓN CIUDADANA - PNP ALERTA',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.brown900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      // URL limpia que no opaca los datos de auxilio
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromInt(0x33000000),
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: PdfColor.fromInt(0x66FFFFFF)),
                        ),
                        child: pw.Column(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text('OFICIAL', style: pw.TextStyle(font: fontBold, fontSize: 5.5, color: PdfColors.amber300)),
                            pw.Text('pnpalerta.web.app', style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        // 2. Nombre Completo Gigante y Badges
                        pw.Column(
                          children: [
                            pw.Text(
                              familiar.nombreCompleto.toUpperCase(),
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(font: fontTitle, fontSize: 20, color: PdfColors.red900),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                _buildPdfBadge('EDAD: ${familiar.edad} AÑOS', PdfColors.blue900, fontBold),
                                pw.SizedBox(width: 8),
                                if (familiar.dni.isNotEmpty) ...[
                                  _buildPdfBadge('DNI: ${familiar.dni}', PdfColors.grey800, fontBold),
                                  pw.SizedBox(width: 8),
                                ],
                                _buildPdfBadge('PARENTESCO: ${familiar.parentesco.toUpperCase()}', PdfColors.green900, fontBold),
                              ],
                            ),
                          ],
                        ),

                        // 3. FOTO CENTRAL GIGANTE
                        pw.Column(
                          children: [
                            pw.Container(
                              width: 250,
                              height: 260,
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.red800, width: 2.5),
                                borderRadius: pw.BorderRadius.circular(8),
                                color: PdfColors.grey200,
                              ),
                              child: fotoBytes != null
                                  ? pw.ClipRRect(
                                      horizontalRadius: 5,
                                      verticalRadius: 5,
                                      child: pw.Image(pw.MemoryImage(fotoBytes), fit: pw.BoxFit.cover),
                                    )
                                  : pw.Center(
                                      child: pw.Text(
                                        'FOTOGRAFÍA RECIENTE\n(NO DISPONIBLE)',
                                        textAlign: pw.TextAlign.center,
                                        style: pw.TextStyle(font: fontTitle, color: PdfColors.grey600, fontSize: 13),
                                      ),
                                    ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              color: PdfColors.black,
                              child: pw.Text(
                                'FOTOGRAFÍA RECIENTE CONFIRMADA POR LA FAMILIA',
                                style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.white),
                              ),
                            ),
                          ],
                        ),

                        // 4. Vestimenta del día y Lugar
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.amber50,
                            border: pw.Border.all(color: PdfColors.amber800, width: 1.2),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'VESTIMENTA AL SALIR / ÚLTIMO AVISTAMIENTO:',
                                style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.brown900),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                familiar.ropaDelDia.isNotEmpty
                                    ? familiar.ropaDelDia
                                    : 'No detallada al momento del reporte. Por favor comunicar cualquier dato relevante.',
                                style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColors.black),
                              ),
                              if (ultimaUbicacion != null && ultimaUbicacion.isNotEmpty) ...[
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  'PUNTO O ZONA DE EXTRAVÍO: $ultimaUbicacion',
                                  style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.red900),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // 5. Grilla de Características en 3 Columnas
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            borderRadius: pw.BorderRadius.circular(6),
                            border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                          ),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    _buildPdfDato('ESTATURA:', familiar.estatura.isNotEmpty ? '${familiar.estatura} m' : 'No especificada', fontBold, fontRegular),
                                    _buildPdfDato('CONTEXTURA:', familiar.contextura, fontBold, fontRegular),
                                    _buildPdfDato('GRUPO SANG.:', familiar.tipoSangre.isNotEmpty ? familiar.tipoSangre : 'No especificado', fontBold, fontRegular),
                                  ],
                                ),
                              ),
                              pw.SizedBox(width: 8),
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    _buildPdfDato('TEZ / PIEL:', familiar.colorPiel, fontBold, fontRegular),
                                    _buildPdfDato('CABELLO:', familiar.colorCabello, fontBold, fontRegular),
                                    _buildPdfDato('SEÑALES:', familiar.senasParticulares.isNotEmpty ? familiar.senasParticulares : 'Sin señas específicas', fontBold, fontRegular),
                                  ],
                                ),
                              ),
                              pw.SizedBox(width: 8),
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    if (familiar.condicionEspecial.isNotEmpty && familiar.condicionEspecial != 'Ninguna')
                                      _buildPdfDato('CONDICIÓN:', familiar.condicionEspecial.toUpperCase(), fontBold, fontRegular, highlight: true)
                                    else
                                      _buildPdfDato('CONDICIÓN:', 'Ninguna reportada', fontBold, fontRegular),
                                    if (familiar.datosMedicos.isNotEmpty)
                                      _buildPdfDato('MÉDICO:', familiar.datosMedicos, fontBold, fontRegular),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 6. Base con Código QR y Teléfonos
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.red50,
                            border: pw.Border.all(color: PdfColors.red600, width: 1.5),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Row(
                            children: [
                              // Código QR
                              pw.Column(
                                children: [
                                  pw.Container(
                                    width: 76,
                                    height: 76,
                                    padding: const pw.EdgeInsets.all(3),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.white,
                                      borderRadius: pw.BorderRadius.circular(4),
                                      border: pw.Border.all(color: PdfColors.red700),
                                    ),
                                    child: pw.BarcodeWidget(
                                      barcode: pw.Barcode.qrCode(),
                                      data: qrData,
                                      width: 70,
                                      height: 70,
                                    ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    'ESCANEA PARA PISTAS',
                                    style: pw.TextStyle(font: fontBold, fontSize: 6, color: PdfColors.red900),
                                  ),
                                ],
                              ),
                              pw.SizedBox(width: 10),

                              // Teléfonos de Auxilio
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      'URGENTE: SI TIENES INFORMACIÓN O LO HAS VISTO, COMUNÍCATE DE INMEDIATO:',
                                      style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.red900),
                                    ),
                                    pw.SizedBox(height: 3),
                                    if (familiar.telefonoContacto.isNotEmpty) ...[
                                      pw.Container(
                                        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                                        decoration: pw.BoxDecoration(
                                          color: PdfColors.green800,
                                          borderRadius: pw.BorderRadius.circular(4),
                                        ),
                                        child: pw.Text(
                                          'FAMILIA: ${familiar.telefonoContacto}',
                                          style: pw.TextStyle(font: fontTitle, fontSize: 13, color: PdfColors.white),
                                        ),
                                      ),
                                      pw.SizedBox(height: 3),
                                    ],
                                    pw.Row(
                                      children: [
                                        pw.Container(
                                          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                                          decoration: pw.BoxDecoration(
                                            color: PdfColors.red800,
                                            borderRadius: pw.BorderRadius.circular(4),
                                          ),
                                          child: pw.Text(
                                            'POLICÍA: 105',
                                            style: pw.TextStyle(font: fontTitle, fontSize: 10.5, color: PdfColors.white),
                                          ),
                                        ),
                                        pw.SizedBox(width: 6),
                                        pw.Container(
                                          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                                          decoration: pw.BoxDecoration(
                                            color: PdfColors.red900,
                                            borderRadius: pw.BorderRadius.circular(4),
                                          ),
                                          child: pw.Text(
                                            'LÍNEA 114 DESAPARECIDOS',
                                            style: pw.TextStyle(font: fontTitle, fontSize: 10.5, color: PdfColors.white),
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
                      ],
                    ),
                  ),
                ),

                // 7. Pie de Página Institucional
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  color: PdfColors.grey200,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Emisión: $nowStr - Plataforma Alerta Desaparecidos Perú', style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey700)),
                      pw.Text('pnpalerta.web.app', style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.blue800)),
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

  static pw.Widget _buildPdfBadge(String texto, PdfColor color, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text(
        texto,
        style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.white),
      ),
    );
  }

  /// Abre el visor interactivo in-app del Afiche PDF con el logo oficial y vista previa visual
  static Future<void> abrirAfichePdf(BuildContext context, FamiliarProfile familiar, {String? ultimaUbicacion}) async {
    BrandedLoadingOverlay.show(
      context,
      message: 'Cargando Afiche Oficial...',
      submessage: 'Preparando diseño de búsqueda de máxima visibilidad',
    );
    await Future.delayed(const Duration(milliseconds: 120));
    try {
      await PdfViewerModal.mostrar(
        context,
        title: 'Afiche de Búsqueda: ${familiar.nombreCompleto}',
        docGenerator: () => construirAficheBytes(familiar, ultimaUbicacion: ultimaUbicacion),
        filename: 'Afiche_Busqueda_${familiar.nombreCompleto.replaceAll(' ', '_')}.pdf',
        icon: Icons.campaign_rounded,
        visualPreviewBuilder: (ctx, onCompartir, onDescargar) {
          BrandedLoadingOverlay.hide();
          return AficheVisualPreviewWidget(
            familiar: familiar,
            ultimaUbicacion: ultimaUbicacion,
            onCompartir: onCompartir,
            onDescargar: onDescargar,
          );
        },
      );
    } finally {
      BrandedLoadingOverlay.hide();
    }
  }

  /// Comparte directamente el Afiche PDF (vía WhatsApp / Compartir nativo o Descarga)
  static Future<void> compartirAfichePdf(BuildContext context, FamiliarProfile familiar, {String? ultimaUbicacion}) async {
    try {
      BrandedLoadingOverlay.show(
        context,
        message: 'Preparando archivo PDF...',
        submessage: 'Optimizando afiche para compartir',
      );

      final bytes = await construirAficheBytes(familiar, ultimaUbicacion: ultimaUbicacion);
      BrandedLoadingOverlay.hide();

      final filename = 'Afiche_Busqueda_${familiar.nombreCompleto.replaceAll(' ', '_')}.pdf';
      final shared = await PlatformFileDownloader.sharePdf(
        bytes: bytes,
        filename: filename,
        subject: '🚨 AFICHE DE BÚSQUEDA: ${familiar.nombreCompleto}',
        text: 'Por favor ayúdanos a compartir este afiche oficial de búsqueda de ${familiar.nombreCompleto}',
      );
      if (!shared && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Afiche PDF descargado en tu dispositivo. Puedes adjuntarlo por WhatsApp.'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      BrandedLoadingOverlay.hide();
      debugPrint('❌ Error al compartir Afiche PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir afiche: $e')),
        );
      }
    }
  }

  /// Genera los bytes de la CREDENCIAL / CARNET PREVENTIVO SOS
  /// Admite formato Horizontal (Billetera), Vertical (Portafotocheck de cuello) o Ambos (Hoja Dual A4)
  static Future<Uint8List> construirCarnetBytes(
    FamiliarProfile familiar, {
    CarnetOrientacion orientacion = CarnetOrientacion.ambas,
    String? estiloOverride,
  }) async {
    final pdf = pw.Document();

    final fontTitle = pw.Font.helveticaBold();
    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    final logoAppBytes = await _obtenerLogoAppBytes();
    final theme = CarnetThemeConfig.desdeFamiliar(familiar, estiloOverride: estiloOverride);

    // Cargar fondos cósmicos / cyber en alta definición y firma cursiva
    final bool esFemenina = (theme.tipo == CarnetTipoEstilo.infantilNina);
    final String fondoAnversoPath = esFemenina
        ? 'assets/images/carnet/bg_girl_anverso_v2.png'
        : 'assets/images/carnet/bg_boy_anverso_v2.png';
    final String fondoReversoPath = esFemenina
        ? 'assets/images/carnet/bg_girl_reverso_v2.png'
        : 'assets/images/carnet/bg_boy_reverso_v2.png';

    final fondoAnversoBytes = await _obtenerAssetBytes(fondoAnversoPath);
    final fondoReversoBytes = await _obtenerAssetBytes(fondoReversoPath);
    final signatureBytes = await _obtenerAssetBytes('assets/images/carnet/signature_script.png');

    Uint8List? fotoBytes;
    if (familiar.fotoBase64 != null && familiar.fotoBase64!.isNotEmpty) {
      try {
        fotoBytes = base64Decode(familiar.fotoBase64!);
      } catch (e) {
        debugPrint('⚠️ Error decodificando foto base64 para carnet: $e');
      }
    }

    // Preparar enlace de auxilio rápido para el QR
    final telSanitized = familiar.telefonoContacto.replaceAll(RegExp(r'[^0-9]'), '');
    final waNumber = telSanitized.length == 9 ? '51$telSanitized' : telSanitized;
    final qrData = telSanitized.isNotEmpty
        ? 'https://wa.me/$waNumber?text=${Uri.encodeComponent('🚨 AUXILIO SOS: He encontrado a ${familiar.nombreCompleto} quien porta este Carnet de Identificación y Auxilio. Por favor comunicarse urgente a este teléfono.')}'
        : 'CREDENCIAL DE AUXILIO PNP ALERTA\nNombre: ${familiar.nombreCompleto}\nEdad: ${familiar.edad} anos\nCondicion: ${familiar.condicionEspecial}\nCentral PNP: 105 - Linea 114';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Encabezado principal institucional
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: pw.BoxDecoration(
                  color: theme.colorPrimario,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        if (logoAppBytes != null)
                          pw.Container(
                            width: 26,
                            height: 26,
                            margin: const pw.EdgeInsets.only(right: 8),
                            padding: const pw.EdgeInsets.all(1.5),
                            decoration: pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              color: PdfColors.white,
                              border: pw.Border.all(color: PdfColors.amber400, width: 1.2),
                            ),
                            child: pw.ClipOval(
                              child: pw.Image(pw.MemoryImage(logoAppBytes), fit: pw.BoxFit.contain),
                            ),
                          ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              orientacion == CarnetOrientacion.ambas
                                  ? 'KIT COMPLETO DE IDENTIFICACIÓN PREVENTIVA (AMBOS FORMATOS)'
                                  : (orientacion == CarnetOrientacion.vertical
                                      ? 'CREDENCIAL VERTICAL PARA PORTAFOTOCHECK DE CUELLO / LANYARD'
                                      : 'CREDENCIAL HORIZONTAL PARA BILLETERA / BOLSILLO'),
                              style: pw.TextStyle(font: fontTitle, fontSize: 9.5, color: PdfColors.white),
                            ),
                            pw.Text(
                              theme.subtituloBanner,
                              style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: PdfColors.grey200),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: pw.BoxDecoration(
                        color: theme.colorBadgeBg,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        theme.tipoPerfil,
                        style: pw.TextStyle(font: fontTitle, fontSize: 7.5, color: theme.colorBadgeText),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // RENDERIZADO SEGÚN LA ORIENTACIÓN SELECCIONADA
              if (orientacion == CarnetOrientacion.ambas) ...[
                // ===== SECCIÓN 1: FORMATO HORIZONTAL (86x54mm) =====
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'OPCIÓN 1: FORMATO HORIZONTAL (86mm x 54mm) - IDEAL PARA BILLETERA O BOLSILLO',
                        style: pw.TextStyle(font: fontTitle, fontSize: 7, color: theme.colorPrimario),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          _buildCarnetHorizontalAnverso(familiar, theme, fontTitle, fontBold, fontRegular, fotoBytes, logoAppBytes),
                          _buildFoldDividerHorizontal(),
                          _buildCarnetHorizontalReverso(familiar, theme, fontTitle, fontBold, fontRegular, logoAppBytes, qrData),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 8),

                // ===== SECCIÓN 2: FORMATO VERTICAL (54x86mm) =====
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'OPCIÓN 2: FORMATO VERTICAL (54mm x 86mm) - PARA PORTAFOTOCHECK DE CUELLO / LANYARD (CON PERFORACIÓN)',
                        style: pw.TextStyle(font: fontTitle, fontSize: 7, color: theme.colorPrimario),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          _buildCarnetVerticalAnverso(
                            familiar,
                            theme,
                            fontTitle,
                            fontBold,
                            fontRegular,
                            fotoBytes,
                            logoAppBytes,
                            qrData,
                            fondoBytes: fondoAnversoBytes,
                            signatureBytes: signatureBytes,
                          ),
                          _buildFoldDividerVertical(),
                          _buildCarnetVerticalReverso(
                            familiar,
                            theme,
                            fontTitle,
                            fontBold,
                            fontRegular,
                            logoAppBytes,
                            qrData,
                            fondoBytes: fondoReversoBytes,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else if (orientacion == CarnetOrientacion.horizontal) ...[
                // SOLO HORIZONTAL (AMPLIADO Y CENTRADO)
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, style: pw.BorderStyle.dashed, width: 1.2),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        '-- RECORTE POR EL BORDE EXTERIOR Y DOBLE POR LA LÍNEA CENTRAL (TAMAÑO BILLETERA 86mm x 54mm) --',
                        style: pw.TextStyle(font: fontTitle, fontSize: 8, color: PdfColors.grey700),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          _buildCarnetHorizontalAnverso(familiar, theme, fontTitle, fontBold, fontRegular, fotoBytes, logoAppBytes),
                          _buildFoldDividerHorizontal(),
                          _buildCarnetHorizontalReverso(familiar, theme, fontTitle, fontBold, fontRegular, logoAppBytes, qrData),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                _buildGuiaDidacticaPdf(theme, fontTitle, fontBold, fontRegular),
              ] else ...[
                // SOLO VERTICAL (PORTAFOTOCHECK CUELLO)
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, style: pw.BorderStyle.dashed, width: 1.2),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        '-- RECORTE Y DOBLE POR LA LÍNEA CENTRAL - INSERTAR EN PORTAFOTOCHECK O LANYARD (65mm x 95mm) --',
                        style: pw.TextStyle(font: fontTitle, fontSize: 8, color: PdfColors.grey700),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          _buildCarnetVerticalAnverso(
                            familiar,
                            theme,
                            fontTitle,
                            fontBold,
                            fontRegular,
                            fotoBytes,
                            logoAppBytes,
                            qrData,
                            fondoBytes: fondoAnversoBytes,
                            signatureBytes: signatureBytes,
                          ),
                          _buildFoldDividerVertical(),
                          _buildCarnetVerticalReverso(
                            familiar,
                            theme,
                            fontTitle,
                            fontBold,
                            fontRegular,
                            logoAppBytes,
                            qrData,
                            fondoBytes: fondoReversoBytes,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                _buildGuiaDidacticaPdf(theme, fontTitle, fontBold, fontRegular),
              ],

              if (orientacion == CarnetOrientacion.ambas) ...[
                pw.SizedBox(height: 6),
                _buildGuiaDidacticaPdf(theme, fontTitle, fontBold, fontRegular),
              ],

              pw.Spacer(),

              // Pie de página A4 con URL limpia
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Módulo Mi Familia Segura - Policía Nacional del Perú', style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey600)),
                  pw.Text('pnpalerta.web.app', style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.blue800)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // =========================================================================
  // SUB-BUILDERS: CARNET HORIZONTAL (86mm x 54mm aprox 244 x 155 pt)
  // Inspirado en el diseño moderno oscuro con anillo circular y mascota oficial
  // =========================================================================

  static pw.Widget _buildCarnetHorizontalAnverso(
    FamiliarProfile familiar,
    CarnetThemeConfig theme,
    pw.Font fontTitle,
    pw.Font fontBold,
    pw.Font fontRegular,
    Uint8List? fotoBytes,
    Uint8List? logoAppBytes,
  ) {
    return pw.Container(
      width: 244,
      height: 155,
      decoration: pw.BoxDecoration(
        color: theme.colorDarkCard,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: theme.colorBorde, width: 1.2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Cabecera elegante con Mascota Oficial
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: pw.BoxDecoration(
              color: theme.colorPillBg,
              borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(7)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    if (logoAppBytes != null)
                      pw.Container(
                        width: 14,
                        height: 14,
                        margin: const pw.EdgeInsets.only(right: 4),
                        padding: const pw.EdgeInsets.all(0.8),
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: PdfColors.white,
                          border: pw.Border.all(color: theme.colorAnillo, width: 1),
                        ),
                        child: pw.ClipOval(child: pw.Image(pw.MemoryImage(logoAppBytes), fit: pw.BoxFit.contain)),
                      ),
                    pw.Text('PNP ALERTA - ESCUDO SOS', style: pw.TextStyle(font: fontTitle, fontSize: 6.8, color: PdfColors.white)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: pw.BoxDecoration(
                    color: theme.colorDarkCard,
                    borderRadius: pw.BorderRadius.circular(3),
                    border: pw.Border.all(color: theme.colorAcento, width: 0.7),
                  ),
                  child: pw.Text(
                    theme.tituloCadete,
                    style: pw.TextStyle(font: fontBold, fontSize: 5, color: theme.colorAcento),
                  ),
                ),
              ],
            ),
          ),

          // Cuerpo: Foto circular con anillo neón y datos
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Avatar circular con anillo de acento
                pw.Container(
                  width: 52,
                  height: 52,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    border: pw.Border.all(color: theme.colorAnillo, width: 2),
                    color: PdfColors.black,
                  ),
                  padding: const pw.EdgeInsets.all(1.5),
                  child: pw.ClipOval(
                    child: fotoBytes != null
                        ? pw.Image(pw.MemoryImage(fotoBytes), fit: pw.BoxFit.cover)
                        : pw.Center(child: pw.Text('FOTO', style: pw.TextStyle(font: fontTitle, fontSize: 7, color: PdfColors.grey500))),
                  ),
                ),
                pw.SizedBox(width: 8),

                // Datos de la persona
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        familiar.nombreCompleto.toUpperCase(),
                        maxLines: 2,
                        style: pw.TextStyle(font: fontTitle, fontSize: 8.5, color: PdfColors.white),
                      ),
                      pw.SizedBox(height: 1.5),
                      pw.Text(
                        familiar.edad > 0 ? 'EDAD: ${familiar.edad} AÑOS' : 'CADETE SOS',
                        style: pw.TextStyle(font: fontBold, fontSize: 6.8, color: theme.colorAcento),
                      ),
                      if (familiar.dni.isNotEmpty) ...[
                        pw.SizedBox(height: 1.5),
                        pw.Text('ID / DNI: ${familiar.dni}', style: pw.TextStyle(font: fontRegular, fontSize: 6.2, color: PdfColors.grey300)),
                      ],
                      pw.SizedBox(height: 2),
                      pw.Row(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.red800,
                              borderRadius: pw.BorderRadius.circular(3),
                            ),
                            child: pw.Text(
                              'RH: ${familiar.tipoSangre.isNotEmpty ? familiar.tipoSangre : "O+"}',
                              style: pw.TextStyle(font: fontTitle, fontSize: 6.2, color: PdfColors.white),
                            ),
                          ),
                          if (familiar.condicionEspecial.isNotEmpty && familiar.condicionEspecial != 'Ninguna') ...[
                            pw.SizedBox(width: 4),
                            pw.Expanded(
                              child: pw.Text(
                                familiar.condicionEspecial,
                                maxLines: 1,
                                style: pw.TextStyle(font: fontBold, fontSize: 5.8, color: PdfColors.amber300),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.Spacer(),

          // Pastilla SOS de Alto Contraste Naranja Neón
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.symmetric(horizontal: 7),
            padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 6),
            decoration: pw.BoxDecoration(
              color: theme.colorSosButton,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.orange200, width: 0.6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('SOS AVISAR: ', style: pw.TextStyle(font: fontBold, fontSize: 6.5, color: PdfColors.white)),
                pw.Text(
                  familiar.telefonoContacto.isNotEmpty ? familiar.telefonoContacto : '105',
                  style: pw.TextStyle(font: fontTitle, fontSize: 8.5, color: PdfColors.yellow300),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 3),

          // Barra inferior institucional con URL limpia
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: pw.BoxDecoration(
              color: theme.colorPillBg,
              borderRadius: const pw.BorderRadius.vertical(bottom: pw.Radius.circular(7)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('EMERGENCIAS PNP: 105', style: pw.TextStyle(font: fontBold, fontSize: 5.5, color: PdfColors.grey300)),
                pw.Text('pnpalerta.web.app', style: pw.TextStyle(font: fontTitle, fontSize: 5.8, color: theme.colorAcento)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCarnetHorizontalReverso(
    FamiliarProfile familiar,
    CarnetThemeConfig theme,
    pw.Font fontTitle,
    pw.Font fontBold,
    pw.Font fontRegular,
    Uint8List? logoAppBytes,
    String qrData,
  ) {
    return pw.Container(
      width: 244,
      height: 155,
      decoration: pw.BoxDecoration(
        color: theme.colorDarkCard,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: theme.colorBorde, width: 1.2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Cabecera Reverso con Mascota
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: pw.BoxDecoration(
              color: theme.colorPillBg,
              borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(7)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    if (logoAppBytes != null)
                      pw.Container(
                        width: 14,
                        height: 14,
                        margin: const pw.EdgeInsets.only(right: 4),
                        padding: const pw.EdgeInsets.all(0.8),
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: PdfColors.white,
                          border: pw.Border.all(color: theme.colorAnillo, width: 1),
                        ),
                        child: pw.ClipOval(child: pw.Image(pw.MemoryImage(logoAppBytes), fit: pw.BoxFit.contain)),
                      ),
                    pw.Text(theme.tituloReverso, style: pw.TextStyle(font: fontTitle, fontSize: 6.5, color: PdfColors.white)),
                  ],
                ),
                pw.Text('WHATSAPP SOS', style: pw.TextStyle(font: fontBold, fontSize: 5.8, color: PdfColors.green300)),
              ],
            ),
          ),

          // Cuerpo Reverso: QR y Protocolo
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // QR
                pw.Column(
                  children: [
                    pw.Container(
                      width: 58,
                      height: 58,
                      padding: const pw.EdgeInsets.all(2.5),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: theme.colorAcento, width: 1),
                      ),
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrData,
                        width: 53,
                        height: 53,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text('ESCANEAR CÁMARA', style: pw.TextStyle(font: fontBold, fontSize: 5, color: theme.colorAcento)),
                  ],
                ),
                pw.SizedBox(width: 8),

                // Instrucciones
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('PERSONAL AUTORIZADO Y PROTEGIDO', style: pw.TextStyle(font: fontTitle, fontSize: 6, color: theme.colorAcento)),
                      pw.SizedBox(height: 1),
                      pw.Text('Identifica al portador ante la PNP o Serenazgo.', style: pw.TextStyle(font: fontRegular, fontSize: 5.2, color: PdfColors.grey300)),
                      pw.SizedBox(height: 3),
                      pw.Text('PROTOCOLO SOS:', style: pw.TextStyle(font: fontTitle, fontSize: 6, color: PdfColors.amber300)),
                      pw.Text('1. Acércate a un Policía o Serenazgo.', style: pw.TextStyle(font: fontRegular, fontSize: 5, color: PdfColors.white)),
                      pw.Text('2. Muestra este carnet para escanear el QR.', style: pw.TextStyle(font: fontRegular, fontSize: 5, color: PdfColors.white)),
                      pw.Text('3. Espera en lugar seguro a tu familia.', style: pw.TextStyle(font: fontRegular, fontSize: 5, color: PdfColors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.Spacer(),

          // Franja inferior reverso con lema
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: pw.BoxDecoration(
              color: theme.colorPillBg,
              borderRadius: const pw.BorderRadius.vertical(bottom: pw.Radius.circular(7)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('PNP: 105 | LÍNEA: 114', style: pw.TextStyle(font: fontBold, fontSize: 5.5, color: PdfColors.grey300)),
                pw.Text('pnpalerta.web.app', style: pw.TextStyle(font: fontTitle, fontSize: 5.8, color: theme.colorAcento)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SUB-BUILDERS: CARNET VERTICAL (65mm x 95mm aprox 180 x 265 pt)
  // Formato portafotocheck de cuello / lanyard con perforación superior,
  // logotipo oficial de la mascota de la app en medalla circular neón,
  // marco fotográfico luminoso, pastilla de aviso SOS naranja de alto contraste,
  // código de barras Code 128, firma y protocolo de auxilio en el reverso.
  // =========================================================================

  static pw.Widget _buildCarnetVerticalAnverso(
    FamiliarProfile familiar,
    CarnetThemeConfig theme,
    pw.Font fontTitle,
    pw.Font fontBold,
    pw.Font fontRegular,
    Uint8List? fotoBytes,
    Uint8List? logoAppBytes,
    String qrData, {
    Uint8List? fondoBytes,
    Uint8List? signatureBytes,
  }) {
    final bool isGirl = theme.tipo == CarnetTipoEstilo.infantilNina;
    final PdfColor textPrimary = PdfColors.white;
    final PdfColor textSecondary = isGirl ? PdfColor.fromInt(0xFFFBCFE8) : PdfColor.fromInt(0xFF80DEEA);

    return pw.ClipRRect(
      horizontalRadius: 12,
      verticalRadius: 12,
      child: pw.Container(
        width: 185,
        height: 275,
        child: pw.Stack(
          children: [
            // 0. Plantilla Maestra Oficial Vertical Anverso
            if (fondoBytes != null)
              pw.Positioned.fill(
                child: pw.Image(pw.MemoryImage(fondoBytes), fit: pw.BoxFit.cover),
              )
            else
              pw.Positioned.fill(
                child: pw.Container(color: theme.colorDarkCard),
              ),

            // Borde exterior suave del carnet
            pw.Positioned.fill(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(
                    color: isGirl ? PdfColor.fromInt(0x66FDA4AF) : PdfColor.fromInt(0x6600E5FF),
                    width: 1.2,
                  ),
                ),
              ),
            ),

            // 1. FOTO DEL MENOR (Calzada con precisión dentro del marco neón de la plantilla HD)
            pw.Positioned(
              left: 50.5,
              top: 71.0,
              child: pw.ClipRRect(
                horizontalRadius: 10,
                verticalRadius: 10,
                child: pw.SizedBox(
                  width: 82.0,
                  height: 79.0,
                  child: fotoBytes != null
                      ? pw.Image(pw.MemoryImage(fotoBytes), fit: pw.BoxFit.cover)
                      : pw.Container(
                          color: isGirl ? PdfColor.fromInt(0xFF4C0519) : PdfColor.fromInt(0xFF071426),
                          child: pw.Center(
                            child: pw.Text(
                              'FOTO\nACTUAL',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                font: fontTitle,
                                fontSize: 7.5,
                                color: isGirl ? PdfColor.fromInt(0xFFFDA4AF) : PdfColor.fromInt(0xFF80DEEA),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),

            // 2. BLOQUE DE DATOS DEL MENOR (Nombre, DNI, Edad/RH, Condición Especial)
            pw.Positioned(
              top: 152.5,
              left: 8,
              right: 8,
              child: pw.Container(
                height: 50,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      familiar.nombreCompleto.toUpperCase(),
                      textAlign: pw.TextAlign.center,
                      maxLines: 2,
                      style: pw.TextStyle(
                        font: fontTitle,
                        fontSize: 8.5,
                        color: textPrimary,
                      ),
                    ),
                    pw.SizedBox(height: 1.5),
                    pw.Text(
                      'ID / DNI: ${familiar.dni.isNotEmpty ? familiar.dni : "CADETE SOS"}',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 6.0,
                        color: textSecondary,
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      'EDAD / RH: ${familiar.edad} AÑOS | ${familiar.tipoSangre.isNotEmpty ? familiar.tipoSangre : "O+"}',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 6.0,
                        color: textSecondary,
                      ),
                    ),
                    if (familiar.condicionEspecial.isNotEmpty && familiar.condicionEspecial != 'Ninguna') ...[
                      pw.SizedBox(height: 1.5),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: pw.BoxDecoration(
                          color: isGirl ? PdfColor.fromInt(0xFFBE185D) : PdfColor.fromInt(0xFF0284C7),
                          borderRadius: pw.BorderRadius.circular(2.5),
                        ),
                        child: pw.Text(
                          familiar.condicionEspecial,
                          style: pw.TextStyle(font: fontBold, fontSize: 4.8, color: PdfColors.white),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 3. NÚMERO DE CONTACTO EN EL BOTÓN SOS (A la derecha de "SOS AVISAR:" con separación elegante)
            pw.Positioned(
              top: 204.5,
              left: 100.0,
              right: 28.0,
              child: pw.Container(
                height: 16,
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  familiar.telefonoContacto.isNotEmpty ? familiar.telefonoContacto : '105',
                  maxLines: 1,
                  style: pw.TextStyle(
                    font: fontTitle,
                    fontSize: 8.2,
                    color: PdfColor.fromInt(0xFFFFD54F),
                  ),
                ),
              ),
            ),

            // 4. CÓDIGO QR REAL DE AUXILIO (Ubicado exactamente en el recuadro blanco)
            pw.Positioned(
              right: 17.5,
              bottom: 9.8,
              child: pw.Container(
                width: 37.7,
                height: 37.4,
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(2.5),
                ),
                padding: const pw.EdgeInsets.all(1.0),
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrData,
                  color: PdfColors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildCarnetVerticalReverso(
    FamiliarProfile familiar,
    CarnetThemeConfig theme,
    pw.Font fontTitle,
    pw.Font fontBold,
    pw.Font fontRegular,
    Uint8List? logoAppBytes,
    String qrData, {
    Uint8List? fondoBytes,
  }) {
    final bool isGirl = theme.tipo == CarnetTipoEstilo.infantilNina;

    return pw.ClipRRect(
      horizontalRadius: 12,
      verticalRadius: 12,
      child: pw.Container(
        width: 185,
        height: 275,
        child: pw.Stack(
          children: [
            // 0. Plantilla Maestra Reverso Oficial HD
            if (fondoBytes != null)
              pw.Positioned.fill(
                child: pw.Image(pw.MemoryImage(fondoBytes), fit: pw.BoxFit.cover),
              )
            else
              pw.Positioned.fill(
                child: pw.Container(color: theme.colorDarkCard),
              ),

            // Borde exterior
            pw.Positioned.fill(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(
                    color: isGirl ? PdfColor.fromInt(0x66FDA4AF) : PdfColor.fromInt(0x6600E5FF),
                    width: 1.2,
                  ),
                ),
              ),
            ),

            // 1. ALERTA MÉDICA (Dentro de la pastilla roja de la plantilla HD, espacio limpio sin [ALERGIAS O MEDICACIÓN])
            pw.Positioned(
              top: 204.5,
              left: 78.0,
              right: 20.0,
              child: pw.Container(
                height: 14.5,
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  familiar.datosMedicos.isNotEmpty ? familiar.datosMedicos.toUpperCase() : "SIN ALERGIAS CONOCIDAS",
                  maxLines: 1,
                  style: pw.TextStyle(
                    font: fontTitle,
                    fontSize: 6.2,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ),

            // 2. TELÉFONO DE FAMILIA DIRECTA (Columna 3 bajo "FAMILIA DIRECTA", espacio limpio sin [N° CONTACTO])
            pw.Positioned(
              top: 236.0,
              right: 17.5,
              child: pw.Container(
                width: 58.0,
                height: 22.0,
                alignment: pw.Alignment.center,
                child: pw.Text(
                  familiar.telefonoContacto.isNotEmpty ? familiar.telefonoContacto : '105',
                  maxLines: 1,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: fontTitle,
                    fontSize: 9.0,
                    color: PdfColor.fromInt(0xFFFDE047),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildFoldDividerHorizontal() {
    return pw.Container(
      width: 12,
      height: 155,
      alignment: pw.Alignment.center,
      child: pw.CustomPaint(
        size: const PdfPoint(2, 135),
        painter: (PdfGraphics canvas, PdfPoint size) {
          canvas.setLineDashPattern([3, 3]);
          canvas.setStrokeColor(PdfColors.grey500);
          canvas.setLineWidth(0.8);
          canvas.drawLine(0, 0, 0, size.y);
          canvas.strokePath();
        },
      ),
    );
  }

  static pw.Widget _buildFoldDividerVertical() {
    return pw.Container(
      width: 14,
      height: 275,
      alignment: pw.Alignment.center,
      child: pw.CustomPaint(
        size: const PdfPoint(2, 260),
        painter: (PdfGraphics canvas, PdfPoint size) {
          canvas.setLineDashPattern([3, 3]);
          canvas.setStrokeColor(PdfColors.grey500);
          canvas.setLineWidth(0.8);
          canvas.drawLine(0, 0, 0, size.y);
          canvas.strokePath();
        },
      ),
    );
  }

  static pw.Widget _buildGuiaDidacticaPdf(
    CarnetThemeConfig theme,
    pw.Font fontTitle,
    pw.Font fontBold,
    pw.Font fontRegular,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: theme.colorFondoBanda,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: theme.colorBorde, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            theme.guiaTitulo,
            style: pw.TextStyle(font: fontTitle, fontSize: 8, color: theme.colorPrimario),
          ),
          pw.SizedBox(height: 3),
          _buildPasoGuia('1. Preparación', theme.guiaPaso1, fontBold, fontRegular),
          _buildPasoGuia('2. Uso Cotidiano', theme.guiaPaso2, fontBold, fontRegular),
          _buildPasoGuia('3. Protocolo', theme.guiaPaso3, fontBold, fontRegular),
          _buildPasoGuia(
            '4. Respuesta Inmediata',
            'Cualquier ciudadano o policía puede escanear el código QR con su celular para abrir un chat de auxilio directo por WhatsApp con usted o llamar a los números oficiales.',
            fontBold,
            fontRegular,
          ),
        ],
      ),
    );
  }

  /// Abre el visor interactivo in-app del Carnet SOS con selector de orientación y vista previa
  static Future<void> abrirCarnetPdf(
    BuildContext context,
    FamiliarProfile familiar, {
    CarnetOrientacion orientacion = CarnetOrientacion.ambas,
    String? estiloOverride,
  }) async {
    BrandedLoadingOverlay.show(
      context,
      message: 'Cargando Carnet SOS...',
      submessage: 'Generando credencial oficial con protección PNP',
    );
    await Future.delayed(const Duration(milliseconds: 120));
    try {
      await PdfViewerModal.mostrar(
        context,
        title: 'Carnet Preventivo SOS: ${familiar.nombreCompleto}',
        docGenerator: () => construirCarnetBytes(familiar, orientacion: orientacion, estiloOverride: estiloOverride),
        filename: 'Carnet_SOS_${familiar.nombreCompleto.replaceAll(' ', '_')}.pdf',
        icon: Icons.badge_rounded,
        visualPreviewBuilder: (ctx, onCompartir, onDescargar) {
          BrandedLoadingOverlay.hide();
          return CarnetVisualPreviewWidget(
            familiar: familiar,
            onCompartir: onCompartir,
            onDescargar: onDescargar,
            inicialEstilo: estiloOverride,
          );
        },
      );
    } finally {
      BrandedLoadingOverlay.hide();
    }
  }

  /// Comparte directamente el Carnet SOS PDF (vía WhatsApp / Compartir nativo o Descarga)
  static Future<void> compartirCarnetPdf(
    BuildContext context,
    FamiliarProfile familiar, {
    CarnetOrientacion orientacion = CarnetOrientacion.ambas,
    String? estiloOverride,
  }) async {
    try {
      BrandedLoadingOverlay.show(
        context,
        message: 'Preparando Carnet para compartir...',
        submessage: 'Generando credencial en alta resolución',
      );

      final bytes = await construirCarnetBytes(familiar, orientacion: orientacion, estiloOverride: estiloOverride);
      BrandedLoadingOverlay.hide();

      final filename = 'Carnet_SOS_${familiar.nombreCompleto.replaceAll(' ', '_')}.pdf';
      final shared = await PlatformFileDownloader.sharePdf(
        bytes: bytes,
        filename: filename,
        subject: 'CARNET SOS: ${familiar.nombreCompleto}',
        text: 'Credencial preventiva de auxilio para ${familiar.nombreCompleto}',
      );
      if (!shared && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Carnet SOS PDF descargado en tu dispositivo. Puedes adjuntarlo por WhatsApp.'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      BrandedLoadingOverlay.hide();
      debugPrint('Error al compartir Carnet SOS PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aviso al compartir carnet: $e')),
        );
      }
    }
  }

  static pw.Widget _buildPasoGuia(String titulo, String descripcion, pw.Font fontTitle, pw.Font fontRegular) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('- ', style: pw.TextStyle(font: fontTitle, fontSize: 9, color: PdfColors.blue900)),
          pw.Expanded(
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: '$titulo: ', style: pw.TextStyle(font: fontTitle, fontSize: 8, color: PdfColors.blue900)),
                  pw.TextSpan(text: descripcion, style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfDato(String etiqueta, String valor, pw.Font fontTitle, pw.Font fontRegular, {bool highlight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.Text(etiqueta, style: pw.TextStyle(font: fontTitle, fontSize: 9.5, color: highlight ? PdfColors.red800 : PdfColors.grey700)),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(valor, style: pw.TextStyle(font: fontTitle, fontSize: 10, color: highlight ? PdfColors.red900 : PdfColors.black)),
          ),
        ],
      ),
    );
  }
}

/// Orientaciones de impresión disponibles para la Credencial / Carnet SOS
enum CarnetOrientacion {
  /// Tamaño 86mm x 54mm (CR80 horizontal - billetera o credencial de bolsillo)
  horizontal,
  /// Tamaño 54mm x 86mm (CR80 vertical - fotocheck de cuello con perforación para lanyard/cinta)
  vertical,
  /// Hoja A4 completa con ambas opciones (Horizontal + Vertical) listas para recortar y usar
  ambas,
}

/// Estilos etarios para el Carnet SOS
enum CarnetTipoEstilo { infantilNino, infantilNina, juvenil, adulto }

/// Configuración visual y temática del Carnet SOS según el grupo etario y género (Cadete Niño, Cadete Niña, Juvenil, Adulto/Senior)
class CarnetThemeConfig {
  final CarnetTipoEstilo tipo;
  final String tipoPerfil;
  final String subtituloBanner;
  final String tituloAnverso;
  final String badgeAnverso;
  final String tituloReverso;
  final String instruccionPortador;
  final String instruccionAuxilio;
  final String guiaTitulo;
  final String guiaPaso1;
  final String guiaPaso2;
  final String guiaPaso3;
  final PdfColor colorPrimario;
  final PdfColor colorSecundario;
  final PdfColor colorAcento;
  final PdfColor colorBorde;
  final PdfColor colorFondoBanda;
  final PdfColor colorFondoTarjeta;
  final String lemaDecorativo;
  final PdfColor colorBadgeBg;
  final PdfColor colorBadgeText;
  final PdfColor colorDarkCard;
  final PdfColor colorPillBg;
  final PdfColor colorAnillo;
  final PdfColor colorSosButton;
  final String tituloCadete;
  final String paso1;
  final String paso2;
  final String paso3;
  final String paso4;

  CarnetThemeConfig({
    required this.tipo,
    required this.tipoPerfil,
    required this.subtituloBanner,
    required this.tituloAnverso,
    required this.badgeAnverso,
    required this.tituloReverso,
    required this.instruccionPortador,
    required this.instruccionAuxilio,
    required this.guiaTitulo,
    required this.guiaPaso1,
    required this.guiaPaso2,
    required this.guiaPaso3,
    required this.colorPrimario,
    required this.colorSecundario,
    required this.colorAcento,
    required this.colorBorde,
    required this.colorFondoBanda,
    required this.colorFondoTarjeta,
    required this.lemaDecorativo,
    required this.colorBadgeBg,
    required this.colorBadgeText,
    required this.colorDarkCard,
    required this.colorPillBg,
    required this.colorAnillo,
    PdfColor? colorSosButton,
    this.tituloCadete = 'CADETE DE EMERGENCIA',
    required this.paso1,
    required this.paso2,
    required this.paso3,
    required this.paso4,
  }) : colorSosButton = colorSosButton ?? PdfColor.fromInt(0xFFEA580C);

  factory CarnetThemeConfig.desdeFamiliar(FamiliarProfile f, {String? estiloOverride}) {
    final bool esFemenina = estiloOverride == 'nina'
        ? true
        : (estiloOverride == 'nino' ? false : f.esFemenino);

    if (f.edad > 0 && f.edad <= 11) {
      if (esFemenina) {
        // 👧 PERFIL CADETE ESPACIAL NIÑA: Nebulosa Rosa Pastel & Rose Gold
        return CarnetThemeConfig(
          tipo: CarnetTipoEstilo.infantilNina,
          tipoPerfil: 'CADETE ESPACIAL (NIÑA)',
          subtituloBanner: 'Credencial Escudo SOS - Cadete de Emergencia PNP Alerta',
          tituloAnverso: 'PNP ALERTA / ESCUDO SOS',
          badgeAnverso: 'CADETE DE EMERGENCIA',
          tituloReverso: 'PNP ALERTA / SOS NACIONAL',
          instruccionPortador: 'INSTRUCCIÓN: Si te desorientas, mantén la calma y muestra este carnet a un Policía o Serenazgo.',
          instruccionAuxilio: 'SI ENCUENTRA A ESTA MENOR EXTRAVIADA:\n1. Mantén la calma y no te alejes del lugar seguro.\n2. Escanee el código QR para llamar a sus padres inmediatamente.\n3. Acérquela a la comisaría más cercana o llame al 105.',
          guiaTitulo: 'GUÍA DIDÁCTICA: CÓMO ENSEÑARLE A USAR ESTE CARNET A TU HIJA',
          guiaPaso1: 'Colócalo en su portafotocheck de cuello o en el bolsillo delantero de su mochila.',
          guiaPaso2: 'Enséñale que es su credencial de seguridad y auxilio inmediato.',
          guiaPaso3: 'Recuérdale que ante cualquier duda o extravío debe buscar un policía o serenazgo.',
          colorPrimario: PdfColor.fromInt(0xFF831843), // Borgoña profundo
          colorSecundario: PdfColor.fromInt(0xFFBE185D), // Rosa intenso
          colorAcento: PdfColor.fromInt(0xFFFBCFE8), // Rosa pastel / Rose gold
          colorBorde: PdfColor.fromInt(0xFFF43F5E), // Rosa neón luminoso
          colorFondoBanda: PdfColor.fromInt(0xFFFFF1F2),
          colorFondoTarjeta: PdfColor.fromInt(0xFF3B0718), // Fondo cósmico borgoña profundo
          lemaDecorativo: 'PROTEGIENDO EL FUTURO DE NUESTRA NIÑEZ',
          colorBadgeBg: PdfColor.fromInt(0xFFBE185D),
          colorBadgeText: PdfColors.white,
          colorDarkCard: PdfColor.fromInt(0xFF4C0519), // Rose dark estelar
          colorPillBg: PdfColor.fromInt(0xFF831843),
          colorAnillo: PdfColor.fromInt(0xFFF43F5E), // Resplandor rosa neón
          colorSosButton: PdfColor.fromInt(0xFFEA580C), // Naranja Neón brillante de alto contraste
          tituloCadete: 'CADETE DE EMERGENCIA',
          paso1: 'Mantén la calma y no te alejes del lugar seguro.',
          paso2: 'Muestra este carnet a un Policía o Serenazgo.',
          paso3: 'Pide que escaneen tu código QR para avisar a tus papás.',
          paso4: 'Espera en un lugar visible a que vengan por ti.',
        );
      } else {
        // 👦 PERFIL CADETE ESPACIAL NIÑO: Obsidian Space & Cyan Neon Glow
        return CarnetThemeConfig(
          tipo: CarnetTipoEstilo.infantilNino,
          tipoPerfil: 'CADETE ESPACIAL (NIÑO)',
          subtituloBanner: 'Credencial Escudo SOS - Cadete de Emergencia PNP Alerta',
          tituloAnverso: 'PNP ALERTA / ESCUDO SOS',
          badgeAnverso: 'CADETE DE EMERGENCIA',
          tituloReverso: 'PNP ALERTA / SOS NACIONAL',
          instruccionPortador: 'INSTRUCCIÓN: Si te desorientas, mantén la calma y muestra este carnet a un Policía o Serenazgo.',
          instruccionAuxilio: 'SI ENCUENTRA A ESTE MENOR EXTRAVIADO:\n1. Mantén la calma y no te alejes del lugar seguro.\n2. Escanee el código QR para llamar a sus padres inmediatamente.\n3. Acérquelo a la comisaría más cercana o llame al 105.',
          guiaTitulo: 'GUÍA DIDÁCTICA: CÓMO ENSEÑARLE A USAR ESTE CARNET A TU HIJO',
          guiaPaso1: 'Colócalo en su portafotocheck de cuello o en el bolsillo delantero de su mochila.',
          guiaPaso2: 'Enséñale que es su credencial de seguridad y auxilio inmediato.',
          guiaPaso3: 'Recuérdale que ante cualquier duda o extravío debe buscar un policía o serenazgo.',
          colorPrimario: PdfColor.fromInt(0xFF0C4A6E),
          colorSecundario: PdfColor.fromInt(0xFF0F172A),
          colorAcento: PdfColor.fromInt(0xFF00E5FF), // Cian Neón eléctrico
          colorBorde: PdfColor.fromInt(0xFF00E5FF),
          colorFondoBanda: PdfColor.fromInt(0xFF082F49),
          colorFondoTarjeta: PdfColor.fromInt(0xFF0B0F19), // Fondo Obsidian Space
          lemaDecorativo: 'PROTEGIENDO EL FUTURO DE NUESTRA NIÑEZ',
          colorBadgeBg: PdfColor.fromInt(0xFF00E5FF),
          colorBadgeText: PdfColor.fromInt(0xFF0B0F19),
          colorDarkCard: PdfColor.fromInt(0xFF0B0F19), // Obsidian Space
          colorPillBg: PdfColor.fromInt(0xFF1E293B),
          colorAnillo: PdfColor.fromInt(0xFF00E5FF), // Resplandor cian neón
          colorSosButton: PdfColor.fromInt(0xFFEA580C), // Naranja Neón brillante de alto contraste
          tituloCadete: 'CADETE DE EMERGENCIA',
          paso1: 'Mantén la calma y no te alejes del lugar seguro.',
          paso2: 'Muestra este carnet a un Policía o Serenazgo.',
          paso3: 'Pide que escaneen tu código QR para avisar a tus papás.',
          paso4: 'Espera en un lugar visible a que vengan por ti.',
        );
      }
    } else if (f.edad >= 12 && f.edad <= 17) {
      // 🧑 PERFIL JUVENIL (12-17 AÑOS): Estilo credencial estudiantil moderna cyberpunk/instagram
      return CarnetThemeConfig(
        tipo: CarnetTipoEstilo.juvenil,
        tipoPerfil: 'JUVENIL (12-17 AÑOS)',
        subtituloBanner: 'Red de Seguridad Preventiva Estudiantil y Juvenil - Alerta Perú',
        tituloAnverso: 'CREDENCIAL JUVENIL DE SEGURIDAD',
        badgeAnverso: 'ID ESTUDIANTIL DIGITAL',
        tituloReverso: 'ENLACE RÁPIDO DE AUXILIO Y CONTACTO SOS',
        instruccionPortador: 'PROTOCOLO: En caso de desorientación, pérdida de transporte o riesgo, active este carnet o comuníquese de inmediato a los números familiares.',
        instruccionAuxilio: 'SI EL JOVEN REQUIERE ASISTENCIA O AUXILIO URGENTE:\n1. Escanee el código QR con su teléfono para enlazar llamada directa con sus apoderados.\n2. Contacte a la central PNP 105 si sospecha riesgo delictivo.',
        guiaTitulo: 'GUÍA JUVENIL: CREDENCIAL PREVENTIVA PARA MOCHILA O FOTOCHECK',
        guiaPaso1: 'Diseño moderno tipo credencial estudiantil para portar cómodamente en la billetera o mochila sin sentir vergüenza.',
        guiaPaso2: 'Ideal para traslados al colegio, academias, eventos masivos o transporte público.',
        guiaPaso3: 'Permite contacto de auxilio sin exponer públicamente el número personal del menor a desconocidos.',
        colorPrimario: PdfColors.indigo900,
        colorSecundario: PdfColors.blueGrey900,
        colorAcento: PdfColors.cyan300,
        colorBorde: PdfColors.indigo700,
        colorFondoBanda: PdfColors.indigo50,
        colorFondoTarjeta: PdfColor.fromInt(0xFF0F172A), // Fondo dark slate obsidian
        lemaDecorativo: 'ID ESTUDIANTIL DIGITAL',
        colorBadgeBg: PdfColors.cyan700,
        colorBadgeText: PdfColors.white,
        colorDarkCard: PdfColor.fromInt(0xFF0F172A), // Obsidian cyberpunk
        colorPillBg: PdfColor.fromInt(0xFF1E1B4B),
        colorAnillo: PdfColor.fromInt(0xFFEC4899), // Anillo neón magenta
        colorSosButton: PdfColor.fromInt(0xFFEA580C),
        tituloCadete: 'CADETE ESTUDIANTIL',
        paso1: 'Mantén la calma y permanece en un punto iluminado.',
        paso2: 'Muestra tu carnet estudiantil ante autoridades policiales.',
        paso3: 'Permite que escaneen el código QR con cualquier teléfono.',
        paso4: 'Comunícate de inmediato a la Central 105 o números familiares.',
      );
    } else {
      // 👨‍🦳 PERFIL ADULTO / SENIOR: Sobrio, institucional, énfasis en datos médicos
      return CarnetThemeConfig(
        tipo: CarnetTipoEstilo.adulto,
        tipoPerfil: 'CIUDADANO (ADULTO / SENIOR)',
        subtituloBanner: 'Sistema Preventivo Familiar y Asistencia Médica - PNP Alerta',
        tituloAnverso: 'CREDENCIAL CIUDADANA DE IDENTIFICACIÓN',
        badgeAnverso: 'AUXILIO SOS',
        tituloReverso: 'FICHA MÉDICA PREVENTIVA Y CONTACTO DE URGENCIA',
        instruccionPortador: 'INSTRUCCIÓN: Si la persona se encuentra desorientada o requiere asistencia médica, comuníquese de inmediato con sus contactos de emergencia.',
        instruccionAuxilio: 'SI ENCUENTRA A ESTA PERSONA DESORIENTADA O EN EMERGENCIA:\n1. Escanee el código QR con su celular para llamar a sus familiares directos.\n2. Si requiere atención médica, revise los datos de sangre y medicación impresos.',
        guiaTitulo: 'GUÍA FAMILIAR: IDENTIFICACIÓN PREVENTIVA PARA ADULTOS Y ADULTOS MAYORES',
        guiaPaso1: 'Indispensable para adultos mayores con pérdidas de memoria, pacientes con medicación crítica o emergencias en vía pública.',
        guiaPaso2: 'Portar siempre en la billetera o bolsillo delantero para rápida visualización por socorristas o policías.',
        guiaPaso3: 'Facilita a las autoridades identificar y atender a la persona en los primeros minutos de desorientación.',
        colorPrimario: PdfColors.blue900,
        colorSecundario: PdfColors.blueGrey900,
        colorAcento: PdfColors.amber300,
        colorBorde: PdfColors.blueGrey700,
        colorFondoBanda: PdfColors.blue50,
        colorFondoTarjeta: PdfColors.white, // Fondo formal blanco
        lemaDecorativo: 'CREDENCIAL CIUDADANA SOS',
        colorBadgeBg: PdfColors.amber400,
        colorBadgeText: PdfColors.blue900,
        colorDarkCard: PdfColor.fromInt(0xFF0A192F), // Navy formal ejecutivo
        colorPillBg: PdfColor.fromInt(0xFF172554),
        colorAnillo: PdfColor.fromInt(0xFFF59E0B), // Anillo dorado ejecutivo
        colorSosButton: PdfColor.fromInt(0xFFEA580C),
        tituloCadete: 'CREDENCIAL CIUDADANA',
        paso1: 'Mantén la calma y permanece en un punto seguro de referencia.',
        paso2: 'Presenta esta credencial médica a personal de auxilio.',
        paso3: 'Escanea el QR para alertar a los contactos de emergencia.',
        paso4: 'Brinda asistencia médica según el grupo y condición impresos.',
      );
    }
  }
}
