import 'package:flutter/material.dart';

/// Contenedor táctil 3D inspirado en `.tactile-surface-3d` de AlToque.
/// Dibuja una micro-trama de puntos matriciales sutiles sobre un degradado vertical
/// y un bisel especular superior de iluminación 3D.
class TactileSurfaceContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<Color>? customGradientColors;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final bool showBevelHighlight;
  final double dotSpacing;
  final double dotRadius;

  const TactileSurfaceContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius,
    this.padding,
    this.margin,
    this.customGradientColors,
    this.border,
    this.boxShadow,
    this.showBevelHighlight = true,
    this.dotSpacing = 10.0,
    this.dotRadius = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultGradient = customGradientColors ??
        (isDark
            ? const [
                Color(0xFF1E293B), // Slate 800
                Color(0xFF0F172A), // Slate 900
                Color(0xFF0B0F19), // Midnight
              ]
            : const [
                Color(0xFFFFFFFF),
                Color(0xFFF8FAFC),
                Color(0xFFF1F5F9),
              ]);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: CustomPaint(
          painter: _TactileSurfacePainter(
            gradientColors: defaultGradient,
            isDark: isDark,
            dotSpacing: dotSpacing,
            dotRadius: dotRadius,
            showBevelHighlight: showBevelHighlight,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              border: border,
              borderRadius: borderRadius,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _TactileSurfacePainter extends CustomPainter {
  final List<Color> gradientColors;
  final bool isDark;
  final double dotSpacing;
  final double dotRadius;
  final bool showBevelHighlight;

  _TactileSurfacePainter({
    required this.gradientColors,
    required this.isDark,
    required this.dotSpacing,
    required this.dotRadius,
    required this.showBevelHighlight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Degradado cenital 180° (Fondo con profundidad)
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: gradientColors,
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, bgPaint);

    // 2. Micro-patrón táctil de puntos (Rejilla matricial 3D de AlToque)
    final dotColor = isDark
        ? Colors.white.withValues(alpha: 0.055)
        : const Color(0xFF64748B).withValues(alpha: 0.12);

    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    final cols = (size.width / dotSpacing).ceil();
    final rows = (size.height / dotSpacing).ceil();

    for (int i = 0; i <= cols; i++) {
      final double x = i * dotSpacing;
      for (int j = 0; j <= rows; j++) {
        final double y = j * dotSpacing;
        canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
      }
    }

    // 3. Bisel de iluminación especular superior 3D (Luz reflejada)
    if (showBevelHighlight && size.height > 2) {
      final highlightPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: isDark
              ? [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.16),
                  Colors.white.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.16),
                  Colors.transparent,
                ]
              : [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.60),
                  Colors.white.withValues(alpha: 0.90),
                  Colors.white.withValues(alpha: 0.60),
                  Colors.transparent,
                ],
          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, 1.5))
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        const Offset(0, 0.75),
        Offset(size.width, 0.75),
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TactileSurfacePainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.gradientColors != gradientColors ||
        oldDelegate.dotSpacing != dotSpacing ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.showBevelHighlight != showBevelHighlight;
  }
}
