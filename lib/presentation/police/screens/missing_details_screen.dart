import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:intl/intl.dart';

import 'package:provider/provider.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../domain/entities/desaparecido.dart';

import '../view_models/missing_details_view_model.dart';

import '../../../injection.dart' as di;

import '../../../common/state_enum.dart';

import 'dart:async';

import '../../citizen/screens/full_screen_image_screen.dart';
import '../widgets/mark_as_found_dialog.dart';
import '../../../services/comisaria_matcher_service.dart';
import '../../../helpers/share_helper.dart';
import '../../common_widgets/theme_sun_moon_toggle.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class MissingDetailsScreen extends StatefulWidget {
  final Desaparecido desaparecido;

  const MissingDetailsScreen({super.key, required this.desaparecido});

  @override
  State<MissingDetailsScreen> createState() => _MissingDetailsScreenState();
}

class _MissingDetailsScreenState extends State<MissingDetailsScreen>
    with TickerProviderStateMixin {
  List<DocumentSnapshot> _comments = [];

  StreamSubscription? _commentsSubscription;

  late ScrollController _scrollController;

  bool _isLoadingComments = true;

  bool _isVettingUser = false;

  // Variables para el carrusel de imágenes

  late PageController _pageController;

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();

    _pageController = PageController(initialPage: _currentPage);

    _subscribeToComments();
    _resolverComisaria();
  }

  ComisariaMatchResult? _comisariaInfo;

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
        setState(() => _comisariaInfo = res);
      }
    } catch (e) {
      debugPrint('Error resolviendo comisaría: $e');
    }
  }

  @override
  void dispose() {
    _commentsSubscription?.cancel();

    _scrollController.dispose();

    _pageController.dispose();

    super.dispose();
  }

  // Suscribirse a los comentarios

  void _subscribeToComments() {
    if (widget.desaparecido.id == null) {
      print('❌ [ERROR] ID de persona desaparecida es nulo');

      setState(() {
        _isLoadingComments = false;
      });

      return;
    }

    _commentsSubscription = FirebaseFirestore.instance
        .collection('desaparecidos')
        .doc(widget.desaparecido.id)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen(
          (snapshot) {
            setState(() {
              _comments = snapshot.docs;

              _isLoadingComments = false;
            });
          },

          onError: (error) {
            print('❌ [ERROR] Error al cargar comentarios: $error');

            setState(() {
              _isLoadingComments = false;
            });
          },
        );
  }

  // Mostrar detalles del usuario que comentó

  Future<void> _showUserDetails(String userId) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('ciudadanos')
              .doc(userId)
              .get();

      if (!mounted) return;

      if (!userDoc.exists) {
        _showErrorMessage('Usuario no encontrado');

        return;
      }

      final userData = userDoc.data()!;

      final nombres = userData['nombres'] ?? 'Sin nombre';

      final apellidos = userData['apellidos'] ?? 'Sin apellido';

      final telefono = userData['telefono'] ?? 'Sin teléfono';

      final email = userData['email'] ?? 'Sin email';

      final departamento = userData['departamento'] ?? 'Sin departamento';

      final provincia = userData['provincia'] ?? 'Sin provincia';

      final distrito = userData['distrito'] ?? 'Sin distrito';

      final fechaRegistro = userData['fechaRegistro'] as Timestamp?;

      final vetado = userData['vetado'] ?? false;

      showDialog(
        context: context,

        builder:
            (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),

              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),

                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),

                  gradient: LinearGradient(
                    colors: [const Color(0xFF667eea), const Color(0xFF764ba2)],

                    begin: Alignment.topLeft,

                    end: Alignment.bottomRight,
                  ),
                ),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),

                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),

                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),

                              shape: BoxShape.circle,
                            ),

                            child: Icon(
                              Icons.person,

                              size: 40,

                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            'Detalles del Usuario',

                            style: TextStyle(
                              fontSize: 22,

                              fontWeight: FontWeight.bold,

                              color: Colors.white,
                            ),
                          ),

                          if (vetado)
                            Container(
                              margin: const EdgeInsets.only(top: 8),

                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,

                                vertical: 4,
                              ),

                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.8),

                                borderRadius: BorderRadius.circular(12),
                              ),

                              child: Text(
                                'USUARIO VETADO',

                                style: TextStyle(
                                  color: Colors.white,

                                  fontWeight: FontWeight.bold,

                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Contenido
                    Container(
                      margin: const EdgeInsets.all(20),

                      padding: const EdgeInsets.all(20),

                      decoration: BoxDecoration(
                        color: Colors.white,

                        borderRadius: BorderRadius.circular(16),
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          _buildInfoRowOriginal(
                            Icons.person,

                            'Nombre Completo',

                            '$nombres $apellidos',
                          ),

                          _buildInfoRowOriginal(
                            Icons.phone,

                            'Teléfono',

                            telefono,
                          ),

                          _buildInfoRowOriginal(Icons.email, 'Email', email),

                          _buildInfoRowOriginal(
                            Icons.location_on,

                            'Ubicación',

                            '$distrito, $provincia, $departamento',
                          ),

                          if (fechaRegistro != null)
                            _buildInfoRowOriginal(
                              Icons.calendar_today,

                              'Fecha de Registro',

                              DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(fechaRegistro.toDate()),
                            ),

                          _buildUserDetailRow(
                            Icons.security,

                            'Estado',

                            vetado ? 'Vetado' : 'Activo',

                            valueColor: vetado ? Colors.red : Colors.green,
                          ),
                        ],
                      ),
                    ),

                    // Botones de acción
                    Container(
                      padding: const EdgeInsets.all(20),

                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),

                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),

                                foregroundColor: Colors.white,

                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),

                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),

                              child: Text('Cerrar'),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);

                                _toggleUserVetStatus(userId, !vetado);
                              },

                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    vetado ? Colors.green : Colors.red,

                                foregroundColor: Colors.white,

                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),

                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),

                              child: Text(vetado ? 'Desvetar' : 'Vetar'),
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
    } catch (e) {
      print('❌ [ERROR] Error al obtener detalles del usuario: $e');

      _showErrorMessage('Error al cargar detalles del usuario');
    }
  }

  // Widget helper para mostrar detalles del usuario

  Widget _buildUserDetailRow(
    IconData icon,

    String label,

    String value, {

    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            padding: const EdgeInsets.all(6),

            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),

              borderRadius: BorderRadius.circular(8),
            ),

            child: Icon(icon, size: 16, color: const Color(0xFF667eea)),
          ),

          const SizedBox(width: 12),

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

                const SizedBox(height: 2),

                Text(
                  value,

                  style: TextStyle(
                    fontSize: 14,

                    fontWeight: FontWeight.w600,

                    color: valueColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Cambiar estado de vetado del usuario

  Future<void> _toggleUserVetStatus(String userId, bool newVetStatus) async {
    if (_isVettingUser) return;

    // Si se va a vetar al usuario, mostrar diálogo de confirmación

    if (newVetStatus) {
      final confirmed = await _showVetConfirmationDialog(userId);

      if (!confirmed) return;
    }

    setState(() {
      _isVettingUser = true;
    });

    try {
      if (newVetStatus) {
        // Vetar usuario: eliminar comentarios, recomendaciones y marcar como vetado

        await _vetUserCompletely(userId);
      } else {
        // Solo cambiar el estado de vetado

        await FirebaseFirestore.instance
            .collection('ciudadanos')
            .doc(userId)
            .update({'vetado': false});
      }

      _showSuccessMessage(
        newVetStatus
            ? 'Usuario vetado exitosamente. Se han eliminado todos sus comentarios y recomendaciones.'
            : 'Usuario desvetado exitosamente',
      );
    } catch (e) {
      print('❌ [ERROR] Error al cambiar estado de vetado: $e');

      _showErrorMessage('Error al actualizar estado del usuario');
    } finally {
      if (mounted) {
        setState(() {
          _isVettingUser = false;
        });
      }
    }
  }

  // Mostrar diálogo de confirmación para vetar usuario

  Future<bool> _showVetConfirmationDialog(String userId) async {
    // Obtener información del usuario

    final userDoc =
        await FirebaseFirestore.instance
            .collection('ciudadanos')
            .doc(userId)
            .get();

    if (!mounted) return false;

    String userName = 'Usuario';

    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;

      final nombres = userData['nombres'] ?? '';

      final apellidos = userData['apellidos'] ?? '';

      userName = '$nombres $apellidos'.trim();

      if (userName.isEmpty) userName = 'Usuario';
    }

    if (!mounted) return false;

    return await showDialog<bool>(
          context: context,

          barrierDismissible: false,

          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),

              elevation: 0,

              backgroundColor: Colors.transparent,

              child: Container(
                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,

                    end: Alignment.bottomRight,

                    colors: [Colors.red.shade50, Colors.orange.shade50],
                  ),

                  borderRadius: BorderRadius.circular(20),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),

                      blurRadius: 20,

                      offset: const Offset(0, 10),
                    ),
                  ],
                ),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    // Icono de advertencia
                    Container(
                      padding: const EdgeInsets.all(16),

                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),

                        shape: BoxShape.circle,
                      ),

                      child: Icon(
                        Icons.warning_rounded,

                        size: 48,

                        color: Colors.red.shade600,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Título
                    Text(
                      '⚠️ ACCIÓN CRÍTICA',

                      style: TextStyle(
                        fontSize: 20,

                        fontWeight: FontWeight.bold,

                        color: Colors.red.shade700,
                      ),

                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Mensaje principal
                    Container(
                      padding: const EdgeInsets.all(16),

                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),

                        borderRadius: BorderRadius.circular(12),

                        border: Border.all(
                          color: Colors.red.withOpacity(0.3),

                          width: 1,
                        ),
                      ),

                      child: Column(
                        children: [
                          Text(
                            'Está a punto de VETAR al usuario:',

                            style: TextStyle(
                              fontSize: 16,

                              color: Colors.grey.shade700,
                            ),

                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 8),

                          Text(
                            userName,

                            style: TextStyle(
                              fontSize: 18,

                              fontWeight: FontWeight.bold,

                              color: Colors.red.shade700,
                            ),

                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Consecuencias
                    Container(
                      padding: const EdgeInsets.all(16),

                      decoration: BoxDecoration(
                        color: Colors.red.shade50,

                        borderRadius: BorderRadius.circular(12),

                        border: Border.all(
                          color: Colors.red.withOpacity(0.2),

                          width: 1,
                        ),
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            'Esta acción realizará lo siguiente:',

                            style: TextStyle(
                              fontSize: 14,

                              fontWeight: FontWeight.bold,

                              color: Colors.red.shade700,
                            ),
                          ),

                          const SizedBox(height: 12),

                          _buildConsequenceItem(
                            '🚫',

                            'Bloqueará permanentemente el acceso del usuario al aplicativo móvil',
                          ),

                          _buildConsequenceItem(
                            '💬',

                            'Eliminará TODOS los comentarios realizados por este usuario',
                          ),

                          _buildConsequenceItem(
                            '📝',

                            'Eliminará TODAS las recomendaciones enviadas por este usuario',
                          ),

                          _buildConsequenceItem(
                            '⚠️',

                            'Esta acción es IRREVERSIBLE y no se puede deshacer',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(false),

                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade300,

                              foregroundColor: Colors.grey.shade700,

                              padding: const EdgeInsets.symmetric(vertical: 16),

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),

                              elevation: 0,
                            ),

                            child: const Text(
                              'Cancelar',

                              style: TextStyle(
                                fontSize: 16,

                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),

                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,

                              foregroundColor: Colors.white,

                              padding: const EdgeInsets.symmetric(vertical: 16),

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),

                              elevation: 2,
                            ),

                            child: const Text(
                              'VETAR USUARIO',

                              style: TextStyle(
                                fontSize: 16,

                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;
  }

  // Widget helper para mostrar consecuencias

  Widget _buildConsequenceItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              text,

              style: TextStyle(
                fontSize: 13,

                color: Colors.red.shade600,

                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Método para eliminar un comentario específico

  Future<void> _deleteComment(String commentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('desaparecidos')
          .doc(widget.desaparecido.id)
          .collection('comments')
          .doc(commentId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Comentario eliminado exitosamente'),

            backgroundColor: Colors.green,

            behavior: SnackBarBehavior.floating,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error al eliminar comentario: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar comentario: $e'),

            backgroundColor: Colors.red,

            behavior: SnackBarBehavior.floating,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  // Diálogo de confirmación para eliminar comentario

  Future<void> _showDeleteCommentDialog(String commentId) async {
    return showDialog<void>(
      context: context,

      barrierDismissible: false,

      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          elevation: 16,

          child: Container(
            padding: const EdgeInsets.all(24),

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),

              gradient: LinearGradient(
                begin: Alignment.topLeft,

                end: Alignment.bottomRight,

                colors: [Colors.red.shade50, Colors.orange.shade50],
              ),
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                // Icono de advertencia
                Container(
                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: Colors.red.shade100,

                    shape: BoxShape.circle,
                  ),

                  child: Icon(
                    Icons.delete_forever_rounded,

                    color: Colors.red.shade600,

                    size: 32,
                  ),
                ),

                const SizedBox(height: 20),

                // Título
                Text(
                  'Eliminar Comentario',

                  style: TextStyle(
                    fontSize: 22,

                    fontWeight: FontWeight.bold,

                    color: Colors.red.shade700,
                  ),
                ),

                const SizedBox(height: 12),

                // Mensaje de advertencia
                Container(
                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),

                    borderRadius: BorderRadius.circular(12),

                    border: Border.all(
                      color: Colors.red.withOpacity(0.2),

                      width: 1,
                    ),
                  ),

                  child: Column(
                    children: [
                      Text(
                        '⚠️ Esta acción es irreversible',

                        style: TextStyle(
                          fontSize: 16,

                          fontWeight: FontWeight.w600,

                          color: Colors.red.shade700,
                        ),

                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'El comentario seleccionado será eliminado permanentemente de Firebase y no podrá ser recuperado.',

                        style: TextStyle(
                          fontSize: 14,

                          color: Colors.grey.shade700,

                          height: 1.4,
                        ),

                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Botones de acción
                Row(
                  children: [
                    // Botón Cancelar
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),

                          border: Border.all(
                            color: Colors.grey.shade300,

                            width: 1,
                          ),
                        ),

                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),

                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),

                          child: Text(
                            'Cancelar',

                            style: TextStyle(
                              color: Colors.grey.shade600,

                              fontWeight: FontWeight.w600,

                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Botón Eliminar
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),

                          gradient: LinearGradient(
                            colors: [Colors.red.shade600, Colors.red.shade700],
                          ),

                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),

                              blurRadius: 8,

                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),

                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();

                            _deleteComment(commentId);
                          },

                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),

                          child: const Text(
                            'Eliminar',

                            style: TextStyle(
                              color: Colors.white,

                              fontWeight: FontWeight.bold,

                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Vetar usuario completamente (eliminar comentarios, recomendaciones y marcar como vetado)

  Future<void> _vetUserCompletely(String userId) async {
    final batch = FirebaseFirestore.instance.batch();

    try {
      // 1. Marcar usuario como vetado

      final userRef = FirebaseFirestore.instance
          .collection('ciudadanos')
          .doc(userId);

      batch.update(userRef, {'vetado': true});

      // 2. Eliminar todos los comentarios del usuario en todos los casos de desaparecidos

      final commentsQuery =
          await FirebaseFirestore.instance
              .collectionGroup('comments')
              .where('userId', isEqualTo: userId)
              .get();

      for (final doc in commentsQuery.docs) {
        batch.delete(doc.reference);
      }

      // 3. Eliminar todas las recomendaciones del usuario

      final recommendationsQuery =
          await FirebaseFirestore.instance
              .collection('recomendaciones')
              .where('userId', isEqualTo: userId)
              .get();

      for (final doc in recommendationsQuery.docs) {
        batch.delete(doc.reference);
      }

      // 4. Eliminar reportes de desaparecidos creados por el usuario (opcional)

      final reportsQuery =
          await FirebaseFirestore.instance
              .collection('desaparecidos')
              .where('reportadoPor', isEqualTo: userId)
              .get();

      for (final doc in reportsQuery.docs) {
        // En lugar de eliminar, podemos marcar como "reportado por usuario vetado"

        batch.update(doc.reference, {
          'reportadoPorVetado': true,

          'observacionesPolicia':
              'Usuario reportante fue vetado por comportamiento inapropiado',
        });
      }

      // Ejecutar todas las operaciones

      await batch.commit();

      print('✅ [SUCCESS] Usuario $userId vetado completamente');
    } catch (e) {
      print('❌ [ERROR] Error al vetar usuario completamente: $e');

      rethrow;
    }
  }

  // Mostrar mensaje de éxito

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),

            const SizedBox(width: 8),

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

  // Mostrar mensaje de error

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),

            const SizedBox(width: 8),

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

  // Función para realizar llamada

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);

      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        _showErrorMessage('No se puede realizar la llamada');
      }
    } catch (e) {
      _showErrorMessage('Error al intentar llamar');
    }
  }

  // Widget para mostrar un comentario de policía (reestructurado según especificaciones)

  Widget _buildPoliceCommentBubble(DocumentSnapshot comment) {
    final data = comment.data() as Map<String, dynamic>;

    final text = data['text'] ?? '';

    final timestamp = data['timestamp'] as Timestamp?;

    final userId = data['userId'] ?? '';

    final phoneNumber = data['phoneNumber'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(12),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),

            blurRadius: 8,

            offset: const Offset(0, 2),
          ),
        ],

        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
      ),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // Contenido principal (expandido para usar más espacio)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  mainAxisSize: MainAxisSize.min,

                  children: [
                    // Información del usuario con color
                    Container(
                      width: double.infinity,

                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),

                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],

                          begin: Alignment.centerLeft,

                          end: Alignment.centerRight,
                        ),

                        borderRadius: BorderRadius.circular(8),
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        mainAxisSize: MainAxisSize.min,

                        children: [
                          // Nombre y primer apellido obtenido desde Firestore
                          FutureBuilder<String>(
                            future: _getUserDisplayName(userId),

                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data ?? 'Cargando...',

                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,

                                  fontSize: 16,

                                  color: Colors.white,
                                ),

                                overflow: TextOverflow.ellipsis,

                                maxLines: 1,
                              );
                            },
                          ),

                          const SizedBox(height: 4),

                          // Número telefónico
                          Row(
                            mainAxisSize: MainAxisSize.min,

                            children: [
                              const Icon(
                                Icons.phone_rounded,

                                size: 14,

                                color: Colors.white70,
                              ),

                              const SizedBox(width: 4),

                              Flexible(
                                child: Text(
                                  phoneNumber.isEmpty ||
                                          phoneNumber == 'Sin número'
                                      ? 'Sin número registrado'
                                      : phoneNumber,

                                  style: const TextStyle(
                                    fontSize: 14,

                                    color: Colors.white70,

                                    fontWeight: FontWeight.w500,
                                  ),

                                  overflow: TextOverflow.ellipsis,

                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Contenido del comentario con límite de altura
                    Container(
                      width: double.infinity,

                      constraints: const BoxConstraints(
                        maxHeight:
                            200, // Límite de altura para comentarios largos
                      ),

                      padding: const EdgeInsets.all(12),

                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,

                        borderRadius: BorderRadius.circular(8),

                        border: Border.all(
                          color: Colors.grey.withOpacity(0.2),

                          width: 1,
                        ),
                      ),

                      child: SingleChildScrollView(
                        child: Text(
                          text,

                          style: const TextStyle(
                            fontSize: 15,

                            color: Colors.black87,

                            height: 1.4,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Fecha y hora
                    if (timestamp != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          Icon(
                            Icons.access_time_rounded,

                            size: 12,

                            color: Colors.grey[500],
                          ),

                          const SizedBox(width: 4),

                          Flexible(
                            child: Text(
                              DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(timestamp.toDate()),

                              style: TextStyle(
                                fontSize: 12,

                                color: Colors.grey[500],
                              ),

                              overflow: TextOverflow.ellipsis,

                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Separación mínima entre contenido y botones
              const SizedBox(width: 12),

              // Botones de acción compactos (solo el espacio necesario)
              Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  // Botón info
                  _buildVerticalActionButton(
                    icon: Icons.info_outline_rounded,

                    color: const Color(0xFF667eea),

                    onPressed: () => _showUserDetails(userId),

                    tooltip: 'Ver detalles',
                  ),

                  const SizedBox(height: 12),

                  // Botón llamar
                  _buildVerticalActionButton(
                    icon: Icons.phone_rounded,

                    color: Colors.green.shade600,

                    onPressed: () => _makePhoneCall(phoneNumber),

                    tooltip: 'Llamar',
                  ),

                  const SizedBox(height: 12),

                  // Botón eliminar comentario
                  _buildVerticalActionButton(
                    icon: Icons.delete_outline_rounded,

                    color: Colors.red.shade600,

                    onPressed: () => _showDeleteCommentDialog(comment.id),

                    tooltip: 'Eliminar comentario',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Método para obtener el nombre y primer apellido del usuario desde Firestore

  Future<String> _getUserDisplayName(String userId) async {
    if (userId.isEmpty) {
      return 'Usuario';
    }

    try {
      final docSnapshot =
          await FirebaseFirestore.instance
              .collection('ciudadanos')
              .doc(userId)
              .get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data()!;

        final nombres = userData['nombres'] as String? ?? "";

        final apellidos = userData['apellidos'] as String? ?? "";

        // Obtener el primer nombre y el primer apellido

        final primerNombre = nombres.isNotEmpty ? nombres.split(' ').first : "";

        final primerApellido =
            apellidos.isNotEmpty ? apellidos.split(' ').first : "";

        final displayName = "$primerNombre $primerApellido".trim();

        return displayName.isEmpty ? "Usuario" : displayName;
      } else {
        return 'Usuario';
      }
    } catch (e) {
      print('❌ [ERROR] Error al obtener el nombre del usuario: $e');

      return 'Usuario';
    }
  }

  // Widget helper para botones de acción verticales

  Widget _buildVerticalActionButton({
    required IconData icon,

    required Color color,

    required VoidCallback? onPressed,

    required String tooltip,
  }) {
    return Container(
      width: 36,

      height: 36,

      decoration: BoxDecoration(
        color: color.withOpacity(0.1),

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius: BorderRadius.circular(8),

          onTap: onPressed,

          child: Tooltip(
            message: tooltip,

            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
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

    return ChangeNotifierProvider(
      create: (context) => di.locator<MissingDetailsViewModel>(),

      child: Consumer<MissingDetailsViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.marcarEncontradoState == RequestState.Loaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Persona marcada como encontrada'),

                  duration: Duration(seconds: 2),
                ),
              );

              viewModel.resetState();

              Navigator.pop(context);
            });
          }

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),

                onPressed: () => Navigator.pop(context),
              ),

              title: Text(
                '${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}',

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
                    colors: (Theme.of(context).brightness == Brightness.dark)
                        ? (isFound
                            ? [const Color(0xFF064E3B), const Color(0xFF047857)]
                            : [const Color(0xFF1E293B), const Color(0xFF0F172A)])
                        : (isFound
                            ? [const Color(0xFF059669), const Color(0xFF10B981)]
                            : [const Color(0xFF003366), const Color(0xFF002244)]),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              actions: [
                const ThemeSunMoonToggle(),
                IconButton(
                  tooltip: 'Compartir Nota de Alerta Oficial',
                  icon: const FaIcon(
                    FontAwesomeIcons.shareNodes,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: () => _shareOfficialNotice(context),
                ),
                IconButton(
                  tooltip: 'Reasignar Unidad / DEPITPTIM',
                  icon: const Icon(
                    Icons.swap_horiz_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => _showReasignarDepitptimDialog(context),
                ),
                const SizedBox(width: 4),
              ],
            ),

            floatingActionButton:
                widget.desaparecido.estado != 'encontrado'
                    ? FloatingActionButton.extended(
                      onPressed: () async {
                        // Obtener el viewModel ANTES de mostrar el diálogo

                        final viewModel = Provider.of<MissingDetailsViewModel>(
                          context,

                          listen: false,
                        );

                        showDialog<void>(
                          context: context,

                          builder:
                              (dialogContext) => MarkAsFoundDialog(
                                onConfirm: (
                                  DateTime fechaEncontrado,
                                  String detalles,
                                ) async {
                                  Navigator.of(
                                    dialogContext,
                                  ).pop(); // Cerrar el diálogo de confirmación

                                  // Mostrar diálogo de progreso

                                  showDialog(
                                    context: context,

                                    barrierDismissible: false,

                                    builder: (BuildContext progressContext) {
                                      return WillPopScope(
                                        onWillPop: () async => false,

                                        child: AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),

                                          content: SizedBox(
                                            width: 300,

                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,

                                              children: [
                                                Icon(
                                                  Icons.check_circle_outline,

                                                  size: 48,

                                                  color: Colors.green,
                                                ),

                                                SizedBox(height: 16),

                                                Text(
                                                  'Marcando como encontrado',

                                                  style: TextStyle(
                                                    fontSize: 18,

                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),

                                                SizedBox(height: 24),

                                                Consumer<
                                                  MissingDetailsViewModel
                                                >(
                                                  builder: (
                                                    context,
                                                    vm,
                                                    child,
                                                  ) {
                                                    return Column(
                                                      children: [
                                                        LinearProgressIndicator(
                                                          value:
                                                              vm.progressValue,

                                                          backgroundColor:
                                                              Colors.grey[300],

                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                Color
                                                              >(Colors.green),
                                                        ),

                                                        SizedBox(height: 16),

                                                        Text(
                                                          vm.progressMessage,

                                                          textAlign:
                                                              TextAlign.center,

                                                          style: TextStyle(
                                                            fontSize: 14,

                                                            color:
                                                                Colors
                                                                    .grey[600],
                                                          ),
                                                        ),

                                                        SizedBox(height: 8),

                                                        Text(
                                                          '${(vm.progressValue * 100).toInt()}%',

                                                          style: TextStyle(
                                                            fontSize: 12,

                                                            fontWeight:
                                                                FontWeight.bold,

                                                            color: Colors.green,
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );

                                  // Ejecutar el proceso

                                  await viewModel.marcarComoEncontrado(
                                    widget.desaparecido.id!,

                                    fechaEncontrado: fechaEncontrado,

                                    encontradoDetalles: detalles,
                                  );

                                  if (!mounted) return;

                                  // Cerrar diálogo de progreso

                                  Navigator.of(context).pop();

                                  if (viewModel.marcarEncontradoState ==
                                      RequestState.Loaded) {
                                    if (mounted) {
                                      // Mostrar mensaje de éxito temporal

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                              ),

                                              SizedBox(width: 8),

                                              Expanded(
                                                child: Text(
                                                  '¡Persona marcada como encontrada exitosamente!',
                                                ),
                                              ),
                                            ],
                                          ),

                                          backgroundColor: Colors.green,

                                          behavior: SnackBarBehavior.floating,

                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),

                                          duration: Duration(seconds: 2),
                                        ),
                                      );

                                      // Navegar al dashboard de policía después de mostrar el mensaje

                                      Future.delayed(
                                        Duration(milliseconds: 500),
                                        () {
                                          if (mounted) {
                                            Navigator.of(
                                              context,
                                            ).pushNamedAndRemoveUntil(
                                              '/police_home',

                                              (route) => false,
                                            );
                                          }
                                        },
                                      );
                                    }
                                  } else if (viewModel.marcarEncontradoState ==
                                      RequestState.Error) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(
                                                Icons.error,
                                                color: Colors.white,
                                              ),

                                              SizedBox(width: 8),

                                              Expanded(
                                                child: Text(
                                                  viewModel
                                                      .mensajeMarcarEncontrado,
                                                ),
                                              ),
                                            ],
                                          ),

                                          backgroundColor: Colors.red,

                                          behavior: SnackBarBehavior.floating,

                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                        );
                      },

                      backgroundColor: Colors.green,

                      foregroundColor: Colors.white,

                      icon: Icon(Icons.check_circle),

                      label: Text(
                        'Marcar como encontrado',

                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),

                      elevation: 8,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    )
                    : null,

            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFF3F9FF), const Color(0xFFE3F2FD)],

                  begin: Alignment.topCenter,

                  end: Alignment.bottomCenter,
                ),
              ),

              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scrollController,

                    padding: const EdgeInsets.only(
                      left: 16.0,

                      right: 16.0,

                      top: 16.0,

                      bottom: 100.0,
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
                                          borderRadius: BorderRadius.circular(
                                            16.0,
                                          ),

                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.3,
                                              ),

                                              blurRadius: 10,

                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),

                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16.0,
                                          ),

                                          child: Stack(
                                            children: [
                                              PageView.builder(
                                                controller: _pageController,

                                                physics:
                                                    const BouncingScrollPhysics(
                                                      parent:
                                                          AlwaysScrollableScrollPhysics(),
                                                    ),

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
                                                          if (loadingProgress ==
                                                              null) {
                                                            return child;
                                                          }

                                                          return Container(
                                                            height: 280,

                                                            decoration: BoxDecoration(
                                                              color:
                                                                  Colors
                                                                      .grey[200],

                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    16,
                                                                  ),
                                                            ),

                                                            child: Center(
                                                              child: CircularProgressIndicator(
                                                                value:
                                                                    loadingProgress.expectedTotalBytes !=
                                                                            null
                                                                        ? loadingProgress.cumulativeBytesLoaded /
                                                                            loadingProgress.expectedTotalBytes!
                                                                        : null,

                                                                color:
                                                                    primaryColor,
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
                                                                    Colors
                                                                        .grey[300],

                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      16,
                                                                    ),
                                                              ),

                                                              child: const Center(
                                                                child: Icon(
                                                                  Icons
                                                                      .error_outline,

                                                                  size: 50,

                                                                  color:
                                                                      Colors
                                                                          .grey,
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
                                                                .withOpacity(
                                                                  0.6,
                                                                ),

                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  25,
                                                                ),
                                                          ),

                                                          child: IconButton(
                                                            icon: const Icon(
                                                              Icons.fullscreen,

                                                              color:
                                                                  Colors.white,

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
                                                        MainAxisAlignment
                                                            .center,

                                                    children: List.generate(
                                                      imageUrls.length,

                                                      (index) {
                                                        return AnimatedContainer(
                                                          duration:
                                                              const Duration(
                                                                milliseconds:
                                                                    300,
                                                              ),

                                                          width:
                                                              _currentPage ==
                                                                      index
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
                                                                _currentPage ==
                                                                        index
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .white
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

                                    Wrap(
                                      alignment: WrapAlignment.center,

                                      spacing: 8,

                                      runSpacing: 6,

                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,

                                            vertical: 6,
                                          ),

                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),

                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),

                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.3,
                                              ),
                                            ),
                                          ),

                                          child: Text(
                                            isFound
                                                ? 'ENCONTRADO'
                                                : 'DESAPARECIDO',

                                            style: const TextStyle(
                                              color: Colors.white,

                                              fontWeight: FontWeight.bold,

                                              fontSize: 12,
                                            ),
                                          ),
                                        ),

                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,

                                            vertical: 6,
                                          ),

                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),

                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),

                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.3,
                                              ),
                                            ),
                                          ),

                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,

                                            children: [
                                              const Icon(
                                                Icons.shield_outlined,

                                                color: Colors.white,

                                                size: 14,
                                              ),

                                              const SizedBox(width: 4),

                                              Text(
                                                widget
                                                        .desaparecido
                                                        .unidadACargo ??
                                                    'División de Búsqueda PNP (Línea 114)',

                                                style: const TextStyle(
                                                  color: Colors.white,

                                                  fontWeight: FontWeight.bold,

                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Información detallada con mejor diseño
                              Padding(
                                padding: const EdgeInsets.all(24.0),

                                child: Column(
                                  children: [
                                    if (widget.desaparecido.unidadACargo !=
                                            null &&
                                        widget.desaparecido.unidadACargo!
                                            .trim()
                                            .isNotEmpty)
                                      _buildInfoRow(
                                        Icons.local_police,

                                        'Comisaría / Dependencia a Cargo',

                                        _comisariaInfo?.nombreOficial ??
                                            ((!widget.desaparecido.unidadACargo!
                                                        .toUpperCase()
                                                        .contains('DEPINCRI') &&
                                                    !widget
                                                        .desaparecido
                                                        .unidadACargo!
                                                        .toUpperCase()
                                                        .contains('FAMILIA') &&
                                                    !widget
                                                        .desaparecido
                                                        .unidadACargo!
                                                        .toUpperCase()
                                                        .contains('TRANSITO') &&
                                                    !widget
                                                        .desaparecido
                                                        .unidadACargo!
                                                        .toUpperCase()
                                                        .contains(
                                                          'POLICÍA NACIONAL',
                                                        ) &&
                                                    !widget
                                                        .desaparecido
                                                        .unidadACargo!
                                                        .toUpperCase()
                                                        .contains(
                                                          'POLICIA NACIONAL',
                                                        ))
                                                ? widget
                                                    .desaparecido
                                                    .unidadACargo!
                                                : (widget
                                                                .desaparecido
                                                                .distrito !=
                                                            null &&
                                                        widget
                                                            .desaparecido
                                                            .distrito!
                                                            .trim()
                                                            .isNotEmpty
                                                    ? 'Comisaría PNP '
                                                    : 'Comisaría PNP de la Jurisdicción')),

                                        primaryColor,
                                      )
                                    else
                                      _buildInfoRow(
                                        Icons.shield_outlined,

                                        'Unidad Policial a Cargo',

                                        'DIRCTPTIM - PNP',

                                        primaryColor,
                                      ),

                                    if (widget.desaparecido.fechaDesaparicion !=
                                        null)
                                      _buildInfoRow(
                                        Icons.calendar_today,

                                        'Fecha de Desaparición',

                                        DateFormat('dd/MM/yyyy HH:mm').format(
                                          widget
                                              .desaparecido
                                              .fechaDesaparicion!,
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

                                    _buildInfoRow(
                                      Icons.phone,
                                      widget.desaparecido.unidadACargo != null
                                          ? 'Teléfono de la Comisaría'
                                          : 'Teléfono de Contacto',
                                      (_comisariaInfo != null &&
                                              _comisariaInfo!
                                                  .tieneTelefonoDirecto)
                                          ? '${_comisariaInfo!.nombreOficial}: ${_comisariaInfo!.telefono}'
                                          : 'Central 105 / Línea 114 PNP',
                                      primaryColor,
                                    ),
                                    if (_comisariaInfo != null &&
                                        _comisariaInfo!.direccion
                                            .trim()
                                            .isNotEmpty)
                                      _buildInfoRow(
                                        Icons.location_city_rounded,
                                        'Dirección Dependencia',
                                        _comisariaInfo!.direccion,
                                        primaryColor,
                                      ),

                                    // Botón/Tarjeta de acceso directo a la Nota de Alerta Oficial
                                    if (widget.desaparecido.imagenFichaUrl !=
                                            null &&
                                        widget.desaparecido.imagenFichaUrl!
                                            .trim()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 12),

                                      InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,

                                            MaterialPageRoute(
                                              builder:
                                                  (
                                                    context,
                                                  ) => FullScreenImageScreen(
                                                    imageUrl:
                                                        widget
                                                            .desaparecido
                                                            .imagenFichaUrl!,
                                                  ),
                                            ),
                                          );
                                        },

                                        borderRadius: BorderRadius.circular(14),

                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),

                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFFDC2626,
                                            ).withOpacity(0.08),

                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),

                                            border: Border.all(
                                              color: const Color(
                                                0xFFDC2626,
                                              ).withOpacity(0.3),

                                              width: 1.2,
                                            ),
                                          ),

                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),

                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFDC2626,
                                                  ),

                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),

                                                child: const Icon(
                                                  Icons.assignment_turned_in,

                                                  color: Colors.white,

                                                  size: 20,
                                                ),
                                              ),

                                              const SizedBox(width: 12),

                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,

                                                  children: const [
                                                    Text(
                                                      'Nota de Alerta Oficial PNP',

                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,

                                                        fontSize: 13,

                                                        color: Color(
                                                          0xFFB91C1C,
                                                        ),
                                                      ),
                                                    ),

                                                    SizedBox(height: 2),

                                                    Text(
                                                      'Ver afiche oficial completo en alta definición',

                                                      style: TextStyle(
                                                        fontSize: 11,

                                                        color: Colors.black54,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              const Icon(
                                                Icons.arrow_forward_ios,

                                                size: 14,

                                                color: Color(0xFFDC2626),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],

                                    if (widget
                                            .desaparecido
                                            .detallesAdicionales !=
                                        null)
                                      _buildInfoCard(
                                        'Detalles Adicionales',

                                        widget
                                            .desaparecido
                                            .detallesAdicionales!,

                                        primaryColor,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Sección de comentarios
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
                              // Header de comentarios
                              Container(
                                padding: const EdgeInsets.all(20),

                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF667eea).withOpacity(0.1),

                                      const Color(0xFF764ba2).withOpacity(0.05),
                                    ],
                                  ),

                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20),

                                    topRight: Radius.circular(20),
                                  ),
                                ),

                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),

                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF667eea,
                                        ).withOpacity(0.1),

                                        borderRadius: BorderRadius.circular(12),
                                      ),

                                      child: Icon(
                                        Icons.comment,

                                        color: const Color(0xFF667eea),

                                        size: 24,
                                      ),
                                    ),

                                    const SizedBox(width: 16),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,

                                        children: [
                                          Text(
                                            'Comentarios de Ciudadanos',

                                            style: TextStyle(
                                              fontSize: 18,

                                              fontWeight: FontWeight.bold,

                                              color: const Color(0xFF667eea),
                                            ),
                                          ),

                                          Text(
                                            'Información reportada por la comunidad',

                                            style: TextStyle(
                                              fontSize: 14,

                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,

                                        vertical: 6,
                                      ),

                                      decoration: BoxDecoration(
                                        color: const Color(0xFF667eea),

                                        borderRadius: BorderRadius.circular(20),
                                      ),

                                      child: Text(
                                        '${_comments.length}',

                                        style: const TextStyle(
                                          color: Colors.white,

                                          fontWeight: FontWeight.bold,

                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Lista de comentarios
                              Container(
                                padding: const EdgeInsets.all(20),

                                child:
                                    _isLoadingComments
                                        ? Center(
                                          child: Column(
                                            children: [
                                              CircularProgressIndicator(
                                                color: const Color(0xFF667eea),
                                              ),

                                              const SizedBox(height: 16),

                                              Text(
                                                'Cargando comentarios...',

                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        : _comments.isEmpty
                                        ? Container(
                                          padding: const EdgeInsets.all(32),

                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.chat_bubble_outline,

                                                size: 48,

                                                color: Colors.grey[400],
                                              ),

                                              const SizedBox(height: 16),

                                              Text(
                                                'No hay comentarios aún',

                                                style: TextStyle(
                                                  fontSize: 16,

                                                  fontWeight: FontWeight.w500,

                                                  color: Colors.grey[600],
                                                ),
                                              ),

                                              const SizedBox(height: 8),

                                              Text(
                                                'Los comentarios de los ciudadanos aparecerán aquí',

                                                style: TextStyle(
                                                  fontSize: 14,

                                                  color: Colors.grey[500],
                                                ),

                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        )
                                        : Column(
                                          children:
                                              _comments
                                                  .map(
                                                    (comment) =>
                                                        _buildPoliceCommentBubble(
                                                          comment,
                                                        ),
                                                  )
                                                  .toList(),
                                        ),
                              ),
                            ],
                          ),
                        ),

                        if (viewModel.marcarEncontradoState ==
                            RequestState.Error)
                          Container(
                            margin: const EdgeInsets.only(top: 16),

                            padding: const EdgeInsets.all(16),

                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),

                              borderRadius: BorderRadius.circular(12),

                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                              ),
                            ),

                            child: Row(
                              children: [
                                Icon(Icons.error, color: Colors.red),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Text(
                                    viewModel.mensajeMarcarEncontrado,

                                    style: const TextStyle(color: Colors.red),
                                  ),
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
          );
        },
      ),
    );
  }

  // Widget helper para filas de información (versión del ciudadano)

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    MaterialColor primaryColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            padding: const EdgeInsets.all(12),

            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),

              borderRadius: BorderRadius.circular(12),
            ),

            child: Icon(icon, color: primaryColor, size: 20),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  label,

                  style: TextStyle(
                    fontSize: 14,

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

  // Widget helper para tarjetas de información (versión del ciudadano)

  Widget _buildInfoCard(
    String title,
    String content,
    MaterialColor primaryColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 8),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.05),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: primaryColor.withOpacity(0.2)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),

                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),

                  borderRadius: BorderRadius.circular(8),
                ),

                child: Icon(Icons.info_outline, color: primaryColor, size: 18),
              ),

              const SizedBox(width: 12),

              Text(
                title,

                style: TextStyle(
                  fontSize: 16,

                  fontWeight: FontWeight.bold,

                  color: primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

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

  // Widget helper para filas de información (versión original del policía)

  Widget _buildInfoRowOriginal(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            padding: const EdgeInsets.all(8),

            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),

              borderRadius: BorderRadius.circular(8),
            ),

            child: Icon(icon, color: const Color(0xFF667eea), size: 18),
          ),

          const SizedBox(width: 12),

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
                    fontSize: 14,

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

  void _showReasignarDepitptimDialog(BuildContext context) {
    String selectedUnidad =
        widget.desaparecido.unidadACargo ??
        'División de Búsqueda PNP (Línea 114)';

    final List<String> opciones = [
      'División de Búsqueda PNP (Línea 114)',

      'DEPITPTIM ABANCAY',

      'DIRCTPTIM CENTRAL LIMA',

      'COMISARÍA SECTORIAL TALAVERA',

      'COMISARÍA SAN JERÓNIMO',

      'COMISARÍA CHINCHEROS',
    ];

    if (!opciones.contains(selectedUnidad)) {
      opciones.insert(0, selectedUnidad);
    }

    showDialog(
      context: context,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),

              title: Row(
                children: const [
                  Icon(Icons.shield, color: Color(0xFF667eea)),

                  SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      'Reasignar Unidad / DEPITPTIM',

                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Seleccione la unidad especializada o comisaría responsable del caso:',

                    style: TextStyle(fontSize: 14),
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: selectedUnidad,

                    isExpanded: true,

                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),

                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,

                        vertical: 8,
                      ),
                    ),

                    items:
                        opciones.map((op) {
                          return DropdownMenuItem(
                            value: op,

                            child: Text(
                              op,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),

                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedUnidad = val);
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(10),

                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withOpacity(0.08),

                      borderRadius: BorderRadius.circular(8),
                    ),

                    child: const Text(
                      'Nota: Al reasignar la unidad, se actualizará la dependencia policial de contacto y despacho comunitario en el aplicativo.',

                      style: TextStyle(fontSize: 12, color: Color(0xFF667eea)),
                    ),
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),

                  child: const Text('Cancelar'),
                ),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),

                    foregroundColor: Colors.white,
                  ),

                  onPressed: () async {
                    Navigator.pop(dialogContext);

                    try {
                      if (widget.desaparecido.id != null) {
                        await FirebaseFirestore.instance
                            .collection('desaparecidos')
                            .doc(widget.desaparecido.id)
                            .update({
                              'unidad_a_cargo': selectedUnidad,

                              'depitptim_nombre': selectedUnidad,

                              'fecha_reasignacion_depitptim':
                                  FieldValue.serverTimestamp(),
                            });

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Caso reasignado exitosamente a $selectedUnidad',
                              ),

                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al reasignar caso: $e'),

                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },

                  child: const Text('Confirmar Reasignación'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _shareOfficialNotice(BuildContext context) async {
    final d = widget.desaparecido;
    final fullName = '${d.nombres} ${d.apellidos}'.trim();
    final isEncontrado = (d.estado ?? '').toLowerCase() == 'encontrado';

    final String message;
    if (isEncontrado) {
      message =
          '🟢 *PERSONA UBICADA - CASO RESUELTO*\n\n'
          'La Policía Nacional del Perú comunica con satisfacción que *$fullName* '
          'ha sido *UBICADO(A)* y se encuentra a buen recaudo con sus familiares.\n\n'
          'Agradecemos a la ciudadanía y a los medios de comunicación por su apoyo en la difusión.';
    } else {
      final dniText = (d.dni != null && d.dni!.isNotEmpty) ? ' (DNI: ${d.dni})' : '';
      final edadText = (d.edadCalculada != null) ? ' - ${d.edadCalculada} años' : '';
      message =
          '🚨 *ALERTA OFICIAL DE DESAPARICIÓN - POLICÍA NACIONAL DEL PERÚ*\n\n'
          'Ayúdanos a encontrar a *$fullName*$dniText$edadText.\n'
          '📌 Se adjunta la *Nota de Alerta Oficial* emitida por la PNP.\n\n'
          'Si cuenta con información relevante sobre su paradero, comuníquese de inmediato a la *Línea 114 PNP* o acérquese a la Comisaría más cercana.\n\n'
          '¡Cada minuto cuenta para salvar una vida!';
    }

    final String? notaUrl = (d.imagenFichaUrl?.isNotEmpty == true)
        ? d.imagenFichaUrl
        : (d.fotoUrl?.isNotEmpty == true ? d.fotoUrl : null);

    await ShareHelper.shareCase(
      context: context,
      message: message,
      subject: 'Alerta PNP: $fullName',
      imageUrl: notaUrl,
    );
  }
}
