import 'package:alerta_desaparecidos/presentation/screens/otp_screen.dart';
import 'package:alerta_desaparecidos/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Esta línea se puede eliminar si no se usa en otro lugar

class RegistrationScreen extends StatefulWidget {
  static const routeName = '/registration-screen';

  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey();
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _phoneController = TextEditingController();
  PhoneNumber? _phoneNumber;
  bool _isRegistering = false;
  String? _errorMessage;
  int _verificationAttempts = 0;
  final int _maxAttempts = 2;

  bool _isNavigationScheduled = false;
  String? _verificationIdForNavigation;
  String? _phoneNumberForNavigation;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _registerUser(String phoneNumber) async {
    if (!mounted) return;
    setState(() {
      _isRegistering = true;
      _errorMessage = null;
    });

    await _firebaseService.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        if (!mounted) return;
        setState(() {
          _isRegistering = false;
        });
        // En un escenario real, podrías querer auto-iniciar sesión aquí.
        // Por ahora, navegamos a la pantalla de OTP como en los otros casos.
        _scheduleNavigation(phoneNumber, null);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() {
          _isRegistering = false;
          if (e.code == 'too-many-requests' ||
              (e.message?.contains('reCAPTCHA') ?? false)) {
            _errorMessage =
                'Demasiados intentos o problema de verificación. Inténtalo más tarde.';
          } else {
            _errorMessage = 'Error de verificación: ${e.message}';
          }
          _verificationAttempts++;
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        print(
          'Verification code sent to $phoneNumber. VerificationId: $verificationId',
        );
        _scheduleNavigation(phoneNumber, verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!mounted) return;
        print('Auto-retrieval timeout. VerificationId: $verificationId');
        _scheduleNavigation(phoneNumber, verificationId);
      },
    );
  }

  void _scheduleNavigation(String phoneNumber, String? verificationId) {
    if (!mounted) return;

    // Ya no usamos setState para un flag. Navegamos directamente después del frame.
    _isNavigationScheduled = true; // Mantenemos el flag por si acaso, pero la lógica cambia.
    _phoneNumberForNavigation = phoneNumber;
    _verificationIdForNavigation = verificationId;
    _isRegistering = false;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OTPScreen(
              phoneNumber: _phoneNumberForNavigation!,
              verificationId: _verificationIdForNavigation,
            ),
          ),
        );
      }
    });
  }

  void _registerOrLogin() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    if (_phoneNumber?.countryISOCode != 'PE') {
      _showPeruOnlyWarning();
      return;
    }

    final fullNumber = _phoneNumber!.completeNumber;
    _registerUser(fullNumber);
  }

  void _showPeruOnlyWarning() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Número no válido'),
            content: const Text(
              'Por el momento, solo se admiten números de Perú.',
            ),
            actions: [
              TextButton(
                child: const Text('Entendido'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
    );
  }

  void _resetState() {
    setState(() {
      _isRegistering = false;
      _errorMessage = null;
      _verificationAttempts = 0;
      _phoneController.clear();
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Eliminamos completamente el bloque if (_isNavigationScheduled) de aquí.

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Image.asset('assets/icons/logo_pnp_policia.png', height: 100),
                const SizedBox(height: 10),
                Image.asset('assets/icons/logo_pnp_letras.png', height: 80),
                const SizedBox(height: 40),
                const Text(
                  'Ingresa tu número de celular para continuar',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 30),
                IntlPhoneField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Número de celular',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.phone),
                  ),
                  initialCountryCode: 'PE',
                  onChanged: (phone) {
                    _phoneNumber = phone;
                  },
                  validator: (phoneNumber) {
                    if (phoneNumber == null || phoneNumber.number.isEmpty) {
                      return 'Por favor, ingresa tu número.';
                    }
                    if (phoneNumber.countryISOCode == 'PE' &&
                        phoneNumber.number.length != 9) {
                      return 'El número de celular de Perú debe tener 9 dígitos.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_verificationAttempts >= _maxAttempts)
                  Column(
                    children: [
                      const Text(
                        'Has superado el número de intentos de verificación.',
                        style: TextStyle(color: Colors.orange, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Intentar de nuevo'),
                        onPressed: _resetState,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isRegistering ? null : _registerOrLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child:
                          _isRegistering
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : const Text(
                                'Registrarme',
                                style: TextStyle(fontSize: 16),
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
