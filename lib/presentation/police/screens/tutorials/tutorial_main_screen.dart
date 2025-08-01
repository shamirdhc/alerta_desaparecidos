import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'tutorial_google_drive_screen.dart';
import 'tutorial_whatsapp_screen.dart';
import 'tutorial_usb_screen.dart';

class TutorialMainScreen extends StatelessWidget {
  const TutorialMainScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text(
          'Tutoriales de Transferencia',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF1B263B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con logo PNP
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1565C0),
                    const Color(0xFF0D47A1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/icons/logo_pnp_policia.png',
                    height: 60,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'POLICÍA NACIONAL DEL PERÚ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tutoriales para Transferir Archivos',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Introducción
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Información Importante',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Después de registrar un caso en el sistema oficial PNP, necesitas subir la ficha y foto del desaparecido a esta aplicación móvil.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Elige el método que más te convenga:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Opciones de tutorial
            const Text(
              'Selecciona un Método:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Tutorial Google Drive
            _buildTutorialCard(
              context,
              title: 'Google Drive',
              subtitle: 'Método más fácil y recomendado',
              description: 'Sube archivos a la nube y accede desde cualquier dispositivo',
              icon: FontAwesomeIcons.googleDrive,
              color: const Color(0xFF4285F4),
              difficulty: 'Fácil',
              time: '5 minutos',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TutorialGoogleDriveScreen(),
                ),
              ),
            ),
            
            const SizedBox(height: 15),
            
            // Tutorial WhatsApp
            _buildTutorialCard(
              context,
              title: 'WhatsApp Web',
              subtitle: 'Rápido y familiar',
              description: 'Usa WhatsApp desde tu PC para enviar archivos',
              icon: FontAwesomeIcons.whatsapp,
              color: const Color(0xFF25D366),
              difficulty: 'Fácil',
              time: '3 minutos',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TutorialWhatsAppScreen(),
                ),
              ),
            ),
            
            const SizedBox(height: 15),
            
            // Tutorial USB
            _buildTutorialCard(
              context,
              title: 'Cable USB',
              subtitle: 'Método tradicional',
              description: 'Conecta directamente tu celular al PC',
              icon: FontAwesomeIcons.usb,
              color: const Color(0xFFFF6B35),
              difficulty: 'Intermedio',
              time: '7 minutos',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TutorialUsbScreen(),
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Archivos de práctica
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.school,
                        color: Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Archivos de Práctica',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Incluimos archivos de ejemplo para que practiques:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'ficha_prueba.pdf',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.image, color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'imagen_prueba.jpg',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color color,
    required String difficulty,
    required String time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 5),
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
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FaIcon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white54,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              description,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                _buildInfoChip(difficulty, Icons.signal_cellular_alt, Colors.green),
                const SizedBox(width: 10),
                _buildInfoChip(time, Icons.access_time, Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}