import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'scale_on_tap.dart';

class AlToqueNavItem {
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final Color activeColor;
  final bool isSpecialAction;

  const AlToqueNavItem({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.activeColor,
    this.isSpecialAction = false,
  });
}

/// Barra inferior con dock 3D táctil, cuna líquida continua (notch dinámico) y
/// burbuja circular elevada 3D con halo radial luminoso, porteada directamente
/// del sistema de diseño interactivo de "AlToque".
class AlToqueElevatedBottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final VoidCallback? onMenuTap;
  final List<AlToqueNavItem> items;

  const AlToqueElevatedBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.onMenuTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxDockWidth = math.min(screenWidth - 24, 460.0);

    // Comprobar si el índice seleccionado corresponde a un botón del dock
    final isIndexValid = selectedIndex >= 0 && selectedIndex < items.length;
    final activeItem = isIndexValid ? items[selectedIndex] : items.first;
    final activeColor = activeItem.activeColor;
    final effectiveIndex = isIndexValid ? selectedIndex.toDouble() : 0.0;

    return SafeArea(
      bottom: true,
      child: RepaintBoundary(
        child: Container(
          height: 78,
          alignment: Alignment.bottomCenter,
          margin: const EdgeInsets.only(bottom: 6),
          child: SizedBox(
            width: maxDockWidth,
            height: 78,
            child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ==========================================================
              // CAPA 1 & 2: DOCK CURVO 3D (CUNA LÍQUIDA + SOMBRA + BISEL)
              // ==========================================================
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 64,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: effectiveIndex,
                    end: effectiveIndex,
                  ),
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedIndex, child) {
                    return CustomPaint(
                      painter: _AlToqueDockPainter(
                        activeIndex: animatedIndex,
                        itemCount: items.length,
                        isDark: isDark,
                        activeColor: activeColor,
                        hasActiveSelection: isIndexValid,
                      ),
                      child: const SizedBox.expand(),
                    );
                  },
                ),
              ),

              // ==========================================================
              // CAPA 3: BURBUJA CIRCULAR ELEVADA 3D CON HALO RADIAL LUMINOSO
              // ==========================================================
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: effectiveIndex,
                  end: effectiveIndex,
                ),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                builder: (context, animatedIndex, child) {
                  final columnWidth = maxDockWidth / items.length;
                  final bubbleCenterX = (animatedIndex + 0.5) * columnWidth;
                  const bubbleSize = 52.0;

                  return Positioned(
                    left: bubbleCenterX - (bubbleSize / 2),
                    top: 2, // Elevación sobre el dock
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: isIndexValid ? 1.0 : 0.0,
                      child: child!,
                    ),
                  );
                },
                child: _buildElevated3DBubble(activeItem, activeColor, isDark),
              ),

              // ==========================================================
              // CAPA 4: BOTONES INTERACTIVOS (GRID DE 5 COLUMNAS)
              // ==========================================================
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 64,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final isActive = selectedIndex == index;

                    return Expanded(
                      child: ScaleOnTap(
                        scaleFactor: 0.92,
                        onTap: () {
                          if (item.isSpecialAction && onMenuTap != null) {
                            onMenuTap!();
                          } else {
                            onItemSelected(index);
                          }
                        },
                        child: _buildNavItemButton(
                          item: item,
                          isActive: isActive,
                          isDark: isDark,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  /// Construye la burbuja 3D flotante con halo radiante y relieve especular
  Widget _buildElevated3DBubble(
    AlToqueNavItem item,
    Color activeColor,
    bool isDark,
  ) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. Resplandor / Halo luminoso radial
          // 1. Resplandor / Halo luminoso radial Neón Multicapa
          Positioned(
            top: -9,
            bottom: -9,
            left: -9,
            right: -9,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: isDark ? 0.85 : 0.70),
                    blurRadius: isDark ? 22 : 18,
                    spreadRadius: isDark ? 3.0 : 2.0,
                  ),
                  BoxShadow(
                    color: activeColor.withValues(alpha: isDark ? 0.55 : 0.40),
                    blurRadius: 36,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),

          // 2. Botón Circular 3D con doble bisel especular
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(activeColor, Colors.white, 0.45)!,
                  activeColor,
                  Color.lerp(activeColor, Colors.black, 0.22)!,
                ],
              ),
              boxShadow: [
                // Sombra de profundidad
                BoxShadow(
                  color: activeColor.withValues(alpha: isDark ? 0.60 : 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
                // Bisel especular superior (Luz cenital)
                const BoxShadow(
                  color: Colors.white,
                  blurRadius: 2,
                  spreadRadius: -1,
                  offset: Offset(0, 1.5),
                ),
                // Bisel inferior de contacto
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 3,
                  spreadRadius: -1,
                  offset: const Offset(0, -1.5),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.65),
                width: 1.4,
              ),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: CurvedAnimation(
                      parent: animation,
                      curve: Curves.elasticOut,
                    ),
                    child: child,
                  );
                },
                child: Icon(
                  item.activeIcon,
                  key: ValueKey(item.label),
                  color: Colors.white,
                  size: 27,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.50),
                      blurRadius: 6,
                      offset: const Offset(0, 2.5),
                    ),
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.80),
                      blurRadius: 3,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye cada botón individual dentro del dock
  Widget _buildNavItemButton({
    required AlToqueNavItem item,
    required bool isActive,
    required bool isDark,
  }) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.only(bottom: 5, top: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Icono inactivo con micro-cápsula táctil de color Neón sutil y vistosa
          AnimatedOpacity(
            duration: const Duration(milliseconds: 240),
            opacity: isActive ? 0.0 : 1.0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 240),
              offset: isActive ? const Offset(0, 0.35) : Offset.zero,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      item.activeColor.withValues(alpha: isDark ? 0.25 : 0.18),
                      item.activeColor.withValues(alpha: isDark ? 0.10 : 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: item.activeColor.withValues(alpha: isDark ? 0.55 : 0.40),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: item.activeColor.withValues(alpha: isDark ? 0.30 : 0.20),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    item.inactiveIcon,
                    size: 20,
                    color: isDark
                        ? Color.lerp(item.activeColor, Colors.white, 0.20)
                        : item.activeColor,
                    shadows: [
                      Shadow(
                        color: item.activeColor.withValues(alpha: isDark ? 0.70 : 0.40),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 3),

          // Etiqueta de texto con escala dinámica, peso y sombra neón
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: isActive ? 10.8 : 9.8,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
              color: isActive
                  ? item.activeColor
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155)),
              letterSpacing: 0.2,
              shadows: isActive
                  ? [
                      Shadow(
                        color: item.activeColor.withValues(alpha: isDark ? 0.70 : 0.45),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter para el dock curvado continuo con cuna líquida (notch)
class _AlToqueDockPainter extends CustomPainter {
  final double activeIndex;
  final int itemCount;
  final bool isDark;
  final Color activeColor;
  final bool hasActiveSelection;

  _AlToqueDockPainter({
    required this.activeIndex,
    required this.itemCount,
    required this.isDark,
    required this.activeColor,
    this.hasActiveSelection = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final columnWidth = w / itemCount;
    final xc = (activeIndex + 0.5) * columnWidth;

    // Dimensiones de la cuna líquida idénticas a AlToque
    const cradleRadius = 31.0;
    final x1 = (xc - cradleRadius).clamp(16.0, w - 16.0);
    final x2 = (xc + cradleRadius).clamp(16.0, w - 16.0);
    const topY = 12.0;
    const dipY = 38.0;
    const cornerR = 24.0;

    // =========================================================================
    // 1. SILUETA CONTINUA DEL DOCK (BÉZIER CÚBICO)
    // =========================================================================
    final path = Path();
    path.moveTo(0, topY + cornerR);

    // Esquina superior izquierda
    path.cubicTo(0, topY + 6, 6, topY, cornerR, topY);

    if (hasActiveSelection) {
      // Tramo horizontal hasta la entrada de la cuna
      path.lineTo(x1, topY);

      // Cuna líquida (Bajada suave, fondo cóncavo y subida fluida)
      path.cubicTo(
        xc - 17.0,
        topY,
        xc - 13.0,
        dipY,
        xc,
        dipY,
      );
      path.cubicTo(
        xc + 13.0,
        dipY,
        xc + 17.0,
        topY,
        x2,
        topY,
      );
    }

    // Tramo horizontal hasta la esquina superior derecha
    path.lineTo(w - cornerR, topY);
    path.cubicTo(w - 6, topY, w, topY + 6, w, topY + cornerR);

    // Esquinas inferiores y base
    path.lineTo(w, h - 8);
    path.cubicTo(w, h, w - 8, h, w - 16, h);
    path.lineTo(16, h);
    path.cubicTo(8, h, 0, h, 0, h - 8);
    path.close();

    // =========================================================================
    // 2. SOMBRA DE PROFUNDIDAD TÁCTIL 3D (MULTICAPA CON AURA NEÓN)
    // =========================================================================
    if (isDark) {
      // 1. Sombra base negra
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.70)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawPath(path.shift(const Offset(0, 6)), shadowPaint);

      // 2. Resplandor Neón ambiental teñido con el color activo
      final darkNeonGlowPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawPath(path.shift(const Offset(0, 4)), darkNeonGlowPaint);
    } else {
      // En modo claro:
      // 1. Sombra de contacto nítida para delimitar perfectamente el contorno exterior
      final contactShadowPaint = Paint()
        ..color = const Color(0xFF0F172A).withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(path.shift(const Offset(0, 2)), contactShadowPaint);

      // 2. Resplandor Neón ambiental de elevación teñido con el color activo
      final neonGlowShadowPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawPath(path.shift(const Offset(0, 5)), neonGlowShadowPaint);

      // 3. Sombra difusa de elevación para flotación física 3D
      final elevationShadowPaint = Paint()
        ..color = const Color(0xFF1E3A8A).withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
      canvas.drawPath(path.shift(const Offset(0, 8)), elevationShadowPaint);
    }

    // =========================================================================
    // 3. FONDO 3D CON DEGRADADO CENITAL (LUMINOSO Y CRISTALINO)
    // =========================================================================
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? const [
              Color(0xFF1E293B),
              Color(0xFF0F172A),
              Color(0xFF070B14),
            ]
          : const [
              Color(0xFFFFFFFF),
              Color(0xFFF8FAFC),
              Color(0xFFEFF6FF), // Toque azul hielo brillante de policía
            ],
      stops: const [0.0, 0.40, 1.0],
    );

    final bgPaint = Paint()
      ..shader = bgGradient.createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, bgPaint);

    // =========================================================================
    // 3.5. MICRO-PATRÓN TÁCTIL 3D (AlToque .tactile-surface-3d optimizado en batch)
    // =========================================================================
    canvas.save();
    canvas.clipPath(path);
    const dotSpacing = 10.0;
    const dotRadius = 0.9;
    final dotColor = isDark
        ? Colors.white.withValues(alpha: 0.065)
        : const Color(0xFF475569).withValues(alpha: 0.12);
    final dotPaint = Paint()
      ..color = dotColor
      ..strokeWidth = dotRadius * 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final points = <Offset>[];
    for (double x = 0; x <= w; x += dotSpacing) {
      for (double y = 0; y <= h; y += dotSpacing) {
        points.add(Offset(x, y));
      }
    }
    if (points.isNotEmpty) {
      canvas.drawPoints(ui.PointMode.points, points, dotPaint);
    }
    canvas.restore();

    // =========================================================================
    // 3.8. RESPLANDOR NEÓN AMBIENTAL EN LA CUNA LÍQUIDA (Halo reactivo)
    // =========================================================================
    if (hasActiveSelection) {
      final cradleNeonPaint = Paint()
        ..color = activeColor.withValues(alpha: isDark ? 0.38 : 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(Offset(xc, dipY - 2), cradleRadius + 4, cradleNeonPaint);
    }

    // =========================================================================
    // 4. BISEL DE BRILLO ESPECULAR SUPERIOR 3D (Luz reflejada de AlToque)
    // =========================================================================
    final topHighlightPath = Path();
    topHighlightPath.moveTo(cornerR, topY);
    if (hasActiveSelection) {
      topHighlightPath.lineTo(x1, topY);
      topHighlightPath.cubicTo(
        xc - 17.0,
        topY,
        xc - 13.0,
        dipY,
        xc,
        dipY,
      );
      topHighlightPath.cubicTo(
        xc + 13.0,
        dipY,
        xc + 17.0,
        topY,
        x2,
        topY,
      );
    }
    topHighlightPath.lineTo(w - cornerR, topY);

    if (isDark) {
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(topHighlightPath, highlightPaint);
    } else {
      // En modo claro, un brillo interior limpio
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(topHighlightPath, highlightPaint);
    }

    // =========================================================================
    // 5. CONTORNO PERIMETRAL TÁCTIL NÍTIDO CON HALO NEÓN EN TODO EL BORDE
    // =========================================================================
    // 1. Resplandor difuso exterior Neón alrededor de todo el borde del dock
    final outerNeonGlowPaint = Paint()
      ..color = (isDark
              ? const Color(0xFF38BDF8)
              : const Color(0xFF0284C7))
          .withValues(alpha: isDark ? 0.35 : 0.26)
      ..strokeWidth = 4.2
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawPath(path, outerNeonGlowPaint);

    // 2. Resplandor intermedio Neón concentrado
    final innerNeonGlowPaint = Paint()
      ..color = (isDark
              ? const Color(0xFF06B6D4)
              : const Color(0xFF38BDF8))
          .withValues(alpha: isDark ? 0.50 : 0.40)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawPath(path, innerNeonGlowPaint);

    // 3. Trazo perimetral central nítido con color neón institucional
    final borderPaint = Paint()
      ..color = isDark
          ? const Color(0xFF38BDF8).withValues(alpha: 0.85)
          : const Color(0xFF0284C7).withValues(alpha: 0.70)
      ..strokeWidth = isDark ? 1.3 : 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _AlToqueDockPainter oldDelegate) {
    return oldDelegate.activeIndex != activeIndex ||
        oldDelegate.itemCount != itemCount ||
        oldDelegate.isDark != isDark ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.hasActiveSelection != hasActiveSelection;
  }
}
