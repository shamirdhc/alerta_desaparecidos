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
    this.size = 64,
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

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.04).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
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
                // Resplandor pulsante
                Container(
                  width: widget.size * 1.5,
                  height: widget.size * 1.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(_glowAnimation.value * 0.4),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(_glowAnimation.value * 0.25),
                        blurRadius: 36,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),

                // Anillo de progreso exterior
                SizedBox(
                  width: widget.size + 24,
                  height: widget.size + 24,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                    backgroundColor: Colors.white12,
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
                      border: Border.all(color: const Color(0xFF38BDF8), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/icons/icon_police.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.shield_rounded,
                          color: Color(0xFF0284C7),
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (widget.message != null) ...[
              const SizedBox(height: 18),
              Text(
                widget.message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: 0.3,
                ),
              ),
            ],

            if (widget.submessage != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.submessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
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
/// Implementado con OverlayEntry síncrono y temporizador de seguridad para evitar
/// bloqueos de interfaz o desincronizaciones en el Navigator.
class BrandedLoadingOverlay {
  static OverlayEntry? _currentEntry;
  static bool _isVisible = false;

  static void show(
    BuildContext context, {
    String message = 'Cargando...',
    String? submessage,
  }) {
    hide();

    try {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) return;

      final isDark = Theme.of(context).brightness == Brightness.dark;

      _currentEntry = OverlayEntry(
        builder: (ctx) => Stack(
          children: [
            // Fondo semi-transparente
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  // Permite cerrar en caso extremo si el usuario toca la pantalla
                },
                child: Container(
                  color: Colors.black.withOpacity(0.65),
                ),
              ),
            ),
            // Contenedor de carga
            Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B).withOpacity(0.96) : Colors.white.withOpacity(0.97),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: BrandedLoadingWidget(
                    message: message,
                    submessage: submessage,
                    size: 68,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      overlay.insert(_currentEntry!);
      _isVisible = true;

      // Temporizador de seguridad: si tras 7 segundos no se cerró, se auto-destruye para proteger al usuario
      Future.delayed(const Duration(seconds: 7), () {
        if (_isVisible) {
          hide();
        }
      });
    } catch (e) {
      debugPrint('Aviso en BrandedLoadingOverlay.show: $e');
    }
  }

  static void hide() {
    _isVisible = false;
    if (_currentEntry != null) {
      try {
        _currentEntry?.remove();
      } catch (_) {}
      _currentEntry = null;
    }
  }
}
