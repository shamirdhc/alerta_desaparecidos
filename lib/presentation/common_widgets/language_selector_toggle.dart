import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'scale_on_tap.dart';

class LanguageSelectorToggle extends StatelessWidget {
  const LanguageSelectorToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageService>(
      builder: (context, langService, _) {
        final isQuechua = langService.isQuechua;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Tooltip(
          message: isQuechua
              ? 'Kutiy Castellano simiman (Cambiar a Español)'
              : 'Cambiar a Runasimi (Quechua)',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: ScaleOnTap(
              onTap: () {
                HapticFeedback.lightImpact();
                langService.toggleLanguage();
              },
              child: Container(
                height: 38,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.9)
                      : const Color(0xFFF1F5F9),
                  border: Border.all(
                    color: isQuechua
                        ? const Color(0xFF10B981)
                        : (isDark
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.5)
                            : const Color(0xFF0284C7).withValues(alpha: 0.5)),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isQuechua
                          ? const Color(0xFF10B981).withValues(alpha: 0.25)
                          : const Color(0xFF00E5FF).withValues(alpha: 0.20),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Opción ES
                    _buildPill(
                      label: 'ES',
                      flag: '🇵🇪',
                      isSelected: !isQuechua,
                      activeColor: const Color(0xFF0284C7),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 2),
                    // Opción QU
                    _buildPill(
                      label: 'QU',
                      flag: '🌾',
                      isSelected: isQuechua,
                      activeColor: const Color(0xFF10B981),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPill({
    required String label,
    required String flag,
    required bool isSelected,
    required Color activeColor,
    required bool isDark,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isSelected ? activeColor : Colors.transparent,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(flag, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
