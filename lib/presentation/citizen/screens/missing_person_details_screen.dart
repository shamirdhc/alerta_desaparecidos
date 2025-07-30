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
import 'dart:ui' as ui;
import 'package:url_launcher/url_launcher.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/session_service.dart';

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
  late ScrollController _scrollController;

  // Declare and initialize FirebaseAuth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
    _subscribeToComments();
    _scrollController = ScrollController();

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
    _scrollController.dispose();
    super.dispose();
  }

  void _shareDetails() async {
    // Mostrar modal simplificado con solo 2 opciones
    await _showShareOptionsModal();
  }

  Future<void> _showShareOptionsModal() async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              minHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.share_rounded,
                          size: 40,
                          color: Colors.blue[600],
                        ),
                        SizedBox(height: 12),
                        Text(
                          '¡Ayuda a difundir!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Elige cómo quieres compartir esta información',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Dos botones principales
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Botón WhatsApp
                        _buildShareButton(
                          icon: Icons.chat,
                          title: 'Compartir en WhatsApp',
                          subtitle: 'Formato optimizado para WhatsApp',
                          color: Color(0xFF25D366), // Verde WhatsApp
                          onTap: () => _shareWhatsApp(),
                        ),

                        SizedBox(height: 15),

                        // Botón Redes Sociales
                        _buildShareButton(
                          icon: Icons.share,
                          title: 'Compartir en Redes Sociales',
                          subtitle:
                              'Formato optimizado para Facebook, Instagram, etc.',
                          color: Color(0xFF1877F2), // Azul Facebook
                          onTap: () => _shareSocialMedia(),
                        ),
                      ],
                    ),
                  ),

                  // Footer con mensaje motivacional
                  Container(
                    margin: EdgeInsets.all(20),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.favorite, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tu ayuda puede marcar la diferencia. Cada compartir cuenta.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildShareButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  // Compartir directamente a WhatsApp
  Future<void> _shareWhatsApp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final whatsappText = _generateWhatsAppText();
      
      // Descargar la ficha primero
      final List<String> imagePaths = [];
      final directory = await getTemporaryDirectory();

      if (widget.desaparecido.imagenFichaUrl != null) {
        try {
          final response = await http.get(
            Uri.parse(widget.desaparecido.imagenFichaUrl!),
          );
          if (response.statusCode == 200) {
            final file = File('${directory.path}/ficha_whatsapp.jpg');
            await file.writeAsBytes(response.bodyBytes);
            imagePaths.add(file.path);
          }
        } catch (e) {
          print('Error downloading ficha for WhatsApp: $e');
        }
      }

      // Compartir con ficha adjunta usando SharePlus
      if (imagePaths.isNotEmpty) {
        final List<XFile> xFiles = imagePaths.map((path) => XFile(path)).toList();
        await SharePlus.instance.share(ShareParams(text: whatsappText, files: xFiles));
        _showSuccessMessage('¡Ficha enviada a WhatsApp! 💚📎');
      } else {
        // Si no hay ficha, usar URL scheme directo para ir a WhatsApp
        final encodedText = Uri.encodeComponent(whatsappText);
        final whatsappUrl = "whatsapp://send?text=$encodedText";
        
        if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
          await launchUrl(Uri.parse(whatsappUrl));
          _showSuccessMessage('¡Abriendo WhatsApp! 💚');
        } else {
          await SharePlus.instance.share(ShareParams(text: whatsappText));
          _showSuccessMessage('¡Mensaje listo para WhatsApp! 💚');
        }
      }

      // Limpiar archivos temporales
      for (var path in imagePaths) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (e) {
          print('Error deleting temp file: $e');
        }
      }
    } catch (e) {
      print('Error al compartir en WhatsApp: $e');
      _showErrorMessage('Error al compartir en WhatsApp');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Método de respaldo que usa SharePlus (el método anterior)
  Future<void> _shareWithFallback(String text) async {
    try {
      // Usar solo la imagen de ficha para WhatsApp
      final List<String> imagePaths = [];
      final directory = await getTemporaryDirectory();

      if (widget.desaparecido.imagenFichaUrl != null) {
        try {
          final response = await http.get(
            Uri.parse(widget.desaparecido.imagenFichaUrl!),
          );
          if (response.statusCode == 200) {
            final file = File('${directory.path}/ficha_whatsapp.jpg');
            await file.writeAsBytes(response.bodyBytes);
            imagePaths.add(file.path);
          }
        } catch (e) {
          print('Error downloading ficha for WhatsApp: $e');
        }
      }

      // Compartir con imagen de ficha si está disponible
      if (imagePaths.isNotEmpty) {
        final List<XFile> xFiles =
            imagePaths.map((path) => XFile(path)).toList();
        await SharePlus.instance.share(ShareParams(text: text, files: xFiles));
      } else {
        await SharePlus.instance.share(ShareParams(text: text));
      }

      _showSuccessMessage('¡Listo para WhatsApp! 💚');

      // Limpiar archivos temporales
      for (var path in imagePaths) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (e) {
          print('Error deleting temp file: $e');
        }
      }
    } catch (e) {
      _showErrorMessage('Error al preparar para WhatsApp');
    }
  }

  // Compartir optimizado para redes sociales
  Future<void> _shareSocialMedia() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final socialText = _generateSocialMediaText();

      // Usar solo la imagen de ficha (segunda imagen) para redes sociales
      final List<String> imagePaths = [];
      final directory = await getTemporaryDirectory();

      if (widget.desaparecido.imagenFichaUrl != null) {
        try {
          final response = await http.get(
            Uri.parse(widget.desaparecido.imagenFichaUrl!),
          );
          if (response.statusCode == 200) {
            final file = File('${directory.path}/ficha_social.jpg');
            await file.writeAsBytes(response.bodyBytes);
            imagePaths.add(file.path);
          }
        } catch (e) {
          print('Error downloading ficha for social media: $e');
        }
      }

      // Compartir con imagen de ficha
      if (imagePaths.isNotEmpty) {
        final List<XFile> xFiles =
            imagePaths.map((path) => XFile(path)).toList();
        await SharePlus.instance.share(
          ShareParams(text: socialText, files: xFiles),
        );
      } else {
        await SharePlus.instance.share(ShareParams(text: socialText));
      }

      _showSuccessMessage('¡Listo para redes sociales! 📱');

      // Limpiar archivos temporales
      for (var path in imagePaths) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (e) {
          print('Error deleting temp file: $e');
        }
      }
    } catch (e) {
      _showErrorMessage('Error al preparar para redes sociales');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Función para calcular la edad basada en la fecha de nacimiento
  int _calcularEdad(DateTime fechaNacimiento) {
    final hoy = DateTime.now();
    int edad = hoy.year - fechaNacimiento.year;

    // Ajustar si aún no ha cumplido años este año
    if (hoy.month < fechaNacimiento.month ||
        (hoy.month == fechaNacimiento.month && hoy.day < fechaNacimiento.day)) {
      edad--;
    }

    return edad;
  }

  // Texto optimizado para WhatsApp - Máximo impacto
  String _generateWhatsAppText() {
    final edad =
        widget.desaparecido.fechaNacimiento != null
            ? ' (${_calcularEdad(widget.desaparecido.fechaNacimiento!)} años)'
            : '';
    final sexoIcon =
        widget.desaparecido.sexo?.toLowerCase() == 'masculino'
            ? '👨'
            : widget.desaparecido.sexo?.toLowerCase() == 'femenino'
            ? '👩'
            : '👤';

    return '🚨 *URGENTE - PERSONA DESAPARECIDA* 🚨\n\n'
        '$sexoIcon *${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}*$edad\n\n'
        '📅 *Desaparecido desde:* ${widget.desaparecido.fechaDesaparicion != null ? DateFormat('dd/MM/yyyy').format(widget.desaparecido.fechaDesaparicion!) : 'Fecha no especificada'}\n'
        '📍 *Última ubicación conocida:*\n${_formatLocation()}\n\n'
        '${widget.desaparecido.detallesAdicionales != null && widget.desaparecido.detallesAdicionales!.isNotEmpty ? '📝 *Información importante:*\n${widget.desaparecido.detallesAdicionales}\n\n' : ''}'
        '📞 *¿Lo has visto? Contacta:*\n${widget.desaparecido.telefonoContacto ?? '948269740'}\n\n'
        '🚓 *Policía Nacional: 948269740*\n\n'
        '🙏 *¡TU AYUDA ES VITAL!*\n'
        '💚 *Comparte este mensaje*\n'
        '👀 *Mantente alerta*\n'
        '📢 *Cada compartir cuenta*\n\n'
        '_"Una familia te necesita. Ayúdanos a traerle a casa."_';
  }

  // Texto optimizado para redes sociales - Máximo alcance
  String _generateSocialMediaText() {
    final edad =
        widget.desaparecido.fechaNacimiento != null
            ? ' (${_calcularEdad(widget.desaparecido.fechaNacimiento!)} años)'
            : '';
    final sexoIcon =
        widget.desaparecido.sexo?.toLowerCase() == 'masculino'
            ? '👨'
            : widget.desaparecido.sexo?.toLowerCase() == 'femenino'
            ? '👩'
            : '👤';

    return '🚨 #URGENTE #PersonaDesaparecida #AyudaAEncontrar\n\n'
        '🔍 *BÚSQUEDA ACTIVA* 🔍\n\n'
        '$sexoIcon *${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}*$edad\n\n'
        '📅 Desaparecido/a desde: ${widget.desaparecido.fechaDesaparicion != null ? DateFormat('dd/MM/yyyy').format(widget.desaparecido.fechaDesaparicion!) : 'Fecha no especificada'}\n'
        '📍 Última ubicación: ${_formatLocation()}\n\n'
        '${widget.desaparecido.detallesAdicionales != null && widget.desaparecido.detallesAdicionales!.isNotEmpty ? '📝 Información clave: ${widget.desaparecido.detallesAdicionales}\n\n' : ''}'
        '📞 Información: ${widget.desaparecido.telefonoContacto ?? '948269740'}\n'
        '🚓 PNP: 948269740\n\n'
        '🔄 *¡COMPARTE AHORA!* 🔄\n'
        '👥 *Etiqueta a tus contactos*\n'
        '📢 *Difunde en tus historias*\n'
        '💪 *Juntos podemos encontrarle*\n\n'
        '#EncontremosJuntos #PeruSolidario #FamiliasUnidas\n'
        '#CompartePorFavor #CadaCompartirCuenta #AyudaSocial\n'
        '#BusquedaActiva #SolidaridadPeruana #UnidosPorEllos';
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Función auxiliar para formatear la ubicación
  String _formatLocation() {
    final List<String> locationParts = [];

    if (widget.desaparecido.distrito != null &&
        widget.desaparecido.distrito!.isNotEmpty) {
      locationParts.add(widget.desaparecido.distrito!);
    }
    if (widget.desaparecido.provincia != null &&
        widget.desaparecido.provincia!.isNotEmpty) {
      locationParts.add(widget.desaparecido.provincia!);
    }
    if (widget.desaparecido.departamento != null &&
        widget.desaparecido.departamento!.isNotEmpty) {
      locationParts.add(widget.desaparecido.departamento!);
    }

    return locationParts.isNotEmpty
        ? locationParts.join(', ')
        : 'Ubicación no especificada';
  }

  // Method to fetch comments from Firestore (now uses a stream)
  void _subscribeToComments() {
    if (widget.desaparecido.id == null) {
      print('❌ [ERROR] ID de persona desaparecida es nulo');
      return;
    }

    final collectionPath = 'desaparecidos/${widget.desaparecido.id}/comments';
    print('🔍 [DEBUG] Ruta de lectura: $collectionPath');

    _commentsSubscription = FirebaseFirestore.instance
        .collection('desaparecidos')
        .doc(widget.desaparecido.id)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen(
      (snapshot) {
        print('📥 [DEBUG] Snapshot recibido con ${snapshot.docs.length} documentos');
        
        setState(() {
          _comments = snapshot.docs;
        });
        
        print('✅ [DEBUG] Estado actualizado con ${_comments.length} comentarios');
      },
      onError: (error) {
        print('❌ [ERROR] Error en stream de comentarios: $error');
      },
    );
  }

  // Función para abrir el buscador de comisarías
  Future<void> _openComisariaFinder() async {
    try {
      const url = 'https://aplicaciones.mininter.gob.pe/ubicatucomisaria/';
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showSuccessMessage('Abriendo buscador de comisarías 🏢');
      } else {
        _showErrorMessage('No se pudo abrir el enlace');
      }
    } catch (e) {
      print('Error al abrir buscador de comisarías: $e');
      _showErrorMessage('Error al abrir el buscador de comisarías');
    }
  }

  // Función para llamar al contacto de la víctima
  Future<void> _callVictimContact() async {
    try {
      final phoneNumber = widget.desaparecido.telefonoContacto;

      if (phoneNumber == null || phoneNumber.isEmpty) {
        _showErrorMessage('No hay número de contacto disponible');
        return;
      }

      // Limpiar el número de teléfono (remover espacios, guiones, etc.)
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
      final uri = Uri.parse('tel:$cleanNumber');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        _showSuccessMessage('Iniciando llamada... 📞');
      } else {
        _showErrorMessage('No se pudo iniciar la llamada');
      }
    } catch (e) {
      print('Error al llamar al contacto: $e');
      _showErrorMessage('Error al intentar llamar');
    }
  }

  // Función para llamar al 114 (PNP)
  Future<void> _callPNP114() async {
    try {
      const phoneNumber = '114';
      final uri = Uri.parse('tel:$phoneNumber');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        _showSuccessMessage('Llamando a la PNP (114)... 🚓');
      } else {
        _showErrorMessage('No se pudo iniciar la llamada');
      }
    } catch (e) {
      print('Error al llamar al 114: $e');
      _showErrorMessage('Error al intentar llamar al 114');
    }
  }

  // Method to submit a new comment to Firestore
  Future<void> _submitComment() async {
    final commentText = _commentController.text.trim();
    
    if (commentText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, escribe un comentario antes de enviar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      // Verificar y asegurar autenticación
      final isAuthenticated = await SessionService.ensureUserAuthenticated();
      if (!isAuthenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sesión expirada. Por favor, inicia sesión nuevamente.'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Ir a Login',
                textColor: Colors.white,
                onPressed: () {
                  // Navegar a la pantalla de login
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                },
              ),
            ),
          );
        }
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      print('👤 [DEBUG] Usuario autenticado: ${user?.uid}');
      
      if (user == null) {
        print('❌ [ERROR] Usuario no autenticado después de verificación');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error de autenticación. Reinicia la aplicación.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Verificar conectividad
      if (!await ConnectivityService.hasInternetConnection()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sin conexión a internet. Verifica tu conexión.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Obtener datos del usuario con timeout
      final userDoc = await FirebaseFirestore.instance
          .collection('ciudadanos')
          .doc(user.uid)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Timeout al obtener datos del usuario'),
          );

      if (!userDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Usuario no encontrado en la base de datos'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final userData = userDoc.data();
      // Mejorar la lógica para obtener el número de teléfono
      String phoneNumber = 'Sin número';
      if (userData?['telefono'] != null && userData!['telefono'].toString().trim().isNotEmpty) {
        phoneNumber = userData['telefono'].toString().trim();
      }
      final nombres = userData?['nombres'] ?? '';
      final apellidos = userData?['apellidos'] ?? '';
      
      // Verificar si el usuario está vetado
      if (userData?['vetado'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No tienes permisos para comentar'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      print('📱 [DEBUG] Número de teléfono del usuario: $phoneNumber');

      final docPath = 'desaparecidos/${widget.desaparecido.id}/comments';
      print('💾 [DEBUG] Ruta de guardado: $docPath');

      final commentData = {
        'text': commentText,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'phoneNumber': phoneNumber,
        'nombres': nombres,
        'apellidos': apellidos,
        'createdAt': DateTime.now().toIso8601String(), // Timestamp local como backup
      };
      print('💾 [DEBUG] Datos del comentario a guardar: $commentData');

      // Intentar guardar el comentario con timeout
      final docRef = await FirebaseFirestore.instance
          .collection('desaparecidos')
          .doc(widget.desaparecido.id)
          .collection('comments')
          .add(commentData)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Timeout al guardar comentario'),
          );

      // Guardar el ID del último comentario enviado
      setState(() {
        _lastSentCommentId = docRef.id;
      });

      print('✅ [DEBUG] Comentario guardado exitosamente con ID: ${docRef.id}');

      _commentController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Comentario añadido correctamente'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        // Desplazamiento automático al último comentario (al final de la lista)
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _scrollController.hasClients) {
            // Asegurarse de que el scroll se realiza después de que la UI se haya actualizado
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            });
          }
        });
      }
    } on FirebaseException catch (e) {
      print('❌ [FIREBASE ERROR] Error al enviar comentario: ${e.code} - ${e.message}');
      if (mounted) {
        String errorMessage = 'Error al enviar comentario';
        switch (e.code) {
          case 'permission-denied':
            errorMessage = 'No tienes permisos para comentar en este caso';
            break;
          case 'unavailable':
            errorMessage = 'Servicio no disponible. Inténtalo más tarde';
            break;
          case 'deadline-exceeded':
            errorMessage = 'La operación tardó demasiado. Inténtalo de nuevo';
            break;
          default:
            errorMessage = 'Error: ${e.message}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      print('❌ [ERROR] Error general al enviar comentario: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingComment = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isFound = widget.desaparecido.estado == 'Encontrado';
    final MaterialColor primaryColor = isFound ? Colors.green : Colors.blue;
    final List<String> imageUrls = [
      // Cambiamos el orden: primero imagenFichaUrl, luego fotoUrl
      if (widget.desaparecido.imagenFichaUrl != null)
        widget.desaparecido.imagenFichaUrl!,
      if (widget.desaparecido.fotoUrl != null) widget.desaparecido.fotoUrl!,
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
              controller: _scrollController,
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 16.0,
                bottom:
                    200.0, // Aumentado significativamente para evitar superposición
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
                                                          color:
                                                              Colors.grey[300],
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
                                                          BorderRadius.circular(
                                                            25,
                                                          ),
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
                                                                  .withOpacity(
                                                                    0.5,
                                                                  ),
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
                                  DateFormat('dd/MM/yyyy HH:mm').format(
                                    widget.desaparecido.fechaDesaparicion!,
                                  ),
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
                              if (widget.desaparecido.detallesAdicionales !=
                                  null)
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
                      gradient: LinearGradient(
                        colors: [
                          primaryColor.withOpacity(0.05),
                          Colors.blue.withOpacity(0.02),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // Header mejorado
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.help_outline,
                                color: primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '¿Tienes información?',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '¡Tu ayuda puede salvar vidas! 💙',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        // Botones reorganizados
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
                              'assets/icons/search_icon.png',
                              'Comisaría',
                              Colors.blue[700]!,
                              false,
                              _openComisariaFinder,
                            ),
                            _buildActionButton(
                              'assets/icons/llamada_icon.png',
                              'Llamar',
                              Colors.green[600]!,
                              false,
                              _callVictimContact,
                            ),
                            _buildActionButton(
                              'assets/icons/llamada_pnp_icon.png',
                              'PNP 114',
                              Colors.red[600]!,
                              false,
                              _callPNP114,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Mensaje motivacional
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.volunteer_activism,
                                color: Colors.orange[700],
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cada llamada, cada pista, cada compartir puede ser la clave para encontrarle',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
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
                                    final data =
                                        comment.data() as Map<String, dynamic>;
                                    final currentUser =
                                        FirebaseAuth.instance.currentUser;
                                    final isCurrentUser =
                                        currentUser != null &&
                                        data['phoneNumber'] ==
                                            currentUser.phoneNumber;

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: CommentBubble(
                                        text: data['text'] ?? 'No text',
                                        timestamp:
                                            data['timestamp'] as Timestamp?,
                                        phoneNumber: data['phoneNumber'] ?? '',
                                        userId: data['userId'] ?? '',
                                        isCurrentUser: currentUser != null && data['userId'] == currentUser.uid,
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
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -8),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 30,
                    offset: const Offset(0, -15),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
                border: Border(
                  top: BorderSide(
                    color: primaryColor.withOpacity(0.2),
                    width: 2,
                  ),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Indicador visual de que es flotante
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header motivacional
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor.withOpacity(0.1),
                              Colors.orange.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: primaryColor,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '¿Tienes información? ¡Compártela!',
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Campo de texto mejorado
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.grey[50]!, Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                _commentController.text.isNotEmpty
                                    ? primaryColor.withOpacity(0.5)
                                    : Colors.grey[300]!,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Icono indicativo
                            Container(
                              margin: const EdgeInsets.only(left: 16),
                              child: Icon(
                                Icons.chat_bubble_outline,
                                color: primaryColor.withOpacity(0.6),
                                size: 20,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                enabled: !_isSubmittingComment,
                                decoration: InputDecoration(
                                  hintText:
                                      _isSubmittingComment
                                          ? 'Enviando información...'
                                          : '¿Viste algo? ¿Sabes dónde está? Cuéntanos...',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  hintStyle: TextStyle(
                                    color:
                                        _isSubmittingComment
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade500,
                                    fontSize: 15,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                maxLines: null,
                                style: TextStyle(
                                  fontSize: 15,
                                  color:
                                      _isSubmittingComment
                                          ? Colors.grey.shade400
                                          : Colors.black87,
                                ),
                                onChanged: (value) {
                                  setState(() {}); // Para actualizar el borde
                                },
                              ),
                            ),
                            // Botón de envío mejorado
                            Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor,
                                    primaryColor.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon:
                                    _isSubmittingComment
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Icon(
                                          Icons.send_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                onPressed:
                                    _isSubmittingComment
                                        ? null
                                        : _submitComment,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
