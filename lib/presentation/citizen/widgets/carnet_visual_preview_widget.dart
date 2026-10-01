import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:alerta_desaparecidos/services/mi_familia_service.dart';
import 'package:alerta_desaparecidos/services/mi_familia_pdf_service.dart';
import 'package:alerta_desaparecidos/core/utils/platform_file_downloader.dart';

/// Vista previa visual e interactiva del CARNET PREVENTIVO SOS en Flutter nativo.
/// Permite al usuario alternar entre:
/// 1. Formato Horizontal (86mm x 54mm - Billetera / Credencial con anillo de neón circular)
/// 2. Formato Vertical (54mm x 86mm - Portafotocheck de cuello / Lanyard con perforación y pasos 01-04)
/// 3. Hoja Dual A4 (Ambos formatos listos para imprimir y recortar)
class CarnetVisualPreviewWidget extends StatefulWidget {
  final FamiliarProfile familiar;
  final VoidCallback? onCompartir;
  final VoidCallback? onDescargar;
  final CarnetOrientacion inicialOrientacion;

  const CarnetVisualPreviewWidget({
    super.key,
    required this.familiar,
    this.onCompartir,
    this.onDescargar,
    this.inicialOrientacion = CarnetOrientacion.horizontal,
  });

  @override
  State<CarnetVisualPreviewWidget> createState() => _CarnetVisualPreviewWidgetState();
}

class _CarnetVisualPreviewWidgetState extends State<CarnetVisualPreviewWidget> {
  late CarnetOrientacion _orientacion;

  @override
  void initState() {
    super.initState();
    _orientacion = widget.inicialOrientacion;
  }

  Future<void> _descargarPdf(CarnetOrientacion orientacion) async {
    try {
      final bytes = await MiFamiliaPdfService.construirCarnetBytes(widget.familiar, orientacion: orientacion);
      final sufijo = orientacion == CarnetOrientacion.horizontal
          ? 'Horizontal'
          : (orientacion == CarnetOrientacion.vertical ? 'Vertical_Cuello' : 'Dual_A4');
      final filename = 'Carnet_SOS_${widget.familiar.nombreCompleto.replaceAll(' ', '_')}_$sufijo.pdf';
      await PlatformFileDownloader.downloadPdf(bytes: bytes, filename: filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Carnet PDF ($sufijo) descargado exitosamente'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar: $e')),
        );
      }
    }
  }

  Future<void> _compartirPdf(CarnetOrientacion orientacion) async {
    try {
      final bytes = await MiFamiliaPdfService.construirCarnetBytes(widget.familiar, orientacion: orientacion);
      final sufijo = orientacion == CarnetOrientacion.horizontal
          ? 'Horizontal'
          : (orientacion == CarnetOrientacion.vertical ? 'Vertical_Cuello' : 'Dual_A4');
      final filename = 'Carnet_SOS_${widget.familiar.nombreCompleto.replaceAll(' ', '_')}_$sufijo.pdf';
      await PlatformFileDownloader.sharePdf(
        bytes: bytes,
        filename: filename,
        subject: 'CARNET SOS: ${widget.familiar.nombreCompleto}',
        text: 'Credencial preventiva de auxilio para ${widget.familiar.nombreCompleto}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final familiar = widget.familiar;
    final bool esNino = familiar.edad < 12;
    final bool esJoven = familiar.edad >= 12 && familiar.edad < 18;

    // Configuración estética
    final Color colorPrimario = esNino
        ? const Color(0xFF0284C7)
        : (esJoven ? const Color(0xFF4F46E5) : const Color(0xFF1E3A8A));

    final Color colorAcento = esNino
        ? const Color(0xFFFBBF24)
        : (esJoven ? const Color(0xFF06B6D4) : const Color(0xFFF59E0B));

    final String badgePerfil = esNino
        ? '⭐ SUPER PROTEGIDO'
        : (esJoven ? 'ID ESTUDIANTIL DIGITAL' : 'CREDENCIAL MÉDICA SOS');

    final String tituloAnverso = esNino
        ? '⭐ CARNET INFANTIL DE AUXILIO ⭐'
        : (esJoven ? 'CREDENCIAL JUVENIL DE SEGURIDAD' : 'CREDENCIAL CIUDADANA DE IDENTIFICACIÓN');

    final telSanitized = familiar.telefonoContacto.replaceAll(RegExp(r'[^0-9]'), '');
    final waNumber = telSanitized.length == 9 ? '51$telSanitized' : telSanitized;
    final qrData = telSanitized.isNotEmpty
        ? 'https://wa.me/$waNumber?text=${Uri.encodeComponent('🚨 AUXILIO SOS: He encontrado a ${familiar.nombreCompleto} quien porta este Carnet de Identificación y Auxilio. Por favor comunicarse urgente a este teléfono.')}'
        : 'CREDENCIAL DE AUXILIO PNP ALERTA\nNombre: ${familiar.nombreCompleto}\nEdad: ${familiar.edad} anos\nCondicion: ${familiar.condicionEspecial}\nCentral PNP: 105 - Linea 114';

    ImageProvider? fotoProvider;
    if (familiar.fotoBase64 != null && familiar.fotoBase64!.isNotEmpty) {
      try {
        fotoProvider = MemoryImage(base64Decode(familiar.fotoBase64!));
      } catch (_) {}
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorPrimario.withOpacity(0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // ================= CABECERA INSTITUCIONAL CON LOGO =================
              Container(
                decoration: BoxDecoration(
                  color: colorPrimario,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  gradient: LinearGradient(
                    colors: esNino
                        ? [const Color(0xFF0284C7), const Color(0xFF38BDF8), const Color(0xFF06B6D4)]
                        : (esJoven
                            ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B), const Color(0xFF4F46E5)]
                            : [const Color(0xFF0A192F), const Color(0xFF1E3A8A), const Color(0xFF1E40AF)]),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
                        ],
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: Image.asset('assets/icons/icon_police.png', fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tituloAnverso,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          Text(
                            esNino
                                ? 'Credencial Infantil de Auxilio y Protección'
                                : (esJoven
                                    ? 'Red Preventiva Estudiantil y Juvenil'
                                    : 'Credencial Preventiva de Auxilio Ciudadano'),
                            style: const TextStyle(fontSize: 9.5, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgePerfil,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: colorPrimario,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ================= SELECTOR DE FORMATO (HORIZONTAL / VERTICAL / AMBOS) =================
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSelectorTab(
                        label: 'Horizontal (Billetera)',
                        icon: Icons.credit_card_rounded,
                        active: _orientacion == CarnetOrientacion.horizontal,
                        onTap: () => setState(() => _orientacion = CarnetOrientacion.horizontal),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildSelectorTab(
                        label: 'Vertical (Lanyard)',
                        icon: Icons.badge_rounded,
                        active: _orientacion == CarnetOrientacion.vertical,
                        onTap: () => setState(() => _orientacion = CarnetOrientacion.vertical),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildSelectorTab(
                        label: 'Hoja Dual A4',
                        icon: Icons.print_rounded,
                        active: _orientacion == CarnetOrientacion.ambas,
                        onTap: () => setState(() => _orientacion = CarnetOrientacion.ambas),
                      ),
                    ),
                  ],
                ),
              ),

              // ================= CONTENIDO VISUAL SEGÚN EL FORMATO SELECCIONADO =================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    if (_orientacion == CarnetOrientacion.horizontal) ...[
                      _buildBannerGuia('FORMATO HORIZONTAL (86mm x 54mm) - TAMAÑO ESTÁNDAR BILLETERA'),
                      const SizedBox(height: 10),
                      _buildHorizontalAnversoWidget(familiar, fotoProvider, esNino, esJoven, colorPrimario, colorAcento),
                      const SizedBox(height: 12),
                      _buildHorizontalReversoWidget(familiar, qrData, esNino, esJoven, colorPrimario, colorAcento),
                    ] else if (_orientacion == CarnetOrientacion.vertical) ...[
                      _buildBannerGuia('FORMATO VERTICAL (54mm x 86mm) - PORTAFOTOCHECK DE CUELLO / LANYARD'),
                      const SizedBox(height: 10),
                      _buildVerticalAnversoWidget(familiar, fotoProvider, qrData, esNino, esJoven, colorPrimario, colorAcento),
                      const SizedBox(height: 12),
                      _buildVerticalReversoWidget(familiar, esNino, esJoven, colorPrimario, colorAcento),
                    ] else ...[
                      _buildBannerGuia('HOJA DUAL A4 - INCLUYE AMBOS TAMAÑOS LISTOS PARA IMPRIMIR Y RECORTAR'),
                      const SizedBox(height: 10),
                      // Vista combinada
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Opción 1: Credencial Horizontal (Billetera / Mochila)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E3A8A)),
                            ),
                            const SizedBox(height: 8),
                            _buildHorizontalAnversoWidget(familiar, fotoProvider, esNino, esJoven, colorPrimario, colorAcento),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(color: Colors.grey, thickness: 1),
                            ),
                            const Text(
                              'Opción 2: Portafotocheck Vertical (Cinta al Cuello / Lanyard)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E3A8A)),
                            ),
                            const SizedBox(height: 8),
                            _buildVerticalAnversoWidget(familiar, fotoProvider, qrData, esNino, esJoven, colorPrimario, colorAcento),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ================= ACCIONES DE DESCARGA Y COMPARTIR =================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Botón Compartir
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _compartirPdf(_orientacion),
                            icon: const Icon(Icons.share_rounded, size: 16, color: Color(0xFF25D366)),
                            label: const Text(
                              'Compartir PDF',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF065F46)),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Botón Descargar Formato Seleccionado
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _descargarPdf(_orientacion),
                            icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                            label: Text(
                              _orientacion == CarnetOrientacion.ambas ? 'Descargar Kit Dual A4' : 'Descargar PDF',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorPrimario,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_orientacion != CarnetOrientacion.ambas) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _descargarPdf(CarnetOrientacion.ambas),
                        icon: const Icon(Icons.print_rounded, size: 15, color: Color(0xFF1E40AF)),
                        label: const Text(
                          'Descargar Hoja A4 con Ambos Formatos para Imprimir',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorTab({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: active ? const Color(0xFF1E40AF) : Colors.grey.shade600),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                  color: active ? const Color(0xFF1E40AF) : Colors.grey.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerGuia(String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        '✂️ $texto',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
      ),
    );
  }

  // =========================================================================
  // WIDGET: FORMATO HORIZONTAL (Inspirado en la Imagen de Referencia 2)
  // =========================================================================

  Widget _buildHorizontalAnversoWidget(
    FamiliarProfile familiar,
    ImageProvider? fotoProvider,
    bool esNino,
    bool esJoven,
    Color colorPrimario,
    Color colorAcento,
  ) {
    final Color cardBg = esNino
        ? const Color(0xFF0C4A6E)
        : (esJoven ? const Color(0xFF0F172A) : const Color(0xFF0A192F));

    final Color ringColor = esNino
        ? const Color(0xFF38BDF8)
        : (esJoven ? const Color(0xFFEC4899) : const Color(0xFFF59E0B));

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 460),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorAcento.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Barra superior con Logo Policial y URL limpia
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      child: ClipOval(child: Image.asset('assets/icons/icon_police.png', fit: BoxFit.contain)),
                    ),
                    const SizedBox(width: 6),
                    const Text('PNP ALERTA - IDENTIFICACIÓN SOS', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(color: colorAcento, borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    esNino ? 'SUPER PROTEGIDO' : (esJoven ? 'ID DIGITAL' : 'CREDENCIAL SOS'),
                    style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),

          // Cuerpo de la credencial: Foto circular con anillo vibrante y datos
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Anillo de neón con foto circular (Estilo Imagen 2)
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: esJoven
                        ? const SweepGradient(
                            colors: [
                              Color(0xFFEC4899),
                              Color(0xFF8B5CF6),
                              Color(0xFF06B6D4),
                              Color(0xFFF59E0B),
                              Color(0xFFEC4899),
                            ],
                          )
                        : null,
                    border: !esJoven ? Border.all(color: ringColor, width: 3) : null,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: fotoProvider != null
                          ? Image(image: fotoProvider, fit: BoxFit.cover)
                          : const Icon(Icons.person_rounded, size: 40, color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Datos de la persona
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        familiar.nombreCompleto.toUpperCase(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${familiar.parentesco.toUpperCase()} - ${familiar.edad} AÑOS',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorAcento),
                      ),
                      if (familiar.dni.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('DNI: ${familiar.dni}', style: const TextStyle(fontSize: 9.5, color: Colors.white70)),
                      ],
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              'RH: ${familiar.tipoSangre.isNotEmpty ? familiar.tipoSangre : "O+"}',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
                          if (familiar.condicionEspecial.isNotEmpty && familiar.condicionEspecial != 'Ninguna') ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                familiar.condicionEspecial,
                                style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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

          // Teléfono de contacto familiar destacado
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF064E3B),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF10B981), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone_in_talk_rounded, size: 12, color: Color(0xFF34D399)),
                const SizedBox(width: 6),
                Text(
                  'AVISAR URGENTE AL FAMILIAR: ${familiar.telefonoContacto}',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Barra inferior con Iconos de Seguridad y URL limpia (Estilo Imagen 2)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.home_rounded, size: 12, color: Colors.white54),
                    SizedBox(width: 8),
                    Icon(Icons.search_rounded, size: 12, color: Colors.white54),
                    SizedBox(width: 8),
                    Icon(Icons.favorite_rounded, size: 12, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Icon(Icons.shield_rounded, size: 12, color: Colors.cyanAccent),
                  ],
                ),
                const Text(
                  'pnpalerta.web.app',
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF67E8F9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalReversoWidget(
    FamiliarProfile familiar,
    String qrData,
    bool esNino,
    bool esJoven,
    Color colorPrimario,
    Color colorAcento,
  ) {
    final Color cardBg = esNino
        ? const Color(0xFF0C4A6E)
        : (esJoven ? const Color(0xFF0F172A) : const Color(0xFF0A192F));

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 460),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade700, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('CANAL DE CONTACTO SOS RÁPIDO', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('WHATSAPP INMEDIATO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF34D399))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // QR
                Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorAcento, width: 1.5),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 72,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EN CASO DE EXTRAVÍO O AUXILIO:',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFFFBBF24)),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Escanea el QR con la cámara de cualquier teléfono para abrir WhatsApp directo con la familia del portador.',
                        style: TextStyle(fontSize: 8.5, color: Colors.white, height: 1.2),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: const [
                          Icon(Icons.local_police_rounded, size: 12, color: Colors.cyanAccent),
                          SizedBox(width: 4),
                          Text('POLICÍA: 105', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                          SizedBox(width: 8),
                          Text('LÍNEA: 114', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: const BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('EMERGENCIAS NACIONALES: 105', style: TextStyle(fontSize: 8, color: Colors.white60)),
                Text('pnpalerta.web.app', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF67E8F9))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // WIDGET: FORMATO VERTICAL (Inspirado en la Imagen de Referencia 1)
  // Con perforación superior para lanyard y pasos numerados 01-04
  // =========================================================================

  Widget _buildVerticalAnversoWidget(
    FamiliarProfile familiar,
    ImageProvider? fotoProvider,
    String qrData,
    bool esNino,
    bool esJoven,
    Color colorPrimario,
    Color colorAcento,
  ) {
    final Color cardBg = esNino
        ? const Color(0xFF0C4A6E)
        : (esJoven ? const Color(0xFF0F172A) : const Color(0xFF0A192F));

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorAcento.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          // 1. Perforación superior para cinta/lanyard (Estilo Imagen 1)
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 32,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade400, width: 1),
            ),
          ),

          // 2. Cabecera geométrica
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: Colors.black26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: ClipOval(child: Image.asset('assets/icons/icon_police.png', fit: BoxFit.contain)),
                ),
                const SizedBox(width: 6),
                const Text('PNP ALERTA DESAPARECIDOS', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 3. Foto enmarcada central con sombra/borde blanco (Estilo Imagen 1)
          Container(
            width: 86,
            height: 98,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 3)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: fotoProvider != null
                  ? Image(image: fotoProvider, fit: BoxFit.cover)
                  : const Icon(Icons.person_rounded, size: 54, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),

          // 4. Nombre en pastilla redondeada oscura (Estilo "YOUR NAME" Imagen 1)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24, width: 0.8),
            ),
            child: Text(
              familiar.nombreCompleto.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
              maxLines: 2,
            ),
          ),
          const SizedBox(height: 4),

          // 5. Pastilla de Rol / Parentesco
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: colorAcento,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${familiar.parentesco.toUpperCase()} - ${familiar.edad} AÑOS',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black),
            ),
          ),
          const SizedBox(height: 6),

          // Teléfono de aviso
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF065F46),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'AVISAR: ${familiar.telefonoContacto}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),

          const SizedBox(height: 8),

          // 6. Base con mini QR, RH y DNI
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: QrImageView(data: qrData, size: 40, padding: EdgeInsets.zero),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(3)),
                        child: Text(
                          'RH: ${familiar.tipoSangre.isNotEmpty ? familiar.tipoSangre : "O+"}',
                          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                      if (familiar.dni.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text('DNI: ${familiar.dni}', style: const TextStyle(fontSize: 8, color: Colors.white70)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Franja inferior con URL limpia
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: const BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: const Text(
              'pnpalerta.web.app',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF67E8F9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalReversoWidget(
    FamiliarProfile familiar,
    bool esNino,
    bool esJoven,
    Color colorPrimario,
    Color colorAcento,
  ) {
    final Color cardBg = esNino
        ? const Color(0xFF0C4A6E)
        : (esJoven ? const Color(0xFF0F172A) : const Color(0xFF0A192F));

    final pasos = [
      esNino ? 'Mantén la calma y no te alejes del lugar seguro.' : 'Mantén la calma y permanece en un punto seguro de referencia.',
      'Muestra este carnet a un Policía Nacional o Serenazgo.',
      'Permite que escaneen el código QR con cualquier celular.',
      'Comunícate de inmediato a la Central 105 o al teléfono impreso.',
    ];

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade700, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          // Perforación coincidente
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 32,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade400, width: 1),
            ),
          ),

          // Pastilla Instrucciones SOS (Estilo Imagen 1 reverso)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorAcento.withOpacity(0.6)),
            ),
            child: const Text('INSTRUCCIONES SOS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(height: 6),

          // Pasos numerados 01, 02, 03, 04 (Idéntico a la Imagen de Referencia 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                for (int i = 0; i < pasos.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorAcento,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '0${i + 1}',
                            style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.black),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pasos[i],
                            style: const TextStyle(fontSize: 8.5, color: Colors.white, height: 1.2),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          if (familiar.datosMedicos.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: const Color(0xFF7F1D1D), borderRadius: BorderRadius.circular(5)),
              child: Text(
                'MÉDICO: ${familiar.datosMedicos}',
                style: const TextStyle(fontSize: 8, color: Colors.white),
                maxLines: 2,
              ),
            ),
          ],

          const SizedBox(height: 6),

          // Centrales oficiales
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(6)),
            child: Column(
              children: [
                const Text('CENTRAL PNP: 105 | LÍNEA: 114', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('FAMILIA: ${familiar.telefonoContacto}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24))),
              ],
            ),
          ),

          // Franja inferior con URL limpia
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: const BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: const Text(
              'pnpalerta.web.app',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF67E8F9)),
            ),
          ),
        ],
      ),
    );
  }
}
