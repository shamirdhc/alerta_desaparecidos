import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/theme_service.dart';
import '../../common/styles/app_colors.dart';

/// Modal moderno e interactivo para la selección del tema visual
/// (Claro / Oscuro / Predeterminado del Sistema)
class ThemeSelectionDialog extends StatelessWidget {
  const ThemeSelectionDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const ThemeSelectionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.18),
            blurRadius: 36,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tirador superior (Drag Handle)
                  Center(
                    child: Container(
                      width: 48,
                      height: 4.5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Cabecera institucional con sol y luna
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFF3B82F6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(
                              FontAwesomeIcons.solidSun,
                              color: Colors.white,
                              size: 15,
                            ),
                            SizedBox(width: 4),
                            FaIcon(
                              FontAwesomeIcons.solidMoon,
                              color: Colors.white,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Apariencia y Tema',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppColors.policeNavy,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Elige el modo que mejor se adapte a tu vista',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                            size: 18,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // TARJETA 1: MODO CLARO (☀️ Sol)
                  _buildThemeOptionCard(
                    context: context,
                    title: 'Modo Claro',
                    badge: 'DÍA',
                    description: 'Fondo blanco pulcro, máximo contraste y nitidez visual para ambientes iluminados.',
                    icon: FontAwesomeIcons.solidSun,
                    iconGradient: const [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                    accentColor: const Color(0xFFF59E0B),
                    isSelected: themeProvider.themeMode == ThemeMode.light,
                    isDarkContext: isDark,
                    miniPreviewColors: const [Colors.white, Color(0xFF0A3981), Color(0xFFE2E8F0)],
                    onTap: () {
                      themeProvider.setThemeMode(ThemeMode.light);
                    },
                  ),

                  const SizedBox(height: 11),

                  // TARJETA 2: MODO OSCURO (🌙 Luna)
                  _buildThemeOptionCard(
                    context: context,
                    title: 'Modo Oscuro',
                    badge: 'NOCHE',
                    description: 'Fondo táctico profundo, reduce la fatiga visual nocturna y ahorra batería.',
                    icon: FontAwesomeIcons.solidMoon,
                    iconGradient: const [Color(0xFF818CF8), Color(0xFF4F46E5)],
                    accentColor: const Color(0xFF38BDF8),
                    isSelected: themeProvider.themeMode == ThemeMode.dark,
                    isDarkContext: isDark,
                    miniPreviewColors: const [Color(0xFF0A0F1D), Color(0xFF1E293B), Color(0xFF38BDF8)],
                    onTap: () {
                      themeProvider.setThemeMode(ThemeMode.dark);
                    },
                  ),

                  const SizedBox(height: 11),

                  // TARJETA 3: AUTOMÁTICO DEL SISTEMA (🌓)
                  _buildThemeOptionCard(
                    context: context,
                    title: 'Predeterminado del Sistema',
                    badge: 'AUTO',
                    description: 'Sincroniza automáticamente la apariencia con la configuración de tu teléfono o PC.',
                    icon: FontAwesomeIcons.circleHalfStroke,
                    iconGradient: const [Color(0xFF38BDF8), Color(0xFF6366F1)],
                    accentColor: const Color(0xFF818CF8),
                    isSelected: themeProvider.themeMode == ThemeMode.system,
                    isDarkContext: isDark,
                    miniPreviewColors: const [Color(0xFFE2E8F0), Color(0xFF0F172A), Color(0xFF64748B)],
                    onTap: () {
                      themeProvider.setThemeMode(ThemeMode.system);
                    },
                  ),

                  const SizedBox(height: 18),

                  // Botón de confirmación / cierre elegante
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF1E293B)
                            : AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Listo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOptionCard({
    required BuildContext context,
    required String title,
    required String badge,
    required String description,
    required IconData icon,
    required List<Color> iconGradient,
    required Color accentColor,
    required bool isSelected,
    required bool isDarkContext,
    required List<Color> miniPreviewColors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDarkContext
                    ? accentColor.withValues(alpha: 0.16)
                    : accentColor.withValues(alpha: 0.08))
                : (isDarkContext
                    ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                    : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : (isDarkContext
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.shade200),
              width: isSelected ? 1.8 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: isDarkContext ? 0.25 : 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icono con gradiente celestial
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: iconGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: iconGradient.last.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: FaIcon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Contenido descriptivo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDarkContext ? Colors.white : AppColors.policeNavy,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accentColor.withValues(alpha: 0.2)
                                : (isDarkContext
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? accentColor
                                  : (isDarkContext ? Colors.white70 : Colors.grey.shade700),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: isDarkContext
                            ? const Color(0xFF94A3B8)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Indicador de selección (Checkmark animado o radio)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? accentColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? accentColor
                        : (isDarkContext ? Colors.white30 : Colors.grey.shade400),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Center(
                        child: FaIcon(
                          FontAwesomeIcons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
