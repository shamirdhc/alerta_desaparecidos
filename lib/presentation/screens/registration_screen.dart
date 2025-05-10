import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'otp_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final bool showTermsPrompt; // <-- ADD THIS FIELD

  const RegistrationScreen({
    super.key,
    this.showTermsPrompt = false, // <-- ADD THIS PARAMETER WITH A DEFAULT VALUE
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String? _errorMessage;
  bool _isRegistering = false;

  Future<bool> _isNumberVetoed(String phoneNumber) async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('vetados')
            .where('numero_telefono', isEqualTo: phoneNumber)
            .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> _registerUser(String phoneNumber) async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          // La navegación ahora se maneja en OTPScreen
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _errorMessage =
                'Error al enviar el código de verificación: ${e.message}';
            _isRegistering = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => OTPScreen(
                    phoneNumber: phoneNumber,
                    verificationId: verificationId,
                  ),
            ),
          );
          setState(() {
            _isRegistering = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _errorMessage =
                'Tiempo de espera para la auto-verificación agotado.';
            _isRegistering = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error durante el registro: $e';
        _isRegistering = false;
      });
    }
  }

  Future<void> _registerOrLogin() async {
    setState(() {
      _errorMessage = null;
      _isRegistering = true;
    });

    final String phoneNumber = '+51${_phoneController.text.trim()}';

    if (await _isNumberVetoed(phoneNumber)) {
      setState(() {
        _errorMessage =
            'El número de teléfono proporcionado ha sido identificado por infringir los términos de servicio y no puede ser utilizado para el registro.';
        _isRegistering = false;
      });
      return;
    }

    _registerUser(phoneNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Número de Teléfono (Ej: 9XXXXXXXX)',
                border: OutlineInputBorder(),
              ),
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
              onPressed: _isRegistering ? null : _registerOrLogin,
              child: Text(_isRegistering ? 'Verificando...' : 'Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}
