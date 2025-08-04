import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:ui';
import 'modern_login_screen.dart';
import '../police/screens/about_police_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _buttonController;
  late Animation<double> _logoAnimation;
  late Animation<Offset> _textAnimation;
  late Animation<double> _buttonAnimation;

  bool _isCheckingAuth = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _textAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    _buttonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeOutBack),
    );

    _startAnimationSequence();
  }

  void _startAnimationSequence() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    _textController.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    _buttonController.forward();
  }

  Future<void> _checkSessionAndNavigate() async {
    setState(() {
      _isCheckingAuth = true;
    });

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final String? userRole = prefs.getString('userRole');

      if (currentUser != null && userRole != null) {
        // Verificar si es ciudadano y si está vetado
        if (userRole == 'citizen') {
          final String? phoneNumber = prefs.getString('last_phone_number');
          if (phoneNumber != null) {
            final citizenQuery =
                await FirebaseFirestore.instance
                    .collection('ciudadanos')
                    .where('telefono', isEqualTo: phoneNumber)
                    .get();

            if (citizenQuery.docs.isNotEmpty) {
              final citizenData = citizenQuery.docs.first.data();
              final bool isVetado = citizenData['vetado'] ?? false;

              if (isVetado) {
                setState(() {
                  _isCheckingAuth = false;
                });
                _showVetadoDialog();
                return;
              }
            }
          }
        }

        // Si no está vetado o es policía, navegar al home
        _navigateToHome(userRole);
      } else {
        // No hay sesión, ir al login
        setState(() {
          _isCheckingAuth = false;
        });
        _navigateToLogin();
      }
    } catch (e) {
      setState(() {
        _isCheckingAuth = false;
      });
      _navigateToLogin();
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
            content: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.security, size: 64, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Su acceso al aplicativo ha sido restringido por haber infringido las normas de uso.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Text(
                      'Para más información, contacte con las autoridades correspondientes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Cerrar sesión y ir al login
                  FirebaseAuth.instance.signOut();
                  SharedPreferences.getInstance().then((prefs) {
                    prefs.clear();
                  });
                  _navigateToLogin();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Entendido',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _navigateToHome(String userRole) {
    final String route =
        userRole == 'police' ? '/police_home' : '/citizen_home';
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                const ModernLoginScreen(),
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

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                isDark
                    ? [
                      const Color(0xFF1A1A2E),
                      const Color(0xFF16213E),
                      const Color(0xFF0F3460),
                    ]
                    : [
                      const Color(0xFF667eea),
                      const Color(0xFF764ba2),
                      const Color(0xFF667eea),
                    ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Logo animado
                _buildAnimatedLogo(),

                const SizedBox(height: 60),

                // Texto de bienvenida
                _buildWelcomeText(),

                const Spacer(flex: 3),

                // Botones de acción
                if (!_isCheckingAuth) _buildActionButtons(),

                if (_isCheckingAuth) _buildLoadingIndicator(),

                const SizedBox(height: 40),

                // Footer
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return ScaleTransition(
      scale: _logoAnimation,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Image.asset(
            'assets/icons/logo_pnp_policia.png',
            // Remover: color: Colors.white,
            // Para mostrar la imagen original con colores
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeText() {
    return SlideTransition(
      position: _textAnimation,
      child: FadeTransition(
        opacity: _textController,
        child: Column(
          children: [
            const Text(
              'Alerta Desaparecidos',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Sistema de búsqueda y reporte\nde personas desaparecidas',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.8),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Policía Nacional del Perú',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return ScaleTransition(
      scale: _buttonAnimation,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCheckingAuth ? null : _checkSessionAndNavigate,
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
                  _isCheckingAuth
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
                        'Iniciar Sesión',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                _showInfoDialog();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Información',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
        const SizedBox(height: 16),
        Text(
          'Verificando sesión...',
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'Versión 1.0.0',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          '© 2024 Policía Nacional del Perú',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        ),
      ],
    );
  }

  void _showInfoDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AboutPoliceScreen()),
    );
  }
}
