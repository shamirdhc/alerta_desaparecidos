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
        automaticallyImplyLeading: false, // Eliminar botón atrás automático
        title: const Text(
          'Tutorial Paso a Paso',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18, // Reducido de 20 a 18
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
              // Progress Indicator - más compacto
              Container(
                margin: const EdgeInsets.all(16), // Reducido de 20 a 16
                child: Row(
                  children: List.generate(
                    _tutorialSteps.length,
                    (index) => Expanded(
                      child: GestureDetector(
                        onTap: () => _goToStep(index),
                        child: Container(
                          height: 3, // Reducido de 4 a 3
                          margin: const EdgeInsets.symmetric(horizontal: 1), // Reducido de 2 a 1
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

              // Page Counter - más compacto
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16), // Reducido de 20 a 16
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Paso ${_currentPage + 1} de ${_tutorialSteps.length}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12, // Reducido de 14 a 12
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, // Reducido de 12 a 8
                        vertical: 4, // Reducido de 6 a 4
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16), // Reducido de 20 a 16
                      ),
                      child: Text(
                        '${((_currentPage + 1) / _tutorialSteps.length * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10, // Reducido de 12 a 10
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

              // Navigation Buttons - más compactos
              Container(
                padding: const EdgeInsets.all(16), // Reducido de 20 a 16
                child: Row(
                  children: [
                    // Previous Button
                    Expanded(
                      child:
                          _currentPage > 0
                              ? ElevatedButton.icon(
                                onPressed: _previousPage,
                                icon: const Icon(Icons.arrow_back, size: 18), // Reducido tamaño
                                label: const Text('Anterior', style: TextStyle(fontSize: 13)), // Reducido tamaño
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(
                                    0.2,
                                  ),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12, // Reducido de 16 a 12
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10), // Reducido de 12 a 10
                                  ),
                                ),
                              )
                              : const SizedBox(),
                    ),

                    const SizedBox(width: 12), // Reducido de 16 a 12

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
                          size: 18, // Reducido tamaño
                        ),
                        label: Text(
                          _currentPage < _tutorialSteps.length - 1
                              ? 'Siguiente'
                              : 'Finalizar',
                          style: const TextStyle(fontSize: 13), // Reducido tamaño
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1A237E),
                          padding: const EdgeInsets.symmetric(vertical: 12), // Reducido de 16 a 12
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10), // Reducido de 12 a 10
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 32, // Restar padding
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Container - más compacto y responsivo
                  Container(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.25, // 25% de la altura de pantalla
                    constraints: const BoxConstraints(
                      minHeight: 200,
                      maxHeight: 280,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 15,
                          spreadRadius: 0,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        step.image,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Imagen no disponible',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Title - más compacto
                  Text(
                    step.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18, // Reducido de 20 a 18
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 10),

                  // Description - más compacto
                  Text(
                    step.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13, // Reducido de 14 a 13
                      height: 1.3, // Reducido de 1.4 a 1.3
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 16),

                  // Tips Section - más compacto
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(12), // Reducido de 16 a 12
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: Colors.amber,
                                size: 18, // Reducido de 20 a 18
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Consejos importantes:',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14, // Reducido de 16 a 14
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8), // Reducido de 12 a 8
                          ...step.tips.take(3).map( // Limitar a 3 tips máximo
                            (tip) => Padding(
                              padding: const EdgeInsets.only(bottom: 6), // Reducido de 8 a 6
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '• ',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 14, // Reducido de 16 a 14
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      tip,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12, // Reducido de 14 a 12
                                        height: 1.3, // Reducido de 1.4 a 1.3
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
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
          ),
        );
      },
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
