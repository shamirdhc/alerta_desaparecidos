import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:alerta_desaparecidos/services/mi_familia_service.dart';
import 'package:alerta_desaparecidos/services/mi_familia_pdf_service.dart';
import 'package:alerta_desaparecidos/core/utils/platform_file_downloader.dart';
import 'package:alerta_desaparecidos/presentation/common/widgets/branded_loading_dialog.dart';

/// Vista previa visual e interactiva del CARNET PREVENTIVO ESCUDO SOS en Flutter nativo.
/// Permite al usuario alternar entre:
/// 1. Formato Horizontal (86mm x 54mm - Billetera / Credencial con anillo de neón circular)
/// 2. Formato Vertical (65mm x 95mm - Portafotocheck de cuello / Lanyard con perforación y pasos 01-03)
/// 3. Hoja Dual A4 (Ambos formatos listos para imprimir y recortar)
///
/// Además permite alternar el estilo etario/género:
/// - 👦 Cadete Espacial (Niño - Neón Cian Eléctrico y Obsidian Space)
/// - 👧 Cadete Espacial (Niña - Rose Gold, Rosa Neón y Borgoña Cósmico)
/// - 🏛️ Credencial Ciudadana / Juvenil
class CarnetVisualPreviewWidget extends StatefulWidget {
  final FamiliarProfile familiar;
  final VoidCallback? onCompartir;
  final VoidCallback? onDescargar;
  final CarnetOrientacion inicialOrientacion;
  final String? inicialEstilo;

  const CarnetVisualPreviewWidget({
    super.key,
    required this.familiar,
    this.onCompartir,
    this.onDescargar,
    this.inicialOrientacion = CarnetOrientacion.vertical,
    this.inicialEstilo,
  });

  @override
  State<CarnetVisualPreviewWidget> createState() => _CarnetVisualPreviewWidgetState();
}

class _CarnetVisualPreviewWidgetState extends State<CarnetVisualPreviewWidget> {
  late CarnetOrientacion _orientacion;
  late String _estiloActual; // 'auto', 'nino', 'nina'

  @override
  void initState() {
    super.initState();
    _orientacion = widget.inicialOrientacion;
    _estiloActual = widget.inicialEstilo ?? widget.familiar.estiloCarnet;
  }

  bool get _esFemenina {
    if (_estiloActual == 'nina') return true;
    if (_estiloActual == 'nino') return false;
    return widget.familiar.esFemenino;
  }

  Future<void> _descargarPdf(CarnetOrientacion orientacion) async {
    BrandedLoadingOverlay.show(
      context,
      message: 'Generando Carnet SOS...',
      submessage: 'Preparando archivo PDF de alta resolución listo para imprimir',
    );
    try {
      final bytes = await MiFamiliaPdfService.construirCarnetBytes(
        widget.familiar,
        orientacion: orientacion,
        estiloOverride: _estiloActual,
      );
      final sufijo = orientacion == CarnetOrientacion.horizontal
          ? 'Horizontal_Billetera'
          : (orientacion == CarnetOrientacion.vertical ? 'Vertical_Lanyard' : 'Dual_A4');
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
    } finally {
      BrandedLoadingOverlay.hide();
    }
  }

  Future<void> _compartirPdf(CarnetOrientacion orientacion) async {
    BrandedLoadingOverlay.show(
      context,
      message: 'Preparando Carnet SOS...',
      submessage: 'Generando credencial en alta calidad para compartir',
    );
    try {
      final bytes = await MiFamiliaPdfService.construirCarnetBytes(
        widget.familiar,
        orientacion: orientacion,
        estiloOverride: _estiloActual,
      );
      final sufijo = orientacion == CarnetOrientacion.horizontal
          ? 'Horizontal_Billetera'
          : (orientacion == CarnetOrientacion.vertical ? 'Vertical_Lanyard' : 'Dual_A4');
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
    } finally {
      BrandedLoadingOverlay.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final familiar = widget.familiar;
    final bool esNino = familiar.edad > 0 && familiar.edad <= 11;
    final bool esJoven = familiar.edad >= 12 && familiar.edad < 18;
    final bool esFem = _esFemenina;

    // Configuración temática según grupo y género
    Color cardBg;
    Color colorPrimario;
    Color colorAcento;
    Color ringColor;
    Color pillBg;
    const Color colorSosButton = Color(0xFFEA580C); // Naranja neón de alto impacto
    String badgePerfil;
    String tituloAnverso;
    String tituloCadete;

    if (esNino) {
      if (esFem) {
        // 👧 Cadete Niña: Cosmic Burgundy & Rose Gold / Pink Neon
        cardBg = const Color(0xFF3B0718);
        colorPrimario = const Color(0xFF831843);
        colorAcento = const Color(0xFFFBCFE8);
        ringColor = const Color(0xFFF43F5E);
        pillBg = const Color(0xFF4C0519);
        badgePerfil = '👧 CADETE NIÑA';
        tituloAnverso = 'PNP ALERTA / ESCUDO SOS';
        tituloCadete = 'CADETE DE EMERGENCIA';
      } else {
        // 👦 Cadete Niño: Obsidian Space & Electric Cyan Neon
        cardBg = const Color(0xFF0B0F19);
        colorPrimario = const Color(0xFF0C4A6E);
        colorAcento = const Color(0xFF00E5FF);
        ringColor = const Color(0xFF00E5FF);
        pillBg = const Color(0xFF1E293B);
        badgePerfil = '👦 CADETE NIÑO';
        tituloAnverso = 'PNP ALERTA / ESCUDO SOS';
        tituloCadete = 'CADETE DE EMERGENCIA';
      }
    } else if (esJoven) {
      cardBg = const Color(0xFF0F172A);
      colorPrimario = const Color(0xFF4F46E5);
      colorAcento = const Color(0xFF06B6D4);
      ringColor = const Color(0xFFEC4899);
      pillBg = const Color(0xFF1E1B4B);
      badgePerfil = 'ID ESTUDIANTIL DIGITAL';
      tituloAnverso = 'CREDENCIAL JUVENIL';
      tituloCadete = 'CADETE ESTUDIANTIL';
    } else {
      cardBg = const Color(0xFF0A192F);
      colorPrimario = const Color(0xFF1E3A8A);
      colorAcento = const Color(0xFFF59E0B);
      ringColor = const Color(0xFFF59E0B);
      pillBg = const Color(0xFF172554);
      badgePerfil = 'CREDENCIAL MÉDICA SOS';
      tituloAnverso = 'CREDENCIAL CIUDADANA';
      tituloCadete = 'CREDENCIAL CIUDADANA';
    }

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
          constraints: const BoxConstraints(maxWidth: 640),
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
                        ? (esFem
                            ? [const Color(0xFF4C0519), const Color(0xFF831843), const Color(0xFFBE185D)]
                            : [const Color(0xFF0B0F19), const Color(0xFF0C4A6E), const Color(0xFF0284C7)])
                        : (esJoven
                            ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B), const Color(0xFF4F46E5)]
                            : [const Color(0xFF0A192F), const Color(0xFF1E3A8A), const Color(0xFF1E40AF)]),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: ringColor, width: 2),
                        boxShadow: [
                          BoxShadow(color: ringColor.withOpacity(0.4), blurRadius: 6),
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
                                ? 'Credencial Escudo SOS - Cadete de Emergencia'
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

              // ================= SELECTOR RÁPIDO DE ESTILO CADETE (SI ES NIÑO/A) =================
              if (esNino) ...[
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🎨 Versión del Carnet:',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      Row(
                        children: [
                          _buildThemeOptionChip(
                            label: '👦 Niño (Cian)',
                            active: _estiloActual == 'nino' || (_estiloActual == 'auto' && !esFem),
                            accentColor: const Color(0xFF00E5FF),
                            onTap: () => setState(() => _estiloActual = 'nino'),
                          ),
                          const SizedBox(width: 6),
                          _buildThemeOptionChip(
                            label: '👧 Niña (Rose Gold)',
                            active: _estiloActual == 'nina' || (_estiloActual == 'auto' && esFem),
                            accentColor: const Color(0xFFF43F5E),
                            onTap: () => setState(() => _estiloActual = 'nina'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

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
                        label: 'Vertical (Lanyard Cuello)',
                        icon: Icons.badge_rounded,
                        active: _orientacion == CarnetOrientacion.vertical,
                        onTap: () => setState(() => _orientacion = CarnetOrientacion.vertical),
                      ),
                    ),
                    const SizedBox(width: 4),
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
                    if (_orientacion == CarnetOrientacion.vertical) ...[
                      _buildBannerGuia('FORMATO VERTICAL (65mm x 95mm) - PORTAFOTOCHECK DE CUELLO / LANYARD CON PERFORACIÓN'),
                      const SizedBox(height: 10),
                      _buildVerticalAnversoWidget(familiar, fotoProvider, qrData, cardBg, pillBg, ringColor, colorAcento, colorSosButton, tituloCadete),
                      const SizedBox(height: 14),
                      _buildVerticalReversoWidget(familiar, cardBg, pillBg, ringColor, colorAcento, qrData),
                    ] else if (_orientacion == CarnetOrientacion.horizontal) ...[
                      _buildBannerGuia('FORMATO HORIZONTAL (86mm x 54mm) - TAMAÑO ESTÁNDAR BILLETERA / BOLSILLO'),
                      const SizedBox(height: 10),
                      _buildHorizontalAnversoWidget(familiar, fotoProvider, cardBg, pillBg, ringColor, colorAcento, colorSosButton, tituloCadete),
                      const SizedBox(height: 14),
                      _buildHorizontalReversoWidget(familiar, qrData, cardBg, pillBg, ringColor, colorAcento),
                    ] else ...[
                      _buildBannerGuia('HOJA DUAL A4 - INCLUYE AMBOS TAMAÑOS LISTOS PARA IMPRIMIR Y RECORTAR'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Opción 1: Portafotocheck Vertical (Cinta al Cuello / Lanyard)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E3A8A)),
                            ),
                            const SizedBox(height: 8),
                            _buildVerticalAnversoWidget(familiar, fotoProvider, qrData, cardBg, pillBg, ringColor, colorAcento, colorSosButton, tituloCadete),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Divider(color: Colors.grey, thickness: 1),
                            ),
                            const Text(
                              'Opción 2: Credencial Horizontal (Billetera / Mochila)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E3A8A)),
                            ),
                            const SizedBox(height: 8),
                            _buildHorizontalAnversoWidget(familiar, fotoProvider, cardBg, pillBg, ringColor, colorAcento, colorSosButton, tituloCadete),
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

                        // Botón Descargar
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

  Widget _buildThemeOptionChip({
    required String label,
    required bool active,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? accentColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? accentColor : Colors.grey.shade400,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: active ? FontWeight.w900 : FontWeight.w500,
            color: active ? const Color(0xFF0F172A) : Colors.grey.shade700,
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
  // WIDGET: FORMATO VERTICAL (65mm x 95mm - Portafotocheck de Cuello / Lanyard)
  // Con perforación superior, marco fotográfico luminoso, pastilla SOS naranja,
  // código de barras, firma de tutor y protocolo 3 pasos en el reverso.
  // =========================================================================

  Widget _buildVerticalAnversoWidget(
    FamiliarProfile familiar,
    ImageProvider? fotoProvider,
    String qrData,
    Color cardBg,
    Color pillBg,
    Color ringColor,
    Color colorAcento,
    Color colorSosButton,
    String tituloCadete,
  ) {
    final bool esFem = _esFemenina;
    const Color textPrimary = Colors.white;
    final Color textSecondary = esFem ? const Color(0xFFFBCFE8) : const Color(0xFF80DEEA);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 270,
        height: 405,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: (esFem ? const Color(0xFFF43F5E) : const Color(0xFF00E5FF)).withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 0. Plantilla Maestra Oficial (con logo PNP, títulos, marco neón, botón SOS, barcode y firma)
            Positioned.fill(
              child: Image.asset(
                esFem ? 'assets/images/carnet/bg_girl_anverso_v2.png' : 'assets/images/carnet/bg_boy_anverso_v2.png',
                fit: BoxFit.cover,
              ),
            ),

            // Borde perimetral fino
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: esFem ? const Color(0xFFFDA4AF).withOpacity(0.4) : const Color(0xFF00E5FF).withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
              ),
            ),

            // 1. FOTO DEL MENOR (Calzada con precisión milimétrica dentro del marco neón de la plantilla HD)
            Positioned(
              left: 74,
              top: 104,
              width: 120,
              height: 116,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: fotoProvider != null
                    ? Image(image: fotoProvider, fit: BoxFit.cover)
                    : Container(
                        color: esFem ? const Color(0xFF4C0519) : const Color(0xFF071426),
                        child: Center(
                          child: Icon(
                            Icons.person_rounded,
                            size: 58,
                            color: esFem ? const Color(0xFFFDA4AF) : const Color(0xFF80DEEA),
                          ),
                        ),
                      ),
              ),
            ),

            // 2. BLOQUE DE DATOS DEL MENOR (Nombre, DNI, Edad/RH, Condición Especial)
            // Ubicado exactamente en el espacio libre entre el marco de la foto y el botón SOS
            Positioned(
              top: 224,
              left: 12,
              right: 12,
              height: 74,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    familiar.nombreCompleto.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      letterSpacing: 0.3,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID / DNI: ${familiar.dni.isNotEmpty ? familiar.dni : "CADETE SOS"}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: textSecondary,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 3),
                      ],
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'EDAD / RH: ${familiar.edad} AÑOS | ${familiar.tipoSangre.isNotEmpty ? familiar.tipoSangre : "O+"}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: textSecondary,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 3),
                      ],
                    ),
                  ),
                  if (familiar.condicionEspecial.isNotEmpty && familiar.condicionEspecial != 'Ninguna') ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: esFem ? const Color(0xFFBE185D) : const Color(0xFF0284C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        familiar.condicionEspecial,
                        style: const TextStyle(fontSize: 7.0, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 3. NÚMERO DE CONTACTO SOS
            // Encaja con separación elegante a la derecha de "SOS AVISAR:" dentro del botón de la plantilla
            Positioned(
              top: 301,
              height: 24,
              left: 146,
              right: 40,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  familiar.telefonoContacto.isNotEmpty ? familiar.telefonoContacto : '105',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD54F),
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                ),
              ),
            ),

            // 4. CÓDIGO QR REAL DE AUXILIO
            // Ubicado exactamente en el recuadro blanco de la plantilla sin tapar barcode ni firma
            Positioned(
              right: 26,
              bottom: 14,
              width: 55,
              height: 55,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.all(2.0),
                child: QrImageView(
                  data: qrData,
                  size: 51,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalReversoWidget(
    FamiliarProfile familiar,
    Color cardBg,
    Color pillBg,
    Color ringColor,
    Color colorAcento,
    String qrData,
  ) {
    final bool esFem = _esFemenina;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 270,
        height: 405,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: (esFem ? const Color(0xFFF43F5E) : const Color(0xFF00E5FF)).withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 0. Plantilla Maestra Reverso Oficial
            // Contiene: cabecera, "PERSONAL AUTORIZADO Y PROTEGIDO", "PROTOCOLO SOS 1-2-3", columnas PNP/Desaparecidos y lema
            Positioned.fill(
              child: Image.asset(
                esFem ? 'assets/images/carnet/bg_girl_reverso_v2.png' : 'assets/images/carnet/bg_boy_reverso_v2.png',
                fit: BoxFit.cover,
              ),
            ),

            // Borde exterior fino
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: esFem ? const Color(0xFFFDA4AF).withOpacity(0.4) : const Color(0xFF00E5FF).withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
              ),
            ),

            // 1. ALERTA MÉDICA (Dentro de la pastilla roja de la plantilla HD, a la derecha de "ALERTA MÉDICA:")
            Positioned(
              top: 301,
              height: 22,
              left: 114,
              right: 28,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  familiar.datosMedicos.isNotEmpty ? familiar.datosMedicos.toUpperCase() : 'SIN ALERGIAS CONOCIDAS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.0,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),

            // 2. TELÉFONO DE FAMILIA DIRECTA (En la 3ra columna bajo "FAMILIA DIRECTA", sin texto [N° CONTACTO])
            Positioned(
              top: 346,
              height: 34,
              right: 24,
              width: 86,
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  familiar.telefonoContacto.isNotEmpty ? familiar.telefonoContacto : '105',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFDE047),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // WIDGET: FORMATO HORIZONTAL (86mm x 54mm - Billetera / Bolsillo)
  // =========================================================================

  Widget _buildHorizontalAnversoWidget(
    FamiliarProfile familiar,
    ImageProvider? fotoProvider,
    Color cardBg,
    Color pillBg,
    Color ringColor,
    Color colorAcento,
    Color colorSosButton,
    String tituloCadete,
  ) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 460),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ringColor, width: 2),
        boxShadow: [
          BoxShadow(color: ringColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Barra superior con Mascota Oficial
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: ringColor.withOpacity(0.4), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: ringColor, width: 1.5),
                      ),
                      padding: const EdgeInsets.all(1),
                      child: ClipOval(child: Image.asset('assets/icons/icon_police.png', fit: BoxFit.contain)),
                    ),
                    const SizedBox(width: 8),
                    const Text('PNP ALERTA - ESCUDO SOS', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(4), border: Border.all(color: colorAcento)),
                  child: Text(
                    tituloCadete,
                    style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: colorAcento),
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
                // Anillo de neón con foto circular
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor, width: 2.5),
                    boxShadow: [
                      BoxShadow(color: ringColor.withOpacity(0.4), blurRadius: 8),
                    ],
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
                    padding: const EdgeInsets.all(1.5),
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
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.white),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        familiar.edad > 0 ? 'EDAD: ${familiar.edad} AÑOS' : 'CADETE SOS',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorAcento),
                      ),
                      if (familiar.dni.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('ID / DNI: ${familiar.dni}', style: const TextStyle(fontSize: 9, color: Colors.white70)),
                      ],
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              'RH: ${familiar.tipoSangre.isNotEmpty ? familiar.tipoSangre : "O+"}',
                              style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.white),
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

          // Pastilla SOS de Alto Contraste Naranja Neón
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: colorSosButton,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFED7AA), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone_in_talk_rounded, size: 12, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'SOS AVISAR AL FAMILIAR: ${familiar.telefonoContacto.isNotEmpty ? familiar.telefonoContacto : "105"}',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Barra inferior con URL limpia
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              border: Border(top: BorderSide(color: ringColor.withOpacity(0.4), width: 0.8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'EMERGENCIAS PNP: 105',
                  style: TextStyle(fontSize: 8, color: Colors.white70),
                ),
                Text(
                  'pnpalerta.web.app',
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: colorAcento),
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
    Color cardBg,
    Color pillBg,
    Color ringColor,
    Color colorAcento,
  ) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 460),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ringColor, width: 2),
        boxShadow: [
          BoxShadow(color: ringColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: ringColor.withOpacity(0.4), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: ringColor, width: 1.2),
                      ),
                      padding: const EdgeInsets.all(1),
                      child: ClipOval(child: Image.asset('assets/icons/icon_police.png', fit: BoxFit.contain)),
                    ),
                    const SizedBox(width: 6),
                    const Text('PNP ALERTA / SOS NACIONAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
                const Text('WHATSAPP SOS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF34D399))),
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
                      Text(
                        'PERSONAL AUTORIZADO Y PROTEGIDO',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: colorAcento),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Escanea el QR con la cámara de cualquier teléfono para abrir auxilio directo por WhatsApp.',
                        style: TextStyle(fontSize: 8.5, color: Colors.white, height: 1.2),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: const [
                          Icon(Icons.local_police_rounded, size: 12, color: Colors.cyanAccent),
                          SizedBox(width: 4),
                          Text('PNP: 105', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
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
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              border: Border(top: BorderSide(color: ringColor.withOpacity(0.4), width: 0.8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('★ PROTEGIENDO EL FUTURO DE NUESTRA NIÑEZ ★', style: TextStyle(fontSize: 7.5, color: Colors.white60)),
                Text('pnpalerta.web.app', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: colorAcento)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
