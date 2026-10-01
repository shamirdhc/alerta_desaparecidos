import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:alerta_desaparecidos/services/mi_familia_service.dart';

/// Vista previa visual e interactiva del AFICHE OFICIAL DE BÚSQUEDA A4 en Flutter puro.
/// Garantiza que el usuario SIEMPRE vea el afiche completo con su foto central gigante,
/// diseño de máxima visibilidad y código QR, sin depender de canvas externos ni motores PDF.
class AficheVisualPreviewWidget extends StatelessWidget {
  final FamiliarProfile familiar;
  final String? ultimaUbicacion;
  final VoidCallback? onCompartir;
  final VoidCallback? onDescargar;

  const AficheVisualPreviewWidget({
    super.key,
    required this.familiar,
    this.ultimaUbicacion,
    this.onCompartir,
    this.onDescargar,
  });

  @override
  Widget build(BuildContext context) {
    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // Preparar enlace de auxilio rápido para el QR
    final telSanitized = familiar.telefonoContacto.replaceAll(RegExp(r'[^0-9]'), '');
    final waNumber = telSanitized.length == 9 ? '51$telSanitized' : telSanitized;
    final qrData = telSanitized.isNotEmpty
        ? 'https://wa.me/$waNumber?text=${Uri.encodeComponent('🚨 ALERTA CIUDADANA: Tengo pistas/información sobre ${familiar.nombreCompleto}, quien figura como desaparecido(a) en el Afiche Oficial.')}'
        : 'ALERTA DE DESAPARECIDO(A)\nNombre: ${familiar.nombreCompleto}\nEdad: ${familiar.edad} anos\nCentral Policia Nacional: 105\nLinea Desaparecidos: 114';

    ImageProvider? fotoProvider;
    if (familiar.fotoBase64 != null && familiar.fotoBase64!.isNotEmpty) {
      try {
        fotoProvider = MemoryImage(base64Decode(familiar.fotoBase64!));
      } catch (_) {}
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDC2626), width: 3.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ================= CABECERA DE ALTO IMPACTO CON LOGO Y URL =================
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Row(
                  children: [
                    // Logo oficial circular del aplicativo
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 4),
                        ],
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: Image.asset('assets/icons/icon_police.png', fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            '¡AYÚDANOS A ENCONTRARLO(A)!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ALERTA NACIONAL DE BÚSQUEDA Y DIFUSIÓN CIUDADANA',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF451A03),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Píldora sutil con URL limpia (no opaca los datos)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_rounded, size: 13, color: Color(0xFFFDE047)),
                          SizedBox(height: 1),
                          Text(
                            'pnpalerta.web.app',
                            style: TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ================= NOMBRE COMPLETO =================
                    Text(
                      familiar.nombreCompleto.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF991B1B),
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Badges de Datos Clave Superiores
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildBadge('EDAD: ${familiar.edad} AÑOS', const Color(0xFF1E3A8A)),
                        if (familiar.dni.isNotEmpty)
                          _buildBadge('DNI: ${familiar.dni}', const Color(0xFF374151)),
                        _buildBadge('PARENTESCO: ${familiar.parentesco.toUpperCase()}', const Color(0xFF047857)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ================= FOTO CENTRAL GIGANTE =================
                    Container(
                      width: 260,
                      height: 280,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDC2626), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: fotoProvider != null
                            ? Image(
                                image: fotoProvider,
                                fit: BoxFit.cover,
                              )
                            : const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_search_rounded, size: 64, color: Colors.grey),
                                    SizedBox(height: 6),
                                    Text('FOTO RECIENTE NO DISPONIBLE',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'FOTOGRAFÍA RECIENTE CONFIRMADA POR FAMILIARES',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ================= VESTIMENTA Y LUGAR =================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD97706), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.checkroom_rounded, size: 16, color: Color(0xFFB45309)),
                              SizedBox(width: 6),
                              Text(
                                'VESTIMENTA AL SALIR / ÚLTIMO AVISTAMIENTO:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            familiar.ropaDelDia.isNotEmpty
                                ? familiar.ropaDelDia
                                : 'No detallada al momento del reporte. Comunicar cualquier rasgo.',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          if (ultimaUbicacion != null && ultimaUbicacion!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFDC2626)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'PUNTO O ZONA DE EXTRAVÍO: $ultimaUbicacion',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11.5,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ================= CARACTERÍSTICAS FÍSICAS Y MÉDICAS =================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CARACTERÍSTICAS FÍSICAS Y SEÑAS:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF374151)),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDatoItem('Estatura:', familiar.estatura.isNotEmpty ? '${familiar.estatura} m' : 'No especificada'),
                                    _buildDatoItem('Contextura:', familiar.contextura),
                                    _buildDatoItem('Grupo Sanguíneo:', familiar.tipoSangre.isNotEmpty ? familiar.tipoSangre : 'No especificado'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDatoItem('Tez / Piel:', familiar.colorPiel),
                                    _buildDatoItem('Cabello:', familiar.colorCabello),
                                    _buildDatoItem('Señales:', familiar.senasParticulares.isNotEmpty ? familiar.senasParticulares : 'Sin señas específicas'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (familiar.condicionEspecial.isNotEmpty && familiar.condicionEspecial != 'Ninguna') ...[
                            const Divider(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'CONDICIÓN ESPECIAL: ${familiar.condicionEspecial.toUpperCase()}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFDC2626)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (familiar.datosMedicos.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Atención Médica / Medicación: ${familiar.datosMedicos}',
                              style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF4B5563)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ================= BASE: QR + TELÉFONOS DE EMERGENCIA =================
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEF4444), width: 2),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          // Código QR Inteligente
                          Column(
                            children: [
                              Container(
                                width: 88,
                                height: 88,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFDC2626)),
                                ),
                                child: QrImageView(
                                  data: qrData,
                                  version: QrVersions.auto,
                                  size: 80,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'ESCANEA CON TU CELULAR\nPARA DAR PISTA O LLAMAR',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 6.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),

                          // Teléfonos de Contacto
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '🚨 SI LO HAS VISTO O TIENES DATOS, LLAMA AHORA MISMO:',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF991B1B)),
                                ),
                                const SizedBox(height: 4),
                                if (familiar.telefonoContacto.isNotEmpty) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF047857),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      '📞 FAMILIA: ${familiar.telefonoContacto}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDC2626),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: const Text(
                                          '🚔 POLICÍA: 105',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFB91C1C),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: const Text(
                                          '🆘 LÍNEA 114',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
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
                    const SizedBox(height: 8),

                    // Pie de página
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Emisión: $nowStr - Sistema PNP Alerta',
                            style: const TextStyle(fontSize: 8.5, color: Color(0xFF6B7280))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Text('pnpalerta.web.app',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ================= BARRA DE ACCIÓN INFERIOR =================
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onCompartir,
                        icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                        label: const Text('Compartir por WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onDescargar,
                        icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                        label: const Text('Descargar PDF A4', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  static Widget _buildDatoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 10.5, color: Color(0xFF1F2937)),
          children: [
            TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
