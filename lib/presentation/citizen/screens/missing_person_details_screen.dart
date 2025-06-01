import 'package:alerta_desaparecidos/presentation/citizen/screens/full_screen_image_screen.dart';
import 'package:alerta_desaparecidos/presentation/common_widgets/comment_bubble.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../domain/entities/desaparecido.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Importar para StreamSubscription
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
  final TextEditingController _commentController = TextEditingController();
  // Add a list to store comments
  List<DocumentSnapshot> _comments = [];
  StreamSubscription? _commentsSubscription; // Variable para la suscripción

  // Declare and initialize FirebaseAuth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
    _subscribeToComments(); // Iniciar la suscripción al stream
  }

  @override
  void dispose() {
    _pageController.dispose();
    _commentController.dispose();
    _commentsSubscription?.cancel(); // Cancelar la suscripción
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

  // Method to fetch comments from Firestore (now uses a stream)
  void _subscribeToComments() {
    if (widget.desaparecido.id == null)
      return; // Cannot subscribe without missing person ID

    print(
      'Subscribing to comments for missingPersonId: ${widget.desaparecido.id}',
    ); // Added print

    _commentsSubscription = FirebaseFirestore.instance
        .collection('comments')
        .where('missingPersonId', isEqualTo: widget.desaparecido.id)
        .orderBy('timestamp', descending: true) // Order by newest first
        .snapshots() // Use snapshots() to get a stream
        .listen(
          (querySnapshot) {
            setState(() {
              _comments = querySnapshot.docs;
              print(
                'Stream updated. Number of comments: ${_comments.length}',
              ); // Added print statement
            });
          },
          onError: (error) {
            print('Error fetching comments via stream: $error');
            // TODO: Show an error message to the user
          },
        );
  }

  // Method to submit a new comment to Firestore
  void _submitComment() async {
    final commentText = _commentController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (commentText.isNotEmpty &&
        widget.desaparecido.id != null &&
        user != null) {
      final userPhoneNumber = user.phoneNumber;

      if (userPhoneNumber != null) {
        try {
          // Obtener la ubicación actual
          Position? position;
          String? departamento, provincia, distrito;
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
            try {
              position = await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.high);
              List<Placemark> placemarks = await placemarkFromCoordinates(
                  position.latitude, position.longitude);
              if (placemarks.isNotEmpty) {
                final placemark = placemarks.first;
                departamento = placemark.administrativeArea;
                provincia = placemark.subAdministrativeArea;
                distrito = placemark.locality;
              }
            } catch (e) {
              print('Error obteniendo la ubicación: $e');
              // Opcional: Informar al usuario que no se pudo obtener la ubicación
            }
          }

          print(
            'Submitting comment for missingPersonId: ${widget.desaparecido.id}',
          ); // Added print
          await FirebaseFirestore.instance.collection('comments').add({
            'missingPersonId': widget.desaparecido.id,
            'text': commentText,
            'timestamp': Timestamp.now(), // Use Firestore Timestamp
            'phoneNumber': userPhoneNumber, // Save the user's phone number
            'latitude': position?.latitude,
            'longitude': position?.longitude,
            'departamento': departamento,
            'provincia': provincia,
            'distrito': distrito,
          });
          print('Comment added to Firestore');
          _commentController.clear(); // Clear the input field after submission
          // No need to call _fetchComments() here, the stream will update
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

  @override
  Widget build(BuildContext context) {
    final List<String> imageUrls = [];
    if (widget.desaparecido.fotoUrl != null) {
      imageUrls.add(widget.desaparecido.fotoUrl!);
    }
    if (widget.desaparecido.imagenFichaUrl != null) {
      imageUrls.add(widget.desaparecido.imagenFichaUrl!);
    }

    // Determinar el título del AppBar
    String appBarTitle = widget.desaparecido.estado == 'ENCONTRADO'
        ? 'Persona Encontrada'
        : 'Persona Desaparecida';

    // La variable appBarColor ha sido eliminada ya que no se usaba.

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        centerTitle: false, // Alinear el título a la izquierda
        backgroundColor: Colors.transparent, // Hacer AppBar transparente
        elevation: 0, // Quitar sombra del AppBar
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.desaparecido.estado == 'ENCONTRADO'
                  ? [
                      Colors.green.shade300, // Un verde más claro para el inicio del gradiente
                      Colors.green.shade700, // Un verde más oscuro para el final del gradiente
                    ]
                  : [
                      const Color(0xFFADD8E6), // Azul Suave
                      const Color(0xFF90EE90), // Verde Esperanza
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: _shareDetails,
              tooltip: 'Compartir',
            )
          else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
              ),
            ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.desaparecido.estado == 'ENCONTRADO'
                ? [
                    Colors.green.shade200, // Un verde aún más claro para el cuerpo
                    Colors.green.shade500, // Un verde medio para el cuerpo
                  ]
                : [
                    const Color(0xFFADD8E6), // Azul Suave
                    const Color(0xFF90EE90), // Verde Esperanza
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
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
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment =
                            _comments[index].data() as Map<String, dynamic>;
                        final commentText = comment['text'] ?? 'No text';
                        final timestamp = comment['timestamp'] as Timestamp?;
                        final phoneNumber = comment['phoneNumber'] ?? '';

                        // Determine if the comment is from the current user
                        final isCurrentUser =
                            phoneNumber == _auth.currentUser?.phoneNumber;

                        return CommentBubble(
                          text: commentText,
                          timestamp: timestamp,
                          phoneNumber: phoneNumber,
                          isCurrentUser: isCurrentUser,
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
      ),
    );
  }
}
