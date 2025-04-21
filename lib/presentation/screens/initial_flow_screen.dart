import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../citizen/screens/citizen_home_screen.dart';
import '../police/screens/police_home_screen.dart';
import 'registration_screen.dart';

class InitialFlowScreen extends StatefulWidget {
  const InitialFlowScreen({super.key});

  @override
  State<InitialFlowScreen> createState() => _InitialFlowScreenState();
}

class _InitialFlowScreenState extends State<InitialFlowScreen> {
  Future<void> _checkUserAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final termsAccepted = prefs.getBool('terms_accepted') ?? false;

    if (!termsAccepted) {
      _showTermsAndConditions(context);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // El usuario está autenticado, verificar su rol en Firestore

      // Verificar si es policía
      final policeSnapshot =
          await FirebaseFirestore.instance
              .collection('policias')
              .where('uid', isEqualTo: user.uid)
              .get();
      if (policeSnapshot.docs.isNotEmpty) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PoliceHomeScreen()),
          );
        }
        return;
      }

      // Verificar si es ciudadano
      final citizenDoc =
          await FirebaseFirestore.instance
              .collection('ciudadanos')
              .doc(user.uid)
              .get();
      if (citizenDoc.exists &&
          citizenDoc.data() != null &&
          citizenDoc.data()!['rol'] == 'ciudadano') {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CitizenHomeScreen()),
          );
        }
        return;
      }

      // Si el usuario está autenticado pero no se encuentra su rol,
      // o si el documento en ciudadanos no tiene el campo 'rol' (para el caso de ciudadanos),
      // lo redirigimos a la pantalla de registro para que vuelva a completar el proceso.
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RegistrationScreen()),
        );
      }
    } else {
      // El usuario no está autenticado, ir a la pantalla de registro
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RegistrationScreen()),
        );
      }
    }
  }

  Future<void> _showTermsAndConditions(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must accept the terms
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Términos y Condiciones'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Aquí irán los términos y condiciones de la aplicación. Por favor, léalos cuidadosamente.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 10),
                // Puedes agregar más texto o un archivo de texto aquí
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Rechazar'),
              onPressed: () {
                // Puedes implementar lógica para cerrar la aplicación o mostrar un mensaje
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Aceptar'),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('terms_accepted', true);
                Navigator.of(context).pop();
                _checkUserAuthState(); // Re-check the auth state after accepting terms
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _checkUserAuthState();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
