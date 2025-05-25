import 'package:flutter/material.dart';
import '../../../domain/entities/desaparecido.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class MissingPersonDetailsScreen extends StatefulWidget {
  final Desaparecido desaparecido;

  const MissingPersonDetailsScreen({super.key, required this.desaparecido});

  @override
  // Cambia el tipo de retorno aquí
  MissingPersonDetailsScreenState createState() =>
      MissingPersonDetailsScreenState();
}

// Y cambia el nombre de la clase aquí
class MissingPersonDetailsScreenState
    extends State<MissingPersonDetailsScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _isLoading = false;

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

  void _shareDetails() async {
    setState(() {
      _isLoading = true;
    });

    final String shareText =
        '🚨 *¡ALERTA DE PERSONA DESAPARECIDA!* 🚨\n\n' +
        '👤 *NOMBRE:* ${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}\n\n' +
        (widget.desaparecido.sexo != null
            ? '🚻 *SEXO:* ${widget.desaparecido.sexo}\n\n'
            : '') +
        (widget.desaparecido.fechaDesaparicion != null
            ? '🗓️ *FECHA DE DESAPARICIÓN:* ${DateFormat('dd/MM/yyyy HH:mm').format(widget.desaparecido.fechaDesaparicion!)}\n\n'
            : '') +
        (widget.desaparecido.departamento != null
            ? '📍 *LUGAR:* ${widget.desaparecido.distrito}, ${widget.desaparecido.provincia}, ${widget.desaparecido.departamento}\n\n'
            : '') +
        (widget.desaparecido.detallesAdicionales != null
            ? '📝 *DETALLES ADICIONALES:* ${widget.desaparecido.detallesAdicionales}\n\n'
            : '') +
        (widget.desaparecido.telefonoContacto != null
            ? '📞 *CONTACTO:* ${widget.desaparecido.telefonoContacto}\n\n'
            : '') +
        '\n' +
        '🚨 🚓 *CONTACTO POLICÍA: 948269740* 🚓 🚨\n\n' +
        '🙏 *POR FAVOR, COMPARTE ESTA INFORMACIÓN PARA AYUDAR A ENCONTRAR A ${widget.desaparecido.nombres}.* 🙏';

    final List<String> imagePaths = [];
    final directory = await getTemporaryDirectory();

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

    ShareResult shareResult;
    if (imagePaths.isNotEmpty) {
      final List<XFile> xFiles = imagePaths.map((path) => XFile(path)).toList();
      shareResult = await SharePlus.instance.share(
        ShareParams(text: shareText, files: xFiles),
      );
    } else {
      shareResult = await SharePlus.instance.share(
        ShareParams(text: shareText),
      );
    }

    setState(() {
      _isLoading = false;
    });

    if (shareResult.status == ShareResultStatus.success ||
        shareResult.status == ShareResultStatus.dismissed) {
      for (var path in imagePaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
            print('Archivo temporal eliminado: $path');
          }
        } catch (e) {
          print('Error al eliminar archivo temporal $path: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Contenedor para la cinta de iconos con fondo azul
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue[800]!.withOpacity(
                      0.7,
                    ), // Start color with opacity
                    Colors.blue[600]!.withOpacity(
                      0.7,
                    ), // End color with opacity
                  ],
                ),
                borderRadius: BorderRadius.circular(
                  16.0,
                ), // Mover borderRadius aquí
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (imageUrls.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: SizedBox(
                        height: 250,
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
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) =>
                                      const Center(child: Icon(Icons.error)),
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 12.0),
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
                                  ? Colors.white
                                  : Colors.white.withAlpha((255 * 0.5).round()),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    '${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8.0),
                  if (widget.desaparecido.fechaDesaparicion != null)
                    Text(
                      'Fecha de Desaparición: ${DateFormat('dd/MM/yyyy HH:mm').format(widget.desaparecido.fechaDesaparicion!)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  if (widget.desaparecido.provincia != null ||
                      widget.desaparecido.distrito != null)
                    Text(
                      '${widget.desaparecido.provincia ?? ''} - ${widget.desaparecido.distrito ?? ''}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  if (widget.desaparecido.telefonoContacto != null)
                    Text(
                      'Teléfono Contacto: ${widget.desaparecido.telefonoContacto}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  if (widget.desaparecido.detallesAdicionales != null)
                    Text(
                      'Detalles Adicionales: ${widget.desaparecido.detallesAdicionales}',
                      style: const TextStyle(color: Colors.white),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8.0),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color.fromARGB(
                      255,
                      166,
                      182,
                      199,
                    ).withOpacity(0.7), // Start color with opacity
                    const Color.fromARGB(
                      255,
                      145,
                      172,
                      196,
                    ).withOpacity(0.7), // End color with opacity
                  ],
                ),
                borderRadius: BorderRadius.circular(
                  16.0,
                ), // Mover borderRadius aquí
              ),
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _isLoading
                      ? const SizedBox(
                        width: 30.0,
                        height: 30.0,
                        child: CircularProgressIndicator(
                          color: Colors.blue,
                          strokeWidth: 2.0,
                        ),
                      )
                      : IconButton(
                        icon: Image.asset(
                          'assets/icons/share_icon.png',
                          width: 30.0,
                          height: 30.0,
                        ),
                        onPressed: _shareDetails,
                      ),
                  const SizedBox(width: 20.0),
                  IconButton(
                    icon: Image.asset(
                      'assets/icons/whatsapp_icon.png',
                      width: 30.0,
                      height: 30.0,
                    ),
                    onPressed: null,
                  ),
                  const SizedBox(width: 20.0),
                  IconButton(
                    icon: Image.asset(
                      'assets/icons/llamada_icon.png',
                      width: 30.0,
                      height: 30.0,
                    ),
                    onPressed: null,
                  ),
                  const SizedBox(width: 20.0),
                  IconButton(
                    icon: Image.asset(
                      'assets/icons/llamada_pnp_icon.png',
                      width: 30.0,
                      height: 30.0,
                    ),
                    onPressed: null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
          ],
        ),
      ),
    );
  }
}
