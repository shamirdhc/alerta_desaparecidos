import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- AÑADIR ESTA LÍNEA
import '../citizen/screens/citizen_home_screen.dart';
import '../police/screens/police_home_screen.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OTPScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final TextEditingController _otpController = TextEditingController();
  String? _errorMessage;
  bool _verifying = false;

  Future<bool> _isNumberInPoliceCollection(String phoneNumber) async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('policias')
            .where('telefono', isEqualTo: phoneNumber)
            .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> _createUserFirestore(String uid, String phoneNumber) async {
    try {
      await FirebaseFirestore.instance.collection('ciudadanos').doc(uid).set({
        'telefono': phoneNumber,
        'rol': 'ciudadano', // Asegúrate que el rol se guarda aquí también
        'fecha_registro': FieldValue.serverTimestamp(),
        'uid': uid,
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al crear el perfil del ciudadano: $e';
        _verifying = false;
      });
      return;
    }
  }

  Future<void> _verifyOTPAndNavigate() async {
    setState(() {
      _errorMessage = null;
      _verifying = true;
    });
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otpController.text.trim(),
      );
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final phoneNumber = widget.phoneNumber;
        final isPolice = await _isNumberInPoliceCollection(phoneNumber);
        final prefs = await SharedPreferences.getInstance(); // <-- OBTENER INSTANCIA

        if (isPolice) {
          await prefs.setString('userRole', 'police'); // <-- GUARDAR ROL POLICÍA
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const PoliceHomeScreen()),
            );
          }
        } else {
          // Primero, asegúrate de que el perfil del ciudadano se cree o verifique.
          // La función _createUserFirestore ya establece el rol 'ciudadano' en Firestore.
          await _createUserFirestore(user.uid, phoneNumber);
          
          // Solo proceder si no hubo error en _createUserFirestore
          if (_errorMessage == null) { 
            await prefs.setString('userRole', 'citizen'); // <-- GUARDAR ROL CIUDADANO
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const CitizenHomeScreen(),
                ),
              );
            }
          } else {
            // Si hubo un error al crear el perfil (ej. _errorMessage fue seteado en _createUserFirestore),
            // no navegamos y el error se mostrará.
             setState(() {
              _verifying = false; // Detener la indicación de carga
            });
          }
        }
      } else {
        setState(() {
          _errorMessage = 'Error al autenticar al usuario.';
          _verifying = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = 'Código OTP inválido o expirado: ${e.message}';
        _verifying = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ocurrió un error inesperado: $e';
        _verifying = false;
      });
    } finally {
      if (mounted && _errorMessage != null) {
        setState(() {
          _verifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verificar OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Text('Se envió un código de verificación a ${widget.phoneNumber}'),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Código OTP'),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _verifying ? null : _verifyOTPAndNavigate,
              child: Text(_verifying ? 'Verificando...' : 'Verificar Código'),
            ),
          ],
        ),
      ),
    );
  }
}
