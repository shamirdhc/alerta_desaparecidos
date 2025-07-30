import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../domain/entities/desaparecido.dart';
import '../view_models/missing_details_view_model.dart';
import '../../../domain/use_cases/marcar_como_encontrado_use_case.dart';
import '../../../data/repositories/desaparecido_repository_impl.dart';
import '../../../data/data_sources/desaparecido_remote_data_source.dart';
import '../../../common/state_enum.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

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
  String? _vettingUserId;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _subscribeToComments();
  }

  @override
  void dispose() {
    _commentsSubscription?.cancel();
    _scrollController.dispose();
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
                          _buildUserDetailRow(
                            Icons.person,
                            'Nombre Completo',
                            '$nombres $apellidos',
                          ),
                          _buildUserDetailRow(
                            Icons.phone,
                            'Teléfono',
                            telefono,
                          ),
                          _buildUserDetailRow(Icons.email, 'Email', email),
                          _buildUserDetailRow(
                            Icons.location_on,
                            'Ubicación',
                            '$distrito, $provincia, $departamento',
                          ),
                          if (fechaRegistro != null)
                            _buildUserDetailRow(
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
      _vettingUserId = userId;
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
      setState(() {
        _isVettingUser = false;
        _vettingUserId = null;
      });
    }
  }

  // Mostrar diálogo de confirmación para vetar usuario
  Future<bool> _showVetConfirmationDialog(String userId) async {
    // Obtener información del usuario
    final userDoc = await FirebaseFirestore.instance
        .collection('ciudadanos')
        .doc(userId)
        .get();
    
    String userName = 'Usuario';
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      final nombres = userData['nombres'] ?? '';
      final apellidos = userData['apellidos'] ?? '';
      userName = '$nombres $apellidos'.trim();
      if (userName.isEmpty) userName = 'Usuario';
    }

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
                colors: [
                  Colors.red.shade50,
                  Colors.orange.shade50,
                ],
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
    ) ?? false;
  }

  // Widget helper para mostrar consecuencias
  Widget _buildConsequenceItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 16),
          ),
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
                colors: [
                  Colors.red.shade50,
                  Colors.orange.shade50,
                ],
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
      final userRef = FirebaseFirestore.instance.collection('ciudadanos').doc(userId);
      batch.update(userRef, {'vetado': true});

      // 2. Eliminar todos los comentarios del usuario en todos los casos de desaparecidos
      final commentsQuery = await FirebaseFirestore.instance
          .collectionGroup('comentarios')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in commentsQuery.docs) {
        batch.delete(doc.reference);
      }

      // 3. Eliminar todas las recomendaciones del usuario
      final recommendationsQuery = await FirebaseFirestore.instance
          .collection('recomendaciones')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in recommendationsQuery.docs) {
        batch.delete(doc.reference);
      }

      // 4. Eliminar reportes de desaparecidos creados por el usuario (opcional)
      final reportsQuery = await FirebaseFirestore.instance
          .collection('desaparecidos')
          .where('reportadoPor', isEqualTo: userId)
          .get();

      for (final doc in reportsQuery.docs) {
        // En lugar de eliminar, podemos marcar como "reportado por usuario vetado"
        batch.update(doc.reference, {
          'reportadoPorVetado': true,
          'observacionesPolicia': 'Usuario reportante fue vetado por comportamiento inapropiado'
        });
      }

      // Ejecutar todas las operaciones
      await batch.commit();

      print('✅ [SUCCESS] Usuario $userId vetado completamente');
    } catch (e) {
      print('❌ [ERROR] Error al vetar usuario completamente: $e');
      throw e;
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
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: phoneNumber,
      );
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
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                  phoneNumber,
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
                        maxHeight: 200, // Límite de altura para comentarios largos
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
                              DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate()),
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
      final docSnapshot = await FirebaseFirestore.instance
          .collection('ciudadanos')
          .doc(userId)
          .get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data()!;
        final nombres = userData['nombres'] as String? ?? "";
        final apellidos = userData['apellidos'] as String? ?? "";

        // Obtener el primer nombre y el primer apellido
        final primerNombre = nombres.isNotEmpty ? nombres.split(' ').first : "";
        final primerApellido = apellidos.isNotEmpty ? apellidos.split(' ').first : "";

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
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final desaparecidoRemoteDataSource = DesaparecidoRemoteDataSource(
          FirebaseFirestore.instance,
          FirebaseStorage.instance,
        );
        final desaparecidoRepository = DesaparecidoRepositoryImpl(
          desaparecidoRemoteDataSource,
        );
        final marcarComoEncontradoUseCase = MarcarComoEncontradoUseCase(
          desaparecidoRepository,
        );
        return MissingDetailsViewModel(marcarComoEncontradoUseCase);
      },
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
                    colors: [const Color(0xFF667eea), const Color(0xFF764ba2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
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
                        // Información de la persona desaparecida
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
                              // Imagen de la persona
                              if (widget.desaparecido.fotoUrl != null)
                                Container(
                                  height: 200,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      topRight: Radius.circular(20),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      topRight: Radius.circular(20),
                                    ),
                                    child: Image.network(
                                      widget.desaparecido.fotoUrl!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              // Información detallada
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (widget.desaparecido.sexo != null)
                                      _buildInfoRow(
                                        Icons.person,
                                        'Sexo',
                                        widget.desaparecido.sexo!,
                                      ),
                                    if (widget.desaparecido.dni != null)
                                      _buildInfoRow(
                                        Icons.credit_card,
                                        'DNI',
                                        widget.desaparecido.dni!,
                                      ),
                                    if (widget.desaparecido.telefonoContacto !=
                                        null)
                                      _buildInfoRow(
                                        Icons.phone,
                                        'Teléfono de Contacto',
                                        widget.desaparecido.telefonoContacto!,
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
                                      ),
                                    if (widget.desaparecido.departamento !=
                                        null)
                                      _buildInfoRow(
                                        Icons.location_on,
                                        'Ubicación',
                                        '${widget.desaparecido.distrito ?? ''}, ${widget.desaparecido.provincia ?? ''}, ${widget.desaparecido.departamento}',
                                      ),
                                    if (widget
                                            .desaparecido
                                            .detallesAdicionales !=
                                        null)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 16),
                                          Text(
                                            'Detalles Adicionales:',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF667eea),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF667eea,
                                              ).withOpacity(0.05),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFF667eea,
                                                ).withOpacity(0.2),
                                              ),
                                            ),
                                            child: Text(
                                              widget
                                                  .desaparecido
                                                  .detallesAdicionales!,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black87,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
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
                  // Botón flotante para marcar como encontrado
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: viewModel.marcarEncontradoState == RequestState.Loaded
                              ? [
                                  const Color(0xFF27AE60),
                                  const Color(0xFF2ECC71),
                                ]
                              : [
                                  const Color(0xFF667eea),
                                  const Color(0xFF764ba2),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (viewModel.marcarEncontradoState == RequestState.Loaded
                                    ? const Color(0xFF27AE60)
                                    : const Color(0xFF667eea))
                                .withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: viewModel.marcarEncontradoState == RequestState.Loading ||
                                  viewModel.marcarEncontradoState == RequestState.Loaded
                              ? null
                              : () async {
                                  await viewModel.marcarComoEncontrado(
                                    widget.desaparecido.id!,
                                  );
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 24,
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: viewModel.marcarEncontradoState == RequestState.Loading
                                  ? Row(
                                      key: const ValueKey('loading'),
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: Colors.white,
                                            backgroundColor: Colors.white.withOpacity(0.3),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          'Procesando...',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      key: ValueKey(viewModel.marcarEncontradoState),
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            viewModel.marcarEncontradoState == RequestState.Loaded
                                                ? Icons.check_circle_rounded
                                                : Icons.person_search_rounded,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            viewModel.marcarEncontradoState == RequestState.Loaded
                                                ? '¡Marcado como Encontrado!'
                                                : 'Marcar como Encontrado',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        if (viewModel.marcarEncontradoState != RequestState.Loaded)
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.arrow_forward_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (viewModel.marcarEncontradoState == RequestState.Loading)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: const Color(0xFF667eea),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Procesando...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
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
        },
      ),
    );
  }

  // Widget helper para filas de información
  Widget _buildInfoRow(IconData icon, String label, String value) {
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
}
