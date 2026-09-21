import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <--- ADD THIS LINE
import 'package:firebase_auth/firebase_auth.dart';
// Importa tus pantallas de destino y la de carga
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateBasedOnAuth();
    });
  }

  Future<void> _navigateBasedOnAuth() async {
    if (!mounted) return;

    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.of(context).pushReplacementNamed('/welcome');
    } else {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final String? userRole = prefs.getString('userRole');

      if (userRole == 'police') {
        Navigator.of(context).pushReplacementNamed('/police_home');
      } else if (userRole == 'citizen') {
        Navigator.of(context).pushReplacementNamed('/citizen_home');
      } else {
        print(
          "Rol no determinado para UID: ${user.uid}. Redirigiendo a /welcome.",
        );
        Navigator.of(context).pushReplacementNamed('/welcome');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Muestra una pantalla de carga mientras se realizan las verificaciones.
    return const LoadingScreen();
  }
}
