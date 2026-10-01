import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onFinished;

  const SplashScreen({super.key, this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // 1. Animación de vuelo y levitación heroica del policía
  late AnimationController _flightController;
  late Animation<double> _flightAnimation;
  late Animation<double> _tiltAnimation;

  // 2. Animación de pulso, halo de energía y respiración luminosa
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // 3. Rotación continua de los nodos orbitales (red ciudadana)
  late AnimationController _orbitController;

  // 4. Ondas de radar expansivas (búsqueda continua)
  late AnimationController _radarController;

  // 5. Animación de entrada inicial de elementos (Fade + Slide)
  late AnimationController _entranceController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideUpAnimation;

  // 6. Barra de progreso tecnológica continua
  late AnimationController _progressController;

  // Mensajes rotativos inspiradores y de acción ciudadana
  final List<String> _inspirationalMessages = [
    "Cada minuto cuenta • Tu alerta salva vidas",
    "Conectando familias y comisarías en todo el Perú",
    "Línea 114 PNP gratuita y activa las 24 horas",
    "Tecnología y solidaridad comunitaria",
    "Juntos somos la esperanza de encontrarlos",
  ];
  int _currentMessageIndex = 0;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();

    // Entrada suave e instantánea (0 lag)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeInAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _slideUpAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack,
    ));
    _entranceController.forward();

    // 1. Vuelo y balanceo del policía con capa
    _flightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _flightAnimation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _flightController, curve: Curves.easeInOutSine),
    );

    // Inclinación sutil de vuelo dinámico (-2.5° a +2.5°)
    _tiltAnimation = Tween<double>(begin: -0.04, end: 0.04).animate(
      CurvedAnimation(parent: _flightController, curve: Curves.easeInOutSine),
    );

    // 2. Pulso de halo de energía
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 3. Órbita continua de partículas y red de búsqueda
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // 4. Ondas de radar de búsqueda
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    // 5. Barra de progreso fluida
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // Rotación de mensajes cada 2.2 segundos
    _messageTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (mounted) {
        setState(() {
          _currentMessageIndex =
              (_currentMessageIndex + 1) % _inspirationalMessages.length;
        });
      }
    });

    // Soporte para callback externo si se especificó
    if (widget.onFinished != null) {
      Timer(const Duration(milliseconds: 3200), () {
        if (mounted) {
          widget.onFinished!();
        }
      });
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _entranceController.dispose();
    _flightController.dispose();
    _pulseController.dispose();
    _orbitController.dispose();
    _radarController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF051124),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. FONDO DEGRADADO ULTRA-PROFUNDO Y TECNOLÓGICO
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.25,
                colors: [
                  Color(0xFF0F3066), // Azul policial iluminado
                  Color(0xFF0A1E3F), // Navy táctico
                  Color(0xFF061021), // Midnight blue profundo
                  Color(0xFF020710), // Base oscura
                ],
                stops: [0.0, 0.4, 0.75, 1.0],
              ),
            ),
          ),

          // 2. ONDAS DE RADAR DE BÚSQUEDA PNP (EN MOVIMIENTO CONTINUO)
          AnimatedBuilder(
            animation: _radarController,
            builder: (context, _) {
              return CustomPaint(
                painter: _RadarWavesPainter(_radarController.value),
                size: Size.infinite,
              );
            },
          ),

          // 3. PARTÍCULAS FLOTANTES DE LA RED CIUDADANA Y ESPERANZA
          AnimatedBuilder(
            animation: _orbitController,
            builder: (context, _) {
              return CustomPaint(
                painter: _CommunityParticlesPainter(_orbitController.value),
                size: Size.infinite,
              );
            },
          ),

          // 4. CONTENIDO PRINCIPAL CENTRADO
          SafeArea(
            child: FadeTransition(
              opacity: _fadeInAnimation,
              child: SlideTransition(
                position: _slideUpAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // BADGE SUPERIOR: SISTEMA OFICIAL PNP
                      _buildInstitutionalBadge(),

                      const SizedBox(height: 24),

                      // HÉROE CENTRAL: EL POLICÍA SUPERHÉROE CON CAPA
                      _buildHeroPoliceMascot(size),

                      const SizedBox(height: 28),

                      // TÍTULO DE IMPACTO CON SOMBRA LUMINOSA
                      _buildAppTitle(),

                      const SizedBox(height: 10),

                      // SUBTÍTULO DE LA RED NACIONAL
                      const Text(
                        'RED NACIONAL DE BÚSQUEDA Y SOLIDARIDAD',
                        style: TextStyle(
                          color: Color(0xFF64B5F6),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const Spacer(flex: 2),

                      // CÁPSULA GLASSMÓRFICA DE MENSAJES ROTATIVOS
                      _buildInspirationalCarousel(),

                      const SizedBox(height: 24),

                      // BARRA DE CARGA CIBERNÉTICA Y ESTADO
                      _buildModernLoadingTrack(),

                      const SizedBox(height: 12),

                      // PIE DE PÁGINA INSTITUCIONAL
                      _buildFooterInfo(),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Insignia superior institucional
  Widget _buildInstitutionalBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFFD4AF37).withOpacity(0.55), // Oro pulido
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.18),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.people_alt_rounded,
            color: Color(0xFFFFD700), // Dorado
            size: 15,
          ),
          SizedBox(width: 8),
          Text(
            'PLATAFORMA CIUDADANA COLABORATIVA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // Mascota heroica animada: policía con capa y órbita de nodos de energía
  Widget _buildHeroPoliceMascot(Size screenSize) {
    final mascotSize = math.min(screenSize.width * 0.46, 175.0);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _flightAnimation,
        _tiltAnimation,
        _pulseAnimation,
        _orbitController,
      ]),
      builder: (context, child) {
        final floatProgress = (_flightAnimation.value + 10.0) / 20.0;

        return SizedBox(
          width: mascotSize + 50,
          height: mascotSize + 55,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // A. Sombra dinámica en la base
              Positioned(
                bottom: 6,
                child: Opacity(
                  opacity: 0.25 + (0.35 * (1.0 - floatProgress)),
                  child: Container(
                    width: (mascotSize * 0.65) *
                        (0.8 + (0.3 * (1.0 - floatProgress))),
                    height: 14 * (0.8 + (0.3 * (1.0 - floatProgress))),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(mascotSize * 0.65, 14),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withOpacity(0.2),
                          blurRadius: 14 + (8 * floatProgress),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // B. Personaje flotando y balanceándose en vuelo heroico
              Transform.translate(
                offset: Offset(0, _flightAnimation.value),
                child: Transform.rotate(
                  angle: _tiltAnimation.value,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Halo de resplandor expansivo cian y azul
                      Transform.scale(
                        scale: _pulseAnimation.value * 1.12,
                        child: Container(
                          width: mascotSize + 22,
                          height: mascotSize + 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF00E5FF).withOpacity(0.55),
                                const Color(0xFF1D4ED8).withOpacity(0.25),
                                Colors.transparent,
                              ],
                              stops: const [0.45, 0.75, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Anillo orbital giratorio con nodos satélites (red comunitaria)
                      Transform.rotate(
                        angle: _orbitController.value * 2 * math.pi,
                        child: SizedBox(
                          width: mascotSize + 36,
                          height: mascotSize + 36,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF00E5FF)
                                        .withOpacity(0.35),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              // 4 Nodos satélite luminosos que orbitan
                              ...List.generate(4, (i) {
                                final angle = (i * 90) * math.pi / 180;
                                final radius = (mascotSize + 36) / 2;
                                return Transform.translate(
                                  offset: Offset(
                                    math.cos(angle) * radius,
                                    math.sin(angle) * radius,
                                  ),
                                  child: Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: i % 2 == 0
                                          ? const Color(0xFFFFD700)
                                          : const Color(0xFF00E5FF),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (i % 2 == 0
                                                  ? const Color(0xFFFFD700)
                                                  : const Color(0xFF00E5FF))
                                              .withOpacity(0.85),
                                          blurRadius: 7,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),

                      // Medallón central con el logo oficial del policía con capa
                      Container(
                        width: mascotSize,
                        height: mascotSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.85),
                            width: 3.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withOpacity(0.55),
                              blurRadius: 25,
                              spreadRadius: 4,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/icons/icon_police.png',
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Título principal con efectos de luz
  Widget _buildAppTitle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'ALERTA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 4.0,
                shadows: [
                  Shadow(
                    offset: Offset(0, 3),
                    blurRadius: 12,
                    color: Color(0xFF00E5FF),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Punto de pulso de emergencia
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, _) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF3B30),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFFF3B30),
                          blurRadius: 10,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 2),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFFFD54F), // Oro luminoso
              Color(0xFFFFB300), // Oro cálido
              Color(0xFFFF8F00), // Ámbar
            ],
          ).createShader(bounds),
          child: const Text(
            'DESAPARECIDOS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 3.5,
              shadows: [
                Shadow(
                  offset: Offset(0, 2),
                  blurRadius: 8,
                  color: Colors.black45,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Carrusel de mensajes inspiradores con animación suave
  Widget _buildInspirationalCarousel() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.25),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey<int>(_currentMessageIndex),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withOpacity(0.18),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.stars_rounded,
              color: Color(0xFFFFD700),
              size: 18,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                _inspirationalMessages[_currentMessageIndex],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.0,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Barra de progreso y texto de inicio dinámico
  Widget _buildModernLoadingTrack() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pista de progreso luminosa
        Container(
          width: 200,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: AnimatedBuilder(
            animation: _progressController,
            builder: (context, _) {
              return Stack(
                children: [
                  Positioned(
                    left: _progressController.value * 160,
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0xFF00E5FF),
                            Colors.white,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFF00E5FF),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.lock_clock_outlined,
              color: Color(0xFF00E5FF),
              size: 13,
            ),
            SizedBox(width: 6),
            Text(
              'Iniciando Red Nacional PNP en tiempo real...',
              style: TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Información del pie de página institucional
  Widget _buildFooterInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFD32F2F).withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.phone_in_talk, color: Colors.white, size: 12),
              SizedBox(width: 4),
              Text(
                'LÍNEA 114',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'v2.0 • Plataforma Ciudadana Independiente',
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 11.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Pintor de ondas de radar concéntricas que se expanden desde el fondo
class _RadarWavesPainter extends CustomPainter {
  final double animationValue;

  _RadarWavesPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.38);
    final maxRadius = size.width * 0.85;

    for (int i = 0; i < 3; i++) {
      final progress = (animationValue + (i * 0.33)) % 1.0;
      final radius = progress * maxRadius;
      final opacity = (1.0 - progress) * 0.22;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF00E5FF).withOpacity(opacity);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarWavesPainter oldDelegate) => true;
}

// Pintor de partículas flotantes conectadas que representan la red comunitaria
class _CommunityParticlesPainter extends CustomPainter {
  final double animationValue;

  _CommunityParticlesPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 18; i++) {
      final seed = i * 42.0;
      final baseX = ((seed * 17) % size.width);
      final baseY = ((seed * 31) % size.height);

      final dx = math.sin(animationValue * 2 * math.pi + i) * 18;
      final dy = math.cos(animationValue * 2 * math.pi + i * 0.7) * 22;

      final x = (baseX + dx) % size.width;
      final y = (baseY + dy) % size.height;

      final opacity =
          (0.25 + 0.35 * math.sin(animationValue * 2 * math.pi + i)).clamp(0.05, 0.7);

      paint.color = i % 3 == 0
          ? const Color(0xFFFFD700).withOpacity(opacity) // Dorado
          : const Color(0xFF00E5FF).withOpacity(opacity); // Cian

      final particleRadius = 1.6 + (i % 3) * 0.8;
      canvas.drawCircle(Offset(x, y), particleRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CommunityParticlesPainter oldDelegate) => true;
}

