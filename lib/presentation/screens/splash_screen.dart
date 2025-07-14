import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'initial_flow_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _heartController;
  late AnimationController _particleController;
  late AnimationController _textRotationController;
  late AnimationController _transitionController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _heartAnimation;
  late Animation<double> _particleAnimation;
  late Animation<double> _transitionAnimation;

  int _currentMessageIndex = 0;
  Timer? _messageTimer;
  bool _showOriginalImage = true;

  final List<String> _inspirationalMessages = [
    "Juntos somos más fuertes",
    "Tu ayuda puede cambiar una vida",
    "Cada reporte cuenta",
    "Unidos encontraremos el camino",
    "La esperanza nunca se pierde",
    "Construyamos una red de apoyo",
  ];

  @override
  void initState() {
    super.initState();

    _initializeAnimations();
    _startSequence();

    Timer(const Duration(seconds: 6), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const InitialFlowScreen()),
        );
      }
    });
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _heartController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );

    _textRotationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.8),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _heartAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeInOut),
    );

    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.linear),
    );

    _transitionAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _transitionController, curve: Curves.easeInOut),
    );
  }

  void _startSequence() async {
    // Mostrar imagen original por 2 segundos
    await Future.delayed(const Duration(seconds: 2));

    // Iniciar transición
    if (mounted) {
      _transitionController.forward();
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _showOriginalImage = false;
      });
    }

    // Iniciar animaciones del nuevo diseño
    _startAnimations();
    _startMessageRotation();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _fadeController.forward();

    await Future.delayed(const Duration(milliseconds: 500));
    _scaleController.forward();

    await Future.delayed(const Duration(milliseconds: 800));
    _slideController.forward();

    await Future.delayed(const Duration(milliseconds: 1000));
    _heartController.repeat(reverse: true);
    _particleController.repeat();
  }

  void _startMessageRotation() {
    _messageTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentMessageIndex =
              (_currentMessageIndex + 1) % _inspirationalMessages.length;
        });
        _textRotationController.reset();
        _textRotationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _heartController.dispose();
    _particleController.dispose();
    _textRotationController.dispose();
    _transitionController.dispose();
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Imagen original del splash screen
          if (_showOriginalImage)
            AnimatedBuilder(
              animation: _transitionAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _transitionAnimation.value,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/icons/splash_screen.png',
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        bottom: 50,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          // Nuevo diseño empático
          if (!_showOriginalImage)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D47A1),
                    Color(0xFF1565C0),
                    Color(0xFF1976D2),
                    Color(0xFF42A5F5),
                  ],
                  stops: [0.0, 0.3, 0.7, 1.0],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Partículas flotantes de esperanza
                  AnimatedBuilder(
                    animation: _particleAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: ParticlesPainter(_particleAnimation.value),
                        size: Size.infinite,
                      );
                    },
                  ),

                  // Ondas de conexión en el fondo
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ConnectionWavesPainter(_particleAnimation.value),
                    ),
                  ),

                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo principal con efecto de corazón pulsante
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: AnimatedBuilder(
                              animation: _heartAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _heartAnimation.value,
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      gradient: const RadialGradient(
                                        colors: [
                                          Colors.white,
                                          Color(0xFFF8F9FA),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.4),
                                          blurRadius: 30,
                                          spreadRadius: 10,
                                        ),
                                        BoxShadow(
                                          color: const Color(
                                            0xFF1976D2,
                                          ).withOpacity(0.3),
                                          blurRadius: 20,
                                          spreadRadius: 5,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Anillo de conexión
                                        Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(
                                                0xFF42A5F5,
                                              ).withOpacity(0.3),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        // Logo
                                        ClipOval(
                                          child: Image.asset(
                                            'assets/icons/logo_placeholder.png',
                                            width: 90,
                                            height: 90,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        // Iconos de personas conectadas
                                        ...List.generate(6, (index) {
                                          final angle =
                                              (index * 60) * math.pi / 180;
                                          return Transform.translate(
                                            offset: Offset(
                                              math.cos(angle) * 60,
                                              math.sin(angle) * 60,
                                            ),
                                            child: AnimatedBuilder(
                                              animation: _particleAnimation,
                                              builder: (context, child) {
                                                return Transform.scale(
                                                  scale:
                                                      0.8 +
                                                      (math.sin(
                                                            _particleAnimation
                                                                        .value *
                                                                    2 *
                                                                    math.pi +
                                                                index,
                                                          ) *
                                                          0.2),
                                                  child: Container(
                                                    width: 12,
                                                    height: 12,
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber
                                                          .withOpacity(0.8),
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.amber
                                                              .withOpacity(0.5),
                                                          blurRadius: 8,
                                                          spreadRadius: 2,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 50),

                        // Título principal con efecto de unidad
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'ALERTA',
                                      style: TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 4,
                                        shadows: [
                                          Shadow(
                                            offset: Offset(2, 2),
                                            blurRadius: 6,
                                            color: Colors.black26,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Corazón pulsante
                                    AnimatedBuilder(
                                      animation: _heartAnimation,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: _heartAnimation.value * 0.8,
                                          child: const Icon(
                                            Icons.favorite,
                                            color: Colors.red,
                                            size: 24,
                                            shadows: [
                                              Shadow(
                                                offset: Offset(1, 1),
                                                blurRadius: 3,
                                                color: Colors.black26,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const Text(
                                  'DESAPARECIDOS',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 3,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(1, 1),
                                        blurRadius: 4,
                                        color: Colors.black26,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Línea de conexión animada
                                AnimatedBuilder(
                                  animation: _particleAnimation,
                                  builder: (context, child) {
                                    return Container(
                                      width:
                                          80 +
                                          (math.sin(
                                                _particleAnimation.value *
                                                    2 *
                                                    math.pi,
                                              ) *
                                              20),
                                      height: 4,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.amber,
                                            Colors.orange,
                                            Colors.amber,
                                          ],
                                          stops: const [0.0, 0.5, 1.0],
                                        ),
                                        borderRadius: BorderRadius.circular(2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.amber.withOpacity(
                                              0.6,
                                            ),
                                            blurRadius: 12,
                                            spreadRadius: 3,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Mensajes rotativos inspiradores
                        SizedBox(
                          height: 60,
                          child: AnimatedBuilder(
                            animation: _textRotationController,
                            builder: (context, child) {
                              return FadeTransition(
                                opacity: _textRotationController,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.5),
                                    end: Offset.zero,
                                  ).animate(_textRotationController),
                                  child: Column(
                                    children: [
                                      Text(
                                        _inspirationalMessages[_currentMessageIndex],
                                        style: const TextStyle(
                                          fontSize: 18,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 1.5,
                                          shadows: [
                                            Shadow(
                                              offset: Offset(1, 1),
                                              blurRadius: 3,
                                              color: Colors.black26,
                                            ),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      // Indicador de comunidad
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          ...List.generate(5, (index) {
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 2,
                                                  ),
                                              child: AnimatedBuilder(
                                                animation: _particleAnimation,
                                                builder: (context, child) {
                                                  return Transform.scale(
                                                    scale:
                                                        0.8 +
                                                        (math.sin(
                                                              _particleAnimation
                                                                          .value *
                                                                      2 *
                                                                      math.pi +
                                                                  index * 0.5,
                                                            ) *
                                                            0.3),
                                                    child: const Icon(
                                                      Icons.person,
                                                      color: Colors.amber,
                                                      size: 16,
                                                    ),
                                                  );
                                                },
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Mensaje de esperanza y colaboración
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              '"Cuando nos unimos como comunidad,\nlos milagros suceden"',
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    Colors
                                        .white70, // Corregido: usar Colors.white70 en lugar de white90
                                fontStyle: FontStyle.italic,
                                letterSpacing: 0.8,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Indicador de carga con mensaje de esperanza
                  Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          // Indicador circular con efecto de pulso
                          AnimatedBuilder(
                            animation: _heartAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _heartAnimation.value * 0.9,
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.1),
                                        Colors.transparent,
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.amber,
                                    ),
                                    backgroundColor: Colors.transparent,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Conectando corazones...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Información de la app con mensaje de comunidad
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.group,
                                color: Colors.white38,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Red Comunitaria de Apoyo',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'v1.0.0',
                            style: TextStyle(
                              color: Colors.white30,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Painter para partículas flotantes que representan esperanza
class ParticlesPainter extends CustomPainter {
  final double animationValue;

  ParticlesPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Crear partículas que representan personas conectadas
    for (int i = 0; i < 20; i++) {
      final x =
          (size.width * 0.1) +
          (i * size.width * 0.04) +
          (math.sin(animationValue * 2 * math.pi + i) * 30);
      final y =
          (size.height * 0.2) +
          (i * size.height * 0.03) +
          (math.cos(animationValue * 2 * math.pi + i * 0.7) * 40);

      final opacity =
          (math.sin(animationValue * 2 * math.pi + i * 0.5) + 1) * 0.3;
      paint.color = Colors.amber.withOpacity(opacity);

      canvas.drawCircle(
        Offset(x % size.width, y % size.height),
        2 + (math.sin(animationValue * 2 * math.pi + i) * 1),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Painter para ondas de conexión
class ConnectionWavesPainter extends CustomPainter {
  final double animationValue;

  ConnectionWavesPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

    // Ondas concéntricas que representan la expansión de la ayuda
    for (int i = 0; i < 3; i++) {
      final radius = (animationValue * size.width * 0.8) + (i * 100);
      final opacity = 1 - ((animationValue + i * 0.3) % 1);

      paint.color = Colors.white.withOpacity(opacity * 0.1);

      canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 0.5),
        radius % (size.width * 0.6),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
