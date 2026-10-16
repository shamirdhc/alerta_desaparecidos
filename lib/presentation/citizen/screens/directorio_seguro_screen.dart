import 'package:flutter/material.dart';
import 'agenda_policial.dart';
import 'directorio_cem_screen.dart';
import '../widgets/sos_dialog.dart';
import '../../../core/services/analytics_telemetry_service.dart';
import '../../../common/localization/app_strings.dart';

class DirectorioSeguroScreen extends StatefulWidget {
  final int initialTabIndex;

  const DirectorioSeguroScreen({super.key, this.initialTabIndex = 0});

  @override
  State<DirectorioSeguroScreen> createState() => _DirectorioSeguroScreenState();
}

class _DirectorioSeguroScreenState extends State<DirectorioSeguroScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    AnalyticsTelemetryService().logModuleUsage('Directorio Seguro');
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _tabController.addListener(_onTabChanged);

    // Animación de respiración / pulso alrededor del botón activo
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
  void didUpdateWidget(covariant DirectorioSeguroScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _tabController.animateTo(widget.initialTabIndex.clamp(0, 1));
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
                  ? const Color(0xFF38BDF8).withValues(alpha: 0.6)
                  : const Color(0xFF2563EB).withValues(alpha: 0.35),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.65)
                    : const Color(0xFF0F172A).withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: isDark
                    ? const Color(0xFF0284C7).withValues(alpha: 0.3)
                    : const Color(0xFF2563EB).withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  isScrollable: false,
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
                      title: strings.agendaPolicialTitle,
                      icon: Icons.contact_phone_rounded,
                      accentColor: const Color(0xFF0284C7),
                      badge: 'PNP',
                      isDark: isDark,
                    ),
                    _buildTabItem(
                      index: 1,
                      title: strings.isQuechua ? 'CEM Willaykuna' : 'Directorio CEM',
                      icon: Icons.shield_rounded,
                      accentColor: const Color(0xFF8B5CF6),
                      badge: 'Línea 100',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              // Botón rápido de emergencia SOS 105/114
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Tooltip(
                  message: 'Central de Emergencias SOS 24/7',
                  child: InkWell(
                    onTap: () => SosDialog.show(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emergency_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AgendaPolicialScreen(),
          DirectorioCemScreen(),
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
              scale: 1.0 + 0.02 * t,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF1D4ED8), Color(0xFF0284C7)]
                        : const [Color(0xFF1E40AF), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: isDark
                        ? Color.lerp(
                            const Color(0xFF38BDF8),
                            Colors.white,
                            t,
                          )!.withValues(alpha: 0.80 + 0.20 * t)
                        : Color.lerp(
                            const Color(0xFF1E40AF),
                            const Color(0xFF93C5FD),
                            t,
                          )!.withValues(alpha: 0.80 + 0.20 * t),
                    width: 1.5 + 0.8 * t,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? const Color(0xFF38BDF8).withValues(alpha: 0.35 + 0.40 * t)
                          : const Color(0xFF2563EB).withValues(alpha: 0.28 + 0.38 * t),
                      blurRadius: 10.0 + 12.0 * t,
                      spreadRadius: 1.2 + 2.5 * t,
                      offset: const Offset(0, 1),
                    ),
                    BoxShadow(
                      color: isDark
                          ? const Color(0xFF0284C7).withValues(alpha: 0.5)
                          : const Color(0xFF1E40AF).withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        icon,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.26),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    // Pestaña inactiva
    return Tab(
      height: 48,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.22 : 0.14),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                icon,
                size: 15,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  letterSpacing: 0.1,
                ),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isDark
                      ? accentColor.withValues(alpha: 0.25)
                      : accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
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
}
