import 'package:flutter/material.dart';
import 'citizen_ai_chat_screen.dart';

export 'citizen_ai_chat_screen.dart';

/// Pantalla de Asistente IA y Orientación Integral de Desaparición.
/// 
/// Reemplaza la antigua guía estática por un Asistente Conversacional Inteligente (AlertaBot PNP)
/// fundamentado en el Decreto Legislativo N° 1428 y D.S. 003-2020-IN, con acceso inmediato
/// al directorio georreferenciado de comisarías a nivel nacional, teléfonos de guardia y 
/// protocolos de la Hora Dorada.
class ReportMissingScreen extends StatelessWidget {
  final Function(int)? onNavigateToTab;

  const ReportMissingScreen({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    return CitizenAiChatScreen(onNavigateToTab: onNavigateToTab);
  }
}
