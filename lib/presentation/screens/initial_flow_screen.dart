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
    _checkTermsAndNavigate();
  }

  Future<void> _checkTermsAndNavigate() async {
    final prefs =
        await SharedPreferences.getInstance(); // Now this should be recognized
    bool termsAccepted = prefs.getBool('terms_accepted') ?? false;

    if (!mounted) return;

    if (!termsAccepted) {
      final accepted = await _showTermsDialog();
      if (accepted == true) {
        await prefs.setBool('terms_accepted', true);
        _navigateBasedOnAuth();
      } else {
        // Usuario no aceptó. Podrías cerrar la app, o redirigir a registro
        // con un mensaje indicando que los términos son necesarios.
        // Por ejemplo, redirigir a registro:
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const RegistrationScreen(showTermsPrompt: true),
            ),
          );
        }
      }
    } else {
      _navigateBasedOnAuth();
    }
  }

  Future<bool?> _showTermsDialog() async {
    if (!mounted) return false;
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Términos y Condiciones'),
          content: const SingleChildScrollView(
            child: Text(
              'Aquí va el texto completo de tus términos y condiciones...\n'
              'Al presionar "Aceptar", confirmas que has leído y estás de acuerdo.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Rechazar'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Aceptar'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateBasedOnAuth() async {
    if (!mounted) return;

    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.of(context).pushReplacementNamed('/registro');
    } else {
      final prefs = await SharedPreferences.getInstance(); // And here
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
