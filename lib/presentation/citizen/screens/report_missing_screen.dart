import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:alerta_desaparecidos/domain/entities/report_step.dart';
import 'educational_guides_screen.dart';
import 'tutorial_screen.dart';

class ReportMissingScreen extends StatefulWidget {
  const ReportMissingScreen({super.key});

  @override
  State<ReportMissingScreen> createState() => _ReportMissingScreenState();
}

class _ReportMissingScreenState extends State<ReportMissingScreen>
    with TickerProviderStateMixin {
  bool _showGuide = false;
  int _currentStep = 0;
  late AnimationController _animationController;
  late PageController _pageController;

  // Variables de configuración
  final String _reportNumber = '105';
  final String _emergencyNumber = '911';
  final String _comisariaUrl = 'https://www.pnp.gob.pe/comisarias';

  // Lista de pasos para la guía
  final List<ReportStep> _steps = [
    ReportStep(
      title: 'Información Básica',
      subtitle: 'Datos de la persona desaparecida',
      description:
          'Recopila toda la información básica de la persona desaparecida: nombre completo, edad, características físicas, ropa que llevaba puesta.',
      icon: Icons.person,
      actionText: 'Preparar Información',
      actionType: 'info',
    ),
    ReportStep(
      title: 'Contactar Autoridades',
      subtitle: 'Llamar a la policía inmediatamente',
      description:
          'Contacta a la Policía Nacional del Perú para reportar la desaparición. Es importante hacerlo lo antes posible.',
      icon: Icons.phone,
      actionText: 'Llamar Ahora',
      actionType: 'call',
    ),
    ReportStep(
      title: 'Denuncia Formal',
      subtitle: 'Acudir a la comisaría más cercana',
      description:
          'Dirígete a la comisaría más cercana para presentar la denuncia formal. Lleva contigo un documento de identidad.',
      icon: Icons.location_on,
      actionText: 'Ver Comisarías',
      actionType: 'website',
    ),
    ReportStep(
      title: 'Difusión',
      subtitle: 'Compartir información en redes sociales',
      description:
          'Comparte la información de la persona desaparecida en redes sociales y grupos comunitarios para ampliar la búsqueda.',
      icon: Icons.share,
      actionText: 'Compartir por WhatsApp',
      actionType: 'whatsapp',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pageController = PageController();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Función para hacer llamadas telefónicas
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      await launchUrl(launchUri);
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('No se pudo realizar la llamada');
      }
    }
  }

  // Función para mostrar mensaje de WhatsApp próximamente
  Future<void> _openWhatsApp() async {
    showDialog(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(Icons.chat, color: Color(0xFF25D366), size: 32),
            ),
            title: const Text(
              '¡Muy Pronto!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
              textAlign: TextAlign.center,
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🚀 Estamos trabajando para brindarte atención directa por WhatsApp',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF4A5568),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'Mientras tanto, puedes usar la Línea 114 para atención inmediata 24/7',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF718096),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Entendido',
                  style: TextStyle(
                    color: Color(0xFF25D366),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          ),
    );
  }

  // Función para abrir sitio web de comisarías
  Future<void> _openComisariaWebsite() async {
    final Uri uri = Uri.parse(_comisariaUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('No se pudo abrir el sitio web');
      }
    }
  }

  // Función para mostrar mensajes de error
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // Navegación entre pasos
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
      setState(() {
        _showGuide = false;
        _currentStep = 0;
      });
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

  // Función para mostrar la guía
  void _showGuideDialog() {
    setState(() {
      _showGuide = true;
      _currentStep = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _showGuide ? _buildGuideContent() : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header con gradiente
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.security,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'DENUNCIA SEGURA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Si una persona ha desaparecido, es crucial actuar rápidamente. Sigue nuestra guía paso a paso para reportar de manera efectiva.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Botones de acción principales
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // Sección de emergencia (movida arriba por prioridad)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53E3E).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.emergency,
                                color: Color(0xFFE53E3E),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Denuncia de Emergencia',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Si es una emergencia inmediata, contacta directamente:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF718096),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildEmergencyButton(
                                icon: Icons.phone,
                                title: 'Línea 114',
                                subtitle: 'Línea directa PNP',
                                color: const Color(0xFF1565C0),
                                onTap: () => _makePhoneCall('114'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildEmergencyButton(
                                icon: Icons.chat,
                                title: 'WhatsApp',
                                subtitle: 'Mensaje rápido',
                                color: const Color(0xFF25D366),
                                onTap: _openWhatsApp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tutorial Paso a Paso (ahora después de Emergencia)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4CAF50).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TutorialScreen(),
                              ),
                            ),
                        borderRadius: BorderRadius.circular(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.school,
                                color: Color(0xFF4CAF50),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tutorial Paso a Paso',
                                    style: TextStyle(
                                      color: Color(0xFF2D3748),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Guía visual completa para denunciar',
                                    style: TextStyle(
                                      color: Color(0xFF718096),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Color(0xFF4CAF50),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Botón de videos educativos
                  _buildActionButton(
                    icon: Icons.play_circle_outline,
                    title: 'Ver Videos Educativos',
                    subtitle: 'Aprende con contenido visual',
                    color: const Color(0xFF7B1FA2),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EducationalGuidesScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Portal de Búsqueda de Personas Desaparecidas
                  _buildPortalSection(),

                  const SizedBox(height: 24),

                  const SizedBox(height: 24),

                  // Mensaje de seguridad
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A5568).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4A5568).withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: const Color(0xFF4A5568),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Tu información está protegida y será tratada con total confidencialidad',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF4A5568),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: color.withOpacity(0.1), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideContent() {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() {
              _showGuide = false;
              _currentStep = 0;
            });
          },
        ),
        title: const Text(
          'Guía para Denunciar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Indicador de progreso
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Paso ${_currentStep + 1} de ${_steps.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: List.generate(_steps.length, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(
                          right: index < _steps.length - 1 ? 8 : 0,
                        ),
                        decoration: BoxDecoration(
                          color:
                              index <= _currentStep
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // Contenido de los pasos
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FA),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentStep = index;
                  });
                },
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  return _buildStepCard(_steps[index]);
                },
              ),
            ),
          ),

          // Botones de navegación
          Container(
            color: const Color(0xFFF8F9FA),
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF1565C0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Anterior',
                        style: TextStyle(
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentStep == _steps.length - 1
                          ? 'Finalizar'
                          : 'Siguiente',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
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

  Widget _buildStepCard(ReportStep step) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono y título
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  step.icon,
                  color: const Color(0xFF1565C0),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.subtitle,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Descripción
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              step.description,
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Color(0xFF4A5568),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Botón de acción
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showActionDialog(step.actionType),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                step.actionText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActionDialog(String actionType) {
    switch (actionType) {
      case 'info':
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Información a Preparar'),
                content: const Text(
                  'Antes de hacer la denuncia, ten lista la siguiente información:\n\n'
                  '• Nombre completo\n'
                  '• Edad y fecha de nacimiento\n'
                  '• Características físicas\n'
                  '• Ropa que llevaba puesta\n'
                  '• Última ubicación conocida\n'
                  '• Hora y fecha de desaparición\n'
                  '• Fotografía reciente',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendido'),
                  ),
                ],
              ),
        );
        break;
      case 'call':
        _showEmergencyNumbersDialog();
        break;
      case 'website':
        _openComisariaWebsite();
        break;
      case 'whatsapp':
        _openWhatsApp();
        break;
    }
  }

  void _showEmergencyNumbersDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Números de Emergencia'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEmergencyNumberDialog(
                  'Policía Nacional',
                  _emergencyNumber,
                ),
                const SizedBox(height: 12),
                _buildEmergencyNumberDialog(
                  'Línea de Denuncias',
                  _reportNumber,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  Widget _buildEmergencyNumberDialog(String title, String number) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone, color: Color(0xFF1565C0)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                Text(
                  number,
                  style: const TextStyle(
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _makePhoneCall(number);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Llamar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Portal de Búsqueda de Personas Desaparecidas
  Widget _buildPortalSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.search, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portal Oficial PNP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Registro Nacional de Personas Desaparecidas',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Consulta el registro oficial y accede a herramientas especializadas para la búsqueda de personas desaparecidas según el Decreto Legislativo N° 1428.',
            style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),

          // Portal Principal - Búsqueda de Personas
          _buildPortalOption(
            icon: Icons.search,
            title: 'Portal de Búsqueda',
            subtitle: 'desaparecidosenperu.policia.gob.pe',
            color: const Color(0xFF4CAF50),
            onTap:
                () => _launchUrl(
                  'https://desaparecidosenperu.policia.gob.pe/Desaparecidos/desaparecidos_menor_mujer_hombre',
                ),
            isEmergency: false,
          ),
        ],
      ),
    );
  }

  Widget _buildPortalOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isEmergency,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(isEmergency ? 0.95 : 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isEmergency ? color : Colors.white.withOpacity(0.3),
              width: isEmergency ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      isEmergency
                          ? color.withOpacity(0.1)
                          : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isEmergency ? color : Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color:
                            isEmergency
                                ? const Color(0xFF2D3748)
                                : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color:
                            isEmergency
                                ? const Color(0xFF718096)
                                : Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: isEmergency ? color : Colors.white.withOpacity(0.7),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Función para abrir URLs
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('No se pudo abrir el enlace');
      }
    }
  }

  // Función para mostrar información de la app
  void _showAppInfo() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('App CUD 1818'),
            content: const Text(
              'La aplicación móvil oficial CUD 1818 está disponible para descargar en las tiendas de aplicaciones. Permite reportar y consultar casos de personas desaparecidas.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
    );
  }
}
