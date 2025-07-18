import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../citizen/screens/citizen_home_screen.dart';
import '../police/screens/police_home_screen.dart';
import 'citizen_registration_form_screen.dart';
import 'package:pinput/pinput.dart'; // Importar el paquete pinput

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String? verificationId;

  const OTPScreen({
    super.key,
    required this.phoneNumber,
    this.verificationId, // Ya no es requerido
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

  Future<void> _verifyOTPAndNavigate() async {
    setState(() {
      _errorMessage = null;
      _verifying = true;
    });
    try {
      if (widget.verificationId == null) {
        setState(() {
          _errorMessage = 'No se pudo obtener el ID de verificación. Inténtalo de nuevo.';
          _verifying = false;
        });
        return;
      }
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId!,
        smsCode: _otpController.text.trim(),
      );
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final phoneNumber = widget.phoneNumber;
        final isPolice = await _isNumberInPoliceCollection(phoneNumber);
        final prefs = await SharedPreferences.getInstance();

        if (isPolice) {
          await prefs.setString('userRole', 'police');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const PoliceHomeScreen()),
            );
          }
        } else {
          // Verificar si el usuario ciudadano ya existe en Firestore
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('ciudadanos')
                  .doc(user.uid)
                  .get();

          if (userDoc.exists) {
            // Usuario existente - acceso normal
            await prefs.setString('userRole', 'citizen');
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const CitizenHomeScreen(),
                ),
              );
            }
          } else {
            // Usuario nuevo - mostrar formulario de registro
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => CitizenRegistrationFormScreen(
                        uid: user.uid,
                        phoneNumber: phoneNumber,
                      ),
                ),
              );
            }
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
        fontWeight: FontWeight.w600,
      ),
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
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 80),

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
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 40),

                // Reemplazar TextField con Pinput
                Pinput(
                  controller: _otpController,
                  length: 6,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  submittedPinTheme: submittedPinTheme,
                  pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                  showCursor: true,
                  onCompleted: (pin) => _verifyOTPAndNavigate(),
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
                const SizedBox(height: 40),

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
                  child:
                      _verifying
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
