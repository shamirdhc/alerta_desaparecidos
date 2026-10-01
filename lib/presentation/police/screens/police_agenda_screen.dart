import 'package:flutter/material.dart';
import '../../citizen/screens/agenda_policial.dart';

/// Pantalla de Agenda y Directorio Policial Oficial PNP.
/// Conecta directamente con la red nacional geoespacial del MININTER
/// que contiene más de 1,400 comisarías con coordenadas GPS, teléfonos y ubigeo.
class PoliceAgendaScreen extends StatelessWidget {
  final String? initialSearchQuery;
  final String? initialDepartamento;
  final String? initialProvincia;

  const PoliceAgendaScreen({
    super.key,
    this.initialSearchQuery,
    this.initialDepartamento,
    this.initialProvincia,
  });

  @override
  Widget build(BuildContext context) {
    return AgendaPolicialScreen(
      initialSearchQuery: initialSearchQuery,
      initialDepartamento: initialDepartamento,
      initialProvincia: initialProvincia,
    );
  }
}
