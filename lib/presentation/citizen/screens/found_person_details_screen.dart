import 'package:flutter/material.dart';
import '../../../domain/entities/desaparecido.dart';
import 'package:intl/intl.dart';

class FoundPersonDetailsScreen extends StatelessWidget {
  final Desaparecido desaparecido;

  const FoundPersonDetailsScreen({super.key, required this.desaparecido});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${desaparecido.nombres} ${desaparecido.apellidos}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (desaparecido.fotoUrl != null)
              Center(
                child: Image.network(
                  desaparecido.fotoUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16.0),
            Text(
              '${desaparecido.nombres} ${desaparecido.apellidos}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8.0),
            if (desaparecido.sexo != null)
              Text('Sexo: ${desaparecido.sexo}'),
            if (desaparecido.dni != null)
              Text('DNI: ${desaparecido.dni}'),
            if (desaparecido.telefonoContacto != null)
              Text(
                'Teléfono Contacto: ${desaparecido.telefonoContacto}',
              ),
            if (desaparecido.fechaDesaparicion != null)
              Text(
                'Fecha de Desaparición: ${DateFormat('dd/MM/yyyy HH:mm').format(desaparecido.fechaDesaparicion!)}',
              ),
            if (desaparecido.departamento != null)
              Text('Departamento: ${desaparecido.departamento}'),
            if (desaparecido.provincia != null)
              Text('Provincia: ${desaparecido.provincia}'),
            if (desaparecido.distrito != null)
              Text('Distrito: ${desaparecido.distrito}'),
            const SizedBox(height: 16.0),
            if (desaparecido.detallesAdicionales != null)
              Text(
                'Detalles Adicionales:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            if (desaparecido.detallesAdicionales != null)
              Text(desaparecido.detallesAdicionales!),
            const SizedBox(height: 16.0),
            // Mensaje específico para persona encontrada
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Text(
                'Esta persona ha sido encontrada',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}