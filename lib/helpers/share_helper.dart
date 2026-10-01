import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareHelper {
  /// Comparte directamente la Nota de Alerta Policial con la imagen oficial y texto estructurado.
  /// En movil y web descarga y adjunta fisicamente el archivo de la imagen.
  /// No comparte el link crudo de la imagen en el texto.
  static Future<void> shareWhatsApp({
    required BuildContext context,
    required String message,
    String? imageUrl,
  }) async {
    const portalUrl = 'https://pnpalerta.web.app';
    final textWithPortal = message.contains(portalUrl)
        ? message
        : '$message\n\n🌐 *Portal Oficial PNP:* $portalUrl';

    // 1. Descargar la imagen de la Nota de Alerta Policial
    XFile? imageFile;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        _showToast(context, 'Preparando Nota de Alerta Policial...', isSuccess: true);
        final response = await http
            .get(Uri.parse(imageUrl))
            .timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          if (kIsWeb) {
            imageFile = XFile.fromData(
              response.bodyBytes,
              name: 'nota_alerta_policial_pnp.jpg',
              mimeType: 'image/jpeg',
            );
          } else {
            final tempDir = await getTemporaryDirectory();
            final file = File(
              '${tempDir.path}/nota_alerta_pnp_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            await file.writeAsBytes(response.bodyBytes);
            imageFile = XFile(
              file.path,
              name: 'nota_alerta_policial_pnp.jpg',
              mimeType: 'image/jpeg',
            );
          }
        }
      } catch (e) {
        debugPrint('Error descargando nota de alerta para WhatsApp: $e');
      }
    }

    // 2. Intentar compartir el archivo fisico de la imagen junto con el texto
    if (imageFile != null) {
      try {
        final result = await Share.shareXFiles(
          [imageFile],
          text: textWithPortal,
        );

        if (!kIsWeb) {
          Future.delayed(const Duration(seconds: 30), () async {
            try {
              final f = File(imageFile!.path);
              if (await f.exists()) await f.delete();
            } catch (_) {}
          });
        }

        if (result.status == ShareResultStatus.success ||
            result.status == ShareResultStatus.dismissed) {
          return;
        }
      } catch (e) {
        debugPrint('Share.shareXFiles no disponible en este entorno: $e');
      }
    }

    // 3. Fallback para WhatsApp en Web (Escritorio PC o navegador sin Web Share API para archivos)
    final textForSharing = (imageUrl != null && imageUrl.isNotEmpty && !textWithPortal.contains(imageUrl))
        ? '$textWithPortal\n\n📷 *Foto / Ficha Oficial:* $imageUrl'
        : textWithPortal;

    if (kIsWeb) {
      final encoded = Uri.encodeComponent(textForSharing);
      final waUrl = 'https://wa.me/?text=$encoded';
      final uri = Uri.parse(waUrl);

      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showToast(context, 'Abriendo WhatsApp con datos del caso...', isSuccess: true);
        return;
      } catch (e) {
        debugPrint('Fallo al abrir enlace de WhatsApp en web: $e');
      }

      await _copyToClipboard(context, textForSharing, isWhatsApp: true);
      return;
    }

    // 4. Fallback con protocolo directo de WhatsApp en movil si shareXFiles no se completo
    final encoded = Uri.encodeComponent(textForSharing);
    try {
      final nativeUri = Uri.parse('whatsapp://send?text=$encoded');
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri);
        _showToast(context, 'Abriendo WhatsApp...', isSuccess: true);
        return;
      }
    } catch (_) {}

    // 5. Fallback estandar de Share
    try {
      await Share.share(textForSharing);
    } catch (_) {
      await _copyToClipboard(context, textForSharing, isWhatsApp: true);
    }
  }

  /// Comparte la alerta en redes sociales (Facebook, Instagram, X, etc.) adjuntando la imagen de la Nota de Alerta Policial.
  static Future<void> shareCase({
    required BuildContext context,
    required String message,
    String? subject,
    String? imageUrl,
  }) async {
    const portalUrl = 'https://pnpalerta.web.app';
    final textWithPortal = message.contains(portalUrl)
        ? message
        : '$message\n\n🌐 *Portal Oficial PNP:* $portalUrl';

    // 1. Descargar la imagen de la Nota de Alerta Policial
    XFile? imageFile;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        _showToast(context, 'Preparando Nota de Alerta oficial...', isSuccess: true);
        final response = await http
            .get(Uri.parse(imageUrl))
            .timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          if (kIsWeb) {
            imageFile = XFile.fromData(
              response.bodyBytes,
              name: 'nota_alerta_policial_pnp.jpg',
              mimeType: 'image/jpeg',
            );
          } else {
            final tempDir = await getTemporaryDirectory();
            final file = File(
              '${tempDir.path}/nota_alerta_pnp_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            await file.writeAsBytes(response.bodyBytes);
            imageFile = XFile(
              file.path,
              name: 'nota_alerta_policial_pnp.jpg',
              mimeType: 'image/jpeg',
            );
          }
        }
      } catch (e) {
        debugPrint('Error descargando imagen para compartir: $e');
      }
    }

    // 2. Compartir el archivo fisico de la imagen junto con el texto
    if (imageFile != null) {
      try {
        final result = await Share.shareXFiles(
          [imageFile],
          text: textWithPortal,
          subject: subject,
        );

        if (!kIsWeb) {
          Future.delayed(const Duration(seconds: 30), () async {
            try {
              final f = File(imageFile!.path);
              if (await f.exists()) await f.delete();
            } catch (_) {}
          });
        }

        if (result.status == ShareResultStatus.success ||
            result.status == ShareResultStatus.dismissed) {
          return;
        }
      } catch (e) {
        debugPrint('Error al compartir archivo en redes: $e');
      }
    }

    // 3. Fallback estandar de Share (con enlace de imagen para preview enriquecido)
    final textForSharing = (imageUrl != null && imageUrl.isNotEmpty && !textWithPortal.contains(imageUrl))
        ? '$textWithPortal\n\n📷 *Foto / Ficha Oficial:* $imageUrl'
        : textWithPortal;

    try {
      final result = await Share.share(
        textForSharing,
        subject: subject,
      );

      if (kIsWeb && result.status != ShareResultStatus.success) {
        await _copyToClipboard(context, textForSharing);
      }
    } catch (e) {
      debugPrint('Share no disponible nativamente: $e. Usando portapapeles.');
      await _copyToClipboard(context, textForSharing);
    }
  }

  static Future<void> _copyToClipboard(
    BuildContext context,
    String text, {
    bool isWhatsApp = false,
  }) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        _showToast(
          context,
          isWhatsApp
              ? '📋 Datos del caso copiados al portapapeles.'
              : '📋 ¡Alerta copiada al portapapeles! Lista para pegar en redes.',
          isSuccess: true,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showToast(context, 'No se pudo copiar la información', isSuccess: false);
      }
    }
  }

  static void _showToast(
    BuildContext context,
    String message, {
    required bool isSuccess,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: duration,
      ),
    );
  }
}
