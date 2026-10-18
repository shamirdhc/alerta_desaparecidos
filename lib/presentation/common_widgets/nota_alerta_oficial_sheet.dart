import 'package:flutter/material.dart';
import '../../domain/entities/desaparecido.dart';
import '../../services/comisaria_matcher_service.dart';
import '../../services/desaparecido_pdf_service.dart';

/// Hoja modal institucional para consultar, descargar y verificar
/// la Nota de Alerta Oficial PNP (DIVINBUS) de una persona desaparecida.
class NotaAlertaOficialSheet extends StatelessWidget {
  final Desaparecido desaparecido;
  final ComisariaMatchResult? comisariaInfo;

  const NotaAlertaOficialSheet({
    super.key,
    required this.desaparecido,
    this.comisariaInfo,
  });

  /// Muestra la hoja modal de forma accesible y adaptable
  static Future<void> show(
    BuildContext context,
    Desaparecido desaparecido, {
    ComisariaMatchResult? comisariaInfo,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NotaAlertaOficialSheet(
        desaparecido: desaparecido,
        comisariaInfo: comisariaInfo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEncontrado = (desaparecido.estado ?? '').trim().toLowerCase() == 'encontrado';
    final String nombreCompleto = '${desaparecido.nombres} ${desaparecido.apellidos}'.trim();
    final String codigoAlerta = desaparecido.id?.isNotEmpty == true
        ? desaparecido.id!
        : 'OFICIAL';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 25,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra superior de agarre
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cabecera Institucional PNP
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF0F766E).withOpacity(0.3), width: 1.5),
                    ),
                    child: Image.asset(
                      'assets/icons/emblema_pnp.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.shield_rounded,
                        color: Color(0xFF10B981),
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isEncontrado ? const Color(0xFF10B981) : const Color(0xFFC00000),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isEncontrado ? 'UBICADO CON VIDA' : 'ALERTA OFICIAL PNP',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'N° $codigoAlerta',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[700],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Nota de Alerta DIVINBUS',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Policía Nacional del Perú - DIRINCRI',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tarjeta Resumen del Caso
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_pin_rounded, color: Color(0xFF174E75), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombreCompleto.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            desaparecido.edadCalculada != null
                                ? '${desaparecido.edadCalculada} años • Desapareció en ${desaparecido.distrito ?? "Perú"}'
                                : 'Desapareció en ${desaparecido.distrito ?? "Perú"}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ==========================================
              // ACCIÓN 1: ABRIR / DESCARGAR PDF OFICIAL A4
              // ==========================================
              _buildActionCard(
                context: context,
                icon: Icons.picture_as_pdf_rounded,
                iconColor: const Color(0xFFC00000),
                iconBg: const Color(0xFFFEE2E2),
                title: 'Ver / Descargar PDF Oficial A4',
                subtitle: 'Formato 1:1 DIVINBUS listo para imprimir (300 DPI vectorial)',
                badgeText: 'OFICIAL A4',
                onTap: () {
                  Navigator.pop(context);
                  DesaparecidoPdfService.abrirNotaAlertaPdf(
                    context,
                    desaparecido,
                    comisariaInfo: comisariaInfo,
                  );
                },
              ),
              const SizedBox(height: 12),

              // ==========================================
              // ACCIÓN 2: COMPARTIR EN WHATSAPP / REDES
              // ==========================================
              _buildActionCard(
                context: context,
                icon: Icons.share_rounded,
                iconColor: const Color(0xFF25D366),
                iconBg: const Color(0xFFDCFCE7),
                title: 'Compartir Alerta Oficial',
                subtitle: 'Envía el documento y enlace directo por WhatsApp o redes',
                badgeText: 'DIFUSIÓN',
                onTap: () {
                  Navigator.pop(context);
                  DesaparecidoPdfService.compartirNotaAlertaPdf(
                    context,
                    desaparecido,
                    comisariaInfo: comisariaInfo,
                  );
                },
              ),
              const SizedBox(height: 12),

              // ==========================================
              // ACCIÓN 3: VERIFICAR EN PORTAL WEB DE LA PNP
              // ==========================================
              _buildActionCard(
                context: context,
                icon: Icons.verified_user_rounded,
                iconColor: const Color(0xFF174E75),
                iconBg: const Color(0xFFE0F2FE),
                title: 'Verificar en Portal Web PNP',
                subtitle: 'Consulta legal directa en desaparecidosenperu.policia.gob.pe',
                badgeText: 'PORTAL PNP',
                onTap: () {
                  Navigator.pop(context);
                  DesaparecidoPdfService.abrirPortalOficialPnp(context, desaparecido);
                },
              ),
              const SizedBox(height: 20),

              // Banner de Garantía y Líneas de Emergencia
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_in_talk_rounded, color: Color(0xFFC00000), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Línea Gratuita 114 PNP | Central 105',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Atención inmediata las 24 horas del día a nivel nacional.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF475569),
                            ),
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
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[400], size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
