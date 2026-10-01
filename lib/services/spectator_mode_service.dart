import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'gps_location_service.dart';
import 'session_service.dart';
import '../presentation/citizen/screens/citizen_home_screen.dart';
import '../presentation/screens/modern_login_screen.dart';

/// Servicio oficial para el "Modo Espectador" (Visitante).
/// Permite que cualquier ciudadano explore la plataforma (casos de desaparecidos,
/// personas ubicadas, comisarías, directorio CEM, guías y números de emergencia)
/// sin necesidad de vincular cuenta Google.
/// Acciones sensibles (como publicar pistas o comentar) quedan protegidas con invitación a iniciar sesión.
class SpectatorModeService {
  static bool _isSpectator = false;
  static bool get isSpectator => _isSpectator;

  static final ValueNotifier<bool> spectatorNotifier = ValueNotifier<bool>(false);

  /// Inicializa el estado persistido de modo espectador
  static Future<bool> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSpectator = prefs.getBool('is_spectator_mode') ?? false;
      spectatorNotifier.value = _isSpectator;
      return _isSpectator;
    } catch (_) {
      _isSpectator = false;
      spectatorNotifier.value = false;
      return false;
    }
  }

  /// Ingresa al Modo Espectador y navega a CitizenHomeScreen
  static Future<void> enterSpectatorMode(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_spectator_mode', true);
      await prefs.setString('userRole', 'citizen');
      await prefs.setString('user_role', 'citizen');
      await prefs.setBool('is_superadmin', false);
      await prefs.remove('is_superadmin');
      await prefs.setString('user_name', 'Modo Espectador');

      // Intentar obtener ubicación GPS real de forma proactiva para brindar alcance completo
      String dept = '';
      String prov = '';
      try {
        final loc = await GpsLocationService.getCurrentLocation(requestPermission: true);
        if (loc != null &&
            loc.departamento.isNotEmpty &&
            loc.departamento != 'TODOS' &&
            loc.departamento != 'TODAS') {
          dept = loc.departamento;
          prov = loc.provincia;
        }
      } catch (_) {}

      // Si no hubo GPS inmediato, revisar si había una lectura previa de GPS
      if (dept.isEmpty) {
        final cachedGpsDept = prefs.getString('gps_departamento');
        final cachedGpsProv = prefs.getString('gps_provincia');
        if (cachedGpsDept != null &&
            cachedGpsDept.isNotEmpty &&
            cachedGpsDept != 'TODOS' &&
            cachedGpsDept != 'TODAS') {
          dept = cachedGpsDept;
          prov = cachedGpsProv ?? '';
        }
      }

      await prefs.setString('user_departamento', dept);
      await prefs.setString('user_provincia', prov);

      // Guardar sesión en memoria de SessionService
      await SessionService.saveUserSession(
        userRole: 'citizen',
        userId: 'spectator_user',
        phoneNumber: '',
        userName: 'Modo Espectador',
        departamento: dept,
        provincia: prov,
      );

      _isSpectator = true;
      spectatorNotifier.value = true;

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CitizenHomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('⚠️ [SPECTATOR] Error al entrar en modo espectador: $e');
    }
  }

  /// Sale del Modo Espectador y redirige al Login
  static Future<void> exitSpectatorMode(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_spectator_mode');
      await SessionService.clearUserSession();

      _isSpectator = false;
      spectatorNotifier.value = false;

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ModernLoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('⚠️ [SPECTATOR] Error al salir de modo espectador: $e');
    }
  }

  /// Dirige al usuario a iniciar sesión con Google
  static void promptLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ModernLoginScreen()),
    );
  }

  /// Muestra modal institucional moderno explicando la limitación del espectador
  static void showLimitationModal(
    BuildContext context, {
    String? title,
    String? message,
    String? actionTitle,
    String? description,
    String actionLabel = 'Iniciar Sesión con Google',
  }) {
    final effectiveTitle = actionTitle ?? title ?? 'Identificación Requerida';
    final effectiveMessage = description ??
        message ??
        'Para aportar pistas o colaborar con información sobre personas desaparecidas, es necesario identificarse con su cuenta Google para garantizar la veracidad del reporte.';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A), // Slate 900 Institucional
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 30,
              offset: Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra superior de arrastre
              Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // Ícono insignia con halo de seguridad
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.35),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 34,
                ),
              ),

              const SizedBox(height: 16),

              // Badge institucional
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  'MODO ESPECTADOR • FUNCIÓN PROTEGIDA',
                  style: TextStyle(
                    color: Color(0xFFFCD34D),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Título
              Text(
                effectiveTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),

              const SizedBox(height: 10),

              // Mensaje explicativo
              Text(
                effectiveMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 24),

              // Botón 1: Iniciar Sesión con Google
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    promptLogin(context);
                  },
                  icon: const Icon(Icons.login_rounded, size: 20),
                  label: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Botón 2: Llamar gratis a Línea 114 PNP (alternativa directa inmediata)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final Uri url = Uri(scheme: 'tel', path: '114');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                  icon: const Icon(Icons.phone_in_talk, size: 18, color: Color(0xFF10B981)),
                  label: const Text(
                    'Llamar gratis a Línea 114 PNP',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF34D399),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0x3310B981), width: 1.2),
                    backgroundColor: const Color(0x1010B981),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Botón 3: Cancelar / Seguir explorando
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Seguir como espectador',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
