import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pinput/pinput.dart';
import 'package:local_auth/local_auth.dart';
import '../citizen/screens/citizen_home_screen.dart';
import '../police/screens/police_home_screen.dart';
import 'citizen_registration_form_screen.dart';
import '../../services/firebase_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/session_service.dart';

class ModernOTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String? verificationId;

  const ModernOTPScreen({
    super.key,
    required this.phoneNumber,
    this.verificationId,
  });

  @override
  State<ModernOTPScreen> createState() => _ModernOTPScreenState();
}

class _ModernOTPScreenState extends State<ModernOTPScreen>
    with TickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseService _firebaseService = FirebaseService();

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  bool _verifying = false;
  bool _canUseBiometric = false;
  String? _errorMessage;
  int _resendCountdown = 60;
  String? _currentVerificationId;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _initializeAnimations();
    _checkBiometricAvailability();
    _startResendCountdown();
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

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
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

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideController.forward();
    _fadeController.forward();
    _pulseController.repeat(reverse: true);
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      setState(() {
        _canUseBiometric = isAvailable && isDeviceSupported;
      });
    } catch (e) {
      setState(() {
        _canUseBiometric = false;
      });
    }
  }

  void _startResendCountdown() {
    setState(() {
      _resendCountdown = 60;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _resendCountdown--;
        });
        return _resendCountdown > 0;
      }
      return false;
    });
  }

  Future<bool> _isNumberInPoliceCollection(String phoneNumber) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('policias')
        .where('telefono', isEqualTo: phoneNumber)
        .get()
        .timeout(const Duration(seconds: 10));
    return snapshot.docs.isNotEmpty;
  }

  Future<void> _verifyOTPAndNavigate() async {
    if (_otpController.text.length != 6) {
      _showErrorMessage('Por favor, ingresa el código completo');
      return;
    }

    setState(() {
      _errorMessage = null;
      _verifying = true;
    });

    HapticFeedback.lightImpact();

    try {
      // Verificar conectividad
      if (!await ConnectivityService.hasInternetConnection()) {
        _showErrorMessage('Sin conexión a internet. Verifica tu conexión.');
        return;
      }

      // Usar el ID de verificación actual (puede haber sido actualizado por reenvío)
      if (_currentVerificationId == null) {
        _showErrorMessage(
          'No se pudo obtener el ID de verificación. Solicita un nuevo código.',
        );
        return;
      }

      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _currentVerificationId!,
        smsCode: _otpController.text.trim(),
      );

      // Verificar credencial con timeout
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw FirebaseAuthException(
                code: 'timeout',
                message: 'La verificación tardó demasiado. Inténtalo de nuevo.',
              );
            },
          );

      final User? user = userCredential.user;

      if (user != null) {
        final phoneNumber = widget.phoneNumber;

        // Verificar rol con timeout
        final isPolice = await _isNumberInPoliceCollection(
          phoneNumber,
        ).timeout(const Duration(seconds: 10), onTimeout: () => false);

        if (isPolice) {
          // Verificar datos del policía
          final policeDoc = await FirebaseFirestore.instance
              .collection('policias')
              .where('telefono', isEqualTo: phoneNumber)
              .get()
              .timeout(const Duration(seconds: 10));

          if (policeDoc.docs.isNotEmpty) {
            final policeData = policeDoc.docs.first.data();
            await SessionService.saveUserSession(
              userRole: 'police',
              userId: policeDoc.docs.first.id,
              phoneNumber: phoneNumber,
              userName: policeData['nombre'] ?? 'Policía', // Incluir nombre del policía
              biometricEnabled: _canUseBiometric,
            );

            if (mounted) {
              _navigateWithAnimation(const PoliceHomeScreen());
            }
          } else {
            await SessionService.clearUserSession();
            await FirebaseAuth.instance.signOut();
            _showErrorMessage('Error: Usuario policía no encontrado');
          }
        } else {
          // Verificar datos del ciudadano
          final citizenDoc = await FirebaseFirestore.instance
              .collection('ciudadanos')
              .where('telefono', isEqualTo: phoneNumber)
              .get()
              .timeout(const Duration(seconds: 10));

          if (citizenDoc.docs.isNotEmpty) {
            final citizenData = citizenDoc.docs.first.data();

            if (citizenData['vetado'] == true) {
              await SessionService.clearUserSession();
              await FirebaseAuth.instance.signOut();
              _showErrorMessage(
                'Tu cuenta ha sido suspendida. Contacta al administrador.',
              );
              return;
            }

            await SessionService.saveUserSession(
              userRole: 'citizen',
              userId: citizenDoc.docs.first.id,
              phoneNumber: phoneNumber,
              userName: citizenData['nombre'] ?? 'Usuario', // Incluir nombre del ciudadano
              biometricEnabled: _canUseBiometric,
            );

            if (mounted) {
              _navigateWithAnimation(const CitizenHomeScreen());
            }
          } else {
            // Usuario no registrado, ir a registro
            if (mounted) {
              _navigateWithAnimation(
                CitizenRegistrationFormScreen(
                  uid: user.uid,
                  phoneNumber: phoneNumber,
                ),
              );
            }
          }
        }
      } else {
        _showErrorMessage('Error al autenticar al usuario.');
      }
    } on FirebaseAuthException catch (e) {
      HapticFeedback.heavyImpact();
      String errorMessage = 'Error de verificación';

      switch (e.code) {
        case 'invalid-verification-code':
          errorMessage = 'Código incorrecto. Verifica e intenta nuevamente.';
          break;
        case 'session-expired':
          errorMessage = 'Sesión expirada. Solicita un nuevo código.';
          break;
        case 'too-many-requests':
          errorMessage = 'Demasiados intentos. Espera unos minutos.';
          break;
        case 'network-request-failed':
          errorMessage = 'Error de conexión. Verifica tu internet.';
          break;
        case 'credential-already-in-use':
          errorMessage = 'Este número ya está en uso por otra cuenta.';
          break;
        case 'timeout':
          errorMessage = 'La verificación tardó demasiado. Inténtalo de nuevo.';
          break;
        default:
          errorMessage = 'Error: ${e.message ?? 'Código inválido o expirado'}';
      }

      _showErrorMessage(errorMessage);
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (e.toString().contains('Timeout')) {
        _showErrorMessage(
          'La conexión tardó demasiado. Verifica tu internet e inténtalo de nuevo.',
        );
      } else {
        _showErrorMessage('Error inesperado: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _verifying = false;
        });
      }
    }
  }

  void _navigateWithAnimation(Widget destination) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOutCubic,
                ),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _showErrorMessage(String message) {
    setState(() {
      _errorMessage = message;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _resendCode() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();

    try {
      // Verificar conectividad
      if (!await ConnectivityService.hasInternetConnection()) {
        _showErrorMessage('Sin conexión a internet. Verifica tu conexión.');
        return;
      }

      await _firebaseService.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verificación completada
          if (mounted) {
            setState(() {
              _otpController.text = credential.smsCode ?? '';
            });
            _verifyOTPAndNavigate();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          String errorMessage = 'Error al reenviar código';

          switch (e.code) {
            case 'too-many-requests':
              errorMessage =
                  'Demasiados intentos de reenvío. Espera 15 minutos.';
              break;
            case 'network-request-failed':
              errorMessage = 'Error de conexión. Verifica tu internet.';
              break;
            case 'invalid-phone-number':
              errorMessage = 'Número de teléfono inválido.';
              break;
            default:
              errorMessage = 'Error: ${e.message ?? 'Inténtalo más tarde.'}';
          }

          _showErrorMessage(errorMessage);
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _currentVerificationId = verificationId;
          });
          _startResendCountdown();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Código reenviado exitosamente'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!mounted) return;
          setState(() {
            _currentVerificationId = verificationId;
          });
        },
      );
    } catch (e) {
      _showErrorMessage('Error al reenviar código: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    _otpController.dispose();
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
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      // Header con botón de regreso
                      _buildHeader(),

                      const SizedBox(height: 60),

                      // Icono animado
                      _buildAnimatedIcon(),

                      const SizedBox(height: 40),

                      // Título y descripción
                      _buildTitleSection(),

                      const SizedBox(height: 40),

                      // Campo OTP
                      _buildOTPField(),

                      const SizedBox(height: 30),

                      // Botón de verificación
                      _buildVerifyButton(),

                      const SizedBox(height: 30),

                      // Opción de reenvío
                      _buildResendSection(),

                      const SizedBox(height: 40),
                    ],
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
    return Row(
      children: [
        const SizedBox(width: 48), // Espacio para balancear
        const Expanded(
          child: Text(
            'Verificación',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 48), // Para balancear
      ],
    );
  }

  Widget _buildAnimatedIcon() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
        ),
        child: const Icon(Icons.sms_outlined, size: 50, color: Colors.white),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      children: [
        const Text(
          'Ingresa el código',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Enviamos un código de 6 dígitos a',
          style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          widget.phoneNumber,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOTPField() {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 64,
      textStyle: const TextStyle(
        fontSize: 24,
        color: Color(0xFF2D3748),
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: const Color(0xFF667eea), width: 2),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF667eea).withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        color: const Color(0xFF667eea).withOpacity(0.1),
        border: Border.all(color: const Color(0xFF667eea)),
      ),
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Colors.red, width: 2),
      boxShadow: [
        BoxShadow(
          color: Colors.red.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Pinput(
            controller: _otpController,
            length: 6,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: focusedPinTheme,
            submittedPinTheme: submittedPinTheme,
            errorPinTheme: _errorMessage != null ? errorPinTheme : null,
            pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
            showCursor: true,
            onCompleted: (pin) => _verifyOTPAndNavigate(),
            onChanged: (value) {
              if (_errorMessage != null) {
                setState(() {
                  _errorMessage = null;
                });
              }
            },
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
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

  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _verifying ? null : _verifyOTPAndNavigate,
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
            _verifying
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
                  'Verificar código',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
      ),
    );
  }

  Widget _buildResendSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '¿No recibiste el código?',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),

          if (_resendCountdown > 0)
            Text(
              'Reenviar en ${_resendCountdown}s',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            )
          else
            TextButton(
              onPressed: _resendCode,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Reenviar código',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
