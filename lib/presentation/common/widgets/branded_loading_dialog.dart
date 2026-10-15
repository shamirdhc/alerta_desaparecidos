import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

/// Diálogo y widget de carga institucional con el logo circular de la Policía y Alerta Desaparecidos
class BrandedLoadingWidget extends StatefulWidget {
  final String? message;
  final String? submessage;
  final double size;

  const BrandedLoadingWidget({
    super.key,
    this.message,
    this.submessage,
    this.size = 68,
  });

  @override
  State<BrandedLoadingWidget> createState() => _BrandedLoadingWidgetState();
}

class _BrandedLoadingWidgetState extends State<BrandedLoadingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Contenedor del logo con halo de luz y anillo giratorio
            Stack(
              alignment: Alignment.center,
              children: [
                // Resplandor pulsante cálido y visible
                Container(
                  width: widget.size * 1.55,
                  height: widget.size * 1.55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: _glowAnimation.value * 0.45),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: _glowAnimation.value * 0.3),
                        blurRadius: 38,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),

                // Anillo de progreso exterior
                SizedBox(
                  width: widget.size + 26,
                  height: widget.size + 26,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.8,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                    backgroundColor: Colors.black12,
                  ),
                ),

                // Logo circular con respiración
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      border: Border.all(color: const Color(0xFF38BDF8), width: 2.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(5),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/icons/icon_police.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.shield_rounded,
                          color: Color(0xFF0284C7),
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (widget.message != null && widget.message!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                widget.message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: 0.2,
                ),
              ),
            ],

            if (widget.submessage != null && widget.submessage!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.submessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  height: 1.35,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Administrador estático para mostrar/ocultar el diálogo de carga institucional
/// Implementado con OverlayEntry síncrono, filtro de cristal y temporizador de seguridad.
class BrandedLoadingOverlay {
  static OverlayEntry? _currentEntry;
  static bool _isVisible = false;
  static Timer? _safetyTimer;
  static final ValueNotifier<String> _messageNotifier = ValueNotifier<String>('Cargando...');
  static final ValueNotifier<String?> _submessageNotifier = ValueNotifier<String?>(null);

  static bool get isVisible => _isVisible;

  static void show(
    BuildContext context, {
    String message = 'Cargando...',
    String? submessage,
    int timeoutSeconds = 12,
  }) {
    hide();

    try {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) return;

      _messageNotifier.value = message;
      _submessageNotifier.value = submessage;

      final isDark = Theme.of(context).brightness == Brightness.dark;

      _currentEntry = OverlayEntry(
        builder: (ctx) => Stack(
          children: [
            // Fondo con desenfoque de cristal (BackdropFilter)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.52),
                ),
              ),
            ),
            // Contenedor de carga centrado
            Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
                  constraints: const BoxConstraints(maxWidth: 380),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B).withValues(alpha: 0.96)
                        : Colors.white.withValues(alpha: 0.98),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF38BDF8).withValues(alpha: 0.25)
                          : const Color(0xFF0284C7).withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_messageNotifier, _submessageNotifier]),
                    builder: (context, _) {
                      return BrandedLoadingWidget(
                        message: _messageNotifier.value,
                        submessage: _submessageNotifier.value,
                        size: 72,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      overlay.insert(_currentEntry!);
      _isVisible = true;

      // Temporizador de seguridad: si tras timeoutSeconds no se cerró, se auto-destruye
      _safetyTimer?.cancel();
      _safetyTimer = Timer(Duration(seconds: timeoutSeconds), () {
        if (_isVisible) {
          hide();
        }
      });
    } catch (e) {
      debugPrint('Aviso en BrandedLoadingOverlay.show: $e');
    }
  }

  /// Actualiza los mensajes del overlay activo en tiempo real sin parpadeos
  static void update({required String message, String? submessage}) {
    if (_isVisible) {
      _messageNotifier.value = message;
      _submessageNotifier.value = submessage;
    }
  }

  static void hide() {
    _safetyTimer?.cancel();
    _safetyTimer = null;
    _isVisible = false;
    if (_currentEntry != null) {
      try {
        _currentEntry?.remove();
      } catch (_) {}
      _currentEntry = null;
    }
  }
}
