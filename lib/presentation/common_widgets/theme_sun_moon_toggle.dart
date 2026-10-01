import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';
import 'scale_on_tap.dart';

/// Widget de botón único para alternar entre Modo Claro y Oscuro.
/// Utiliza iconos estándar de Flutter Material (Icons.light_mode_rounded y Icons.dark_mode_rounded)
/// garantizando visibilidad total y alto contraste en Web y Móvil.
class ThemeSunMoonToggle extends StatelessWidget {
  final bool compact;

  const ThemeSunMoonToggle({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDarkNow = Theme.of(context).brightness == Brightness.dark;

        return Tooltip(
          message: isDarkNow
              ? 'Cambiar a Modo Claro (Día)'
              : 'Cambiar a Modo Oscuro (Noche)',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: ScaleOnTap(
              onTap: () => themeProvider.toggleTheme(context),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isDarkNow
                        ? const [
                            Color(0xFF1E293B),
                            Color(0xFF0F172A),
                          ]
                        : const [
                            Color(0xFFFFFFFF),
                            Color(0xFFF1F5F9),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: isDarkNow
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF0284C7),
                    width: 1.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkNow
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                          : const Color(0xFF0284C7).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return RotationTransition(
                        turns: animation,
                        child: ScaleTransition(
                          scale: animation,
                          child: child,
                        ),
                      );
                    },
                    child: isDarkNow
                        ? const Icon(
                            Icons.light_mode_rounded,
                            key: ValueKey('sun_icon'),
                            size: 22,
                            color: Color(0xFFF59E0B),
                          )
                        : const Icon(
                            Icons.dark_mode_rounded,
                            key: ValueKey('moon_icon'),
                            size: 22,
                            color: Color(0xFF0284C7),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
