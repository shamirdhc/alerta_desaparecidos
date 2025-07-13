import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ComisariasScreen extends StatefulWidget {
  const ComisariasScreen({super.key});

  @override
  State<ComisariasScreen> createState() => _ComisariasScreenState();
}

class _ComisariasScreenState extends State<ComisariasScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _openComisariasWebsite() async {
    final Uri url = Uri.parse('https://aplicaciones.mininter.gob.pe/ubicatucomisaria/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'No se pudo abrir el sitio web';
    }
  }

  Future<void> _callEmergency() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '105');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      throw 'No se pudo realizar la llamada';
    }
  }

  void _showInteractiveTutorial() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            InteractiveTutorialScreen(
          onComplete: () {
            Navigator.of(context).pop();
            _openComisariasWebsite();
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1565C0), // Azul Policía
            Color(0xFF42A5F5), // Azul Claro
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono principal animado
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_police,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              
              // Título
              const Text(
                'Buscar Mi Comisaría',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              
              // Descripción
              const Text(
                'Encuentra la comisaría más cercana con GPS automático',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // Botón para tutorial interactivo
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showInteractiveTutorial,
                  icon: const FaIcon(FontAwesomeIcons.graduationCap, color: Color(0xFF1565C0)),
                  label: const Text(
                    'Tutorial Paso a Paso',
                    style: TextStyle(
                      color: Color(0xFF1565C0),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              
              // Botón para abrir sitio web
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openComisariasWebsite,
                  icon: const FaIcon(FontAwesomeIcons.mapLocationDot, color: Color(0xFF1565C0)),
                  label: const Text(
                    'Ir Directo al Mapa',
                    style: TextStyle(
                      color: Color(0xFF1565C0),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Botón de emergencia
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _callEmergency,
                  icon: const FaIcon(FontAwesomeIcons.phone, color: Colors.white),
                  label: const Text(
                    'Llamar Emergencias (105)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              // Información adicional
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.gps_fixed,
                      color: Colors.white70,
                      size: 24,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Asegúrate de tener el GPS activado para una mejor experiencia',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
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
}

class InteractiveTutorialScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const InteractiveTutorialScreen({super.key, required this.onComplete});

  @override
  State<InteractiveTutorialScreen> createState() => _InteractiveTutorialScreenState();
}

class _InteractiveTutorialScreenState extends State<InteractiveTutorialScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fadeController;
  late AnimationController _loadingController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _loadingAnimation;
  int _currentStep = 0;
  late List<TutorialStep> _steps; // Cambiar a late

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _loadingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
    
    // Inicializar _steps aquí
    _steps = [
      TutorialStep(
        title: 'Paso 1: Activa tu GPS',
        description: 'Antes de usar el mapa, asegúrate de tener activado el GPS en tu dispositivo para obtener tu ubicación automáticamente.',
        icon: Icons.gps_fixed,
        color: Colors.green,
        mockupWidget: _buildGPSMockup(),
      ),
      TutorialStep(
        title: 'Paso 2: Espera la Carga Automática',
        description: 'Al entrar a la página, espera unos segundos. El sistema cargará automáticamente tu departamento, provincia, distrito y comisaría más cercana.',
        icon: Icons.hourglass_empty,
        color: Colors.orange,
        mockupWidget: _buildLoadingMockup(),
      ),
      TutorialStep(
        title: 'Paso 3: Haz Click en "Trazar Ruta"',
        description: 'Una vez que se carguen los datos automáticamente, presiona el botón azul "Trazar Ruta" para calcular la ruta a tu comisaría.',
        icon: Icons.route,
        color: Colors.blue,
        mockupWidget: _buildTrazarRutaMockup(),
      ),
      TutorialStep(
        title: 'Paso 4: Usa el Botón de Toggle',
        description: 'Después de trazar la ruta, busca el botón cuadrado blanco con "<<" en la esquina superior izquierda para ocultar el formulario y ver el mapa completo.',
        icon: Icons.visibility,
        color: Colors.blueGrey,
        mockupWidget: _buildToggleButtonMockup(),
      ),
      TutorialStep(
        title: 'Paso 5: Visualiza tu Ruta',
        description: 'Ahora verás el mapa con la ruta trazada hacia tu comisaría más cercana. Puedes seguir la línea naranja para llegar.',
        icon: Icons.map,
        color: Colors.deepOrange,
        mockupWidget: _buildMapViewMockup(),
      ),
      TutorialStep(
        title: 'Consejo Extra: Cambiar Comisaría',
        description: 'Si quieres buscar otra comisaría, presiona nuevamente el botón cuadrado blanco con "<<" para mostrar el formulario y seleccionar otra ubicación.',
        icon: Icons.refresh,
        color: Colors.purple,
      ),
      TutorialStep(
        title: '¡Listo para usar el mapa!',
        description: 'Ahora ya sabes cómo usar el mapa de comisarías con GPS automático. ¿Quieres ir directamente al mapa oficial?',
        icon: Icons.check_circle,
        color: Colors.green,
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        title: const Text(
          'Tutorial Comisarías GPS',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: List.generate(_steps.length, (index) {
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: index <= _currentStep
                          ? const Color(0xFF1565C0)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          // Content
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentStep = index;
                });
              },
              itemCount: _steps.length,
              itemBuilder: (context, index) {
                final step = _steps[index];
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: step.color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            step.icon,
                            size: 60,
                            color: step.color,
                          ),
                        ),
                        const SizedBox(height: 30),
                        // Title
                        Text(
                          step.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        // Description
                        Text(
                          step.description,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        // Mockup widget if available
                        if (step.mockupWidget != null) ...[
                          step.mockupWidget!,
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: Color(0xFF1565C0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Anterior',
                        style: TextStyle(
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 15),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      _currentStep == _steps.length - 1 ? 'Ir al Mapa' : 'Siguiente',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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

  static Widget _buildGPSMockup() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(15),
        color: Colors.grey.shade50,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.gps_fixed,
            size: 50,
            color: Colors.green,
          ),
          const SizedBox(height: 10),
          const Text(
            'GPS Activado',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Ubicación detectada automáticamente',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMockup() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade50,
      ),
      child: Column(
        children: [
          const Text(
            'Cargando automáticamente...',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 15),
          _buildLoadingField('Departamento', 'APURIMAC', true),
          const SizedBox(height: 8),
          _buildLoadingField('Provincia', 'ANDAHUAYLAS', true),
          const SizedBox(height: 8),
          _buildLoadingField('Distrito', 'ANDAHUAYLAS', true),
          const SizedBox(height: 8),
          _buildLoadingField('Comisaría', 'CPNP ANDAHUAYLAS', true),
        ],
      ),
    );
  }

  Widget _buildLoadingField(String label, String value, bool isLoaded) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: isLoaded ? Colors.green : Colors.grey),
            borderRadius: BorderRadius.circular(5),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isLoaded ? value : 'Cargando...',
                  style: TextStyle(
                    color: isLoaded ? Colors.black : Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isLoaded)
                const Icon(Icons.check, color: Colors.green, size: 16)
              else
                AnimatedBuilder(
                  animation: _loadingAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _loadingAnimation.value * 2 * 3.14159,
                      child: const Icon(
                        Icons.refresh,
                        color: Colors.grey,
                        size: 16,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildTrazarRutaMockup() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade50,
      ),
      child: Column(
        children: [
          const Text(
            'Datos cargados automáticamente:',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green),
              borderRadius: BorderRadius.circular(5),
              color: Colors.white,
            ),
            child: const Text(
              'CPNP ANDAHUAYLAS',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Text(
              'Trazar ruta',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildToggleButtonMockup() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade50,
      ),
      child: Column(
        children: [
          const Text(
            'Busca este botón en la esquina superior izquierda:',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade400, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Text(
                  '<<',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Presiona para ocultar/mostrar el formulario',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildMapViewMockup() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade50,
      ),
      child: Column(
        children: [
          const Text(
            'Vista del mapa con ruta trazada:',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Stack(
                children: [
                  // Simulación del mapa
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [Colors.green.shade100, Colors.blue.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // Ruta simulada
                  Positioned(
                    left: 20,
                    top: 30,
                    child: Container(
                      width: 4,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    top: 110,
                    child: Container(
                      width: 60,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Marcador de comisaría
                  const Positioned(
                    right: 20,
                    top: 20,
                    child: Icon(
                      Icons.local_police,
                      color: Colors.red,
                      size: 30,
                    ),
                  ),
                  // Tu ubicación
                  const Positioned(
                    left: 15,
                    top: 25,
                    child: Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  // Texto explicativo
                  const Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Text(
                      'Línea naranja = Ruta a seguir',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
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
  }
}

class TutorialStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Widget? mockupWidget;

  TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.mockupWidget,
  });
}
