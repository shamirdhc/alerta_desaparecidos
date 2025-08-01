import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TutorialUsbScreen extends StatefulWidget {
  const TutorialUsbScreen({Key? key}) : super(key: key);

  @override
  _TutorialUsbScreenState createState() => _TutorialUsbScreenState();
}

class _TutorialUsbScreenState extends State<TutorialUsbScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<TutorialStep> _steps = [
    TutorialStep(
      title: "Tutorial: Cable USB",
      subtitle: "Aprende a transferir archivos desde tu PC al celular usando cable USB",
      icon: FontAwesomeIcons.usb,
      color: const Color(0xFFFF6B35),
      isIntro: true,
    ),
    TutorialStep(
      title: "Paso 1: Preparar el Cable",
      subtitle: "Verifica que tengas el cable correcto",
      icon: FontAwesomeIcons.plug,
      color: const Color(0xFFFF6B35),
      content: "Necesitas un cable USB que sea para DATOS, no solo para carga. La mayoría de cables que vienen con los celulares sirven para transferir datos.",
      tips: [
        "🔌 Usa el cable original de tu celular",
        "⚠️ Algunos cables baratos solo sirven para cargar",
        "✅ Si puedes ver fotos del celular en la PC, el cable sirve"
      ],
    ),
    TutorialStep(
      title: "Paso 2: Conectar Dispositivos",
      subtitle: "Conecta tu celular a la computadora",
      icon: FontAwesomeIcons.link,
      color: const Color(0xFFFF6B35),
      content: "Conecta un extremo del cable USB a tu celular y el otro extremo a un puerto USB de tu computadora. Asegúrate de que ambos dispositivos estén encendidos.",
      tips: [
        "🔋 Tu celular debe tener al menos 20% de batería",
        "💻 Usa puertos USB de la parte trasera de la PC (más estables)",
        "⏰ Espera unos segundos después de conectar"
      ],
    ),
    TutorialStep(
      title: "Paso 3: Configurar el Celular",
      subtitle: "Permite la transferencia de archivos",
      icon: FontAwesomeIcons.mobileAlt,
      color: const Color(0xFFFF6B35),
      content: "En tu celular aparecerá una notificación. Toca sobre ella y selecciona 'Transferir archivos' o 'MTP'. Si no aparece, ve a Configuración > Conexiones USB.",
      tips: [
        "📱 Busca la notificación 'USB conectado'",
        "📂 Selecciona 'Transferir archivos' NO 'Solo carga'",
        "🔓 Puede pedirte desbloquear el celular"
      ],
    ),
    TutorialStep(
      title: "Paso 4: Abrir en la PC",
      subtitle: "Accede a tu celular desde la computadora",
      icon: FontAwesomeIcons.desktop,
      color: const Color(0xFFFF6B35),
      content: "En tu PC, abre 'Este equipo' o 'Mi PC'. Verás tu celular como un dispositivo nuevo. Haz doble clic para abrirlo.",
      tips: [
        "🖥️ Busca el nombre de tu celular (ej: Samsung Galaxy)",
        "📁 Si no aparece, desconecta y vuelve a conectar",
        "🔄 Puede tardar unos segundos en aparecer"
      ],
    ),
    TutorialStep(
      title: "Paso 5: Navegar a Descargas",
      subtitle: "Encuentra la carpeta correcta",
      icon: FontAwesomeIcons.folderOpen,
      color: const Color(0xFFFF6B35),
      content: "Dentro de tu celular, busca la carpeta 'Download' o 'Descargas'. Esta es donde copiaremos los archivos para que los puedas encontrar fácilmente.",
      tips: [
        "📁 Busca carpetas: Download, Descargas, o DCIM",
        "🎯 Download es la más común para archivos",
        "📱 Algunas marcas usan nombres diferentes"
      ],
    ),
    TutorialStep(
      title: "Paso 6: Copiar Archivos",
      subtitle: "Transfiere la ficha y la imagen",
      icon: FontAwesomeIcons.copy,
      color: const Color(0xFFFF6B35),
      content: "Desde otra ventana, navega hasta donde tienes guardados los archivos del caso (ficha PDF e imagen). Selecciónalos, cópialos (Ctrl+C) y pégalos (Ctrl+V) en la carpeta Download de tu celular.",
      tips: [
        "📋 Ctrl+C para copiar, Ctrl+V para pegar",
        "📄 Copia tanto el PDF como la imagen",
        "⏳ Espera a que termine la transferencia"
      ],
    ),
    TutorialStep(
      title: "Paso 7: Verificar Transferencia",
      subtitle: "Confirma que los archivos se copiaron",
      icon: FontAwesomeIcons.checkCircle,
      color: const Color(0xFF4CAF50),
      content: "Verifica que los archivos aparezcan en la carpeta Download de tu celular. Deberías ver tanto el archivo PDF de la ficha como la imagen del desaparecido.",
      tips: [
        "✅ Verifica que el tamaño del archivo sea correcto",
        "📱 Los archivos deben aparecer en tu celular",
        "🔍 Puedes abrir los archivos para confirmar"
      ],
    ),
    TutorialStep(
      title: "Paso 8: Desconectar Seguro",
      subtitle: "Desconecta correctamente los dispositivos",
      icon: FontAwesomeIcons.eject,
      color: const Color(0xFFFF6B35),
      content: "En tu PC, haz clic derecho sobre tu celular en 'Este equipo' y selecciona 'Expulsar'. Espera a que aparezca el mensaje de que es seguro desconectar, luego desconecta el cable.",
      tips: [
        "⚠️ SIEMPRE expulsa antes de desconectar",
        "🔒 Espera el mensaje 'Seguro para quitar'",
        "📱 Tu celular volverá al modo normal"
      ],
    ),
    TutorialStep(
      title: "¡Archivos Listos!",
      subtitle: "Ya puedes usar los archivos en la app",
      icon: FontAwesomeIcons.thumbsUp,
      color: const Color(0xFF4CAF50),
      content: "Los archivos ya están en tu celular. Ahora puedes ir al formulario de reporte y seleccionarlos desde la galería o administrador de archivos.",
      tips: [
        "📱 Los archivos están en Descargas",
        "📋 Ve al formulario de reporte",
        "🎯 Selecciona los archivos desde la app"
      ],
      isConclusion: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text(
          'Tutorial: Cable USB',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1B263B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Salir',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Indicador de progreso
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: List.generate(_steps.length, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: index <= _currentPage 
                              ? const Color(0xFFFF6B35)
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Text(
                  'Paso ${_currentPage + 1} de ${_steps.length}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Contenido del tutorial
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _steps.length,
              itemBuilder: (context, index) {
                return _buildTutorialPage(_steps[index]);
              },
            ),
          ),
          
          // Botones de navegación
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0)
                  ElevatedButton.icon(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Anterior'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  )
                else
                  const SizedBox(),
                
                ElevatedButton.icon(
                  onPressed: () {
                    if (_currentPage < _steps.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  icon: Icon(_currentPage < _steps.length - 1 
                      ? Icons.arrow_forward 
                      : Icons.check),
                  label: Text(_currentPage < _steps.length - 1 
                      ? 'Siguiente' 
                      : 'Finalizar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialPage(TutorialStep step) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Icono principal
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: step.color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: step.color, width: 3),
            ),
            child: FaIcon(
              step.icon,
              size: 50,
              color: step.color,
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Título
          Text(
            step.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 15),
          
          // Subtítulo
          Text(
            step.subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 30),
          
          // Contenido específico
          if (step.isIntro) _buildIntroContent(),
          if (step.isConclusion) _buildConclusionContent(),
          if (!step.isIntro && !step.isConclusion) _buildStepContent(step),
        ],
      ),
    );
  }

  Widget _buildIntroContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.info_outline,
                color: Colors.white,
                size: 30,
              ),
              const SizedBox(height: 15),
              const Text(
                'El cable USB es el método más directo y seguro para transferir archivos desde tu computadora al celular.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Te guiaremos paso a paso para que puedas transferir la ficha y la imagen del desaparecido de manera fácil y segura.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildExampleFiles(),
      ],
    );
  }

  Widget _buildConclusionContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.green),
          ),
          child: Column(
            children: [
              const Icon(Icons.celebration, color: Colors.green, size: 40),
              const SizedBox(height: 15),
              const Text(
                '¡Excelente Trabajo!',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Has aprendido a transferir archivos usando cable USB. Este método es muy confiable y no requiere internet.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildNextSteps(),
      ],
    );
  }

  Widget _buildStepContent(TutorialStep step) {
    return Column(
      children: [
        // Contenido principal
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            step.content ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        // Tips
        if (step.tips != null && step.tips!.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Consejos importantes:',
                  style: TextStyle(
                    color: Color(0xFFFF6B35),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ...step.tips!.map((tip) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    tip,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                )).toList(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExampleFiles() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'Archivos que vas a transferir:',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildFileExample(
                  'ficha_prueba.pdf',
                  'Ficha del desaparecido',
                  FontAwesomeIcons.filePdf,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFileExample(
                  'imagen_prueba.jpg',
                  'Foto del desaparecido',
                  FontAwesomeIcons.image,
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileExample(String filename, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          FaIcon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            filename,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNextSteps() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Próximos pasos:',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '1. Ve al formulario de reporte de desaparecidos',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const Text(
            '2. Toca "Foto de la Persona" y selecciona la imagen',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const Text(
            '3. Toca "Ficha/Documento" y selecciona el PDF',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const Text(
            '4. Completa el resto del formulario y envía',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class TutorialStep {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? content;
  final List<String>? tips;
  final bool isIntro;
  final bool isConclusion;

  TutorialStep({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.content,
    this.tips,
    this.isIntro = false,
    this.isConclusion = false,
  });
}