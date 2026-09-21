import 'package:flutter/material.dart';
import '../../services/session_service.dart';

class LegalDisclaimerDialog extends StatefulWidget {
  final String phoneNumber;

  const LegalDisclaimerDialog({
    super.key,
    required this.phoneNumber,
  });

  /// Verifica si el usuario ya aceptó el aviso legal.
  /// Si ya lo aceptó, retorna `true` de inmediato sin mostrar diálogo.
  /// Si es la primera vez, muestra el diálogo formal y guarda la respuesta.
  static Future<bool> checkAndShow(
    BuildContext context, {
    required String phoneNumber,
  }) async {
    final alreadyAccepted = await SessionService.hasAcceptedLegalDisclaimer();
    if (alreadyAccepted) {
      return true;
    }

    if (!context.mounted) return false;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => LegalDisclaimerDialog(phoneNumber: phoneNumber),
    );

    if (accepted == true) {
      await SessionService.setAcceptedLegalDisclaimer(true);
      return true;
    }

    return false;
  }

  @override
  State<LegalDisclaimerDialog> createState() => _LegalDisclaimerDialogState();
}

class _LegalDisclaimerDialogState extends State<LegalDisclaimerDialog> {
  bool _isChecked = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.gavel_rounded,
              color: Colors.amber.shade900,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Aviso de Responsabilidad Legal',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'La información o pista que proporciones será enviada directamente a la Policía Nacional del Perú (DEPITPTIM / Comisaría a cargo) para la búsqueda de la persona desaparecida.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El suministro de información o alertas falsas a la autoridad constituye delito tipificado en el Código Penal Peruano (Art. 368 CP).',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tu número registrado (${widget.phoneNumber.isNotEmpty ? widget.phoneNumber : "registrado en tu cuenta"}) y tu usuario quedarán vinculados a este reporte para que los agentes puedan contactarte.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.35),
            ),
            const SizedBox(height: 8),
            Text(
              '💡 Este aviso de responsabilidad solo se mostrará esta única vez.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => setState(() => _isChecked = !_isChecked),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Checkbox(
                    value: _isChecked,
                    onChanged: (val) => setState(() => _isChecked = val ?? false),
                    activeColor: theme.colorScheme.primary,
                  ),
                  const Expanded(
                    child: Text(
                      'He leído, comprendo y asumo la responsabilidad legal.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade600)),
        ),
        ElevatedButton(
          onPressed: _isChecked ? () => Navigator.of(context).pop(true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Aceptar y Enviar'),
        ),
      ],
    );
  }
}
