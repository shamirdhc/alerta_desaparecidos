import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../../domain/entities/tutorial.dart';

class PdfViewerScreen extends StatefulWidget {
  final Tutorial tutorial;

  const PdfViewerScreen({
    super.key,
    required this.tutorial,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _sharePdf() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar el archivo PDF desde assets
      final ByteData data = await rootBundle.load('assets/tutorial_policia/${widget.tutorial.fileName}');
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Obtener directorio temporal
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = widget.tutorial.fileName;
      final File tempFile = File('${tempDir.path}/$fileName');
      
      // Escribir el archivo temporal
      await tempFile.writeAsBytes(bytes);
      
      // Compartir el archivo
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'Protocolo Policial: ${widget.tutorial.title}',
        subject: 'Protocolo PNP - ${widget.tutorial.title}',
      );
      
      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(FontAwesomeIcons.check, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('PDF compartido exitosamente'),
              ],
            ),
            backgroundColor: const Color(0xFF415A77),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(FontAwesomeIcons.exclamationTriangle, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Error al compartir: ${e.toString()}'),
              ],
            ),
            backgroundColor: const Color(0xFFFF6B35),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadPdf() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar el archivo PDF desde assets
      final ByteData data = await rootBundle.load('assets/tutorial_policia/${widget.tutorial.fileName}');
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Obtener directorio de descargas
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }
      
      if (downloadsDir != null) {
        final String fileName = widget.tutorial.fileName;
        final File downloadFile = File('${downloadsDir.path}/$fileName');
        
        // Escribir el archivo
        await downloadFile.writeAsBytes(bytes);
        
        // Mostrar mensaje de éxito
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(FontAwesomeIcons.download, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('PDF descargado exitosamente'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ubicación: ${downloadFile.path}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF415A77),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(FontAwesomeIcons.exclamationTriangle, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Error al descargar: ${e.toString()}'),
              ],
            ),
            backgroundColor: const Color(0xFFFF6B35),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF415A77)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            _buildPoliceAppBar(),
            _buildInfoBar(),
            _buildActionButtons(),
            Expanded(
              child: _buildPdfViewer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: FontAwesomeIcons.share,
              label: 'COMPARTIR',
              onTap: _isLoading ? null : _sharePdf,
              gradient: const LinearGradient(
                colors: [Color(0xFF415A77), Color(0xFF778DA9)],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: FontAwesomeIcons.download,
              label: 'DESCARGAR',
              onTap: _isLoading ? null : _downloadPdf,
              gradient: const LinearGradient(
                colors: [Color(0xFF0D7377), Color(0xFF14A085)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required Gradient gradient,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          gradient: onTap != null ? gradient : LinearGradient(
            colors: [Colors.grey.shade600, Colors.grey.shade700],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(
                icon,
                color: Colors.white,
                size: 16,
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoliceAppBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 15,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF415A77), Color(0xFF778DA9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                FontAwesomeIcons.arrowLeft,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROTOCOLO POLICIAL',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.tutorial.title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_totalPages > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: widget.tutorial.isRequired
                    ? const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF415A77), Color(0xFF778DA9)],
                      ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    FontAwesomeIcons.fileLines,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_currentPage / $_totalPages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: widget.tutorial.isRequired
            ? const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF415A77), Color(0xFF778DA9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.tutorial.isRequired 
                  ? FontAwesomeIcons.exclamationTriangle
                  : FontAwesomeIcons.infoCircle,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tutorial.isRequired 
                      ? 'PROTOCOLO OBLIGATORIO'
                      : 'PROTOCOLO INFORMATIVO',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.tutorial.isRequired 
                      ? 'Lectura requerida para todo el personal PNP'
                      : 'Tiempo estimado: ${widget.tutorial.estimatedReadTime} minutos',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: PdfViewer.asset(
          'assets/tutorial_policia/${widget.tutorial.fileName}',
          params: PdfViewerParams(
            onPageChanged: (pageNumber) {
              setState(() {
                _currentPage = pageNumber ?? 1;
              });
            },
            onDocumentChanged: (document) {
              if (document != null) {
                setState(() {
                  _totalPages = document.pages.length;
                });
              }
            },
            loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
              return Container(
                color: const Color(0xFF0D1B2A),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF778DA9)),
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'CARGANDO PROTOCOLO...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF778DA9),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}