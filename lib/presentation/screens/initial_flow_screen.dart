import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <--- ADD THIS LINE
import 'package:firebase_auth/firebase_auth.dart';
// Importa tus pantallas de destino y la de carga
import 'registration_screen.dart';
import '../common/loading_screen.dart';

class InitialFlowScreen extends StatefulWidget {
  const InitialFlowScreen({super.key});

  @override
  State<InitialFlowScreen> createState() => _InitialFlowScreenState();
}

class _InitialFlowScreenState extends State<InitialFlowScreen> {
  @override
  void initState() {
    super.initState();
    _navigateBasedOnAuth(); // Cambiado para ir directamente a la navegación basada en autenticación
  }

  // Método _checkTermsAndNavigate eliminado ya que no queremos mostrar los términos

  // Método _showTermsDialog eliminado ya que no queremos mostrar los términos

  Future<void> _navigateBasedOnAuth() async {
    if (!mounted) return;

    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.of(context).pushReplacementNamed('/registro');
    } else {
      final prefs = await SharedPreferences.getInstance();
      final String? userRole = prefs.getString('userRole');

      if (userRole == 'police') {
        Navigator.of(context).pushReplacementNamed('/police_home');
      } else if (userRole == 'citizen') {
        Navigator.of(context).pushReplacementNamed('/citizen_home');
      } else {
        // Rol no determinado o inválido. Redirigir a registro.
        // Considera si necesitas obtener el rol de Firestore si no está en SharedPreferences.
        print(
          "Rol no determinado para UID: ${user.uid}. Redirigiendo a /registro.",
        );
        Navigator.of(context).pushReplacementNamed('/registro');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Muestra una pantalla de carga mientras se realizan las verificaciones.
    return const LoadingScreen();
  }
}
