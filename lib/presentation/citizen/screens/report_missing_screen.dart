import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';

class ReportMissingScreen extends StatefulWidget {
  const ReportMissingScreen({super.key});

  @override
  State<ReportMissingScreen> createState() => _ReportMissingScreenState();
}

class _ReportMissingScreenState extends State<ReportMissingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  int _currentStep = 0;
  bool _showGuide = false;
  final String _reportNumber = '+51948269740';
  final String _emergencyNumber = '114';
  final String _comisariaUrl =
      'https://aplicaciones.mininter.gob.pe/ubicatucomisaria/';

  final List<ReportStep> _steps = [
    ReportStep(
      title: '🚨 ¿CÓMO DENUNCIO LA DESAPARICIÓN DE UNA PERSONA?',
      subtitle:
          'Si un integrante de tu FAMILIA o ALGUIEN A QUIEN CONOCES desaparece, presenta la denuncia policial de MANERA INMEDIATA.',
      description:
          '⏰ No es necesario que transcurran 24 horas para denunciar una desaparición.\n\n📋 La denuncia debe ser presentada por un familiar directo o persona cercana que tenga conocimiento de los hechos.',
      icon: FontAwesomeIcons.triangleExclamation,
      color: Colors.red.shade600,
      isHeader: true,
    ),
    ReportStep(
      title: '📍 PASO 01',
      subtitle: 'Acércate a la dependencia policial más cercana',
      description:
          '🏢 Puedes acudir a:\n• Comisaría más cercana\n• DEPINCRI (Departamento de Investigación Criminal)\n• En Lima: Unidad Especializada de Búsqueda\n\n📸 Lleva contigo:\n• Foto más reciente de la persona (física o digital)\n• Documento de identidad de la persona desaparecida\n• Tu documento de identidad\n\n⚡ Recuerda: Cada minuto cuenta en una desaparición',
      icon: FontAwesomeIcons.mapLocationDot,
      color: Colors.blue.shade700,
      actionText: '🔍 Encontrar Comisaría Cercana',
    ),
    ReportStep(
      title: '📝 PASO 02',
      subtitle: 'Proporciona información detallada y precisa',
      description:
          '📋 Información que debes proporcionar:\n\n👤 Datos personales:\n• Nombre completo y apodos\n• Edad y fecha de nacimiento\n• Características físicas detalladas\n• Vestimenta que llevaba\n\n📍 Circunstancias:\n• Último lugar donde fue vista\n• Hora y fecha exacta\n• Con quién estaba\n• Actividad que realizaba\n\n📱 Información adicional:\n• Números de teléfono\n• Redes sociales\n• Lugares que frecuenta\n• Problemas de salud o medicamentos',
      icon: FontAwesomeIcons.clipboardList,
      color: Colors.orange.shade600,
      actionText: '📋 Ver Lista Completa de Información',
    ),
    ReportStep(
      title: '📞 INFORMACIÓN ADICIONAL IMPORTANTE',
      subtitle: 'Acciones complementarias para la búsqueda',
      description:
          '👥 Contacta a la red de apoyo:\n• Familiares cercanos y lejanos\n• Amigos y compañeros de trabajo/estudio\n• Vecinos y conocidos\n\n🔍 Revisa y documenta:\n• Últimas conversaciones por WhatsApp, SMS\n• Actividad en redes sociales\n• Movimientos bancarios recientes\n• Cámaras de seguridad del área\n\n📢 Difusión responsable:\n• Comparte información oficial únicamente\n• Evita especulaciones o rumores\n• Coordina con la policía antes de publicar\n\n⚠️ Mantén comunicación constante:\n• Informa cualquier novedad al policía a cargo\n• Guarda el número de caso asignado\n• Solicita actualizaciones periódicas',
      icon: FontAwesomeIcons.users,
      color: Colors.purple.shade600,
      actionText: '📱 Números de Emergencia Importantes',
    ),
    ReportStep(
      title: '✅ SI LA PERSONA APARECE',
      subtitle: 'Comunica inmediatamente el hallazgo',
      description:
          '📞 Pasos a seguir:\n\n1️⃣ Llama inmediatamente a la policía\n2️⃣ Proporciona el número de caso\n3️⃣ Confirma la identidad de la persona\n4️⃣ Solicita el cierre oficial del caso\n\n📋 Información importante:\n• El cierre del caso es obligatorio\n• Evita malentendidos futuros\n• Permite liberar recursos policiales\n\n🏥 Si la persona necesita atención:\n• Prioriza su bienestar físico y emocional\n• Busca ayuda médica si es necesario\n• Considera apoyo psicológico',
      icon: FontAwesomeIcons.circleCheck,
      color: Colors.green.shade600,
      actionText: '📞 Llamar para Cerrar Caso',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    HapticFeedback.mediumImpact();
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      _showErrorSnackBar('No se pudo realizar la llamada');
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    HapticFeedback.mediumImpact();
    final Uri whatsappUri = Uri.parse(
      'https://wa.me/$phoneNumber?text=Hola,%20necesito%20reportar%20una%20desaparición.',
    );
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri);
    } else {
      _showErrorSnackBar('No se pudo abrir WhatsApp');
    }
  }

  Future<void> _openComisariaWebsite() async {
    HapticFeedback.mediumImpact();
    final Uri uri = Uri.parse(_comisariaUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar('No se pudo abrir el sitio web');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
      HapticFeedback.lightImpact();
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
      HapticFeedback.lightImpact();
    }
  }

  void _showGuideDialog() {
    setState(() {
      _showGuide = true;
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo con gradiente
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1565C0),
                  Color(0xFF42A5F5),
                  Color(0xFF81C784),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Contenido principal
          if (!_showGuide) _buildMainContent() else _buildGuideContent(),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SafeArea(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Header con logo de seguridad
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.security, size: 60, color: Colors.white),
                    const SizedBox(height: 10),
                    const Text(
                      'DENUNCIA SEGURA',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Tu seguridad y privacidad están protegidas',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Mensaje principal
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 40,
                      color: Color(0xFF1565C0),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      '¿Cómo deseas reportar una desaparición?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Elige la opción que te resulte más cómoda y segura',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Botón de guía interactiva
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 20),
                      child: ElevatedButton.icon(
                        onPressed: _showGuideDialog,
                        icon: const Icon(Icons.school, color: Colors.white),
                        label: const Text(
                          'Ver Guía Paso a Paso',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Botones de acción
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Botón de emergencia
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 15),
                      child: ElevatedButton.icon(
                        onPressed: () => _makePhoneCall(_emergencyNumber),
                        icon: const Icon(Icons.emergency, color: Colors.white),
                        label: const Text(
                          'EMERGENCIA 114',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8,
                        ),
                      ),
                    ),

                    // Botón de llamada
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 15),
                      child: ElevatedButton.icon(
                        onPressed: () => _makePhoneCall(_reportNumber),
                        icon: const FaIcon(
                          FontAwesomeIcons.phone,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Llamar a la Policía',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 5,
                        ),
                      ),
                    ),

                    // Botón de WhatsApp
                    Container(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openWhatsApp(_reportNumber),
                        icon: const FaIcon(
                          FontAwesomeIcons.whatsapp,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Enviar mensaje por WhatsApp',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Mensaje de seguridad
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, color: Colors.white70, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Todas las comunicaciones son seguras y confidenciales',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
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

  Widget _buildGuideContent() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Guía para Denunciar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            setState(() {
              _showGuide = false;
              _currentStep = 0;
            });
          },
        ),
      ),
      body: Column(
        children: [
          // Indicador de progreso
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: List.generate(_steps.length, (index) {
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
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
          ),

          // Contenido de los pasos
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
                return _buildStepCard(step);
              },
            ),
          ),

          // Botones de navegación
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
                        side: const BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Anterior',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 15),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed:
                        _currentStep == _steps.length - 1
                            ? () {
                              setState(() {
                                _showGuide = false;
                                _currentStep = 0;
                              });
                            }
                            : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      _currentStep == _steps.length - 1
                          ? 'Finalizar'
                          : 'Siguiente',
                      style: const TextStyle(
                        color: Color(0xFF1565C0),
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

  Widget _buildStepCard(ReportStep step) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono y título mejorados
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: step.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: step.color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(step.icon, size: 32, color: step.color),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: step.isHeader ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: step.color,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (step.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        step.subtitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          // Descripción mejorada
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              step.description,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                height: 1.6,
                letterSpacing: 0.3,
              ),
            ),
          ),

          // Botón de acción mejorado
          if (step.actionText.isNotEmpty) ...[
            const SizedBox(height: 25),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: step.color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showActionDialog(step);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: step.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      step.title.contains('PASO 01')
                          ? FontAwesomeIcons.externalLinkAlt
                          : step.actionText.contains('Números')
                          ? FontAwesomeIcons.phone
                          : FontAwesomeIcons.arrowRight,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      step.actionText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showActionDialog(ReportStep step) {
    // Acción específica para el paso 1 - Encontrar Comisaría
    if (step.title.contains('PASO 01')) {
      _openComisariaWebsite();
      return;
    }

    // Acción para números de emergencia
    if (step.actionText.contains('Números de Emergencia')) {
      _showEmergencyNumbersDialog();
      return;
    }

    // Acción para cerrar caso
    if (step.actionText.contains('Cerrar Caso')) {
      _makePhoneCall(_emergencyNumber);
      return;
    }

    // Diálogo genérico para otros casos
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(step.icon, color: step.color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.actionText,
                    style: TextStyle(
                      color: step.color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Esta información te ayudará con: ${step.actionText.toLowerCase()}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: step.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        FontAwesomeIcons.lightbulb,
                        color: step.color,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Mantén esta información a mano durante todo el proceso.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
    );
  }

  void _showEmergencyNumbersDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  FontAwesomeIcons.phone,
                  color: Colors.red.shade600,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Números de Emergencia',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEmergencyNumber(
                  '🚨 Línea de Emergencia',
                  '114',
                  'Gratuito las 24 horas',
                  Colors.red.shade600,
                ),
                const SizedBox(height: 15),
                _buildEmergencyNumber(
                  '👮 Policía Nacional',
                  '105',
                  'Emergencias policiales',
                  Colors.blue.shade600,
                ),
                const SizedBox(height: 15),
                _buildEmergencyNumber(
                  '🏥 SAMU (Emergencias Médicas)',
                  '106',
                  'Atención médica de urgencia',
                  Colors.green.shade600,
                ),
                const SizedBox(height: 15),
                _buildEmergencyNumber(
                  '🔥 Bomberos',
                  '116',
                  'Emergencias y rescates',
                  Colors.orange.shade600,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
    );
  }

  Widget _buildEmergencyNumber(
    String title,
    String number,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 16,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _makePhoneCall(number),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                number,
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
    );
  }
}

class ReportStep {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final String actionText;
  final bool isHeader;

  ReportStep({
    required this.title,
    this.subtitle = '',
    required this.description,
    required this.icon,
    required this.color,
    this.actionText = '',
    this.isHeader = false,
  });
}
