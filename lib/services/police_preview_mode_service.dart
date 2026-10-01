import 'package:flutter/material.dart';
import '../presentation/citizen/screens/citizen_home_screen.dart';

/// Servicio singleton que gestiona el "Modo Vista Ciudadano" para administradores policiales.
/// Permite que los oficiales exploren la experiencia ciudadana con funciones de subida/envío bloqueadas,
/// pudiendo regresar a su panel de comando en cualquier momento sin perder su sesión policial.
class PolicePreviewModeService {
  static bool _isPreviewActive = false;
  static bool get isPreviewActive => _isPreviewActive;

  static final ValueNotifier<bool> previewNotifier = ValueNotifier<bool>(false);

  /// Ingresa al modo vista de ciudadano abriendo CitizenHomeScreen
  static void enterPreviewMode(BuildContext context) {
    _isPreviewActive = true;
    previewNotifier.value = true;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CitizenHomeScreen(),
      ),
    ).then((_) {
      // Al salir de CitizenHomeScreen por cualquier medio, aseguramos desactivar el modo
      _isPreviewActive = false;
      previewNotifier.value = false;
    });
  }

  /// Sale del modo vista y regresa al panel policial
  static void exitPreviewMode(BuildContext context) {
    _isPreviewActive = false;
    previewNotifier.value = false;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// Muestra advertencia estandarizada si el oficial intenta una acción reservada para ciudadanos
  static void showRestrictedActionSnackbar(BuildContext context, {String? customMessage}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF06B6D4), width: 1.5),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, color: Color(0xFF06B6D4), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                customMessage ??
                    'Función bloqueada en Modo Vista. Los administradores policiales gestionan casos desde el Panel Policial.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
