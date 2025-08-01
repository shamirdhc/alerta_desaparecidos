import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TutorialGoogleDriveScreen extends StatefulWidget {
  const TutorialGoogleDriveScreen({Key? key}) : super(key: key);

  @override
  _TutorialGoogleDriveScreenState createState() => _TutorialGoogleDriveScreenState();
}

class _TutorialGoogleDriveScreenState extends State<TutorialGoogleDriveScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<TutorialStep> _steps = [
    TutorialStep(
      title: "Google Drive",
      subtitle: "El método más fácil y seguro",
      description: "Google Drive te permite subir archivos desde tu PC y descargarlos en tu celular de forma automática.",
      icon: FontAwesomeIcons.googleDrive,
      color: const Color(0xFF4285F4),
      isIntro: true,
    ),
    TutorialStep(
      title: "Paso 1: Abrir Google Drive en PC",
      subtitle: "Accede desde tu computadora",
      description: "En tu PC, abre el navegador web (Chrome, Firefox, etc.)",
      icon: Icons.computer,
      color: const Color(0xFF4285F4),
      detailedSteps: [
        "1. Abre tu navegador web favorito",
        "2. Escribe en la barra de direcciones: drive.google.com",
        "3. Presiona Enter para ir a la página",
        "4. Si no has iniciado sesión, te pedirá tu Gmail y contraseña"
      ],
      tips: [
        "💡 Usa el mismo Gmail que tienes en tu celular",
        "🔒 Google Drive es completamente seguro",
        "📱 También puedes usar drive.google.com desde cualquier navegador"
      ],
    ),
    TutorialStep(
      title: "Paso 2: Subir los Archivos",
      subtitle: "Arrastra o selecciona tus archivos",
      description: "Sube la ficha PDF y la imagen del desaparecido",
      icon: Icons.cloud_upload,
      color: const Color(0xFF4285F4),
      detailedSteps: [
        "1. Busca el botón '+ Nuevo' en la esquina superior izquierda",
        "2. Haz clic en 'Subir archivo'",
        "3. Selecciona primero la ficha PDF del desaparecido",
        "4. Espera a que se suba (verás una barra de progreso)",
        "5. Repite el proceso para subir la imagen JPG",
        "6. ¡Listo! Tus archivos están en la nube"
      ],
      tips: [
        "📁 También puedes arrastrar los archivos directamente",
        "⏱️ La subida puede tomar unos segundos dependiendo del tamaño",
        "✅ Verás una marca verde cuando se complete la subida"
      ],
    ),
    TutorialStep(
      title: "Paso 3: Abrir Drive en el Celular",
      subtitle: "Accede desde tu dispositivo móvil",
      description: "Ahora abre Google Drive en tu celular",
      icon: Icons.phone_android,
      color: const Color(0xFF4285F4),
      detailedSteps: [
        "1. En tu celular, busca la app 'Google Drive'",
        "2. Si no la tienes, descárgala gratis de Play Store",
        "3. Abre la aplicación",
        "4. Inicia sesión con la MISMA cuenta de Gmail",
        "5. Verás tus archivos recién subidos"
      ],
      tips: [
        "📱 La app Google Drive es gratuita",
        "🔄 Los archivos se sincronizan automáticamente",
        "👀 Deberías ver los archivos que subiste desde la PC"
      ],
    ),
    TutorialStep(
      title: "Paso 4: Descargar al Celular",
      subtitle: "Guarda los archivos en tu dispositivo",
      description: "Descarga los archivos para usarlos en la app",
      icon: Icons.download,
      color: const Color(0xFF4285F4),
      detailedSteps: [
        "1. Toca el archivo que quieres descargar",
        "2. Toca los 3 puntos (⋮) al lado del archivo",
        "3. Selecciona 'Descargar'",
        "4. El archivo se guardará en tu celular",
        "5. Repite para el segundo archivo",
        "6. ¡Ya puedes usar los archivos en la app!"
      ],
      tips: [
        "📂 Los archivos se guardan en la carpeta 'Descargas'",
        "🔍 Puedes buscar archivos por nombre en Drive",
        "💾 Una vez descargados, no necesitas internet para usarlos"
      ],
    ),
    TutorialStep(
      title: "Paso 5: Usar en la App",
      subtitle: "Selecciona los archivos descargados",
      description: "Ahora puedes seleccionar los archivos en el formulario",
      icon: Icons.assignment,
      color: const Color(0xFF4CAF50),
      detailedSteps: [
        "1. Regresa al formulario de reporte de desaparecido",
        "2. Toca 'Foto de la Persona'",
        "3. Selecciona 'Galería' o 'Archivos'",
        "4. Busca en la carpeta 'Descargas'",
        "5. Selecciona la imagen descargada",
        "6. Repite para la ficha PDF"
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
          'Tutorial: Google Drive',
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
              const Icon(Icons.check_circle, color: Colors.green, size: 40),
              const SizedBox(height: 15),
              const Text(
                'Ventajas de Google Drive:',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              _buildAdvantage('Gratis y seguro'),
              _buildAdvantage('Funciona en cualquier dispositivo'),
              _buildAdvantage('Sincronización automática'),
              _buildAdvantage('No necesitas cables'),
              _buildAdvantage('Acceso desde cualquier lugar'),
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
              const Icon(Icons.info, color: Colors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Necesitas una cuenta de Gmail. Si no tienes, puedes crear una gratis.',
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
                'Instrucciones detalladas:',
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
                  'Consejos útiles:',
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
          const Icon(Icons.celebration, color: Colors.green, size: 40),
          const SizedBox(height: 15),
          const Text(
            '¡Excelente trabajo!',
            style: TextStyle(
              color: Colors.green,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ya sabes cómo usar Google Drive para transferir archivos. Este método es el más recomendado por su facilidad y seguridad.',
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