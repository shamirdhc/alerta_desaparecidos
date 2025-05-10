import 'package:flutter/material.dart';
import 'dart:async';
// Asegúrate de que la ruta a InitialFlowScreen sea correcta
import 'initial_flow_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        // Navega a InitialFlowScreen en lugar de directamente a /registro o /home
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const InitialFlowScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Usamos un Stack para asegurar que la imagen pueda cubrir toda la pantalla
      // y potencialmente añadir otros elementos encima si fuera necesario en el futuro.
      body: Stack(
        fit: StackFit.expand, // Hace que el Stack ocupe toda la pantalla
        children: <Widget>[
          Image.asset(
            'assets/icons/splash_screen.png', // Ruta de tu imagen
            fit:
                BoxFit
                    .cover, // Asegura que la imagen cubra todo el espacio disponible
          ),
          //Puedes añadir un CircularProgressIndicator encima si lo deseas,
          //aunque una splash screen con imagen completa a veces no lo lleva.
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white,
                ), // Color opcional
              ),
            ),
          ),
        ],
      ),
    );
  }
}
