import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/session_service.dart';
import 'modern_otp_screen.dart';
import 'package:alerta_desaparecidos/services/logout_service.dart';

class ModernLoginScreen extends StatefulWidget {
  const ModernLoginScreen({super.key});

  @override
  State<ModernLoginScreen> createState() => _ModernLoginScreenState();
}

class _ModernLoginScreenState extends State<ModernLoginScreen>
    with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey();
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _phoneController = TextEditingController();

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  PhoneNumber? _phoneNumber;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideController.forward();
    _fadeController.forward();
  }

  Future<void> _registerUser(String phoneNumber) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Vibración suave para feedback
    HapticFeedback.lightImpact();

    try {
      // Verificar conectividad antes de proceder
      if (!await ConnectivityService.hasInternetConnection()) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Sin conexión a internet. Verifica tu conexión y vuelve a intentar.';
        });
        return;
      }

      // Esperar a que los servicios de Firebase estén disponibles
      if (!await ConnectivityService.canReachFirebaseServices()) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'No se puede conectar con los servicios de autenticación. Verifica tu conexión.';
        });
        return;
      }

      // Limpiar cualquier sesión anterior
      await SessionService.clearUserSession();
      await FirebaseAuth.instance.signOut();

      // Verificar si el número existe en la colección de ciudadanos
      final citizenQuery = await FirebaseFirestore.instance
          .collection('ciudadanos')
          .where('telefono', isEqualTo: phoneNumber)
          .get()
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Timeout al verificar usuario');
            },
          );

      if (citizenQuery.docs.isNotEmpty) {
        // Es un ciudadano, verificar si está vetado
        final citizenData = citizenQuery.docs.first.data();
        final bool isVetado = citizenData['vetado'] ?? false;

        if (isVetado) {
          // Mostrar mensaje de restricción
          setState(() {
            _isLoading = false;
          });
          _showVetadoDialog();
          return;
        }
      }

      // Si no está vetado o es policía, continuar con el flujo normal
      await _firebaseService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          _navigateToOTP(phoneNumber, null);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            // Mejorar el manejo de errores específicos
            if (e.code == 'too-many-requests') {
              _errorMessage =
                  'Demasiados intentos. Espera 15 minutos antes de intentar de nuevo.';
            } else if (e.code == 'network-request-failed' ||
                e.code == 'network-error') {
              _errorMessage =
                  'Error de conexión. Verifica tu internet e inténtalo de nuevo.';
            } else if (e.code == 'invalid-phone-number') {
              _errorMessage =
                  'Número de teléfono inválido. Verifica el formato.';
            } else if (e.code == 'app-not-authorized') {
              _errorMessage =
                  'Aplicación no autorizada. Contacta al soporte técnico.';
            } else if (e.code == 'captcha-check-failed') {
              _errorMessage =
                  'Verificación de seguridad fallida. Vuelve a intentar.';
            } else if (e.message?.contains('reCAPTCHA') ?? false) {
              _errorMessage =
                  'Error de verificación reCAPTCHA. Inténtalo más tarde.';
            } else if (e.message?.contains('timeout') ?? false) {
              _errorMessage =
                  'La verificación tardó demasiado. Inténtalo de nuevo.';
            } else {
              _errorMessage =
                  'Error de verificación: ${e.message ?? 'Inténtalo nuevamente.'}';
            }
          });
          HapticFeedback.heavyImpact();
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          _navigateToOTP(phoneNumber, verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!mounted) return;

          // NUEVO: Verificar si hay un logout manual en progreso (cualquier servicio)
          if (CitizenLogoutService.isManualLogout() || PoliceLogoutService.isManualLogout()) {
            print(
              '🔍 [AUTH] Logout manual en progreso, ignorando timeout de SMS',
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }

          // NUEVO: Verificar si hubo un reseteo reciente (dentro de los últimos 60 segundos)
          if (CitizenLogoutService.wasRecentlyReset() || PoliceLogoutService.wasRecentlyReset()) {
            print(
              '🔍 [AUTH] Logout manual fue reseteado recientemente, ignorando timeout de SMS',
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }

          // Verificar si el usuario ya está autenticado antes de navegar
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            print('🔍 [AUTH] Usuario ya autenticado, ignorando timeout de SMS');
            setState(() {
              _isLoading = false;
            });
            return;
          }

          // Solo navegar a OTP si no hay usuario autenticado y no hay logout manual
          setState(() {
            _isLoading = false;
          });
          _navigateToOTP(phoneNumber, verificationId);
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        String errorMessage = 'Error de autenticación';

        switch (e.code) {
          case 'too-many-requests':
            errorMessage =
                'Demasiados intentos. Espera 15 minutos antes de volver a intentar.';
            break;
          case 'network-request-failed':
            errorMessage = 'Sin conexión a internet. Verifica tu conexión.';
            break;
          case 'invalid-phone-number':
            errorMessage =
                'Formato de número inválido. Usa solo números sin espacios.';
            break;
          case 'app-not-authorized':
            errorMessage =
                'Error de configuración. Contacta al soporte técnico.';
            break;
          default:
            errorMessage = 'Error: ${e.message}';
        }

        _errorMessage = errorMessage;
      });
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (e.toString().contains('Timeout')) {
          _errorMessage =
              'La conexión tardó demasiado. Verifica tu internet e inténtalo de nuevo.';
        } else {
          _errorMessage =
              'Error al verificar el usuario. Verifica tu conexión e inténtalo nuevamente.';
        }
      });
      HapticFeedback.heavyImpact();
    }
  }

  void _showVetadoDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.block, color: Colors.red.shade600, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Acceso Restringido',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Su cuenta ha sido restringida y no tiene permitido el acceso al sistema. Para más información, contacte con las autoridades correspondientes.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Entendido',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  void _navigateToOTP(String phoneNumber, String? verificationId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ModernOTPScreen(
              phoneNumber: phoneNumber,
              verificationId: verificationId,
            ),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final String phoneNumber = '+51${_phoneNumber!.number}';
      _registerUser(phoneNumber);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        return false; // Deshabilitar navegación del sistema
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  isDark
                      ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                      : [const Color(0xFF667eea), const Color(0xFF764ba2)],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),

                        // Header
                        _buildHeader(),

                        const SizedBox(height: 60),

                        // Formulario
                        _buildLoginForm(),

                        const SizedBox(height: 40),

                        // Botones de acción
                        _buildActionButtons(),

                        const SizedBox(height: 40),

                        // Footer
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Hero(
              tag: 'app_logo',
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Image.asset(
                  'assets/icons/logo_pnp_policia.png',
                  height: 40,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenido',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Ingresa tu número para continuar',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Número de celular',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 12),

          IntlPhoneField(
            controller: _phoneController,
            decoration: InputDecoration(
              hintText: '987 654 321',
              prefixIcon: const Icon(Icons.phone_android),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF667eea),
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            initialCountryCode: 'PE',
            onChanged: (phone) {
              setState(() {
                _phoneNumber = phone;
                _errorMessage = null;
              });
            },
            validator: (phoneNumber) {
              if (phoneNumber == null || phoneNumber.number.isEmpty) {
                return 'Por favor, ingresa tu número.';
              }
              if (phoneNumber.countryISOCode == 'PE' &&
                  phoneNumber.number.length != 9) {
                return 'El número debe tener 9 dígitos.';
              }
              return null;
            },
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF667eea),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.2),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF667eea),
                        ),
                      ),
                    )
                    : const Text(
                      'Continuar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Text(
            'Al continuar, aceptas nuestros términos de servicio',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Policía Nacional del Perú',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
