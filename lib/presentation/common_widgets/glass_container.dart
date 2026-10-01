import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 🪟 GlassContainer: Contenedor con efecto de cristal esmerilado (Glassmorphism)
/// de alto rendimiento, optimizado para GPU (CanvasKit & Native Flutter)
/// con adaptación automática a Modo Claro y Modo Oscuro y borde especular táctico.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double blur;
  final Color? customColor;
  final Border? customBorder;
  final List<BoxShadow>? customShadow;
  final VoidCallback? onTap;
  final bool showSpecularBorder;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur = 14.0,
    this.customColor,
    this.customBorder,
    this.customShadow,
    this.onTap,
    this.showSpecularBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(22);

    // Paleta translúcida adaptativa de alta pureza
    final defaultBgColor = isDark
        ? const Color(0xFF0F172A).withValues(alpha: 0.78)
        : Colors.white.withValues(alpha: 0.88);

    final defaultBorder = customBorder ??
        Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.75),
          width: 1.2,
        );

    final defaultShadow = customShadow ??
        [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.40)
                : const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.60),
              blurRadius: 10,
              spreadRadius: -2,
              offset: const Offset(0, -2),
            ),
        ];

    Widget content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: customColor ?? defaultBgColor,
            borderRadius: radius,
            border: defaultBorder,
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () {
            HapticFeedback.lightImpact();
            onTap!();
          },
          child: content,
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: defaultShadow,
      ),
      child: content,
    );
  }
}

/// 📱 GlassCard: Tarjeta interactiva con micro-escala animada (bounce & haptic feedback on tap)
class GlassCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;
  final Border? border;
  final List<BoxShadow>? shadow;
  final double blur;
  final bool enableHaptic;

  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.border,
    this.shadow,
    this.blur = 14.0,
    this.enableHaptic = true,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      if (widget.enableHaptic) {
        HapticFeedback.selectionClick();
      }
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap != null
            ? () {
                if (widget.enableHaptic) {
                  HapticFeedback.lightImpact();
                }
                widget.onTap!();
              }
            : null,
        behavior: HitTestBehavior.opaque,
        child: GlassContainer(
          padding: widget.padding,
          margin: widget.margin,
          borderRadius: widget.borderRadius,
          blur: widget.blur,
          customColor: widget.color,
          customBorder: widget.border,
          customShadow: widget.shadow,
          child: widget.child,
        ),
      ),
    );
  }
}
