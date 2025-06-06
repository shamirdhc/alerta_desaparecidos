import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportMissingScreen extends StatelessWidget {
  const ReportMissingScreen({super.key});

  final String _reportNumber = '+51948269740';

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'No se pudo realizar la llamada a \$launchUri';
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    final Uri whatsappUri = Uri.parse(
      'https://wa.me/\$phoneNumber?text=Hola,%20necesito%20reportar%20una%20desaparición.',
    );
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri);
    } else {
      throw 'No se pudo abrir WhatsApp';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar Desaparición'),
        backgroundColor: Colors.transparent, // Make app bar transparent
        elevation: 0, // Remove shadow
      ),
      extendBodyBehindAppBar: true, // Extend body behind app bar for full-screen gradient
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFADD8E6), // Azul Suave
              Color(0xFF90EE90), // Verde Esperanza
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '¿Cómo deseas contactarnos para reportar una desaparición?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Adjust text color for better contrast
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => _makePhoneCall(_reportNumber),
                icon: const FaIcon(FontAwesomeIcons.phone, color: Colors.white), // Icon color
                label: const Text('Llamar a la Policía', style: TextStyle(color: Colors.white)), // Text color
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800, // Darker blue for consistency
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _openWhatsApp(_reportNumber),
                icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white), // Icon color
                label: const Text('Enviar mensaje por WhatsApp', style: TextStyle(color: Colors.white)), // Text color
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700, // Slightly darker green
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}