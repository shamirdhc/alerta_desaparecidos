import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:alerta_desaparecidos/presentation/common_widgets/theme_sun_moon_toggle.dart';

class TutorialMainScreen extends StatefulWidget {
  const TutorialMainScreen({super.key});

  @override
  State<TutorialMainScreen> createState() => _TutorialMainScreenState();
}

class _TutorialMainScreenState extends State<TutorialMainScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
          'PROTOCOLOS TÁCTICOS PNP',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.1,
          ),
        ),
        backgroundColor: const Color(0xFF004D40),
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: const [
          ThemeSunMoonToggle(compact: true),
          SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Hero Institucional
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF004D40), Color(0xFF00796B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF004D40).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.scaleBalanced,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300).withOpacity(0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'MARCO LEGAL OFICIAL',
                            style: TextStyle(
                              color: Color(0xFFFFE082),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Decreto Legislativo N° 1428',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Atención inmediata en comisarías, geolocalización en flagrancia y difusión de notas de alerta.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'GUÍAS OPERATIVAS & PROCEDIMIENTOS',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 14),

            // Protocolo 1: Recepción Inmediata
            _buildProtocolCard(
              context,
              title: '1. Recepción Inmediata de Denuncias',
              subtitle: 'Prohibición absoluta de esperar 24 o 48 horas',
              badgeText: 'OBLIGATORIO NACIONAL',
              badgeColor: const Color(0xFFE11D48),
              icon: FontAwesomeIcons.fileShield,
              accentColor: const Color(0xFFE11D48),
              isDark: isDark,
              summary: 'Cualquier efectivo policial está obligado por ley a registrar la denuncia en el acto, sin importar la jurisdicción.',
              details: [
                '• Prohibido exigir plazos de espera (24h/48h). El registro es instantáneo.',
                '• Si la persona es menor de edad, mujer víctima de violencia o adulto mayor, califica como Población Vulnerable de Muy Alto Riesgo.',
                '• El efectivo debe generar la Nota de Alerta y notificar a la DIVIBPD de inmediato.',
                '• La omisión de este procedimiento genera responsabilidad penal y disciplinaria.',
              ],
            ),

            const SizedBox(height: 14),

            // Protocolo 2: Geolocalización en Flagrancia
            _buildProtocolCard(
              context,
              title: '2. Geolocalización Inmediata (Art. 13)',
              subtitle: 'Localización celular en flagrancia sin orden judicial previa',
              badgeText: 'URGENCIA TÁCTICA',
              badgeColor: const Color(0xFFF59E0B),
              icon: FontAwesomeIcons.satelliteDish,
              accentColor: const Color(0xFFF59E0B),
              isDark: isDark,
              summary: 'Procedimiento de triangulación de antenas ante operadoras cuando la vida de la persona desaparecida corre peligro inminente.',
              details: [
                '• Aplica para víctimas de secuestro, menores o peligro inminente contra la vida.',
                '• La unidad policial remite el requerimiento formal a las operadoras telefónicas (Claro, Movistar, Entel, Bitel).',
                '• Las operadoras están obligadas a entregar la ubicación de la celda de inmediato.',
                '• Debe notificarse simultáneamente al Fiscal Provincial de turno.',
              ],
            ),

            const SizedBox(height: 14),

            // Protocolo 3: Escaneo con Gemini OCR
            _buildProtocolCard(
              context,
              title: '3. Escaneo y Extracción con Gemini IA',
              subtitle: 'Digitalización automática de denuncias en 10 segundos',
              badgeText: 'TECNOLOGÍA POLICIAL',
              badgeColor: const Color(0xFF6366F1),
              icon: FontAwesomeIcons.brain,
              accentColor: const Color(0xFF6366F1),
              isDark: isDark,
              summary: 'Aprovecha la cámara del dispositivo móvil para fotografiar el atestado en papel y auto-llenar el formulario de búsqueda.',
              details: [
                '• Ingresa al botón flotante (+) "Registrar Caso PNP".',
                '• Pulsa "Escanear Denuncia con IA". Toma una fotografía nítida de la denuncia física.',
                '• El motor OCR de Gemini detecta nombres, apellidos, DNI, fecha, lugar y señas particulares automáticamente.',
                '• Corrige cualquier dato en pantalla y publica la Nota de Alerta con un solo toque.',
              ],
            ),

            const SizedBox(height: 14),

            // Protocolo 4: Alertas de Emergencia y Difusión
            _buildProtocolCard(
              context,
              title: '4. Difusión Masiva y Alertas Amber',
              subtitle: 'Canales oficiales PNP, medios de comunicación y redes',
              badgeText: 'DIFUSIÓN MASIVA',
              badgeColor: const Color(0xFF00796B),
              icon: FontAwesomeIcons.towerBroadcast,
              accentColor: const Color(0xFF00796B),
              isDark: isDark,
              summary: 'Activación de la red nacional de afiches oficiales para que la ciudadanía aporte pistas y avistamientos en tiempo real.',
              details: [
                '• La Nota de Alerta generada se sincroniza en vivo con la app ciudadana.',
                '• Los ciudadanos en el radio de búsqueda reciben notificaciones push prioritarias.',
                '• Cualquier pista aportada se envía a la sección "Pistas Ciudadanas" para moderación del oficial a cargo.',
                '• Al ubicar a la persona, se debe actualizar el estado a "Ubicado" para cerrar el expediente legalmente.',
              ],
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildProtocolCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required String summary,
    required List<String> details,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showProtocolModal(context, title, subtitle, icon, accentColor, summary, details, isDark),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: FaIcon(icon, color: accentColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            title,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  summary,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tocar para ver pasos y fundamentación legal →',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showProtocolModal(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color accentColor,
    String summary,
    List<String> details,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FaIcon(icon, color: accentColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              summary,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'INSTRUCCIONES OPERATIVAS:',
              style: TextStyle(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            ...details.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    item,
                    style: TextStyle(
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                )),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Entendido, Conforme a Ley'),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}