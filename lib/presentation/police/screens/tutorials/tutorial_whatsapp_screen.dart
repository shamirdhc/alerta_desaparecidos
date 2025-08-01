import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TutorialWhatsAppScreen extends StatefulWidget {
  const TutorialWhatsAppScreen({Key? key}) : super(key: key);

  @override
  _TutorialWhatsAppScreenState createState() => _TutorialWhatsAppScreenState();
}

class _TutorialWhatsAppScreenState extends State<TutorialWhatsAppScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<TutorialStep> _steps = [
    TutorialStep(
      title: "WhatsApp Web",
      subtitle: "Rápido y familiar",
      description: "Usa WhatsApp desde tu PC para enviar archivos a tu celular de forma instantánea.",
      icon: FontAwesomeIcons.whatsapp,
      color: const Color(0xFF25D366),
      isIntro: true,
    ),
    TutorialStep(
      title: "Paso 1: Abrir WhatsApp Web",
      subtitle: "Accede desde tu computadora",
      description: "En tu PC, abre WhatsApp Web en el navegador",
      icon: Icons.computer,
      color: const Color(0xFF25D366),
      detailedSteps: [
        "1. En tu PC, abre tu navegador web",
        "2. Escribe: web.whatsapp.com",
        "3. Presiona Enter",
        "4. Verás un código QR en la pantalla",
        "5. NO cierres esta ventana"
      ],
      tips: [
        "💻 Funciona en Chrome, Firefox, Safari, Edge",
        "📱 Necesitas tener WhatsApp instalado en tu celular",
        "🔄 La página se actualiza automáticamente"
      ],
    ),
    TutorialStep(
      title: "Paso 2: Escanear Código QR",
      subtitle: "Conecta tu celular con la PC",
      description: "Usa tu celular para escanear el código QR",
      icon: Icons.qr_code_scanner,
      color: const Color(0xFF25D366),
      detailedSteps: [
        "1. Toma tu celular y abre WhatsApp",
        "2. Toca los 3 puntos (⋮) en la esquina superior derecha",
        "3. Selecciona 'Dispositivos vinculados'",
        "4. Toca 'Vincular un dispositivo'",
        "5. Apunta la cámara al código QR de la PC",
        "6. ¡Listo! WhatsApp se abrirá en tu PC"
      ],
      tips: [
        "📷 Asegúrate de que la cámara enfoque bien el código",
        "💡 Si no funciona, actualiza la página web",
        "🔒 La conexión es completamente segura"
      ],
    ),
    TutorialStep(
      title: "Paso 3: Crear Chat Contigo Mismo",
      subtitle: "Envíate los archivos",
      description: "Crea un chat personal para transferir archivos",
      icon: Icons.chat,
      color: const Color(0xFF25D366),
      detailedSteps: [
        "1. En WhatsApp Web, busca tu propio número",
        "2. O crea un grupo solo contigo",
        "3. También puedes usar 'Mensajes guardados'",
        "4. Abre el chat que creaste",
        "5. Ya estás listo para enviar archivos"
      ],
      tips: [
        "💡 Puedes enviarte mensajes a ti mismo",
        "📁 Los archivos aparecerán en tu celular inmediatamente",
        "🗂️ Usa este chat como tu 'carpeta personal'"
      ],
    ),
    TutorialStep(
      title: "Paso 4: Enviar los Archivos",
      subtitle: "Sube la ficha y la imagen",
      description: "Arrastra o selecciona los archivos desde tu PC",
      icon: Icons.attach_file,
      color: const Color(0xFF25D366),
      detailedSteps: [
        "1. En el chat, busca el ícono de clip (📎)",
        "2. Haz clic en 'Documento' para la ficha PDF",
        "3. Selecciona el archivo PDF del desaparecido",
        "4. Haz clic en 'Enviar'",
        "5. Repite el proceso para la imagen JPG",
        "6. También puedes arrastrar archivos directamente"
      ],
      tips: [
        "📎 El clip está al lado de donde escribes mensajes",
        "🖱️ Arrastra archivos directamente al chat",
        "⚡ Los archivos se envían muy rápido"
      ],
    ),
    TutorialStep(
      title: "Paso 5: Descargar en el Celular",
      subtitle: "Guarda los archivos en tu dispositivo",
      description: "Descarga los archivos desde WhatsApp en tu celular",
      icon: Icons.download,
      color: const Color(0xFF25D366),
      detailedSteps: [
        "1. En tu celular, abre WhatsApp",
        "2. Ve al chat donde enviaste los archivos",
        "3. Toca el archivo que quieres descargar",
        "4. Toca el ícono de descarga (⬇️)",
        "5. El archivo se guardará en tu celular",
        "6. Repite para todos los archivos"
      ],
      tips: [
        "📂 Los archivos se guardan en WhatsApp/Media",
        "🔍 También aparecen en la galería (imágenes)",
        "💾 Una vez descargados, están disponibles sin internet"
      ],
    ),
    TutorialStep(
      title: "Paso 6: Usar en la App",
      subtitle: "Selecciona los archivos descargados",
      description: "Ahora puedes usar los archivos en el formulario",
      icon: Icons.assignment,
      color: const Color(0xFF4CAF50),
      detailedSteps: [
        "1. Regresa al formulario de reporte",
        "2. Toca 'Foto de la Persona'",
        "3. Selecciona 'Galería' para imágenes",
        "4. Busca la imagen en WhatsApp Images",
        "5. Para PDFs, selecciona 'Archivos'",
        "6. Busca en WhatsApp/Documents"
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
          'Tutorial: WhatsApp Web',
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
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index <= _currentPage 
                              ? _steps[_currentPage].color 
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
                      : 'Completado'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _steps[_currentPage].color,
                    foregroundColor: Colors.white,
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
              border: Border.all(color: step.color, width: 2),
            ),
            child: step.icon is IconData 
                ? Icon(step.icon as IconData, size: 60, color: step.color)
                : FaIcon(step.icon as IconData, size: 60, color: step.color),
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
          
          // Descripción
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              step.description,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Contenido específico
          if (step.isIntro) _buildIntroContent(),
          if (step.detailedSteps != null) _buildStepsContent(step),
          if (step.isConclusion) _buildConclusionContent(),
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
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 40),
              const SizedBox(height: 15),
              const Text(
                'Ventajas de WhatsApp Web:',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              _buildAdvantage('Muy rápido y fácil'),
              _buildAdvantage('Ya conoces WhatsApp'),
              _buildAdvantage('No necesitas apps adicionales'),
              _buildAdvantage('Transferencia instantánea'),
              _buildAdvantage('Funciona con cualquier archivo'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Necesitas tener WhatsApp instalado en tu celular.',
                  style: TextStyle(color: Colors.blue.shade100),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvantage(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsContent(TutorialStep step) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Instrucciones paso a paso:',
                style: TextStyle(
                  color: step.color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              ...step.detailedSteps!.map((stepText) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: step.color,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${step.detailedSteps!.indexOf(stepText) + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        stepText.substring(stepText.indexOf(' ') + 1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
        
        if (step.tips != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Consejos importantes:',
                  style: TextStyle(
                    color: Colors.orange,
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

  Widget _buildConclusionContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        children: [
          const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 40),
          const SizedBox(height: 15),
          const Text(
            '¡Perfecto!',
            style: TextStyle(
              color: Colors.green,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'WhatsApp Web es una excelente opción para transferir archivos rápidamente. Es ideal cuando necesitas enviar archivos de forma inmediata.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.assignment),
            label: const Text('Ir al Formulario'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class TutorialStep {
  final String title;
  final String subtitle;
  final String description;
  final dynamic icon;
  final Color color;
  final List<String>? detailedSteps;
  final List<String>? tips;
  final bool isIntro;
  final bool isConclusion;

  TutorialStep({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    this.detailedSteps,
    this.tips,
    this.isIntro = false,
    this.isConclusion = false,
  });
}