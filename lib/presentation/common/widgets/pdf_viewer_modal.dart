import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:alerta_desaparecidos/presentation/common/widgets/branded_loading_dialog.dart';
import 'package:alerta_desaparecidos/core/utils/platform_file_downloader.dart';

/// Modal interactivo in-app para visualizar, descargar y compartir PDFs en Web, Android, iOS y Desktop
class PdfViewerModal extends StatefulWidget {
  final String title;
  final Uint8List? pdfBytes;
  final Future<Uint8List> Function()? docGenerator;
  final String filename;
  final IconData icon;
  final Widget Function(BuildContext context, VoidCallback onCompartir, VoidCallback onDescargar)? visualPreviewBuilder;

  const PdfViewerModal({
    super.key,
    required this.title,
    this.pdfBytes,
    this.docGenerator,
    required this.filename,
    this.icon = Icons.picture_as_pdf_rounded,
    this.visualPreviewBuilder,
  }) : assert(pdfBytes != null || docGenerator != null, 'Debe proveer pdfBytes o docGenerator');

  static Future<void> mostrar(
    BuildContext context, {
    required String title,
    Uint8List? pdfBytes,
    Future<Uint8List> Function()? docGenerator,
    required String filename,
    IconData icon = Icons.picture_as_pdf_rounded,
    Widget Function(BuildContext context, VoidCallback onCompartir, VoidCallback onDescargar)? visualPreviewBuilder,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => PdfViewerModal(
        title: title,
        pdfBytes: pdfBytes,
        docGenerator: docGenerator,
        filename: filename,
        icon: icon,
        visualPreviewBuilder: visualPreviewBuilder,
      ),
    );
  }

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    Uint8List? pdfBytes,
    Future<Uint8List> Function()? docGenerator,
    required String filename,
    IconData icon = Icons.picture_as_pdf_rounded,
    Widget Function(BuildContext context, VoidCallback onCompartir, VoidCallback onDescargar)? visualPreviewBuilder,
  }) => mostrar(
    context,
    title: title,
    pdfBytes: pdfBytes,
    docGenerator: docGenerator,
    filename: filename,
    icon: icon,
    visualPreviewBuilder: visualPreviewBuilder,
  );


  @override
  State<PdfViewerModal> createState() => _PdfViewerModalState();
}

class _PdfViewerModalState extends State<PdfViewerModal> {
  Uint8List? _cachedBytes;
  bool _mostrarVistaVisual = true;

  @override
  void initState() {
    super.initState();
    _cachedBytes = widget.pdfBytes;
    // Si no hay visualPreviewBuilder, comenzamos en vista de documento PDF
    if (widget.visualPreviewBuilder == null) {
      _mostrarVistaVisual = false;
    }
  }

  Future<Uint8List> _resolveBytes() async {
    if (_cachedBytes != null) return _cachedBytes!;
    if (widget.docGenerator != null) {
      final bytes = await widget.docGenerator!();
      _cachedBytes = bytes;
      return bytes;
    }
    throw Exception('No hay bytes disponibles para renderizar el PDF');
  }

  Future<void> _descargarOGuardar(BuildContext context) async {
    try {
      final bytes = await _resolveBytes();
      await PlatformFileDownloader.downloadPdf(
        bytes: bytes,
        filename: widget.filename,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Documento PDF descargado exitosamente')),
              ],
            ),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Aviso al descargar PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo descargar el archivo: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _compartirNativo(BuildContext context) async {
    try {
      final bytes = await _resolveBytes();
      final success = await PlatformFileDownloader.sharePdf(
        bytes: bytes,
        filename: widget.filename,
        subject: widget.title,
        text: 'Documento preventivo de seguridad: ${widget.title}',
      );
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Documento PDF descargado en tu dispositivo. Puedes adjuntarlo por WhatsApp a tus contactos.',
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF1E40AF),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Aviso al compartir PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aviso: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildFallbackCard(BuildContext context, Object error) {
    if (widget.visualPreviewBuilder != null) {
      return widget.visualPreviewBuilder!(
        context,
        () => _compartirNativo(context),
        () => _descargarOGuardar(context),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF1E40AF).withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF1E40AF),
                ),
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: Image.asset('assets/icons/icon_police.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '¡${widget.title} Generado!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'El documento oficial en alta resolución (${widget.filename}) está listo con foto y código QR de auxilio.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _compartirNativo(context),
                  icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                  label: const Text('Compartir PDF por WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _descargarOGuardar(context),
                  icon: const Icon(Icons.download_rounded, color: Color(0xFF0284C7), size: 18),
                  label: const Text('Descargar Archivo PDF', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 900,
          height: MediaQuery.of(context).size.height * 0.94,
          child: Scaffold(
            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            appBar: AppBar(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              elevation: 1,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Cerrar Visor',
              ),
              title: Row(
                children: [
                  Icon(widget.icon, size: 22, color: const Color(0xFF0284C7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                // Selector de modo si está disponible la vista previa visual
                if (widget.visualPreviewBuilder != null)
                  IconButton(
                    icon: Icon(
                      _mostrarVistaVisual ? Icons.picture_as_pdf_rounded : Icons.visibility_rounded,
                      color: const Color(0xFF0284C7),
                    ),
                    tooltip: _mostrarVistaVisual ? 'Ver Hoja PDF' : 'Ver Vista Previa Interactiva',
                    onPressed: () {
                      setState(() {
                        _mostrarVistaVisual = !_mostrarVistaVisual;
                      });
                    },
                  ),
                // Botón Compartir
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366)),
                  tooltip: 'Compartir PDF',
                  onPressed: () => _compartirNativo(context),
                ),
                // Botón Descargar
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Color(0xFFD97706)),
                  tooltip: 'Descargar / Guardar PDF',
                  onPressed: () => _descargarOGuardar(context),
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: _mostrarVistaVisual && widget.visualPreviewBuilder != null
                ? widget.visualPreviewBuilder!(
                    context,
                    () => _compartirNativo(context),
                    () => _descargarOGuardar(context),
                  )
                : PdfPreview(
                    build: (format) async => await _resolveBytes(),
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    allowPrinting: false,
                    allowSharing: false,
                    pdfFileName: widget.filename,
                    loadingWidget: Center(
                      child: BrandedLoadingWidget(
                        message: 'Generando documento oficial...',
                        submessage: 'Optimizando formato de alta resolución y código QR',
                        size: 64,
                      ),
                    ),
                    onError: (ctx, error) {
                      return _buildFallbackCard(context, error);
                    },
                    scrollViewDecoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0B1120) : const Color(0xFFE2E8F0),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
