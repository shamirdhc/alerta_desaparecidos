import 'package:flutter/material.dart';
import '../../../domain/entities/desaparecido.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart'; // Importar el paquete share_plus

class MissingPersonDetailsScreen extends StatefulWidget {
  final Desaparecido desaparecido;

  const MissingPersonDetailsScreen({super.key, required this.desaparecido});

  @override
  _MissingPersonDetailsScreenState createState() => _MissingPersonDetailsScreenState();
}

class _MissingPersonDetailsScreenState extends State<MissingPersonDetailsScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Función para compartir los detalles
  void _shareDetails() {
    final String shareText =
        '🚨 ¡ALERTA DE PERSONA DESAPARECIDA! 🚨\n\n' +
        '👤 Nombre: ${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}\n' +
        (widget.desaparecido.sexo != null ? '🚻 Sexo: ${widget.desaparecido.sexo}\n' : '') +
        (widget.desaparecido.dni != null ? '🆔 DNI: ${widget.desaparecido.dni}\n' : '') +
        (widget.desaparecido.fechaDesaparicion != null ? '🗓️ Fecha de Desaparición: ${DateFormat('dd/MM/yyyy HH:mm').format(widget.desaparecido.fechaDesaparicion!)}\n' : '') +
        (widget.desaparecido.departamento != null ? '📍 Lugar: ${widget.desaparecido.distrito}, ${widget.desaparecido.provincia}, ${widget.desaparecido.departamento}\n' : '') +
        (widget.desaparecido.detallesAdicionales != null ? '📝 Detalles Adicionales: ${widget.desaparecido.detallesAdicionales}\n' : '') +
        (widget.desaparecido.telefonoContacto != null ? '📞 Contacto: ${widget.desaparecido.telefonoContacto}\n' : '') +
        '\n🖼️ Imágenes:\n' +
        (widget.desaparecido.fotoUrl != null ? 'Foto Principal: ${widget.desaparecido.fotoUrl!}\n' : '') +
        (widget.desaparecido.imagenFichaUrl != null ? 'Imagen de Ficha: ${widget.desaparecido.imagenFichaUrl!}\n' : '') +
        '\n🙏 Por favor, comparte esta información para ayudar a encontrar a ${widget.desaparecido.nombres}.';

    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    // Crear una lista de URLs de imágenes válidas
    final List<String> imageUrls = [];
    if (widget.desaparecido.fotoUrl != null) {
      imageUrls.add(widget.desaparecido.fotoUrl!);
    }
    if (widget.desaparecido.imagenFichaUrl != null) {
      imageUrls.add(widget.desaparecido.imagenFichaUrl!);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}'),
        actions: [
          // Botón de compartir en la AppBar con imagen personalizada
          IconButton(
            icon: Image.asset('assets/icons/share_icon.png'), // Usar la imagen del asset
            onPressed: _shareDetails,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Contenedor azul con bordes curvados
            Container(
              decoration: BoxDecoration(
                color: Colors.blue[800], // Fondo azul oscuro
                borderRadius: BorderRadius.circular(16.0), // Bordes curvados
              ),
              padding: const EdgeInsets.all(16.0), // Espaciado interno
              child: Column(
                children: [
                  // Carrusel de imágenes con bordes curvados
                  if (imageUrls.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.0), // Bordes curvados para la imagen
                      child: SizedBox(
                        height: 250, // Altura del carrusel
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: imageUrls.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return Image.network(
                              imageUrls[index],
                              height: 250,
                              width: double.infinity,
                              fit: BoxFit.cover, // Cambiado a cover para llenar el espacio con bordes curvados
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(child: Icon(Icons.error)), // Manejo de error de carga
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 12.0), // Espacio entre carrusel e indicadores
                  // Indicadores circulares
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(imageUrls.length, (index) {
                      return Container(
                        width: 8.0,
                        height: 8.0,
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? Colors.white // Indicador activo
                              : Colors.white.withOpacity(0.5), // Indicador inactivo
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12.0), // Espacio entre indicadores y nombre
                  // Nombre completo centrado
                  Text(
                    '${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // Color de texto blanco para contraste
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0), // Espacio después del contenedor azul
            // ... Resto de los detalles de la persona
            if (widget.desaparecido.sexo != null)
              Text('Sexo: ${widget.desaparecido.sexo}'),
            if (widget.desaparecido.dni != null)
              Text('DNI: ${widget.desaparecido.dni}'),
            if (widget.desaparecido.telefonoContacto != null)
              Text(
                'Teléfono Contacto: ${widget.desaparecido.telefonoContacto}',
              ),
            if (widget.desaparecido.fechaDesaparicion != null)
              Text(
                'Fecha de Desaparición: ${DateFormat('dd/MM/yyyy HH:mm').format(widget.desaparecido.fechaDesaparicion!)}',
              ),
            if (widget.desaparecido.departamento != null)
              Text('Departamento: ${widget.desaparecido.departamento}'),
            if (widget.desaparecido.provincia != null)
              Text('Provincia: ${widget.desaparecido.provincia}'),
            if (widget.desaparecido.distrito != null)
              Text('Distrito: ${widget.desaparecido.distrito}'),
            const SizedBox(height: 16.0),
            if (widget.desaparecido.detallesAdicionales != null)
              Text(
                'Detalles Adicionales:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            if (widget.desaparecido.detallesAdicionales != null)
              Text(widget.desaparecido.detallesAdicionales!),
            const SizedBox(height: 16.0),
            // Mensaje específico para persona desaparecida
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Text(
                'Esta persona se encuentra desaparecida.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.orange,
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