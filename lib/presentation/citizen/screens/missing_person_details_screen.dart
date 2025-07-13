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
  // Corregir el nombre aquí - debe coincidir con la clase de abajo
  _MissingPersonDetailsScreenState createState() =>
      _MissingPersonDetailsScreenState();
}

// La clase State debe tener el guión bajo al inicio
class _MissingPersonDetailsScreenState extends State<MissingPersonDetailsScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  bool _isLoading = false;
  bool _isSubmittingComment =
      false; // Nueva variable para el estado de carga del comentario
  final TextEditingController _commentController = TextEditingController();
  // Add a list to store comments
  List<DocumentSnapshot> _comments = [];
  StreamSubscription? _commentsSubscription; // Variable para la suscripción
  String? _lastSentCommentId; // Para rastrear el último comentario enviado
  late AnimationController _inputAnimationController;
  late Animation<double> _inputScaleAnimation;

  // Declare and initialize FirebaseAuth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
    _subscribeToComments();

    // Inicializar animación para el campo de entrada
    _inputAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _inputScaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(
        parent: _inputAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _commentController.dispose();
    _commentsSubscription?.cancel(); // Cancelar la suscripción
    _inputAnimationController.dispose();
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
        // 1. Ocultar el teclado inmediatamente
        FocusScope.of(context).unfocus();

        // 2. Animación del botón de envío
        _inputAnimationController.forward().then((_) {
          _inputAnimationController.reverse();
        });

        // 3. Bloquear el campo de texto y mostrar estado de carga
        setState(() {
          _isSubmittingComment = true;
        });

        try {
          // Obtener la ubicación actual
          Position? position;
          String? departamento, provincia, distrito;
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            try {
              position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
              );
              List<Placemark> placemarks = await placemarkFromCoordinates(
                position.latitude,
                position.longitude,
              );
              if (placemarks.isNotEmpty) {
                final placemark = placemarks.first;
                departamento = placemark.administrativeArea;
                provincia = placemark.subAdministrativeArea;
                distrito = placemark.locality;
              }
            } catch (e) {
              print('Error obteniendo la ubicación: $e');
            }
          }

          print(
            'Submitting comment for missingPersonId: ${widget.desaparecido.id}',
          );

          // Agregar comentario a Firestore
          final docRef = await FirebaseFirestore.instance
              .collection('comments')
              .add({
                'missingPersonId': widget.desaparecido.id,
                'text': commentText,
                'timestamp': Timestamp.now(),
                'phoneNumber': userPhoneNumber,
                'latitude': position?.latitude,
                'longitude': position?.longitude,
                'departamento': departamento,
                'provincia': provincia,
                'distrito': distrito,
              });

          // Guardar el ID del último comentario enviado
          setState(() {
            _lastSentCommentId = docRef.id;
          });

          // 4. Esperar a que el comentario aparezca en la lista (máximo 2 segundos)
          bool commentAppeared = false;
          int attempts = 0;
          const maxAttempts = 20; // 2 segundos (20 * 100ms)

          while (!commentAppeared && attempts < maxAttempts) {
            await Future.delayed(const Duration(milliseconds: 100));

            // Verificar si el comentario ya aparece en la lista
            commentAppeared = _comments.any(
              (comment) => comment.id == docRef.id,
            );
            attempts++;
          }

          // 5. Limpiar el campo de texto solo después de que aparezca el comentario
          _commentController.clear();

          // 6. Limpiar el resaltado después de 3 segundos adicionales
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _lastSentCommentId = null;
              });
            }
          });

          print('Comment added to Firestore and appeared in list');
        } catch (e) {
          print('Error adding comment: $e');
          // En caso de error, mostrar un mensaje al usuario
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error al enviar comentario. Inténtalo de nuevo.',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } finally {
          // 7. Reactivar el campo de texto
          if (mounted) {
            setState(() {
              _isSubmittingComment = false;
            });
          }
        }
      } else {
        print('User phone number is not available.');
      }
    } else {
      print(
        'Comment text is empty, missing person ID is missing, or user is not logged in.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isFound = widget.desaparecido.estado == 'Encontrado';
    final MaterialColor primaryColor = isFound ? Colors.green : Colors.blue;
    final List<String> imageUrls = [
      if (widget.desaparecido.fotoUrl != null) widget.desaparecido.fotoUrl!,
      if (widget.desaparecido.imagenFichaUrl != null)
        widget.desaparecido.imagenFichaUrl!,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFound ? 'Persona Encontrada' : 'Persona Desaparecida',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors:
                  isFound
                      ? [Colors.green.shade400, Colors.green.shade700]
                      : [const Color(0xFF1976D2), const Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (!_isLoading)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.share, color: Colors.white, size: 20),
                ),
                onPressed: _shareDetails,
                tooltip: 'Compartir',
              ),
            )
          else
            Container(
              margin: const EdgeInsets.all(16.0),
              width: 24,
              height: 24,
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Contenido principal con padding inferior para la caja de comentarios
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    isFound
                        ? [Colors.green.shade50, Colors.green.shade100]
                        : [const Color(0xFFF3F9FF), const Color(0xFFE3F2FD)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 16.0,
                bottom: 120.0, // Espacio para la caja flotante
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Contenedor principal de información con diseño mejorado
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header con gradiente
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors:
                                  isFound
                                      ? [
                                        Colors.green.shade400,
                                        Colors.green.shade600,
                                      ]
                                      : [
                                        primaryColor.shade600,
                                        primaryColor.shade800,
                                      ],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20.0),
                              topRight: Radius.circular(20.0),
                            ),
                          ),
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              // Carrusel de imágenes mejorado
                              if (imageUrls.isNotEmpty)
                                Container(
                                  height: 280,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16.0),
                                    child: Stack(
                                      children: [
                                        PageView.builder(
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
                                                  height: 280,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (
                                                    context,
                                                    child,
                                                    loadingProgress,
                                                  ) {
                                                    if (loadingProgress == null)
                                                      return child;
                                                    return Container(
                                                      height: 280,
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[200],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16,
                                                            ),
                                                      ),
                                                      child: Center(
                                                        child: CircularProgressIndicator(
                                                          value:
                                                              loadingProgress
                                                                          .expectedTotalBytes !=
                                                                      null
                                                                  ? loadingProgress
                                                                          .cumulativeBytesLoaded /
                                                                      loadingProgress
                                                                          .expectedTotalBytes!
                                                                  : null,
                                                          color: primaryColor,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => Container(
                                                        height: 280,
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey[300],
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                16,
                                                              ),
                                                        ),
                                                        child: const Center(
                                                          child: Icon(
                                                            Icons.error_outline,
                                                            size: 50,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ),
                                                ),
                                                // Botón de pantalla completa mejorado
                                                Positioned(
                                                  top: 12.0,
                                                  right: 12.0,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.6),
                                                      borderRadius:
                                                          BorderRadius.circular(25),
                                                    ),
                                                    child: IconButton(
                                                      icon: const Icon(
                                                        Icons.fullscreen,
                                                        color: Colors.white,
                                                        size: 24.0,
                                                      ),
                                                      onPressed: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder:
                                                                (
                                                                  context,
                                                                ) => FullScreenImageScreen(
                                                                  imageUrl:
                                                                      imageUrls[index],
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        // Indicadores de página mejorados
                                        if (imageUrls.length > 1)
                                          Positioned(
                                            bottom: 16.0,
                                            left: 0,
                                            right: 0,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: List.generate(
                                                imageUrls.length,
                                                (index) {
                                                  return AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 300,
                                                    ),
                                                    width:
                                                        _currentPage == index
                                                            ? 24.0
                                                            : 8.0,
                                                    height: 8.0,
                                                    margin:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 4.0,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4.0,
                                                          ),
                                                      color:
                                                          _currentPage == index
                                                              ? Colors.white
                                                              : Colors.white
                                                                  .withOpacity(0.5),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 20.0),
                              // Nombre con mejor tipografía
                              Text(
                                '${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8.0),
                              // Badge de estado
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  isFound ? 'ENCONTRADO' : 'DESAPARECIDO',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Información detallada con mejor diseño
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              if (widget.desaparecido.fechaDesaparicion != null)
                                _buildInfoRow(
                                  Icons.calendar_today,
                                  'Fecha de Desaparición',
                                  DateFormat(
                                    'dd/MM/yyyy HH:mm',
                                  ).format(widget.desaparecido.fechaDesaparicion!),
                                  primaryColor,
                                ),
                              if (widget.desaparecido.provincia != null ||
                                  widget.desaparecido.distrito != null)
                                _buildInfoRow(
                                  Icons.location_on,
                                  'Ubicación',
                                  '${widget.desaparecido.provincia ?? ''} - ${widget.desaparecido.distrito ?? ''}',
                                  primaryColor,
                                ),
                              if (widget.desaparecido.telefonoContacto != null)
                                _buildInfoRow(
                                  Icons.phone,
                                  'Teléfono de Contacto',
                                  widget.desaparecido.telefonoContacto!,
                                  primaryColor,
                                ),
                              if (widget.desaparecido.detallesAdicionales != null)
                                _buildInfoCard(
                                  'Detalles Adicionales',
                                  widget.desaparecido.detallesAdicionales!,
                                  primaryColor,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  // Botones de acción con diseño mejorado
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          '¿Tienes información?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildActionButton(
                              'assets/icons/share_icon.png',
                              'Compartir',
                              primaryColor,
                              _isLoading,
                              _shareDetails,
                            ),
                            _buildActionButton(
                              'assets/icons/whatsapp_icon.png',
                              'WhatsApp',
                              Colors.green,
                              false,
                              () {}, // Placeholder
                            ),
                            _buildActionButton(
                              'assets/icons/llamada_icon.png',
                              'Llamar',
                              Colors.orange,
                              false,
                              () {}, // Placeholder
                            ),
                            _buildActionButton(
                              'assets/icons/llamada_pnp_icon.png',
                              'PNP',
                              Colors.red,
                              false,
                              () {}, // Placeholder
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  // Sección de comentarios existentes (solo mostrar)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    color: primaryColor,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Comentarios (${_comments.length})',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Lista de comentarios
                              if (_comments.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(40.0),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline,
                                          size: 48,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No hay comentarios aún',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Sé el primero en comentar',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _comments.length,
                                  itemBuilder: (context, index) {
                                    final comment = _comments[index];
                                    final data = comment.data() as Map<String, dynamic>;
                                    final currentUser = FirebaseAuth.instance.currentUser;
                                    final isCurrentUser =
                                        currentUser != null &&
                                        data['phoneNumber'] == currentUser.phoneNumber;

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: CommentBubble(
                                        text: data['text'] ?? 'No text',
                                        timestamp: data['timestamp'] as Timestamp?,
                                        phoneNumber: data['phoneNumber'] ?? '',
                                        isCurrentUser: isCurrentUser,
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Caja flotante de comentarios en la parte inferior
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            enabled: !_isSubmittingComment,
                            decoration: InputDecoration(
                              hintText:
                                  _isSubmittingComment
                                      ? 'Enviando comentario...'
                                      : 'Escribe un comentario...',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                              hintStyle: TextStyle(
                                color:
                                    _isSubmittingComment
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade500,
                                fontSize: 16,
                              ),
                            ),
                            maxLines: null,
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  _isSubmittingComment
                                      ? Colors.grey.shade400
                                      : Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: _isSubmittingComment
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                            onPressed: _isSubmittingComment ? null : _submitComment,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget helper para filas de información
  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget helper para tarjeta de información
  Widget _buildInfoCard(String title, String content, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // Widget helper para botones de acción
  Widget _buildActionButton(
    String iconPath,
    String label,
    Color color,
    bool isLoading,
    VoidCallback onPressed,
  ) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child:
              isLoading
                  ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    ),
                  )
                  : IconButton(
                    icon: Image.asset(
                      iconPath,
                      width: 28,
                      height: 28,
                      color: color,
                    ),
                    onPressed: onPressed,
                  ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
