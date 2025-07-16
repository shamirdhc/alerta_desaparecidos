import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _currentPage = 0;

  final List<TutorialStep> _tutorialSteps = [
    TutorialStep(
      image: 'assets/tutorial_web/tutorial_1.png', // Imagen original del paso 1
      title: 'Sistema de Búsqueda - Herramientas Tecnológicas', // Info del paso 4
      description:
          'Conoce las herramientas tecnológicas del Sistema de Búsqueda de Personas Desaparecidas.',
      tips: [
        'Buscamos personas para reunir familias',
        'Sistema coordinado entre CEORDES y Desaparecidos en Perú',
        'Tecnología al servicio de la búsqueda',
      ],
    ),
    TutorialStep(
      image: 'assets/tutorial_web/tutorial_2.png', // Imagen original del paso 2
      title: 'Portal Web - Información Completa', // Info del paso 5
      description:
          'Brinda información sobre personas desaparecidas. Incluye las notas de alerta, alertas AMBER, estadística y material de orientación.',
      tips: [
        'Acceso a www.desaparecidosenperu.policia.gob.pe',
        'Consulta de casos de personas desaparecidas',
        'Información estadística y material educativo',
      ],
    ),
    TutorialStep(
      image: 'assets/tutorial_web/tutorial_3.png', // Imagen original del paso 3
      title: 'Línea Única de Atención - 114', // Info del paso 6
      description:
          'Línea única de atención en casos de desaparición de personas. Reporta y recibe información.',
      tips: [
        'Número gratuito: 114',
        'Atención especializada 24 horas',
        'Reporta casos y recibe orientación profesional',
      ],
    ),
    TutorialStep(
      image: 'assets/tutorial_web/tutorial_4.png', // Imagen original del paso 4
      title: 'Línea 114 - Llamada Gratis', // Info del paso 1
      description:
          'Reporta la desaparición de una persona y especialistas de la PNP te orientarán para realizar tu denuncia.',
      tips: [
        'Comunica a la Línea 114 la ubicación de una persona desaparecida',
        'La PNP podrá enfocarse en otros casos con tu reporte',
        'Servicio gratuito disponible 24/7',
      ],
    ),
    TutorialStep(
      image: 'assets/tutorial_web/tutorial_5.png', // Imagen original del paso 5
      title: 'Portal Web de Personas Desaparecidas', // Info del paso 2
      description:
          'Denuncia aquí. Registrada la denuncia, el sistema emite la Nota de Alerta en el portal web oficial.',
      tips: [
        'Escanea el código QR para acceso directo',
        'El Mininter lidera el Sistema de Búsqueda de Personas Desaparecidas',
        'Registro oficial de denuncias online',
      ],
    ),
    TutorialStep(
      image: 'assets/tutorial_web/tutorial_6.png', // Imagen original del paso 6
      title: 'Frente a Inadecuada Atención Policial', // Info del paso 3
      description:
          'Si experimentas inadecuada atención policial en casos de denuncias por desaparición, reporta tu queja.',
      tips: [
        'Central Única de Denuncias: 1818',
        'Portal web: http://denuncias.mininter.gob.pe',
        'Correo electrónico: denuncias@mininter.gob.pe',
        'App CUD 1818 disponible solo en Android',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _tutorialSteps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToStep(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tutorial Paso a Paso',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              // Progress Indicator
              Container(
                margin: const EdgeInsets.all(20),
                child: Row(
                  children: List.generate(
                    _tutorialSteps.length,
                    (index) => Expanded(
                      child: GestureDetector(
                        onTap: () => _goToStep(index),
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color:
                                index <= _currentPage
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Page Counter
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Paso ${_currentPage + 1} de ${_tutorialSteps.length}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${((_currentPage + 1) / _tutorialSteps.length * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Tutorial Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                    HapticFeedback.lightImpact();
                  },
                  itemCount: _tutorialSteps.length,
                  itemBuilder: (context, index) {
                    return _buildTutorialPage(_tutorialSteps[index]);
                  },
                ),
              ),

              // Navigation Buttons
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Previous Button
                    Expanded(
                      child:
                          _currentPage > 0
                              ? ElevatedButton.icon(
                                onPressed: _previousPage,
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Anterior'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(
                                    0.2,
                                  ),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              )
                              : const SizedBox(),
                    ),

                    const SizedBox(width: 16),

                    // Next/Finish Button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed:
                            _currentPage < _tutorialSteps.length - 1
                                ? _nextPage
                                : () => Navigator.pop(context),
                        icon: Icon(
                          _currentPage < _tutorialSteps.length - 1
                              ? Icons.arrow_forward
                              : Icons.check_circle,
                        ),
                        label: Text(
                          _currentPage < _tutorialSteps.length - 1
                              ? 'Siguiente'
                              : 'Finalizar',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1A237E),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialPage(TutorialStep step) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Container
          Container(
            width: double.infinity,
            height: 350, // Aumentado para mejor visualización
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                step.image,
                fit: BoxFit.contain, // Cambiado de cover a contain
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Imagen no disponible',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Title
          Text(
            step.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            step.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          // Tips Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.amber,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Consejos importantes:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...step.tips.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.4,
                            ),
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

class TutorialStep {
  final String image;
  final String title;
  final String description;
  final List<String> tips;

  TutorialStep({
    required this.image,
    required this.title,
    required this.description,
    required this.tips,
  });
}
