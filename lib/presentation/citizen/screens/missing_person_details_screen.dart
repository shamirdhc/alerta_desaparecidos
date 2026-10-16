import 'dart:ui';
import 'package:alerta_desaparecidos/presentation/citizen/screens/full_screen_image_screen.dart';
import 'package:alerta_desaparecidos/presentation/common_widgets/comment_bubble.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../domain/entities/desaparecido.dart';
import 'package:intl/intl.dart';
import '../../../helpers/share_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Importar para StreamSubscription
import 'package:url_launcher/url_launcher.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/session_service.dart';
import '../../../services/gps_location_service.dart';
import '../../../services/gemini_comment_moderator_service.dart';
import '../../../services/spectator_mode_service.dart';
import '../../common_widgets/legal_disclaimer_dialog.dart';
import '../../../common/styles/app_colors.dart';
import '../../../services/comisaria_matcher_service.dart';

import 'comisarias_screen.dart';
import 'agenda_policial.dart';
import '../../../common/localization/app_strings.dart';
import 'package:alerta_desaparecidos/presentation/common_widgets/app_cached_image.dart';

class MissingPersonDetailsScreen extends StatefulWidget {
  final Desaparecido desaparecido;
  final bool autoOpenPista;

  const MissingPersonDetailsScreen({
    super.key,
    required this.desaparecido,
    this.autoOpenPista = false,
  });

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
  bool _hasCommentInput = false;
  final TextEditingController _commentController = TextEditingController();
  // Add a list to store comments
  List<DocumentSnapshot> _comments = [];
  StreamSubscription? _commentsSubscription; // Variable para la suscripción
  late AnimationController _inputAnimationController;
  late ScrollController _scrollController;

  // Estado de la Comisaría a Cargo resuelta dinámicamente desde el Prontuario Nacional
  ComisariaMatchResult? _comisariaInfo;
  bool _isLoadingComisaria = true;
  bool _showDetailedInfo = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
    _subscribeToComments();
    _scrollController = ScrollController();
    _resolverComisaria();

    if (widget.autoOpenPista) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showReportSightingModal();
        }
      });
    }

    // Inicializar animación para el campo de entrada
    _inputAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  Future<void> _resolverComisaria() async {
    try {
      final res = await ComisariaMatcherService.resolverComisaria(
        unidadACargo: widget.desaparecido.unidadACargo,
        departamento: widget.desaparecido.departamento,
        provincia: widget.desaparecido.provincia,
        distrito: widget.desaparecido.distrito,
        detallesAdicionales: widget.desaparecido.detallesAdicionales,
      );
      if (mounted) {
        setState(() {
          _comisariaInfo = res;
          _isLoadingComisaria = false;
        });
      }
    } catch (e) {
      debugPrint('Error resolviendo comisaría: $e');
      if (mounted) {
        setState(() => _isLoadingComisaria = false);
      }
    }
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
              maxHeight: MediaQuery.of(context).size.height * 0.78,
              minHeight: MediaQuery.of(context).size.height * 0.45,
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

                  // Tres botones principales
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
      final String? imageUrl = (widget.desaparecido.imagenFichaUrl != null &&
              widget.desaparecido.imagenFichaUrl!.isNotEmpty)
          ? widget.desaparecido.imagenFichaUrl
          : (widget.desaparecido.fotoUrl != null &&
                  widget.desaparecido.fotoUrl!.isNotEmpty
              ? widget.desaparecido.fotoUrl
              : null);

      await ShareHelper.shareWhatsApp(
        context: context,
        message: whatsappText,
        imageUrl: imageUrl,
      );
    } catch (e) {
      debugPrint('Error al compartir en WhatsApp: $e');
      _showErrorMessage('Error al compartir en WhatsApp');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Compartir optimizado para redes sociales
  Future<void> _shareSocialMedia() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final socialText = _generateSocialMediaText();
      final String? imageUrl = (widget.desaparecido.imagenFichaUrl != null &&
              widget.desaparecido.imagenFichaUrl!.isNotEmpty)
          ? widget.desaparecido.imagenFichaUrl
          : (widget.desaparecido.fotoUrl != null &&
                  widget.desaparecido.fotoUrl!.isNotEmpty
              ? widget.desaparecido.fotoUrl
              : null);
      final nombreCompleto =
          '${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}'.trim();

      await ShareHelper.shareCase(
        context: context,
        message: socialText,
        subject: 'Alerta PNP: Se busca a $nombreCompleto',
        imageUrl: imageUrl,
      );
    } catch (e) {
      debugPrint('Error al preparar para redes sociales: $e');
      _showErrorMessage('Error al preparar para redes sociales');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Modal interactivo y ágil: ¿Lo viste? Aportar pista confidencial a la PNP
  Future<void> _showReportSightingModal() async {
    final TextEditingController lugarController = TextEditingController();
    final TextEditingController detallesController = TextEditingController();
    final TextEditingController contactoController = TextEditingController();
    String momentoSeleccionado = 'Hoy';
    bool isLocating = false;
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.remove_red_eye_rounded,
                              color: Color(0xFF0F766E),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Aportar Pista Confidencial',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Tu aporte llega a los agentes PNP a cargo',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Banner de confidencialidad
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Información 100% reservada. No se expondrá tu identidad.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF15803D),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Campo 1: Dónde
                      const Text(
                        '¿Dónde lo/la viste? *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: lugarController,
                        decoration: InputDecoration(
                          hintText: 'Ej: Paradero tren Grau, parque central, etc.',
                          prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                          suffixIcon: isLocating
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.my_location_rounded, color: Color(0xFF0F766E)),
                                  tooltip: 'Usar mi ubicación GPS',
                                  onPressed: () async {
                                    setModalState(() => isLocating = true);
                                    try {
                                      final loc = await GpsLocationService.getCurrentLocation();
                                      if (loc != null) {
                                        final dept = loc.departamento.isNotEmpty ? loc.departamento : '';
                                        final prov = loc.provincia.isNotEmpty ? ', ${loc.provincia}' : '';
                                        lugarController.text = '$dept$prov (GPS: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)})';
                                      }
                                    } catch (e) {
                                      debugPrint('Error obteniendo ubicación: $e');
                                    } finally {
                                      setModalState(() => isLocating = false);
                                    }
                                  },
                                ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Campo 2: Cuándo
                      const Text(
                        '¿Cuándo fue el avistamiento? *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['Hoy', 'Ayer', 'Esta semana', 'Hace días'].map((opcion) {
                          final isSel = momentoSeleccionado == opcion;
                          return ChoiceChip(
                            label: Text(opcion),
                            selected: isSel,
                            selectedColor: const Color(0xFF0F766E),
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : const Color(0xFF334155),
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12.5,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() => momentoSeleccionado = opcion);
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Campo 3: Detalles observables
                      const Text(
                        'Detalles observados (Vestimenta, estado, etc.) *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: detallesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Ej: Llevaba casaca azul, mochila negra, caminaba en dirección al norte...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Campo 4: Teléfono (Opcional)
                      const Text(
                        'Teléfono o WhatsApp de contacto (Opcional)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: contactoController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Ej: 999888777 (Solo si deseas que la PNP te consulte)',
                          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Botón Enviar
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send_rounded, color: Colors.white),
                          label: Text(
                            isSubmitting ? 'Enviando información...' : 'Enviar Pista a la PNP',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final lugar = lugarController.text.trim();
                                  final detalles = detallesController.text.trim();
                                  final contacto = contactoController.text.trim();

                                  if (lugar.isEmpty || detalles.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Por favor completa el lugar y los detalles del avistamiento'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final user = FirebaseAuth.instance.currentUser;
                                    final currentUid = user?.uid;
                                    String remitente = 'Ciudadano Colaborador';

                                    if (currentUid != null) {
                                      try {
                                        final userDoc = await FirebaseFirestore.instance
                                            .collection('ciudadanos')
                                            .doc(currentUid)
                                            .get();
                                        if (userDoc.exists) {
                                          final d = userDoc.data();
                                          final nom = '${d?['nombres'] ?? ''} ${d?['apellidos'] ?? ''}'.trim();
                                          if (nom.isNotEmpty) remitente = nom;
                                        }
                                      } catch (_) {}
                                    }

                                    final contactoStr = contacto.isNotEmpty ? '\n• Teléfono de contacto: $contacto' : '';
                                    final pistaTexto = '📍 PISTA DE AVISTAMIENTO CIUDADANO:\n'
                                        '• Lugar: $lugar\n'
                                        '• Momento: $momentoSeleccionado\n'
                                        '• Detalles: $detalles$contactoStr';

                                    if (widget.desaparecido.id != null) {
                                      // Guardar en subcolección de comentarios del caso para el equipo PNP
                                      await FirebaseFirestore.instance
                                          .collection('desaparecidos')
                                          .doc(widget.desaparecido.id)
                                          .collection('comments')
                                          .add({
                                        'text': pistaTexto,
                                        'tipo': 'pista_avistamiento',
                                        'lugar_visto': lugar,
                                        'momento_visto': momentoSeleccionado,
                                        'detalles': detalles,
                                        'phoneNumber': contacto.isNotEmpty ? contacto : 'Reservado',
                                        'userId': currentUid ?? 'anonimo',
                                        'userName': '$remitente (Pista)',
                                        'timestamp': FieldValue.serverTimestamp(),
                                        'createdAt': DateTime.now().toIso8601String(),
                                        'estado_moderacion': 'pendiente',
                                        'unidad_a_cargo': widget.desaparecido.unidadACargo ?? 'Línea 114 PNP',
                                      });
                                    }

                                    // Guardar en colección central de pistas urgentes
                                    await FirebaseFirestore.instance.collection('pistas_urgentes').add({
                                      'desaparecidoId': widget.desaparecido.id ?? '',
                                      'nombreDesaparecido': '${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}'.trim(),
                                      'notaAlerta': widget.desaparecido.id ?? '',
                                      'lugarVisto': lugar,
                                      'momentoVisto': momentoSeleccionado,
                                      'detalles': detalles,
                                      'contacto': contacto,
                                      'fechaRegistro': FieldValue.serverTimestamp(),
                                      'estado': 'pendiente',
                                      'unidadACargo': widget.desaparecido.unidadACargo ?? 'Línea 114 PNP',
                                    });

                                    if (mounted) {
                                      Navigator.pop(bottomSheetContext);
                                      _showSuccessMessage('¡Pista enviada! La Policía Nacional agradece tu colaboración 🤝');
                                    }
                                  } catch (e) {
                                    debugPrint('Error al enviar pista: $e');
                                    if (mounted) {
                                      setModalState(() => isSubmitting = false);
                                      _showErrorMessage('No se pudo enviar la pista. Inténtalo de nuevo.');
                                    }
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
    final String telContactoInfo = (_comisariaInfo != null && _comisariaInfo!.tieneTelefonoDirecto)
        ? '${_comisariaInfo!.nombreOficial}: ${_comisariaInfo!.telefono}'
        : 'Línea Gratuita 114 PNP / Central 105';

    return '🚨 *URGENTE - PERSONA DESAPARECIDA* 🚨\n\n'
        '$sexoIcon *${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}*$edad\n\n'
        '📅 *Desaparecido desde:* ${widget.desaparecido.fechaDesaparicion != null ? DateFormat('dd/MM/yyyy').format(widget.desaparecido.fechaDesaparicion!) : 'Fecha no especificada'}\n'
        '📍 *Última ubicación conocida:*\n${_formatLocation()}\n\n'
        '${widget.desaparecido.detallesAdicionales != null && widget.desaparecido.detallesAdicionales!.isNotEmpty ? '📝 *Información importante:*\n${widget.desaparecido.detallesAdicionales}\n\n' : ''}'
        '📞 *¿Lo has visto? Contacta:*\n$telContactoInfo\n\n'
        '🚓 *Línea PNP Desaparecidos: 114 | Emergencias: 105*\n\n'
        '🌐 *Ficha oficial con foto y mapa en tiempo real:*\nhttps://pnpalerta.web.app/?id=${widget.desaparecido.id ?? ""}\n\n'
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
    final String telContactoInfo = (_comisariaInfo != null && _comisariaInfo!.tieneTelefonoDirecto)
        ? '${_comisariaInfo!.nombreOficial}: ${_comisariaInfo!.telefono}'
        : 'Línea Gratuita 114 PNP / Central 105';

    return '🚨 #URGENTE #PersonaDesaparecida #AyudaAEncontrar\n\n'
        '🔍 *BÚSQUEDA ACTIVA* 🔍\n\n'
        '$sexoIcon *${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}*$edad\n\n'
        '📅 Desaparecido/a desde: ${widget.desaparecido.fechaDesaparicion != null ? DateFormat('dd/MM/yyyy').format(widget.desaparecido.fechaDesaparicion!) : 'Fecha no especificada'}\n'
        '📍 Última ubicación: ${_formatLocation()}\n\n'
        '${widget.desaparecido.detallesAdicionales != null && widget.desaparecido.detallesAdicionales!.isNotEmpty ? '📝 Información clave: ${widget.desaparecido.detallesAdicionales}\n\n' : ''}'
        '📞 Información: $telContactoInfo\n'
        '🚓 PNP: Línea 114 / 105\n\n'
        '🌐 Ficha oficial y mapa interactivo: https://pnpalerta.web.app/?id=${widget.desaparecido.id ?? ""}\n\n'
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
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        // Solo mostrar comentarios válidos (excluir rechazados)
        final visibleDocs = snapshot.docs.where((doc) {
          final data = doc.data();
          final estado = data['estado_moderacion'];
          if (estado == 'rechazado') {
            return false;
          }
          return true;
        }).toList();

        setState(() {
          _comments = visibleDocs;
        });
      },
      onError: (error) {
        print('❌ [ERROR] Error en stream de comentarios: $error');
      },
    );
  }

  // Función para abrir el mapa interno de comisarías enfocado en la dependencia a cargo y trazar ruta
  Future<void> _openComisariaFinder() async {
    final query = _comisariaInfo?.nombreOficial ??
        _obtenerNombreComisariaTerritorialFallback();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComisariasScreen(
          initialSearchQuery: query,
          initialDepartamento: _comisariaInfo?.departamento ?? widget.desaparecido.departamento,
          initialDistrito: _comisariaInfo?.distrito ?? widget.desaparecido.distrito,
        ),
      ),
    );
  }

  // Función para abrir el Directorio Nacional de Comisarías PNP
  void _openAgendaPolicial() {
    final query = _comisariaInfo?.nombreOficial ??
        _obtenerNombreComisariaTerritorialFallback();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgendaPolicialScreen(
          initialSearchQuery: query,
          initialDepartamento: _comisariaInfo?.departamento ?? widget.desaparecido.departamento,
          initialProvincia: _comisariaInfo?.provincia ?? widget.desaparecido.provincia,
        ),
      ),
    );
  }



  // Función para llamar directamente a la Comisaría a cargo con su teléfono oficial (NUNCA familiares)
  Future<void> _callComisariaDirecto() async {
    // Si tenemos teléfono verificado de la comisaría
    if (_comisariaInfo != null && _comisariaInfo!.tieneTelefonoDirecto) {
      final uri = Uri.parse('tel:${_comisariaInfo!.telefonoLimpio}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        _showSuccessMessage('Llamando a ${_comisariaInfo!.nombreOficial}... 📞');
        return;
      }
    }

    // NUNCA llamar a números de familiares por seguridad (prevenir extorsión de malos elementos).
    // Se comunica de inmediato con la Línea Gratuita 114 PNP de Personas Desaparecidas.
    final uri114 = Uri.parse('tel:114');
    if (await canLaunchUrl(uri114)) {
      await launchUrl(uri114);
      _showSuccessMessage('Comunicando con Línea Gratuita 114 PNP... 📞');
      return;
    }

    // Modal informativo si no hay celular directo en el prontuario
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.local_police_rounded, color: Color(0xFF0F172A)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Contacto Policial Oficial',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _comisariaInfo?.nombreOficial ?? _obtenerNombreComisariaTerritorialFallback(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            const SizedBox(height: 6),
            if (_comisariaInfo != null && _comisariaInfo!.direccion.isNotEmpty) ...[
              Text(
                '📍 Dirección: ${_comisariaInfo!.direccion}',
                style: TextStyle(color: Colors.grey[700], fontSize: 12.5),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              _comisariaInfo != null && _comisariaInfo!.tieneTelefonoDirecto
                  ? '📞 Teléfono de guardia: ${_comisariaInfo!.telefono}'
                  : 'ℹ️ Esta dependencia policial rural no cuenta con celular directo registrado en el prontuario. Te recomendamos llamar de inmediato a la Línea 114 PNP o a la Central 105.',
              style: TextStyle(
                color: _comisariaInfo != null && _comisariaInfo!.tieneTelefonoDirecto ? Colors.green[800] : Colors.grey[800],
                fontSize: 12.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          if (_comisariaInfo != null && _comisariaInfo!.tieneTelefonoDirecto)
            ElevatedButton.icon(
              icon: const Icon(Icons.phone, size: 15),
              label: Text('Llamar ${_comisariaInfo!.telefono}'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('tel:${_comisariaInfo!.telefonoLimpio}'));
              },
            )
          else
            ElevatedButton.icon(
              icon: const Icon(Icons.emergency, size: 15),
              label: const Text('Llamar 114 PNP'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                _callPNP114();
              },
            ),
        ],
      ),
    );
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

  // Helper para sanitizar a solo nombres (sin apellidos) para la privacidad ciudadana
  String _sanitizeOnlyNames(String raw, [String? apellidos]) {
    String clean = raw.trim();
    if (apellidos != null && apellidos.trim().isNotEmpty) {
      clean = clean.replaceAll(RegExp(RegExp.escape(apellidos.trim()), caseSensitive: false), '').trim();
    }
    if (clean.isEmpty) return 'Ciudadano';
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'Ciudadano';

    String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + (s.length > 1 ? s.substring(1).toLowerCase() : '');

    if (parts.length == 1) {
      return cap(parts[0]);
    }

    // Detección de nombres compuestos válidos (ej: "Juan Carlos", "María José", "Ana María")
    const compoundPrefixes = {'juan', 'maria', 'maría', 'jose', 'josé', 'ana', 'luis', 'victor', 'víctor'};
    const compoundSeconds = {
      'carlos', 'jose', 'josé', 'maria', 'maría', 'luis', 'manuel', 'antonio',
      'fernando', 'david', 'eduardo', 'paula', 'sofia', 'sofía', 'elena', 'belen',
      'belén', 'inés', 'ines', 'alberto', 'miguel', 'angel', 'ángel', 'alexander',
      'guillermo', 'alonso', 'gabriel', 'pablo', 'daniel'
    };

    final firstLower = parts[0].toLowerCase();
    final secondLower = parts[1].toLowerCase();

    if (compoundPrefixes.contains(firstLower) && compoundSeconds.contains(secondLower)) {
      return '${cap(parts[0])} ${cap(parts[1])}';
    }

    // Por defecto, solo el primer nombre para asegurar 100% que no se muestre el apellido
    return cap(parts[0]);
  }

  // Method to submit a new comment to Firestore with Gemini AI Instant Moderation
  Future<void> _submitComment() async {
    if (SpectatorModeService.isSpectator) {
      SpectatorModeService.showLimitationModal(
        context,
        actionTitle: 'Enviar Pistas o Comentarios',
        description: 'Para garantizar la veracidad y seriedad de las pistas sobre personas desaparecidas, debes iniciar sesión con tu cuenta Google o llamar directamente a la Línea 114 de la PNP.',
      );
      return;
    }

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
      // 1. Verificar y asegurar autenticación
      final isAuthenticated = await SessionService.ensureUserAuthenticated();
      if (!isAuthenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Sesión expirada. Por favor, inicia sesión nuevamente.'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Ir a Login',
                textColor: Colors.white,
                onPressed: () {
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
      if (user == null) {
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

      // 2. Verificar conectividad (en móvil)
      if (!kIsWeb && !await ConnectivityService.hasInternetConnection()) {
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

      // 3. Obtener datos del usuario con timeout
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
      String phoneNumber = 'Sin número';
      if (userData?['telefono'] != null && userData!['telefono'].toString().trim().isNotEmpty) {
        phoneNumber = userData['telefono'].toString().trim();
      }
      
      // SOLAMENTE NOMBRES - NUNCA APELLIDOS (privacidad estricta)
      final rawNombres = userData?['nombres'] as String? ?? '';
      final rawApellidos = userData?['apellidos'] as String? ?? '';
      final soloNombres = _sanitizeOnlyNames(rawNombres, rawApellidos);
      
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

      // 4. 🤖 MODERACIÓN INSTANTÁNEA CON GEMINI IA
      final moderation = await GeminiCommentModeratorService.moderateComment(commentText);

      if (!moderation.aprobado) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: const [
                  Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Comentario no admitido',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    moderation.motivo,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Text(
                      'Norma Comunitaria PNP: No se permiten insultos, palabras soeces ni ofensas hacia la víctima o familias.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Entendido y corregir',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 5. Verificación de advertencia legal única (Art. 368 Código Penal)
      final acceptedLegal = await LegalDisclaimerDialog.checkAndShow(
        context,
        phoneNumber: phoneNumber,
      );
      if (!acceptedLegal || !mounted) {
        return;
      }

      // 6. Guardar comentario aprobado instantáneamente por IA
      final commentData = {
        'text': commentText,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'phoneNumber': phoneNumber,
        'userName': soloNombres, // SÓLO NOMBRES (sin apellidos)
        'nombres': soloNombres,  // SÓLO NOMBRES (sin apellidos)
        'createdAt': DateTime.now().toIso8601String(),
        'estado_moderacion': 'aprobado', // Validado en ese instante por Gemini IA
        'moderado_por': 'gemini_ia',
        'unidad_a_cargo': widget.desaparecido.unidadACargo ?? 'Línea 114 PNP',
      };

      await FirebaseFirestore.instance
          .collection('desaparecidos')
          .doc(widget.desaparecido.id)
          .collection('comments')
          .add(commentData)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Timeout al guardar comentario'),
          );

      _commentController.clear();
      _hasCommentInput = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.auto_awesome_rounded, color: Color(0xFF10B981), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Comentario verificado por IA PNP y publicado.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        // Desplazamiento automático al inicio de los comentarios (los más actuales primero)
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _scrollController.hasClients) {
            _scrollController.animateTo(
              0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } on FirebaseException catch (e) {
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

  Widget _buildImageErrorCard({
    required bool isNotaAlerta,
    required bool isDark,
    required Color primaryColor,
  }) {
    final nombre = widget.desaparecido.nombres.trim();
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'P';
    final apellidos = widget.desaparecido.apellidos.trim();

    return Container(
      height: double.infinity,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFF1E293B), const Color(0xFF334155)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isNotaAlerta
                      ? const Color(0xFFDC2626).withValues(alpha: 0.2)
                      : primaryColor.withValues(alpha: 0.2),
                  border: Border.all(
                    color: isNotaAlerta
                        ? const Color(0xFFDC2626).withValues(alpha: 0.6)
                        : primaryColor.withValues(alpha: 0.6),
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: isNotaAlerta
                      ? const Icon(
                          Icons.article_rounded,
                          size: 34,
                          color: Color(0xFFFCA5A5),
                        )
                      : Text(
                          inicial,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isNotaAlerta ? 'NOTA DE ALERTA PNP' : '$nombre $apellidos',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      size: 14,
                      color: isNotaAlerta ? const Color(0xFFF87171) : Colors.amber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isNotaAlerta
                          ? 'Ficha oficial en proceso de digitalización'
                          : 'Fotografía oficial registrada en PNP',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Registro Policial Nacional PNP',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isFound = (widget.desaparecido.estado ?? '').trim().toLowerCase() == 'encontrado';
    final MaterialColor primaryColor = isFound ? Colors.green : Colors.blue;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D1A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          isFound
              ? (strings.isQuechua ? 'Tarisqa Runa' : 'Persona Encontrada')
              : (strings.isQuechua ? 'Chinkasqa Runa' : 'Alerta de Búsqueda'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isFound
                ? const LinearGradient(
                    colors: [Color(0xFF047857), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : AppColors.policeHeroGradient,
          ),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
              ),
              onPressed: _shareDetails,
              tooltip: strings.share,
            )
          else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // 📜 Contenido Principal Compacto
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 210),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. HERO FOTOGRÁFICO COMPACTO Y NÍTIDO
                      _buildCompactPhotoHero(isFound, primaryColor, isDark),
                      const SizedBox(height: 12),

                      // 2. RESUMEN DE IDENTIDAD Y SEÑAS CLAVE
                      _buildCompactIdentityCard(isFound, primaryColor, strings),
                      const SizedBox(height: 12),

                      // 3. BARRA DE ACCIÓN RÁPIDA (APORTAR PISTA ANÓNIMA)
                      _buildCompactActionStrip(strings),
                      const SizedBox(height: 14),

                      // 4. FEED DE PISTAS Y COMENTARIOS COMUNITARIOS
                      _buildCompactCommentsSection(strings),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 💬 CAJA DE COMENTARIOS FLOTANTE EN LA PARTE INFERIOR
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildCompactBottomCommentBar(context, isDark),
          ),
        ],
      ),
    );
  }

  // ========================================================
  // 1. HERO FOTOGRÁFICO COMPACTO CON SELECTOR RÁPIDO
  // ========================================================
  Widget _buildCompactPhotoHero(
    bool isFound,
    MaterialColor primaryColor,
    bool isDark,
  ) {
    final bool hasFoto = widget.desaparecido.fotoUrl != null &&
        widget.desaparecido.fotoUrl!.trim().isNotEmpty;
    final bool hasFicha = widget.desaparecido.imagenFichaUrl != null &&
        widget.desaparecido.imagenFichaUrl!.trim().isNotEmpty &&
        widget.desaparecido.imagenFichaUrl != widget.desaparecido.fotoUrl;

    if (!hasFoto && !hasFicha) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 48, color: Colors.white60),
            SizedBox(height: 8),
            Text(
              'Fotografía en procesamiento oficial PNP',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    final int slideCount = (hasFoto && hasFicha) ? 2 : (!hasFoto && hasFicha ? 2 : 1);

    return Container(
      height: 275,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // PageView de Imágenes (Rostro vs Nota de Alerta)
            PageView.builder(
              controller: _pageController,
              itemCount: slideCount,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                if (hasFoto && hasFicha) {
                  if (index == 0) {
                    return _buildPhotoHeroSlide(widget.desaparecido.fotoUrl!, isDark, primaryColor);
                  } else {
                    return _buildFichaHeroSlide(widget.desaparecido.imagenFichaUrl!, isDark, primaryColor);
                  }
                }
                if (hasFoto && !hasFicha) {
                  return _buildPhotoHeroSlide(widget.desaparecido.fotoUrl!, isDark, primaryColor);
                }
                // !hasFoto && hasFicha
                if (index == 0) {
                  return _buildNoPhotoAvailableSlide(isDark);
                } else {
                  return _buildFichaHeroSlide(widget.desaparecido.imagenFichaUrl!, isDark, primaryColor);
                }
              },
            ),

            // Badge Flotante Superior Izquierdo: Estado
            Positioned(
              top: 10,
              left: 10,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isFound ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isFound ? Icons.check_circle : Icons.warning_rounded, color: Colors.white, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          isFound ? 'ENCONTRADO' : 'DESAPARECIDO',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.desaparecido.fechaDesaparicion != null &&
                      DateTime.now().difference(widget.desaparecido.fechaDesaparicion!).inHours >= 0 &&
                      DateTime.now().difference(widget.desaparecido.fechaDesaparicion!).inHours < 72 &&
                      !isFound) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_rounded, color: Colors.black, size: 12),
                          SizedBox(width: 3),
                          Text(
                            '< 72H CRÍTICO',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Botón Flotante Superior Derecho: Pantalla Completa
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () {
                  String? targetImg;
                  if (hasFoto && hasFicha) {
                    targetImg = _currentPage == 0 ? widget.desaparecido.fotoUrl : widget.desaparecido.imagenFichaUrl;
                  } else if (hasFoto) {
                    targetImg = widget.desaparecido.fotoUrl;
                  } else if (hasFicha) {
                    targetImg = widget.desaparecido.imagenFichaUrl;
                  }
                  if (targetImg != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullScreenImageScreen(
                          imageUrl: targetImg!,
                          fallbackImageUrl: widget.desaparecido.imagenFichaUrl,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                  ),
                  child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),

            // Selector Rápido Inferior (Foto vs Nota Oficial PNP)
            if (slideCount > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildImagePillTab(
                          index: 0,
                          icon: hasFoto ? Icons.face_rounded : Icons.person_off_rounded,
                          label: hasFoto ? 'Fotografía' : 'Sin Foto Adjunta',
                          isSelected: _currentPage == 0,
                        ),
                        const SizedBox(width: 4),
                        _buildImagePillTab(
                          index: 1,
                          icon: Icons.assignment_rounded,
                          label: 'Nota Oficial PNP',
                          isSelected: _currentPage == 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoHeroSlide(String photoUrl, bool isDark, MaterialColor primaryColor) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImageScreen(
              imageUrl: photoUrl,
              fallbackImageUrl: widget.desaparecido.imagenFichaUrl,
            ),
          ),
        );
      },
      child: Container(
        color: const Color(0xFF0F172A),
        child: AppCachedImage(
          imageUrl: photoUrl,
          fit: BoxFit.cover,
          memCacheWidth: 700,
          memCacheHeight: 900,
          errorWidget: _buildImageErrorCard(
            isNotaAlerta: false,
            isDark: isDark,
            primaryColor: primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildFichaHeroSlide(String fichaUrl, bool isDark, MaterialColor primaryColor) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImageScreen(
              imageUrl: fichaUrl,
              fallbackImageUrl: widget.desaparecido.fotoUrl,
            ),
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.white,
            child: AppCachedImage(
              imageUrl: fichaUrl,
              fit: BoxFit.contain,
              memCacheWidth: 900,
              memCacheHeight: 1200,
              errorWidget: _buildImageErrorCard(
                isNotaAlerta: true,
                isDark: isDark,
                primaryColor: primaryColor,
              ),
            ),
          ),
          Positioned(
            top: 50,
            left: 12,
            right: 12,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_rounded, color: Color(0xFF38BDF8), size: 13),
                    SizedBox(width: 4),
                    Text(
                      'AFICHE OFICIAL DE NOTA DE ALERTA PNP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPhotoAvailableSlide(bool isDark) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.no_accounts_rounded,
              size: 44,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Fotografía no provista en la denuncia',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'La PNP registró la denuncia policial con datos filiatorios pero sin foto de rostro.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              _pageController.animateToPage(
                1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            icon: const Icon(Icons.assignment_turned_in_rounded, size: 14, color: Colors.white),
            label: const Text(
              'Ver Nota de Alerta Oficial PNP',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePillTab({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? Colors.white : Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================
  // 2. RESUMEN COMPACTO DE IDENTIDAD Y SEÑAS
  // ========================================================
  Widget _buildCompactIdentityCard(
    bool isFound,
    MaterialColor primaryColor,
    AppStrings strings,
  ) {
    final String nombreCompleto =
        '${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}'.trim();
    final String ubicacion = [
      if (widget.desaparecido.distrito != null && widget.desaparecido.distrito!.trim().isNotEmpty)
        widget.desaparecido.distrito!.trim(),
      if (widget.desaparecido.provincia != null && widget.desaparecido.provincia!.trim().isNotEmpty)
        widget.desaparecido.provincia!.trim(),
    ].join(', ');

    final String fechaStr = widget.desaparecido.fechaDesaparicion != null
        ? DateFormat('dd/MM/yyyy').format(widget.desaparecido.fechaDesaparicion!)
        : '';

    final String senas = widget.desaparecido.detallesAdicionales?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre y Edad
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  nombreCompleto,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (widget.desaparecido.edadCalculada != null && widget.desaparecido.edadCalculada! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    '${widget.desaparecido.edadCalculada} años',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Pills Rápidas (Ubicación, Fecha, Comisaría)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (ubicacion.isNotEmpty)
                _buildCompactPill(Icons.location_on_rounded, ubicacion, const Color(0xFF0284C7)),
              if (fechaStr.isNotEmpty)
                _buildCompactPill(Icons.calendar_today_rounded, 'Desap: $fechaStr', const Color(0xFF64748B)),
              _buildCompactPill(
                Icons.local_police_rounded,
                _comisariaInfo?.nombreOficial ?? _obtenerNombreComisariaTerritorialFallback(),
                const Color(0xFF0F766E),
              ),
            ],
          ),

          // Señas Particulares y Vestimenta (Resaltadas y Compactas)
          if (senas.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.accessibility_new_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SEÑAS / VESTIMENTA: $senas',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Acordeón Plegable de Datos Policiales Oficiales
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _showDetailedInfo = !_showDetailedInfo),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _showDetailedInfo ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showDetailedInfo
                        ? 'Ocultar datos técnicos policiales'
                        : '📋 Ver datos de comisaría y contacto policial',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showDetailedInfo) ...[
            const SizedBox(height: 6),
            _buildComisariaCard(primaryColor),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================
  // 3. BARRA DE ACCIÓN RÁPIDA (APORTE DE PISTAS + BOTONES)
  // ========================================================
  Widget _buildCompactActionStrip(AppStrings strings) {
    return Row(
      children: [
        // Botón Principal Destacado: Aportar Pista Confidencial
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showReportSightingModal,
            icon: const Icon(Icons.remove_red_eye_rounded, size: 18, color: Colors.white),
            label: const Text(
              'APORTAR PISTA ANÓNIMA',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Botón Rápido: Compartir en WhatsApp/Redes
        _buildCircleActionButton(
          icon: Icons.share_rounded,
          color: const Color(0xFF0284C7),
          tooltip: 'Compartir',
          onTap: _shareDetails,
        ),
        const SizedBox(width: 6),

        // Botón Rápido: Llamar a la Comisaría a cargo
        _buildCircleActionButton(
          icon: Icons.phone_in_talk_rounded,
          color: const Color(0xFF059669),
          tooltip: 'Llamar a la Comisaría',
          onTap: _callComisariaDirecto,
        ),
        const SizedBox(width: 6),

        // Botón Rápido: Ver Mapa de Comisarías
        _buildCircleActionButton(
          icon: Icons.map_rounded,
          color: const Color(0xFF6366F1),
          tooltip: 'Ver en Mapa',
          onTap: _openComisariaFinder,
        ),
      ],
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.3), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  // ========================================================
  // 4. FEED DE PISTAS Y COMENTARIOS COMUNITARIOS
  // ========================================================
  Widget _buildCompactCommentsSection(AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la Sección
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.forum_rounded, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pistas y Colaboración (${_comments.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'Escribe pistas sobre su paradero o mensajes de aliento',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF6EE7B7)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 12, color: Color(0xFF059669)),
                    SizedBox(width: 2),
                    Text(
                      'En vivo',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Lista de Comentarios o Empty State
          if (_comments.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.volunteer_activism_rounded, color: Color(0xFF64748B), size: 28),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '¡Sé el primero en aportar una pista!',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Si viste a esta persona o tienes datos sobre su vestimenta, escribe abajo. Tu pista es confidencial y segura.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
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
                final currentUser = FirebaseAuth.instance.currentUser;
                final comment = _comments[index];
                final data = comment.data() as Map<String, dynamic>;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CommentBubble(
                    text: data['text'] ?? '',
                    timestamp: data['timestamp'] as Timestamp?,
                    phoneNumber: data['phoneNumber'] ?? '',
                    userId: data['userId'] ?? '',
                    isCurrentUser: currentUser != null && data['userId'] == currentUser.uid,
                    userName: data['userName'] as String?,
                    estadoModeracion: data['estado_moderacion'] as String?,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ========================================================
  // 5. CAJA DE COMENTARIOS FLOTANTE FIJA
  // ========================================================
  Widget _buildCompactBottomCommentBar(BuildContext context, bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A).withOpacity(0.94) : Colors.white.withOpacity(0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (SpectatorModeService.isSpectator)
                      _buildSpectatorCommentBanner(context)
                    else ...[
                      // Chips de Respuesta Rápida
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildQuickChip('📍 Lo vi por...', 'Lo vi por '),
                            _buildQuickChip('🕒 Aprox a las...', 'Aprox a las '),
                            _buildQuickChip('👕 Iba vestido con...', 'Iba vestido con '),
                            _buildQuickChip('🚗 Con quién / vehículo...', 'Iba con / vehículo '),
                            _buildQuickChip('💙 Ánimo a la familia', 'Mucha fuerza y oraciones a la familia. '),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Campo de Texto Compacto y Nítido
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _hasCommentInput
                                ? const Color(0xFF0284C7)
                                : (isDark ? Colors.white.withOpacity(0.15) : const Color(0xFFCBD5E1)),
                            width: _hasCommentInput ? 1.8 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _hasCommentInput
                                  ? const Color(0xFF0284C7).withOpacity(0.12)
                                  : Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 12, bottom: 11),
                              child: Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: _hasCommentInput
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF94A3B8),
                                size: 19,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                enabled: !_isSubmittingComment,
                                cursorColor: const Color(0xFF0284C7),
                                keyboardType: TextInputType.multiline,
                                minLines: 1,
                                maxLines: 3,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText: _isSubmittingComment
                                      ? 'Revisando con IA y enviando...'
                                      : 'Escribe tu pista o mensaje colaborativo...',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 11,
                                  ),
                                ),
                                onChanged: (value) {
                                  final has = value.trim().isNotEmpty;
                                  if (has != _hasCommentInput) {
                                    setState(() => _hasCommentInput = has);
                                  }
                                },
                              ),
                            ),
                            // Botón de Envío
                            Padding(
                              padding: const EdgeInsets.all(5),
                              child: InkWell(
                                onTap: (_isSubmittingComment || !_hasCommentInput)
                                    ? null
                                    : _submitComment,
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    gradient: _hasCommentInput
                                        ? const LinearGradient(
                                            colors: [Color(0xFF0284C7), Color(0xFF2563EB)],
                                          )
                                        : null,
                                    color: _hasCommentInput ? null : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: _isSubmittingComment
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Icon(
                                            Icons.send_rounded,
                                            color: _hasCommentInput ? Colors.white : const Color(0xFF94A3B8),
                                            size: 18,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Pill de Moderación y Privacidad
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, color: Color(0xFF16A34A), size: 10),
                                SizedBox(width: 3),
                                Text(
                                  'IA PNP Activa',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF15803D),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Tu privacidad: solo tu primer nombre es público',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget helper para chips interactivos de colaboración rápida
  Widget _buildQuickChip(String label, String insertText) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (_commentController.text.trim().isEmpty) {
              _commentController.text = insertText;
            } else {
              _commentController.text = '${_commentController.text.trim()} $insertText';
            }
            _commentController.selection = TextSelection.fromPosition(
              TextPosition(offset: _commentController.text.length),
            );
            setState(() {
              _hasCommentInput = _commentController.text.trim().isNotEmpty;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget para invitar a iniciar sesión o llamar a Línea 114 cuando está en Modo Espectador
  Widget _buildSpectatorCommentBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.visibility_rounded,
                  color: Color(0xFF38BDF8),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Tienes pistas o información de este caso?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Estás en Modo Espectador. Inicia sesión para publicar pistas o llama gratis a la PNP.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => SpectatorModeService.promptLogin(context),
                  icon: const Icon(Icons.login_rounded, size: 16, color: Colors.white),
                  label: const Text(
                    'Acceder con Google',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse('tel:114');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                icon: const Icon(Icons.phone_in_talk_rounded, size: 16, color: Color(0xFF10B981)),
                label: const Text(
                  'Línea 114',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  String _obtenerNombreComisariaTerritorialFallback() {
    final dist = widget.desaparecido.distrito;
    final prov = widget.desaparecido.provincia;
    final String distFallback = (dist != null && dist.trim().isNotEmpty)
        ? 'COMISARÍA PNP ${dist.trim().toUpperCase()}'
        : ((prov != null && prov.trim().isNotEmpty)
            ? 'COMISARÍA PNP ${prov.trim().toUpperCase()}'
            : 'Comisaría PNP de la Jurisdicción');

    final String rawUnidad = widget.desaparecido.unidadACargo ?? '';
    final String uUp = rawUnidad.toUpperCase();
    final bool esInvalida = rawUnidad.trim().isEmpty ||
        uUp.contains('POLICÍA NACIONAL') ||
        uUp.contains('POLICIA NACIONAL') ||
        uUp.contains('DIVOPUS') ||
        uUp.contains('DIVPOL') ||
        uUp.contains('DIRITPTIM') ||
        uUp.contains('DIVINTRAP') ||
        uUp.contains('DIRCTPTIM') ||
        uUp.contains('DEPINCRI') ||
        uUp.contains('DIVINCRI') ||
        uUp.contains('SECINCRI') ||
        uUp.contains('DIVBUS') ||
        uUp.contains('DIRINCRI') ||
        uUp.contains('FAMILIA') ||
        uUp.contains('TRANSITO') ||
        uUp.contains('TRÁNSITO') ||
        uUp.contains('VIAL') ||
        uUp.contains('EMERGENCIA') ||
        uUp.contains('OPERACIONES') ||
        (uUp.contains('ROBO') && !uUp.contains('ALGARROBOS'));

    return esInvalida ? distFallback : rawUnidad;
  }

  // 🏛️ Tarjeta institucional de la Comisaría a Cargo resuelta dinámicamente
  Widget _buildComisariaCard(Color primaryColor) {
    final strings = AppStrings.of(context);
    final String nombreComisaria = _comisariaInfo?.nombreOficial ??
        _obtenerNombreComisariaTerritorialFallback();

    final bool tieneTel = _comisariaInfo != null && _comisariaInfo!.tieneTelefonoDirecto;
    final String telefonoMostrar = tieneTel
        ? _comisariaInfo!.telefono
        : 'Línea 114 PNP / Central 105';

    final String? direccion = (_comisariaInfo != null && _comisariaInfo!.direccion.trim().isNotEmpty)
        ? _comisariaInfo!.direccion
        : null;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header institucional
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_police_rounded,
                  color: Color(0xFF38BDF8),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.isQuechua ? 'POLISIYA WASI KAMACHIQ' : 'DEPENDENCIA POLICIAL A CARGO',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                if (_isLoadingComisaria)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                else if (tieneTel)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 11, color: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          'Directorio PNP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombreComisaria,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                // Teléfono
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: tieneTel ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.phone_rounded,
                        size: 16,
                        color: tieneTel ? const Color(0xFF059669) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.isQuechua
                                ? 'Kamachiqpa Tupanan'
                                : (tieneTel ? 'Teléfono Directo de Guardia' : 'Contacto de Emergencia'),
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            telefonoMostrar,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: tieneTel ? const Color(0xFF047857) : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Dirección si está disponible
                if (direccion != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.isQuechua ? 'Tiyanan Maymi Kasqan' : 'Dirección Física',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              direccion,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                // Acciones rápidas de la comisaría
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 14, color: Colors.white),
                        label: Text(
                          strings.isQuechua
                              ? (tieneTel ? 'CPNP-man qayay' : '114 PNP-man qayay')
                              : (tieneTel ? 'Llamar a CPNP' : 'Llamar 114 PNP'),
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tieneTel ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 1,
                        ),
                        onPressed: _callComisariaDirecto,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.menu_book_rounded, size: 14, color: Color(0xFF2563EB)),
                        label: Text(
                          strings.isQuechua ? 'Willakuyninpi qhaway' : 'Ver en Directorio',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _openAgendaPolicial,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
