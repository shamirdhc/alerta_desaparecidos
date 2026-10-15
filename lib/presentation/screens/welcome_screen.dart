import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alerta_desaparecidos/common/styles/app_colors.dart';
import '../../common/localization/app_strings.dart';
import '../common_widgets/language_selector_toggle.dart';
import 'modern_login_screen.dart';
import '../police/screens/about_police_screen.dart';
import '../../services/spectator_mode_service.dart';
import '../../services/pwa_install_service.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PwaInstallService.checkAndShowAutoInstallPrompt(
        context,
        delay: const Duration(seconds: 3),
      );
    });
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
    await Future.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    _textController.forward();

    await Future.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    _buttonController.forward();
  }

  Future<void> _checkSessionAndNavigate() async {
    setState(() {
      _isCheckingAuth = true;
    });

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && (currentUser.email ?? '').trim().toLowerCase() == 'shamirdhc2022@gmail.com') {
        print('⭐ [WELCOME] Superadmin detectado, navegando a panel policial');
        _navigateToHome('police');
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      String? userRole = prefs.getString('userRole') ?? prefs.getString('user_role');
      final bool isDemo = prefs.getBool('is_demo_session') ?? false;

      // FIX CRÍTICO iPHONE: Si Firebase Auth ya tiene al usuario autenticado pero
      // SharedPreferences aún no tenía 'userRole' (ej. tras signInWithRedirect en Safari iOS),
      // resolver su rol en caliente en lugar de devolverlo al Login:
      if (currentUser != null && userRole == null) {
        try {
          final policeDoc = await FirebaseFirestore.instance
              .collection('policias')
              .doc(currentUser.uid)
              .get()
              .timeout(const Duration(seconds: 3));
          userRole = policeDoc.exists ? 'police' : 'citizen';
        } catch (_) {
          userRole = 'citizen';
        }
        await prefs.setString('userRole', userRole);
      }

      if ((currentUser != null || isDemo) && userRole != null) {
        // Verificar si es ciudadano y si está vetado
        if (userRole == 'citizen' && !isDemo) {
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
    final strings = AppStrings.of(context);
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.policeHeroGradient,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: Column(
                  children: [
                    // Selector de Idioma en la parte superior
                    Align(
                      alignment: Alignment.topRight,
                      child: const LanguageSelectorToggle(),
                    ),

                    const Spacer(flex: 2),

                    // Logo animado con efecto aura institucional
                    _buildAnimatedLogo(),

                    const SizedBox(height: 36),

                    // Texto de bienvenida institucional
                    _buildWelcomeText(strings),

                    const Spacer(flex: 3),

                    // Botones de acción
                    if (!_isCheckingAuth) _buildActionButtons(strings),

                    if (_isCheckingAuth) _buildLoadingIndicator(strings),

                    const SizedBox(height: 30),

                    // Footer institucional
                    _buildFooter(strings),
                  ],
                ),
              ),
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
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.accentColor.withValues(alpha: 0.6),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentColor.withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: 4,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Image.asset(
            'assets/icons/icon_police.png',
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeText(AppStrings strings) {
    return SlideTransition(
      position: _textAnimation,
      child: FadeTransition(
        opacity: _textController,
        child: Column(
          children: [
            // Badge de plataforma ciudadana
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accentColor.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_alt_rounded, color: AppColors.accentColor, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    strings.systemEarlyWarning,
                    style: const TextStyle(
                      color: AppColors.accentColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              strings.welcomeTitle,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              strings.welcomeSubtitle,
              style: TextStyle(
                fontSize: 14.5,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  strings.welcomePolice,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(AppStrings strings) {
    return ScaleTransition(
      scale: _buttonAnimation,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCheckingAuth ? null : _checkSessionAndNavigate,
              icon: _isCheckingAuth
                  ? const SizedBox.shrink()
                  : const Icon(Icons.arrow_forward_rounded, size: 20),
              label: _isCheckingAuth
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                      ),
                    )
                  : Text(
                      strings.enterSystem,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                shadowColor: Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showInfoDialog,
              icon: const Icon(Icons.info_outline_rounded, size: 19, color: Colors.white),
              label: Text(
                strings.institutionalInfo,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Acceso directo a Modo Espectador sin registro
          TextButton.icon(
            onPressed: () => SpectatorModeService.enterSpectatorMode(context),
            icon: const Icon(Icons.visibility_rounded, size: 18, color: Color(0xFF67E8F9)),
            label: Text(
              strings.isQuechua
                  ? 'Qhawaq hina yaykuy (Mana cuentayuq)'
                  : 'Explorar sin cuenta (Modo Espectador)',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF67E8F9),
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (PwaInstallService.isInstallOptionAvailable) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => PwaInstallService.promptOrGuideInstall(context),
              icon: const Icon(Icons.install_mobile_rounded, size: 18, color: Color(0xFF34D399)),
              label: Text(
                strings.isQuechua
                    ? 'Aplicativota celularman churay'
                    : '📲 Instalar Aplicativo en este dispositivo',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF34D399),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(AppStrings strings) {
    return Column(
      children: [
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentColor),
        ),
        const SizedBox(height: 16),
        Text(
          strings.verifyingSession,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildFooter(AppStrings strings) {
    return Column(
      children: [
        Text(
          strings.directionTrata,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          strings.emergency114and105,
          style: TextStyle(
            color: AppColors.accentColor.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
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
