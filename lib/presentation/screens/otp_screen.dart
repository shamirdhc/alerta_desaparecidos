import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../citizen/screens/citizen_home_screen.dart';
import '../police/screens/police_home_screen.dart';
import 'package:pinput/pinput.dart'; // Importar el paquete pinput

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
    // Definir el estilo por defecto para Pinput
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(
          fontSize: 20,
          color: Color.fromRGBO(30, 60, 87, 1),
          fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        border: Border.all(color: Color.fromRGBO(234, 239, 243, 1)),
        borderRadius: BorderRadius.circular(20),
      ),
    );

    // Definir el estilo con el foco
    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Color.fromRGBO(114, 178, 238, 1)),
      borderRadius: BorderRadius.circular(8),
    );

    // Definir el estilo con el campo lleno
    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        color: Color.fromRGBO(234, 239, 243, 1),
      ),
    );

    return Scaffold(
      // appBar: AppBar(title: const Text('Verificar OTP')), // Eliminar AppBar
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
        child: Padding(
          padding: const EdgeInsets.all(24.0), // Ajustar padding
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center, // Centrar contenido horizontalmente
              children: <Widget>[
                const SizedBox(height: 80), // Espacio superior
                // Puedes añadir un icono o imagen aquí similar a la pantalla de registro
                // Por ejemplo:
                // Image.asset('assets/icons/some_verification_icon.png', height: 100),
                // const SizedBox(height: 20),

                Text(
                  'Verificación de Código',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Se envió un código de verificación a ${widget.phoneNumber}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 40), // Espacio antes del campo OTP

                // Reemplazar TextField con Pinput
                Pinput(
                  controller: _otpController,
                  length: 6, // Longitud del código OTP
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  submittedPinTheme: submittedPinTheme,
                  pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                  showCursor: true,
                  onCompleted: (pin) => _verifyOTPAndNavigate(), // Verificar automáticamente al completar
                ),

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 40), // Espacio antes del botón

                ElevatedButton(
                  onPressed: _verifying ? null : _verifyOTPAndNavigate,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue.shade800,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                  child: _verifying
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Verificar Código',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
