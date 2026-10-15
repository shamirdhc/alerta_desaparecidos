import 'dart:async';
import '../../services/gps_location_service.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/session_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/logout_service.dart';
import '../../common/styles/app_colors.dart';
import '../../common/constants/peru_locations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import '../../common/localization/app_strings.dart';
import '../citizen/screens/citizen_home_screen.dart';
import '../police/screens/police_home_screen.dart';
import '../../services/spectator_mode_service.dart';
import '../common/widgets/branded_loading_dialog.dart';

class ModernLoginScreen extends StatefulWidget {
  const ModernLoginScreen({super.key});

  @override
  State<ModernLoginScreen> createState() => _ModernLoginScreenState();
}

class _ModernLoginScreenState extends State<ModernLoginScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _isLoading = false;
  bool _isWaitingGoogleAuth = false;
  Timer? _cancelWatcherTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    if (kIsWeb) {
      _checkRedirectResult();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelWatcherTimer?.cancel();
    BrandedLoadingOverlay.hide();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isWaitingGoogleAuth) {
      // El usuario regresó al aplicativo (cerró ventana, dio atrás o cambió de pestaña)
      _cancelWatcherTimer?.cancel();
      _cancelWatcherTimer = Timer(const Duration(milliseconds: 3500), () {
        if (!mounted) return;
        // Si regresó a la app y aún no hay usuario autenticado en Firebase, se canceló
        if (_isWaitingGoogleAuth && FirebaseAuth.instance.currentUser == null) {
          print('ℹ️ [LOGIN] Detección reactiva: usuario volvió a la app sin autenticar (cancelación instantánea).');
          setState(() {
            _isWaitingGoogleAuth = false;
            _isLoading = false;
            _errorMessage = null;
          });
          BrandedLoadingOverlay.hide();
        }
      });
    }
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideController.forward();
    _fadeController.forward();
  }

  /// Verifica si el usuario retornó de un inicio de sesión vía redirección en web móvil
  Future<void> _checkRedirectResult() async {
    try {
      final pendingUser = SessionService.pendingRedirectUser ?? FirebaseAuth.instance.currentUser;
      if (pendingUser != null && mounted) {
        SessionService.pendingRedirectUser = null;
        await _handleSuccessfulGoogleLogin(pendingUser);
        return;
      }
      final result = await FirebaseAuth.instance.getRedirectResult();
      if (result.user != null && mounted) {
        await _handleSuccessfulGoogleLogin(result.user!);
      }
    } catch (e) {
      print('ℹ️ [GOOGLE_AUTH] Verificación de redirección: $e');
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Inicia sesión exclusivamente con Google
  Future<void> _signInWithGoogle() async {
    // Evitar toques múltiples simultáneos
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _isWaitingGoogleAuth = true;
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();

    try {
      final userCredential = await GoogleAuthService.signInWithGoogle();
      if (userCredential == null) {
        // El usuario canceló o cerró la ventana emergente de Google
        if (mounted) {
          setState(() {
            _isWaitingGoogleAuth = false;
            _isLoading = false;
            _errorMessage = null; // No mostrar banner rojo si el usuario canceló voluntariamente
          });
          BrandedLoadingOverlay.hide();
        }
        return;
      }

      final user = userCredential.user;
      if (user != null && mounted) {
        _isWaitingGoogleAuth = false;
        await _handleSuccessfulGoogleLogin(user);
      } else {
        if (mounted) {
          setState(() {
            _isWaitingGoogleAuth = false;
            _isLoading = false;
          });
          BrandedLoadingOverlay.hide();
        }
      }
    } catch (e) {
      print('⚠️ [LOGIN] Error durante inicio de sesión con Google: $e');
      BrandedLoadingOverlay.hide();
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        // Si fue una cancelación detectada tardíamente, solo apagar el loader inmediatamente
        if (errStr.contains('popup-closed') ||
            errStr.contains('cancelled') ||
            errStr.contains('canceled') ||
            errStr.contains('sign_in_canceled') ||
            errStr.contains('12501') ||
            errStr.contains('closed by user') ||
            errStr.contains('user-cancelled')) {
          setState(() {
            _isWaitingGoogleAuth = false;
            _isLoading = false;
            _errorMessage = null;
          });
          return;
        }

        String friendlyError = 'No se pudo iniciar sesión con Google.';
        if (e is FirebaseAuthException) {
          if (e.code == 'network-request-failed') {
            friendlyError = 'Error de conexión. Verifica tu acceso a internet.';
          } else if (e.code == 'popup-blocked') {
            friendlyError = 'La ventana emergente de Google fue bloqueada. Habilita los popups en tu navegador.';
          } else {
            friendlyError = e.message ?? friendlyError;
          }
        }

        setState(() {
          _isWaitingGoogleAuth = false;
          _isLoading = false;
          _errorMessage = friendlyError;
        });
      }
    } finally {
      // GARANTÍA ABSOLUTA: Si no se redirigió y sigue montado sin esperar auth activa, apagar loader
      if (mounted && _isLoading && !_isWaitingGoogleAuth) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Realiza un get de DocumentReference con reintentos para mitigar race-conditions de Firestore Web
  Future<DocumentSnapshot<Map<String, dynamic>>?> _safeGetDoc(
    DocumentReference<Map<String, dynamic>> ref, {
    int maxAttempts = 3,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final doc = await ref.get().timeout(timeout);
        return doc;
      } catch (e) {
        debugPrint('safeGetDoc intento $attempt falló: $e');
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 300 * attempt));
        }
      }
    }
    return null;
  }

  /// Realiza un get de Query con reintentos
  Future<QuerySnapshot<Map<String, dynamic>>?> _safeGetQuery(
    Query<Map<String, dynamic>> query, {
    int maxAttempts = 2,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final snap = await query.get().timeout(timeout);
        return snap;
      } catch (e) {
        debugPrint('safeGetQuery intento $attempt falló: $e');
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 300 * attempt));
        }
      }
    }
    return null;
  }

  /// Procesa el usuario autenticado y verifica sus datos de residencia
  Future<void> _handleSuccessfulGoogleLogin(User user) async {
    setState(() {
      _isLoading = true;
      _isWaitingGoogleAuth = false;
      _errorMessage = null;
    });

    final strings = AppStrings.of(context);
    final String rawName = (user.displayName ?? '').trim();
    final String primerNombre = rawName.isNotEmpty ? rawName.split(' ').first : 'Ciudadano';

    // MOSTRAR INMEDIATAMENTE POPUP CON EL LOGO OFICIAL DEL APLICATIVO
    BrandedLoadingOverlay.show(
      context,
      message: strings.isQuechua
          ? '¡Allillanchu, $primerNombre!'
          : '¡Bienvenido(a), $primerNombre!',
      submessage: strings.isQuechua
          ? 'Yaykuna qhawachkanchik...'
          : 'Iniciando sesión y verificando credenciales...',
      timeoutSeconds: 15,
    );

    try {
      PoliceLogoutService.resetLogoutFlag();
      CitizenLogoutService.resetLogoutFlag();

      // 1. Estabilizar credenciales y sesión tras autenticación biométrica / OAuth en Web
      try {
        await user.getIdToken();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 350));

      final String userEmail = (user.email ?? '').trim().toLowerCase();
      final bool isSuperAdmin = userEmail == 'shamirdhc2022@gmail.com';

      // 2. VERIFICACIÓN DE SUPERADMIN O POLICÍA
      DocumentSnapshot<Map<String, dynamic>>? policeDoc;
      if (!isSuperAdmin) {
        policeDoc = await _safeGetDoc(
          FirebaseFirestore.instance.collection('policias').doc(user.uid),
        );

        // Si no se encontró por UID, buscar por email en policias
        if ((policeDoc == null || !policeDoc.exists) && userEmail.isNotEmpty) {
          final q = await _safeGetQuery(
            FirebaseFirestore.instance
                .collection('policias')
                .where('email', isEqualTo: userEmail)
                .limit(1),
          );
          if (q != null && q.docs.isNotEmpty) {
            policeDoc = q.docs.first;
          }
        }
      }

      if (isSuperAdmin || (policeDoc != null && policeDoc.exists)) {
        final policeData = policeDoc?.data() ?? {};
        final String nombre = isSuperAdmin
            ? (policeData['nombre'] ?? (user.displayName ?? 'SHAMIR DEYVIS'))
            : (policeData['nombre'] ?? (user.displayName ?? 'OFICIAL'));
        final String apellido = isSuperAdmin
            ? (policeData['apellido'] ?? 'HUERTA CCARHUAS')
            : (policeData['apellido'] ?? 'PNP');
        final String telefono = isSuperAdmin
            ? (policeData['telefono'] ?? (user.phoneNumber ?? '+51948269740'))
            : (policeData['telefono'] ?? (user.phoneNumber ?? ''));
        final String cip = isSuperAdmin
            ? (policeData['numero_cip'] ?? '32094511')
            : (policeData['numero_cip'] ?? '32000000');
        final String unidad = isSuperAdmin
            ? (policeData['unidad'] ?? 'DEPITPTIM PNP ANDAHUAYLAS')
            : (policeData['unidad'] ?? 'COMISARÍA PNP');
        final String depto = isSuperAdmin
            ? (policeData['departamento'] ?? 'APURÍMAC')
            : (policeData['departamento'] ?? 'LIMA');

        // Sincronizar documento en Firestore policias de forma tolerante a fallos
        try {
          await FirebaseFirestore.instance.collection('policias').doc(user.uid).set({
            'uid': user.uid,
            'email': userEmail,
            'nombre': nombre,
            'apellido': apellido,
            'telefono': telefono,
            'numero_cip': cip,
            'unidad': unidad,
            'departamento': depto,
            'rango': isSuperAdmin ? 'SUPERADMIN PNP' : (policeData['rango'] ?? 'OFICIAL PNP'),
            'rol': isSuperAdmin ? 'superadmin' : (policeData['rol'] ?? 'policia'),
            'admin': true,
            'tipo_unidad': isSuperAdmin ? 'DEPITPTIM' : (policeData['tipo_unidad'] ?? 'COMISARIA'),
            'fecha_registro': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
        } catch (syncErr) {
          debugPrint('Aviso: Sincronización remota de policía en background diferida: $syncErr');
        }

        // Guardar sesión como policía / superadmin de forma garantizada
        await SessionService.saveUserSession(
          userRole: 'police',
          userId: user.uid,
          phoneNumber: telefono,
          userName: '$nombre $apellido',
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userRole', 'police');
        await prefs.setBool('is_superadmin', isSuperAdmin);
        await prefs.setString('last_phone_number', telefono);
        await prefs.setString('user_departamento', depto);

        BrandedLoadingOverlay.update(
          message: isSuperAdmin ? '¡Acceso Superadmin Verificado!' : '¡Acceso Policial Verificado!',
          submessage: 'Cargando panel de operaciones policiales...',
        );
        await Future.delayed(const Duration(milliseconds: 300));
        BrandedLoadingOverlay.hide();

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const PoliceHomeScreen(),
            ),
            (route) => false,
          );
        }
        return;
      }

      // 3. Verificar si el usuario está en ciudadanos o vetado
      final citizenDoc = await _safeGetDoc(
        FirebaseFirestore.instance.collection('ciudadanos').doc(user.uid),
      );

      if (citizenDoc != null && citizenDoc.exists) {
        final data = citizenDoc.data()!;
        final bool isVetado = data['vetado'] ?? false;
        if (isVetado) {
          BrandedLoadingOverlay.hide();
          await GoogleAuthService.signOut();
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _showVetadoDialog();
          }
          return;
        }

        // 4. Verificar si el perfil ya está completo (teléfono, departamento y provincia)
        final String? existingPhone = data['telefono'] ?? data['celular'];
        final String? existingDept = data['departamento'];
        final String? existingProv = data['provincia'];

        final bool isProfileComplete = existingPhone != null &&
            existingPhone.trim().isNotEmpty &&
            existingDept != null &&
            existingDept.trim().isNotEmpty &&
            existingProv != null &&
            existingProv.trim().isNotEmpty;

        if (isProfileComplete) {
          final cleanDept = existingDept.trim();
          final canonicalDept = PeruLocations.departamentos.firstWhere(
            (d) => PeruLocations.normalize(d) == PeruLocations.normalize(cleanDept),
            orElse: () => cleanDept.isNotEmpty ? cleanDept.toUpperCase() : 'LIMA',
          );
          final canonicalProv = PeruLocations.matchProvincia(canonicalDept, existingProv);

          await SessionService.saveUserSession(
            userRole: 'citizen',
            userId: user.uid,
            phoneNumber: existingPhone,
            userName: user.displayName ?? 'Ciudadano',
            departamento: canonicalDept,
            provincia: canonicalProv,
          );

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userRole', 'citizen');
          await prefs.setBool('is_superadmin', false);
          await prefs.remove('is_superadmin');
          await prefs.setString('last_phone_number', existingPhone);
          await prefs.setString('user_departamento', canonicalDept);
          await prefs.setString('user_department', canonicalDept);
          await prefs.setString('user_provincia', canonicalProv);

          BrandedLoadingOverlay.update(
            message: '¡Acceso Seguro Confirmado!',
            submessage: 'Ingresando a la red nacional de búsqueda...',
          );
          await Future.delayed(const Duration(milliseconds: 300));
          BrandedLoadingOverlay.hide();

          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const CitizenHomeScreen(),
              ),
              (route) => false,
            );
          }
          return;
        }
      } else if (citizenDoc == null) {
        // En caso de que Firestore Web haya tenido fallo de red tras biometría,
        // comprobar si ya existía una sesión local completa para este usuario
        final prefs = await SharedPreferences.getInstance();
        final String? savedPhone = prefs.getString('last_phone_number');
        final String? savedDept = prefs.getString('user_departamento');
        if (savedPhone != null && savedPhone.isNotEmpty && savedDept != null && savedDept.isNotEmpty) {
          BrandedLoadingOverlay.hide();
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const CitizenHomeScreen(),
              ),
              (route) => false,
            );
          }
          return;
        }
      }

      // 5. Si es la primera vez (o faltan datos), ocultar overlay y solicitar teléfono, departamento y provincia
      BrandedLoadingOverlay.hide();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showFirstTimeProfileDialog(user);
      }
    } catch (e) {
      debugPrint('Error en _handleSuccessfulGoogleLogin: $e');
      BrandedLoadingOverlay.hide();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Ocurrió una interrupción momentánea de conexión al confirmar tu identidad. Por favor, presiona "Continuar con Google" para completar tu ingreso.';
        });
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Diálogo obligatorio para nuevos usuarios: Teléfono, Departamento y Provincia
  void _showFirstTimeProfileDialog(User user) {
    final nameController = TextEditingController(text: user.displayName ?? '');
    final phoneController = TextEditingController();
    String? selectedDept;
    String? selectedProv;
    String? dialogError;
    bool isSaving = false;
    bool isDetectingGps = false;

    // Intentar auto-detectar por GPS al abrir el diálogo
    GpsLocationService.getCurrentLocation(requestPermission: false).then((loc) {
      if (loc != null) {
        selectedDept = loc.departamento;
        selectedProv = loc.provincia;
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final provinciasDisponibles = selectedDept != null
                ? PeruLocations.getProvincias(selectedDept!)
                : <String>[];

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
              contentPadding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
              actionsPadding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_pin_circle_rounded,
                      color: AppColors.primaryColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Completa tu Registro',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Datos de contacto y residencia (4 campos)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenido(a), ${user.displayName ?? 'Ciudadano'}. Para mostrarte automáticamente las comisarías y desaparecidos de tu zona, requerimos únicamente estos 4 datos:',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Nombre Completo
                    const Text(
                      'Nombre Completo *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      keyboardType: TextInputType.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                        hintText: 'Tus nombres y apellidos',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.primaryColorLight,
                            width: 1.8,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 2. Teléfono Celular
                    const Text(
                      'Número de celular *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 9,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        prefixIcon: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🇵🇪', style: TextStyle(fontSize: 18)),
                              SizedBox(width: 6),
                              Text(
                                '+51',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        hintText: '987 654 321',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.primaryColorLight,
                            width: 1.8,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Botón para detectar ubicación por GPS
                    InkWell(
                      onTap: isDetectingGps
                          ? null
                          : () async {
                              setDialogState(() => isDetectingGps = true);
                              final loc = await GpsLocationService.getCurrentLocation(requestPermission: true);
                              setDialogState(() {
                                isDetectingGps = false;
                                if (loc != null) {
                                  selectedDept = loc.departamento;
                                  selectedProv = loc.provincia;
                                }
                              });
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.40),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            isDetectingGps
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                                    ),
                                  )
                                : const Icon(Icons.my_location_rounded, color: Color(0xFF059669), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              isDetectingGps ? 'Detectando por GPS...' : '📍 Usar mi ubicación GPS actual',
                              style: const TextStyle(
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 3. Departamento
                    const Text(
                      'Departamento donde vives *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedDept,
                      isExpanded: true,
                      hint: const Text(
                        'Selecciona departamento',
                        style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                      ),
                      items: PeruLocations.departamentos.map((dept) {
                        return DropdownMenuItem<String>(
                          value: dept,
                          child: Text(dept, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedDept = val;
                          selectedProv = null; // Reiniciar provincia
                        });
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.map_outlined, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 4. Provincia
                    const Text(
                      'Provincia donde vives *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: provinciasDisponibles.contains(selectedProv) ? selectedProv : null,
                      isExpanded: true,
                      hint: Text(
                        selectedDept == null
                            ? 'Primero elige un departamento'
                            : 'Selecciona provincia',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                      ),
                      items: provinciasDisponibles.map((prov) {
                        return DropdownMenuItem<String>(
                          value: prov,
                          child: Text(prov, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: selectedDept == null
                          ? null
                          : (val) {
                              setDialogState(() {
                                selectedProv = val;
                              });
                            },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.location_city_outlined, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),

                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dialogError!,
                                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          await GoogleAuthService.signOut();
                          if (context.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                  child: const Text('Cancelar', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final fullName = nameController.text.trim().toUpperCase();
                          final rawPhone = phoneController.text.trim();

                          if (fullName.isEmpty) {
                            setDialogState(() {
                              dialogError = 'Por favor ingresa tu nombre completo.';
                            });
                            return;
                          }

                          if (rawPhone.length != 9 || !rawPhone.startsWith('9')) {
                            setDialogState(() {
                              dialogError = 'Ingresa un celular válido de 9 dígitos que empiece con 9.';
                            });
                            return;
                          }

                          if (selectedDept == null || selectedDept!.isEmpty) {
                            setDialogState(() {
                              dialogError = 'Selecciona tu departamento de residencia.';
                            });
                            return;
                          }

                          if (selectedProv == null || selectedProv!.isEmpty) {
                            setDialogState(() {
                              dialogError = 'Selecciona tu provincia de residencia.';
                            });
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                            dialogError = null;
                          });

                          try {
                            final fullPhone = '+51 $rawPhone';
                            await GoogleAuthService.syncCitizenProfile(
                              user: user,
                              fullName: fullName,
                              phoneNumber: fullPhone,
                              departamento: selectedDept,
                              provincia: selectedProv,
                            );

                            await GpsLocationService.saveLocation(selectedDept!, selectedProv!);

                            if (context.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            if (mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) => const CitizenHomeScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                              dialogError = 'Error al guardar datos: $e';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Completar y Entrar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF080D1A),
        body: Stack(
          children: [
            // Fondo con degradado táctico institucional
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppColors.policeHeroGradient,
              ),
            ),

            // Esferas de luz ambiental (Efecto Glassmorphism Luminous)
            Positioned(
              top: -60,
              right: -50,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              bottom: 120,
              left: -70,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentColor.withValues(alpha: 0.08),
                ),
              ),
            ),

            // Filtro blur para el fondo ambiental
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                child: const SizedBox.expand(),
              ),
            ),

            // Contenido principal
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 24),

                            // Header institucional
                            _buildHeader(context),

                            const SizedBox(height: 22),

                            // Selector visual bilingüe: Español (por defecto) o Runasimi
                            _buildLanguageSelector(context),

                            const SizedBox(height: 14),

                            // Tarjeta Principal Glassmorphic: Solo Google Sign-In
                            _buildGoogleLoginCard(context),

                            const SizedBox(height: 32),

                            // Footer oficial
                            _buildFooter(),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Selector de idioma intuitivo y visual (Español por defecto / Runasimi Quechua)
  Widget _buildLanguageSelector(BuildContext context) {
    final langService = Provider.of<LanguageService>(context);
    final isQuechua = langService.isQuechua;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón Español
          _buildLanguageOption(
            label: 'Español',
            flag: '🇵🇪',
            isSelected: !isQuechua,
            activeColor: const Color(0xFF0284C7),
            onTap: () {
              HapticFeedback.lightImpact();
              langService.setLanguage(AppLanguage.es);
            },
          ),
          const SizedBox(width: 4),
          // Botón Quechua (Runasimi)
          _buildLanguageOption(
            label: 'Runasimi',
            subLabel: 'Quechua',
            flag: '🌾',
            isSelected: isQuechua,
            activeColor: const Color(0xFF10B981),
            onTap: () {
              HapticFeedback.lightImpact();
              langService.setLanguage(AppLanguage.qu);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption({
    required String label,
    String? subLabel,
    required String flag,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? activeColor : Colors.transparent,
          border: isSelected
              ? Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.white70,
                    letterSpacing: 0.3,
                  ),
                ),
                if (subLabel != null)
                  Text(
                    subLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.white54,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final strings = AppStrings.of(context);

    return Column(
      children: [
        // Distintivo Institucional
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.20),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                strings.officialPnp,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Emblema Oficial con marco Glass
        Hero(
          tag: 'app_logo',
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Image.asset(
              'assets/icons/icon_police.png',
              height: 52,
            ),
          ),
        ),

        const SizedBox(height: 14),

        Text(
          strings.loginTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          strings.isQuechua
              ? 'Chinkasqa Runakunata Maskana Pirwapi'
              : 'Plataforma Ciudadana de Búsqueda y Apoyo',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.75),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  /// Tarjeta Glassmorphic Premium y Exclusiva para Acceso Seguro Google
  Widget _buildGoogleLoginCard(BuildContext context) {
    final strings = AppStrings.of(context);
    final isQuechua = strings.isQuechua;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF13233A).withValues(alpha: 0.85),
                const Color(0xFF0A1424).withValues(alpha: 0.92),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 36,
                spreadRadius: 0,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge de seguridad / acceso institucional
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.accentColor.withValues(alpha: 0.40),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: AppColors.accentColor,
                      size: 14,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      strings.citizenAccess.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.accentColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Título
              Text(
                isQuechua ? 'Yaykuy' : 'Iniciar Sesión',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                strings.loginSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.white.withValues(alpha: 0.75),
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 26),

              // Botón Principal Google
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const Key('btn_google_signin'),
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
                            ),
                          )
                        : const FaIcon(
                            FontAwesomeIcons.google,
                            color: Color(0xFFEA4335),
                            size: 20,
                          ),
                    label: Text(
                      _isLoading
                          ? (isQuechua
                              ? 'Google nisqaman yaykuchkan...'
                              : 'Conectando con Google...')
                          : strings.loginWithGoogle,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Separador visual
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      isQuechua ? 'Icha' : 'o también',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Botón Modo Espectador (Explorar sin iniciar sesión)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withValues(alpha: 0.07),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _isLoading
                        ? null
                        : () => SpectatorModeService.enterSpectatorMode(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.visibility_rounded,
                              color: Color(0xFF38BDF8),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isQuechua
                                      ? 'Qhawaq hina yaykuy'
                                      : 'Explorar en Modo Espectador',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isQuechua
                                      ? 'Mana sesiónta qallarispa qhaway'
                                      : 'Consulta casos, comisarías y alertas sin cuenta',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.70),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white.withValues(alpha: 0.50),
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.40),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFFCA5A5),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFFEE2E2),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Indicador de autenticación oficial
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_clock_outlined,
                    size: 13.5,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Plataforma Segura • Conexión Cifrada',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.55),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'Al continuar, aceptas nuestros términos de servicio y políticas PNP.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Dirección de Seguridad Ciudadana • PNP',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
