import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'otp_screen.dart';
import 'package:intl_phone_field/intl_phone_field.dart'; // Importar el paquete

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
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>(); // Declarar _formKey
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

    // El IntlPhoneField ya proporciona el número completo con código de país
    final String phoneNumber = _phoneController.text.trim();

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
      // appBar: AppBar( // Eliminamos el AppBar
      //   title: const Text('Registro'),
      //   backgroundColor: Colors.transparent,
      //   elevation: 0,
      // ),
      body: Container(
        width: double.infinity, // Asegurar que ocupe todo el ancho
        height: double.infinity, // Asegurar que ocupe todo el alto
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
          padding: const EdgeInsets.all(16.0), // Mantener el padding existente
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              top: 40.0,
            ), // Añadir padding en la parte superior
            child: Form(
              // Envolver el Column con un Form
              key: _formKey, // Asignar la clave al Form
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Logo de la PNP
                  DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(
                            0.5,
                          ), // Color de la sombra
                          spreadRadius: 2, // Extensión de la sombra
                          blurRadius: 10, // Desenfoque de la sombra
                          offset: Offset(
                            0,
                            5,
                          ), // Desplazamiento de la sombra (eje X, eje Y)
                        ),
                      ],
                    ),
                    child: Transform(
                      alignment: Alignment.center,
                      transform:
                          Matrix4.identity()
                            ..setEntry(3, 2, 0.001) // Perspectiva
                            ..rotateX(
                              0.1,
                            ), // Rotación en el eje X para efecto 3D
                      child: Image.asset(
                        'assets/icons/logo_pnp_policia.png',
                        scale: 3.0,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ), // Espacio entre las dos imágenes del logo
                  DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(
                            0.7,
                          ), // Color de la sombra
                          spreadRadius: 2, // Extensión de la sombra
                          blurRadius: 10, // Desenfoque de la sombra
                          offset: Offset(
                            0,
                            5,
                          ), // Desplazamiento de la sombra (eje X, eje Y)
                        ),
                      ],
                    ),
                    child: Transform(
                      alignment: Alignment.center,
                      transform:
                          Matrix4.identity()
                            ..setEntry(3, 2, 0.001) // Perspectiva
                            ..rotateX(
                              0.1,
                            ), // Rotación en el eje X para efecto 3D
                      child: Image.asset(
                        'assets/icons/logo_pnp_letras.png',
                        scale: 2.5,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 24,
                  ), // Espacio entre el logo y el campo de texto
                  // Separador visual
                  const Divider(
                    // Añadir un separador
                    height: 40, // Altura del separador
                    thickness: 1, // Grosor de la línea
                    indent: 20, // Espacio desde el inicio
                    endIndent: 20, // Espacio hasta el final
                    color: Colors.white70, // Color del separador
                  ),
                  const SizedBox(height: 20), // Espacio después del separador
                  // Imagen indicativa para el teléfono
                  Image.asset(
                    'assets/icons/telefono_hint_icon.png',
                    height: 80,
                    width: double.infinity,
                  ), // Aumenta la altura y el ancho
                  const SizedBox(
                    height: 10,
                  ), // Espacio entre la imagen y el campo de teléfono
                  // Reemplazar TextField con IntlPhoneField
                  IntlPhoneField(
                    controller: _phoneController,
                    readOnly: true, // Hace el campo de solo lectura para evitar la selección de país
                    decoration: InputDecoration(
                      labelText: 'Número de Teléfono',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      prefixIcon: Image.asset(
                        'assets/icons/telefono_hint_icon.png',
                        height: 80,
                        width: double.infinity,
                      ),
                    ),
                    initialCountryCode: 'PE', // Establece el código de país inicial a Perú
                    showDropdownIcon: false, // Oculta el icono del selector de país
                    onChanged: (phone) {
                      print(phone.completeNumber);
                    },
                    validator: (phone) {
                      if (phone == null || phone.number.isEmpty) {
                        return 'Por favor, ingresa tu número de teléfono';
                      }
                      // Validación para números de Perú (9 dígitos y empiezan con 9)
                      if (phone.countryCode != '51' ||
                          phone.number.length != 9 ||
                          !phone.number.startsWith('9')) {
                        return 'Por favor, ingresa un número de teléfono válido de Perú (9 dígitos, empieza con 9)';
                      }
                      return null;
                    },
                  ),

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Lógica de registro
                      if (_formKey.currentState!.validate()) {
                        // Aquí iría la lógica para procesar el número de teléfono
                        // Por ejemplo, _phoneController.text contiene el número completo
                        print('Número de teléfono: ${_phoneController.text}');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor:
                          Colors
                              .blue
                              .shade800, // Un azul oscuro para un toque moderno
                      padding: const EdgeInsets.symmetric(
                        horizontal: 50,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          30,
                        ), // Bordes más redondeados
                      ),
                      elevation:
                          5, // Una ligera sombra para un efecto flotante sutil
                    ),
                    child: const Text(
                      'Registrarme',
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
      ),
    );
  }
}
