import 'package:flutter/material.dart';
import '../../../domain/entities/desaparecido.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart'; // Importar el paquete share_plus
import 'dart:io'; // Importar para manejar archivos
import 'package:http/http.dart' as http; // Importar para descargar imágenes
import 'package:path_provider/path_provider.dart'; // Importar para obtener directorio temporal

class MissingPersonDetailsScreen extends StatefulWidget {
  final Desaparecido desaparecido;

  const MissingPersonDetailsScreen({super.key, required this.desaparecido});

  @override
  _MissingPersonDetailsScreenState createState() =>
      _MissingPersonDetailsScreenState();
}

class _MissingPersonDetailsScreenState
    extends State<MissingPersonDetailsScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _isLoading =
      false; // Añadir variable de estado para el indicador de carga

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

  // Función para compartir los detalles y las imágenes
  void _shareDetails() async {
    // Hacer la función asíncrona
    setState(() {
      _isLoading = true; // Mostrar indicador de carga al iniciar
    });

    final String shareText =
        '🚨 *¡ALERTA DE PERSONA DESAPARECIDA!* 🚨\n\n' + // Título en negrita
        '👤 *NOMBRE:* ${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}\n\n' + // Espacio de línea adicional
        (widget.desaparecido.sexo != null
            ? '🚻 *SEXO:* ${widget.desaparecido.sexo}\n\n'
            : '') + // Espacio de línea adicional
        // (widget.desaparecido.dni != null ? '🆔 DNI: ${widget.desaparecido.dni}\n\n' : '') + // Eliminado el DNI
        (widget.desaparecido.fechaDesaparicion != null
            ? '🗓️ *FECHA DE DESAPARICIÓN:* ${DateFormat('dd/MM/yyyy HH:mm').format(widget.desaparecido.fechaDesaparicion!)}\n\n'
            : '') + // Espacio de línea adicional
        (widget.desaparecido.departamento != null
            ? '📍 *LUGAR:* ${widget.desaparecido.distrito}, ${widget.desaparecido.provincia}, ${widget.desaparecido.departamento}\n\n'
            : '') + // Espacio de línea adicional
        (widget.desaparecido.detallesAdicionales != null
            ? '📝 *DETALLES ADICIONALES:* ${widget.desaparecido.detallesAdicionales}\n\n'
            : '') + // Espacio de línea adicional
        (widget.desaparecido.telefonoContacto != null
            ? '📞 *CONTACTO:* ${widget.desaparecido.telefonoContacto}\n\n'
            : '') + // Espacio de línea adicional
        '\n' +
        '🚨 🚓 *CONTACTO POLICÍA: 948269740* 🚓 🚨\n\n' + // Agregado número de policía resaltado
        '🙏 *POR FAVOR, COMPARTE ESTA INFORMACIÓN PARA AYUDAR A ENCONTRAR A ${widget.desaparecido.nombres}.* 🙏';

    final List<String> imagePaths = [];
    final directory = await getTemporaryDirectory();

    // Descargar y guardar foto_url si existe
    if (widget.desaparecido.fotoUrl != null) {
      try {
        final response = await http.get(
          Uri.parse(widget.desaparecido.fotoUrl!),
        );
        if (response.statusCode == 200) {
          final file = File('${directory.path}/foto_principal.jpg');
          await file.writeAsBytes(response.bodyBytes);
          imagePaths.add(file.path);
        }
      } catch (e) {
        print('Error downloading foto_url: $e');
      }
    }

    // Descargar y guardar imagen_ficha_url si existe
    if (widget.desaparecido.imagenFichaUrl != null) {
      try {
        final response = await http.get(
          Uri.parse(widget.desaparecido.imagenFichaUrl!),
        );
        if (response.statusCode == 200) {
          final file = File('${directory.path}/imagen_ficha.jpg');
          await file.writeAsBytes(response.bodyBytes);
          imagePaths.add(file.path);
        }
      } catch (e) {
        print('Error downloading imagen_ficha_url: $e');
      }
    }

    // Compartir texto y archivos si hay imágenes descargadas
    ShareResult shareResult;
    if (imagePaths.isNotEmpty) {
      // Convertir las rutas de archivo a objetos XFile
      final List<XFile> xFiles = imagePaths.map((path) => XFile(path)).toList();

      // Usar la nueva API SharePlus.instance.share con ShareParams y capturar el resultado
      shareResult = await SharePlus.instance.share(
        ShareParams(text: shareText, files: xFiles),
      );
    } else {
      // Si no hay imágenes para compartir, solo comparte el texto y capturar el resultado
      shareResult = await SharePlus.instance.share(
        ShareParams(text: shareText),
      );
    }

    // Ocultar indicador de carga después de que la acción de compartir se complete o descarte
    setState(() {
      _isLoading = false;
    });

    // Limpiar archivos temporales solo si la acción de compartir tuvo éxito o fue descartada
    // Este bloque finally asegura que la limpieza ocurra incluso si hay errores después del share.
    // Sin embargo, la lógica de limpieza ya verifica el estado del shareResult.
    // Mantendremos el finally para robustez general, aunque la lógica principal de ocultar carga
    // se movió fuera de él para responder más rápido al cierre del diálogo nativo.
    // La limpieza se ejecutará después de que _isLoading se ponga en false.
    if (shareResult.status == ShareResultStatus.success ||
        shareResult.status == ShareResultStatus.dismissed) {
      for (var path in imagePaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            // Verificar si el archivo existe antes de intentar borrar
            await file.delete();
            print(
              'Archivo temporal eliminado: $path',
            ); // Opcional: log para depuración
          }
        } catch (e) {
          print(
            'Error al eliminar archivo temporal $path: $e',
          ); // Manejo de error
        }
      }
    }
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
        title: Text(
          '${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}',
        ),
        actions: [
          // Botón de compartir en la AppBar con imagen personalizada o indicador de carga
          _isLoading
              ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24.0,
                  height: 24.0,
                  child: CircularProgressIndicator(
                    color: Colors.blue,
                    strokeWidth: 2.0,
                  ), // Color cambiado a azul
                ),
              ) // Mostrar indicador de carga si está cargando
              : IconButton(
                icon: Image.asset(
                  'assets/icons/share_icon.png',
                ), // Usar la imagen del asset
                onPressed: _shareDetails, // Llamar a la función de compartir
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
                      borderRadius: BorderRadius.circular(
                        12.0,
                      ), // Bordes curvados para la imagen
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
                              fit:
                                  BoxFit
                                      .cover, // Cambiado a cover para llenar el espacio con bordes curvados
                              errorBuilder:
                                  (context, error, stackTrace) => const Center(
                                    child: Icon(Icons.error),
                                  ), // Manejo de error de carga
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(
                    height: 12.0,
                  ), // Espacio entre carrusel e indicadores
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
                          color:
                              _currentPage == index
                                  ? Colors
                                      .white // Indicador activo
                                  : Colors.white.withAlpha(
                                    (255 * 0.5).round(),
                                  ), // Indicador inactivo
                        ),
                      );
                    }),
                  ),
                  const SizedBox(
                    height: 12.0,
                  ), // Espacio entre indicadores y nombre
                  // Nombre completo centrado
                  Text(
                    '${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color:
                          Colors.white, // Color de texto blanco para contraste
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0), // Espacio después del contenedor azul
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
                color: Colors.orange.withAlpha((255 * 0.2).round()),
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
