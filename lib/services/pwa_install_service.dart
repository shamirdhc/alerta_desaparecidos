import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pwa_install/pwa_install_stub.dart'
    if (dart.library.js_interop) 'pwa_install/pwa_install_web.dart';

class PwaInstallService {
  static bool _hasAutoPromptedInThisSession = false;
  static const String _prefDismissedKey = 'pwa_auto_prompt_dismissed_at';

  /// Retorna true si la plataforma actual es Web
  static bool get isWebPlatform => kIsWeb;

  /// Retorna true si la aplicación ya está corriendo instalada (Standalone / PWA instalada)
  static bool get isAppInstalled {
    if (!kIsWeb) return true;
    return platformIsPWAInstalled();
  }

  /// Retorna true si el navegador tiene listo el evento nativo `beforeinstallprompt`
  static bool get canPromptInstall {
    if (!kIsWeb) return false;
    return platformCanPromptPWAInstall();
  }

  /// Retorna true si el usuario está en Safari iOS (iPhone / iPad)
  static bool get isIOS {
    if (!kIsWeb) return false;
    return platformIsIOSDevice();
  }

  /// Retorna true si se debe mostrar la opción de instalar
  static bool get isInstallOptionAvailable => kIsWeb && !isAppInstalled;

  /// Verifica y muestra el banner emergente automático si estamos en Web y no está instalada
  static Future<void> checkAndShowAutoInstallPrompt(
    BuildContext context, {
    Duration delay = const Duration(seconds: 3),
  }) async {
    if (!kIsWeb) return;
    if (_hasAutoPromptedInThisSession) return;
    if (isAppInstalled) return;

    // Verificar si el usuario ya lo descartó en las últimas 24 horas en este navegador
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDismissedMs = prefs.getInt(_prefDismissedKey) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - lastDismissedMs < 24 * 60 * 60 * 1000) {
        return;
      }
    } catch (_) {}

    await Future.delayed(delay);
    if (!context.mounted) return;
    if (isAppInstalled) return;

    _hasAutoPromptedInThisSession = true;
    showAutoInstallBanner(context);
  }

  /// Despliega el banner emergente automático e interactivo
  static void showAutoInstallBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                      : [Colors.white, const Color(0xFFF8FAFC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF38BDF8).withOpacity(0.35)
                      : const Color(0xFF2563EB).withOpacity(0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.black : const Color(0xFF1E3A8A)).withOpacity(0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Barra de arrastre superior
                  Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Badge institucional
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF2563EB).withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.verified_user_rounded, color: Color(0xFF2563EB), size: 14),
                        SizedBox(width: 6),
                        Text(
                          'PLATAFORMA OFICIAL PNP • INSTALACIÓN EN 1 TOQUE',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Ícono de la app y títulos
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(
                          'assets/icons/icon_police.png',
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.shield_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¿Instalar Alerta Desaparecidos?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Úsala a pantalla completa desde tu pantalla de inicio, sin barra del navegador y con alertas inmediatas.',
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 3 Beneficios rápidos en horizontal
                  Row(
                    children: [
                      _buildQuickBenefit(Icons.flash_on_rounded, 'Sin descargas', isDark),
                      const SizedBox(width: 8),
                      _buildQuickBenefit(Icons.fullscreen_rounded, 'Pantalla completa', isDark),
                      const SizedBox(width: 8),
                      _buildQuickBenefit(Icons.notifications_active_rounded, 'Alertas en vivo', isDark),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Botón principal de instalación directa (1 Toque)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await promptOrGuideInstall(context);
                      },
                      icon: const Icon(Icons.install_mobile_rounded, color: Colors.white, size: 21),
                      label: const Text(
                        '📲 Instalar con 1 Toque',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 5,
                        shadowColor: const Color(0xFF2563EB).withOpacity(0.4),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Botón descartar
                  TextButton(
                    onPressed: () async {
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt(_prefDismissedKey, DateTime.now().millisecondsSinceEpoch);
                      } catch (_) {}
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(
                      'Ahora no',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildQuickBenefit(IconData icon, String text, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF2563EB)),
            const SizedBox(height: 3),
            Text(
              text,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Dispara la instalación nativa o despliega la guía paso a paso
  static Future<void> promptOrGuideInstall(BuildContext context) async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya te encuentras en la aplicación instalada.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      return;
    }

    if (isAppInstalled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text('¡La aplicación ya está instalada en tu dispositivo!')),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      return;
    }

    // Si el navegador soporta el diálogo oficial directo (Android/Chrome/Edge)
    if (canPromptInstall) {
      final success = await platformTriggerPWAInstallPrompt();
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.celebration_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('¡Aplicación instalada exitosamente en tu dispositivo!')),
              ],
            ),
            backgroundColor: Color(0xFF059669),
          ),
        );
        return;
      }
    }

    // Si no está disponible el diálogo nativo directo o es iOS, mostrar guía interactiva
    if (context.mounted) {
      showInstallGuideModal(context);
    }
  }

  /// Muestra una guía modal visual adaptada al dispositivo (iOS Safari, Android o Computadora)
  static void showInstallGuideModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIosDevice = isIOS;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 25,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de arrastre superior
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),

              // Cabecera con ícono de la app
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      'assets/icons/icon_police.png',
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.shield_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instalar Aplicativo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Alerta Desaparecidos PNP',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        Text(
                          'Versión Web Progresiva (PWA)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Beneficios rápidos
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildFeatureItem(Icons.touch_app_rounded, 'Sin descargas', isDark),
                    _buildFeatureDivider(isDark),
                    _buildFeatureItem(Icons.fullscreen_rounded, 'Pantalla completa', isDark),
                    _buildFeatureDivider(isDark),
                    _buildFeatureItem(Icons.bolt_rounded, 'Ultra rápido', isDark),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Instrucciones específicas por sistema
              if (isIosDevice) ...[
                _buildStepItem(
                  step: '1',
                  title: 'Toca el botón Compartir',
                  subtitle: 'En la barra inferior de Safari, pulsa el ícono de compartir ⎋ (un recuadro con flecha hacia arriba).',
                  icon: Icons.ios_share_rounded,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildStepItem(
                  step: '2',
                  title: 'Selecciona "Agregar a pantalla de inicio"',
                  subtitle: 'Desplázate hacia abajo en el menú y selecciona "Agregar a pantalla de inicio" (o "Add to Home Screen").',
                  icon: Icons.add_box_rounded,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildStepItem(
                  step: '3',
                  title: 'Confirma pulsando "Agregar"',
                  subtitle: 'Arriba a la derecha, pulsa "Agregar". El ícono oficial aparecerá en tu iPhone/iPad.',
                  icon: Icons.check_circle_outline_rounded,
                  isDark: isDark,
                ),
              ] else ...[
                _buildStepItem(
                  step: '1',
                  title: 'Abre el menú del navegador',
                  subtitle: 'Toca los tres puntos ⋮ en la parte superior derecha de tu navegador Chrome / Edge.',
                  icon: Icons.more_vert_rounded,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildStepItem(
                  step: '2',
                  title: 'Selecciona "Instalar aplicación"',
                  subtitle: 'Elige la opción "Instalar aplicación" o "Agregar a la pantalla principal".',
                  icon: Icons.download_rounded,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildStepItem(
                  step: '3',
                  title: 'Listo para usar',
                  subtitle: 'Se creará el acceso directo con icono oficial en tu pantalla principal.',
                  icon: Icons.verified_rounded,
                  isDark: isDark,
                ),
              ],

              const SizedBox(height: 24),

              // Botón de acción principal
              if (canPromptInstall)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await promptOrGuideInstall(context);
                    },
                    icon: const Icon(Icons.install_mobile_rounded, color: Colors.white),
                    label: const Text(
                      'Instalar Ahora',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Entendido',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildFeatureItem(IconData icon, String text, bool isDark) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2563EB)),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  static Widget _buildFeatureDivider(bool isDark) {
    return Container(
      width: 1,
      height: 24,
      color: isDark ? Colors.white12 : Colors.black12,
    );
  }

  static Widget _buildStepItem({
    required String step,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(icon, size: 16, color: const Color(0xFF2563EB)),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
