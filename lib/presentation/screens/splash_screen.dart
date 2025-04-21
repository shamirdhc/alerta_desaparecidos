import 'package:flutter/material.dart';
import 'initial_flow_screen.dart'; // Importa la pantalla siguiente en el flujo

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Simula una carga o espera antes de navegar a la siguiente pantalla
    Future.delayed(const Duration(seconds: 2), () {
      // Navega a InitialFlowScreen después de un breve tiempo
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const InitialFlowScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Theme.of(
            context,
          ).primaryColor, // Puedes personalizar el color de fondo
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Aquí puedes mostrar el logo de tu aplicación
            const Icon(
              Icons.local_police, // Reemplaza con el icono de tu app
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 10),
            const Text(
              'Alerta Desaparecido PNP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
