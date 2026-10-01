import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'comisarias_screen.dart';
import 'agenda_policial.dart';
import 'directorio_cem_screen.dart';
import '../widgets/sos_dialog.dart';
import '../../../core/services/analytics_telemetry_service.dart';
import '../../../common/localization/app_strings.dart';

class CentralAuxilioScreen extends StatefulWidget {
  final int initialTabIndex;

  const CentralAuxilioScreen({super.key, this.initialTabIndex = 0});

  @override
  State<CentralAuxilioScreen> createState() => _CentralAuxilioScreenState();
}

class _CentralAuxilioScreenState extends State<CentralAuxilioScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    AnalyticsTelemetryService().logModuleUsage('Central de Auxilio');
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    _tabController.addListener(_onTabChanged);

    // Animación de respiración / pulso alrededor del botón activo (ritmo más perceptible)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant CentralAuxilioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _tabController.animateTo(widget.initialTabIndex.clamp(0, 3));
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(66),
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF0B132B), Color(0xFF0F172A)]
                  : const [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF38BDF8).withOpacity(0.6)
                  : const Color(0xFF2563EB).withOpacity(0.35),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.65)
                    : const Color(0xFF0F172A).withOpacity(0.12),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: isDark
                    ? const Color(0xFF0284C7).withOpacity(0.3)
                    : const Color(0xFF2563EB).withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            physics: const BouncingScrollPhysics(),
            dividerColor: Colors.transparent,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            padding: const EdgeInsets.all(4),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: const BoxDecoration(color: Colors.transparent),
            tabs: [
              _buildTabItem(
                index: 0,
                title: strings.isQuechua ? 'SOS Yanapay' : 'Central SOS',
                icon: Icons.emergency_rounded,
                accentColor: const Color(0xFFEF4444),
                badge: '24/7',
                isDark: isDark,
              ),
              _buildTabItem(
                index: 1,
                title: strings.isQuechua ? 'Comisarías (Saywiti)' : 'Comisarías (Mapa)',
                icon: Icons.map_rounded,
                accentColor: const Color(0xFF0284C7),
                badge: 'GPS',
                isDark: isDark,
              ),
              _buildTabItem(
                index: 2,
                title: strings.isQuechua ? 'Polisiyakuna Agenda' : 'Agenda Policial',
                icon: Icons.contact_phone_rounded,
                accentColor: const Color(0xFFF59E0B),
                isDark: isDark,
              ),
              _buildTabItem(
                index: 3,
                title: strings.isQuechua ? 'CEM Willaykuna' : 'Directorio CEM',
                icon: Icons.shield_rounded,
                accentColor: const Color(0xFF8B5CF6),
                badge: 'Línea 100',
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCentralEmergenciasTab(context, isDark),
          const ComisariasScreen(isActive: true),
          const AgendaPolicialScreen(),
          const DirectorioCemScreen(),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required String title,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    String? badge,
  }) {
    final isSelected = _tabController.index == index;

    if (isSelected) {
      return Tab(
        height: 48,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, _) {
            final t = _pulseAnimation.value;

            return Transform.scale(
              scale: 1.0 + 0.025 * t,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF1D4ED8), Color(0xFF0284C7)]
                        : const [Color(0xFF1E40AF), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  // Borde animado de respiración de alto impacto
                  border: Border.all(
                    color: isDark
                        ? Color.lerp(
                            const Color(0xFF38BDF8),
                            Colors.white,
                            t,
                          )!.withOpacity(0.80 + 0.20 * t)
                        : Color.lerp(
                            const Color(0xFF1E40AF),
                            const Color(0xFF93C5FD),
                            t,
                          )!.withOpacity(0.80 + 0.20 * t),
                    width: 1.5 + 0.9 * t,
                  ),
                  boxShadow: [
                    // Capa 1: Halo perimetral intenso que se expande hacia afuera
                    BoxShadow(
                      color: isDark
                          ? const Color(0xFF38BDF8).withOpacity(0.35 + 0.45 * t)
                          : const Color(0xFF2563EB).withOpacity(0.28 + 0.42 * t),
                      blurRadius: 10.0 + 14.0 * t,
                      spreadRadius: 1.5 + 3.0 * t,
                      offset: const Offset(0, 1),
                    ),
                    // Capa 2: Aura ambiental difusa de respiración amplia
                    BoxShadow(
                      color: isDark
                          ? const Color(0xFF00E5FF).withOpacity(0.20 + 0.35 * t)
                          : const Color(0xFF3B82F6).withOpacity(0.18 + 0.30 * t),
                      blurRadius: 16.0 + 14.0 * t,
                      spreadRadius: 2.5 + 4.5 * t,
                      offset: const Offset(0, 2),
                    ),
                    // Capa 3: Sombra de relieve interior para máxima definición
                    BoxShadow(
                      color: isDark
                          ? const Color(0xFF0284C7).withOpacity(0.5)
                          : const Color(0xFF1E40AF).withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.24),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.15,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.26),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    // Micro baliza radar pulsante sincronizada
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.5 + 0.5 * t),
                            blurRadius: 4.0 + 6.0 * t,
                            spreadRadius: 1.0 + 1.2 * t,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    // Pestaña inactiva: chip limpio y estilizado con alto contraste
    return Tab(
      height: 48,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(isDark ? 0.22 : 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                letterSpacing: 0.15,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? accentColor.withOpacity(0.25)
                      : accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: accentColor.withOpacity(0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : accentColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCentralEmergenciasTab(BuildContext context, bool isDark) {
    final strings = AppStrings.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Banner de Cabecera
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emergency_rounded, color: Colors.redAccent, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.centralAuxilioTitle,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.freeCallsEverywhere,
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11.5, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Botón SOS destacado
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => SosDialog.show(context),
              icon: const Icon(Icons.warning_rounded, color: Colors.white),
              label: Text(
                strings.openSosPanic,
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 3,
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            strings.emergencyHotlinesTitle,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _buildDirectCallCard(
            context: context,
            number: '105',
            title: strings.isQuechua ? 'Perú Suyupa Policiyan (PNP)' : 'Policía Nacional del Perú',
            description: strings.isQuechua
                ? 'Polisiyapa yanapakuynin suwakunamanta, maqanakuykunamanta utaq usqhaylla yanapanapaq.'
                : 'Central de Emergencias Policiales para asaltos, robos, alteraciones del orden o auxilio inmediato.',
            color: const Color(0xFF1E3A8A),
            icon: Icons.local_police_rounded,
          ),
          const SizedBox(height: 10),

          _buildDirectCallCard(
            context: context,
            number: '114',
            title: strings.isQuechua ? 'Chinkasqakunata Mask\'aq T\'aqa' : 'División de Búsqueda de Personas Desaparecidas',
            description: strings.isQuechua
                ? 'Chinkasqa runakuna willanapaq mana qullqiyuq tupanapaq t\'aqa.'
                : 'Línea gratuita exclusiva para reportar extravíos, desaparecidos y aportar pistas de ubicación.',
            color: const Color(0xFFDC2626),
            icon: Icons.person_search_rounded,
          ),
          const SizedBox(height: 10),

          _buildDirectCallCard(
            context: context,
            number: '100',
            title: strings.isQuechua ? '100 Tupana (Warmikunapaq MIMP)' : 'Línea 100 (Ministerio de la Mujer - MIMP)',
            description: strings.isQuechua
                ? 'Ayllupi maqanakuykunamanta warmikunata, wamrakunata 24 oras yanapanapaq.'
                : 'Atención especializada, psicológica y legal las 24 horas para víctimas de violencia familiar o abuso.',
            color: const Color(0xFFDB2777),
            icon: Icons.volunteer_activism_rounded,
          ),
          const SizedBox(height: 10),

          _buildDirectCallCard(
            context: context,
            number: '116',
            title: strings.firefightersTitle,
            description: strings.isQuechua
                ? 'Rawraq nina, karru tupaykuna utaq k\'irisqa runakunata qespichinapaq.'
                : 'Emergencias por incendios, rescates vehiculares, accidentes graves y personas atrapadas.',
            color: const Color(0xFFD97706),
            icon: Icons.fire_truck_rounded,
          ),
          const SizedBox(height: 10),

          _buildDirectCallCard(
            context: context,
            number: '106',
            title: strings.samuTitle,
            description: strings.isQuechua
                ? 'Usqhaylla unqusqakunata hampi wasiman apanapaq tupana.'
                : 'Urgencias médicas prehospitalarias y traslado en ambulancia en Lima y principales regiones.',
            color: const Color(0xFF059669),
            icon: Icons.medical_services_rounded,
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildDirectCallCard({
    required BuildContext context,
    required String number,
    required String title,
    required String description,
    required Color color,
    required IconData icon,
  }) {
    final strings = AppStrings.of(context);

    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25), width: 1.2),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        number,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.3),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      final uri = Uri.parse('tel:$number');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 16, color: Colors.white),
                    label: Text(
                      strings.isQuechua ? '$number-man gratis qayay' : 'Llamar gratis al $number',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
