import 'package:alerta_desaparecidos/presentation/citizen/screens/full_screen_image_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../domain/entities/desaparecido.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _isDetailsExpanded = false;
  final TextEditingController _commentController = TextEditingController();
  // Add a list to store comments
  List<DocumentSnapshot> _comments = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
    _fetchComments(); // Fetch comments when the screen initializes
  }

  @override
  void dispose() {
    _pageController.dispose();
    _commentController.dispose();
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

  // Method to handle comment submission
  void _submitComment() async {
    final commentText = _commentController.text.trim();
    // Get the current authenticated user
    final user = FirebaseAuth.instance.currentUser;

    if (commentText.isNotEmpty &&
        widget.desaparecido.id != null &&
        user != null) {
      // Get the user's phone number
      final userPhoneNumber = user.phoneNumber;

      if (userPhoneNumber != null) {
        try {
          await FirebaseFirestore.instance.collection('comments').add({
            'missingPersonId': widget.desaparecido.id,
            'text': commentText,
            'timestamp': Timestamp.now(), // Use Firestore Timestamp
            'phoneNumber': userPhoneNumber, // Save the user's phone number
          });
          print('Comment added to Firestore');
          _commentController.clear(); // Clear the input field after submission
          _fetchComments(); // Refresh comments after adding a new one
        } catch (e) {
          print('Error adding comment: $e');
          // TODO: Show an error message to the user
        }
      } else {
        print('User phone number is not available.');
        // TODO: Handle case where phone number is missing
      }
    } else {
      print(
        'Comment text is empty, missing person ID is missing, or user is not logged in.',
      );
      // TODO: Handle these cases (e.g., show a message to the user)
    }
  }

  // Method to fetch comments from Firestore
  void _fetchComments() async {
    if (widget.desaparecido.id == null)
      return; // Cannot fetch without missing person ID

    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance
              .collection('comments')
              .where('missingPersonId', isEqualTo: widget.desaparecido.id)
              .orderBy('timestamp', descending: true) // Order by newest first
              .get();

      setState(() {
        _comments = querySnapshot.docs;
      });
      print('Fetched ${_comments.length} comments.');
    } catch (e) {
      print('Error fetching comments: $e');
      // TODO: Show an error message to the user
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
        title: Row(
          mainAxisSize:
              MainAxisSize
                  .min, // Para que el Row ocupe el mínimo espacio necesario
          children: [
            const Text(
              'PERSONA EN BUSQUEDA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8), // Espacio entre el texto y el icono
            const Icon(
              Icons.search,
              color: Colors.white,
            ), // Icono de búsqueda blanco sin interacción
          ],
        ),
        centerTitle: true,
        backgroundColor:
            Colors
                .transparent, // Establece el color de fondo como transparente para usar la decoración
        elevation: 0, // Elimina la sombra del AppBar
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue[800]!.withOpacity(0.7),
                Colors.blue[600]!.withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Eliminamos la sección actions ya que el icono se movió al título
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.search, color: Colors.white),
        //     onPressed: () {
        //       // TODO: Implementar la funcionalidad de búsqueda
        //     },
        //   ),
        // ],
        toolbarHeight: 40.0, // Ajusta la altura del AppBar
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
              padding: const EdgeInsets.all(8.0),
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
                            return Stack(
                              children: [
                                Image.network(
                                  imageUrls[index],
                                  height: 250,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          const Center(
                                            child: Icon(Icons.error),
                                          ),
                                ),
                                Positioned(
                                  bottom: 8.0, // Ajusta la posición vertical
                                  right: 8.0, // Ajusta la posición horizontal
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.fullscreen,
                                      color: Colors.white, // Color del icono
                                      size: 30.0, // Tamaño del icono
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  FullScreenImageScreen(
                                                    imageUrl: imageUrls[index],
                                                  ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
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

            // Comments Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comentarios',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  // Placeholder for comment input and list
                  // Replaced with comment input field and send button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller:
                              _commentController, // We'll define this controller next
                          decoration: InputDecoration(
                            hintText: 'Escribe un comentario...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[200],
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 10.0,
                            ),
                          ),
                          maxLines: null, // Allows multiple lines
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      CircleAvatar(
                        backgroundColor: Colors.blue, // Or your desired color
                        radius: 24.0,
                        child: IconButton(
                          icon: Icon(Icons.send, color: Colors.white),
                          onPressed:
                              _submitComment, // We'll define this method next
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  // Placeholder for comment list
                  // Replaced with a basic ListView structure
                  ListView.builder(
                    shrinkWrap: true, // Important for ListView inside Column
                    physics:
                        NeverScrollableScrollPhysics(), // Disable ListView's own scrolling
                    itemCount:
                        _comments.length, // Use the actual number of comments
                    itemBuilder: (context, index) {
                      final comment =
                          _comments[index].data() as Map<String, dynamic>;
                      final commentText = comment['text'] ?? 'No text';
                      final timestamp = comment['timestamp'] as Timestamp?;
                      final phoneNumber =
                          comment['phoneNumber'] ??
                          'Unknown user'; // Get phone number

                      // Format timestamp if available
                      String formattedTimestamp =
                          timestamp != null
                              ? DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(timestamp.toDate())
                              : 'Unknown time';

                      // Mask phone number for privacy (optional, adjust as needed)
                      String maskedPhoneNumber = phoneNumber
                          .toString()
                          .replaceRange(
                            0,
                            phoneNumber.toString().length - 4,
                            '****',
                          );

                      return ListTile(
                        leading: CircleAvatar(
                          // Placeholder for user image/icon
                          backgroundColor: Colors.blueGrey,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(
                          maskedPhoneNumber,
                        ), // Display masked phone number
                        subtitle: Text(
                          '$commentText\n$formattedTimestamp',
                        ), // Display comment text and timestamp
                        isThreeLine:
                            true, // Allow subtitle to use multiple lines
                      );
                    },
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
