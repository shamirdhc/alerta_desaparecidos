import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../../domain/entities/desaparecido.dart';

class PoliceCommentsManagementScreen extends StatefulWidget {
  final Desaparecido desaparecido;

  const PoliceCommentsManagementScreen({super.key, required this.desaparecido});

  @override
  State<PoliceCommentsManagementScreen> createState() => _PoliceCommentsManagementScreenState();
}

class _PoliceCommentsManagementScreenState extends State<PoliceCommentsManagementScreen> {
  List<DocumentSnapshot> _comments = [];
  StreamSubscription? _commentsSubscription;
  late ScrollController _scrollController;
  bool _isLoadingComments = true;

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
        .orderBy('timestamp', descending: true) // Más recientes primero
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

  // Obtener nombre del usuario
  Future<String> _getUserDisplayName(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('ciudadanos')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final nombres = userData['nombres'] ?? '';
        final apellidos = userData['apellidos'] ?? '';
        
        if (nombres.isNotEmpty && apellidos.isNotEmpty) {
          return '$nombres $apellidos';
        } else if (nombres.isNotEmpty) {
          return nombres;
        } else if (apellidos.isNotEmpty) {
          return apellidos;
        }
      }
      return 'Usuario sin nombre';
    } catch (e) {
      print('❌ [ERROR] Error al obtener nombre del usuario: $e');
      return 'Error al cargar nombre';
    }
  }

  // Mostrar detalles del usuario que comentó
  Future<void> _showUserDetails(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
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
        builder: (context) => Dialog(
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
                      _buildInfoRowOriginal(
                        Icons.email,
                        'Email',
                        email,
                      ),
                      _buildInfoRowOriginal(
                        Icons.location_on,
                        'Ubicación',
                        '$departamento, $provincia, $distrito',
                      ),
                      if (fechaRegistro != null)
                        _buildInfoRowOriginal(
                          Icons.calendar_today,
                          'Fecha de Registro',
                          DateFormat('dd/MM/yyyy').format(fechaRegistro.toDate()),
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
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.grey.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Cerrar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showVetUserDialog(userId);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: vetado ? Colors.green : Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(vetado ? 'Desvetar' : 'Vetar Usuario'),
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
      print('❌ [ERROR] Error al mostrar detalles del usuario: $e');
      _showErrorMessage('Error al cargar detalles del usuario');
    }
  }

  // Widget helper para filas de información
  Widget _buildInfoRowOriginal(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.grey[600], size: 16),
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

  // Mostrar diálogo para vetar usuario
  Future<void> _showVetUserDialog(String userId) async {
    final confirmed = await _showVetConfirmationDialog(userId);
    if (confirmed == true) {
      await _toggleUserVetStatus(userId);
    }
  }

  // Mostrar diálogo de confirmación para vetar usuario
  Future<bool?> _showVetConfirmationDialog(String userId) async {
    // Obtener información del usuario
    final userDoc = await FirebaseFirestore.instance
        .collection('ciudadanos')
        .doc(userId)
        .get();
    
    if (!mounted) return false;

    String userName = 'Usuario';
    bool isCurrentlyVetted = false;
    
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      final nombres = userData['nombres'] ?? '';
      final apellidos = userData['apellidos'] ?? '';
      userName = '$nombres $apellidos'.trim();
      if (userName.isEmpty) userName = 'Usuario';
      isCurrentlyVetted = userData['vetado'] ?? false;
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
                colors: isCurrentlyVetted 
                    ? [Colors.green.shade50, Colors.green.shade100]
                    : [Colors.red.shade50, Colors.orange.shade50],
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
                // Icono
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (isCurrentlyVetted ? Colors.green : Colors.red).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCurrentlyVetted ? Icons.check_circle : Icons.warning_rounded,
                    size: 48,
                    color: isCurrentlyVetted ? Colors.green.shade600 : Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Título
                Text(
                  isCurrentlyVetted ? '✅ DESVETAR USUARIO' : '⚠️ VETAR USUARIO',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isCurrentlyVetted ? Colors.green.shade700 : Colors.red.shade700,
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
                      color: (isCurrentlyVetted ? Colors.green : Colors.red).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isCurrentlyVetted 
                            ? 'Está a punto de DESVETAR al usuario:'
                            : 'Está a punto de VETAR al usuario:',
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
                          color: isCurrentlyVetted ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                        textAlign: TextAlign.center,
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
                          backgroundColor: isCurrentlyVetted ? Colors.green : Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          isCurrentlyVetted ? 'Desvetar' : 'Vetar',
                          style: const TextStyle(
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
    );
  }

  // Cambiar estado de vetado del usuario
  Future<void> _toggleUserVetStatus(String userId) async {
    try {
      // Obtener estado actual
      final userDoc = await FirebaseFirestore.instance
          .collection('ciudadanos')
          .doc(userId)
          .get();

      if (!mounted) return;
      if (!userDoc.exists) {
        _showErrorMessage('Usuario no encontrado');
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final currentVetStatus = userData['vetado'] ?? false;
      final newVetStatus = !currentVetStatus;

      if (newVetStatus) {
        // Vetar usuario completamente
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
            ? 'Usuario vetado exitosamente. Se han eliminado todos sus comentarios.'
            : 'Usuario desvetado exitosamente',
      );
    } catch (e) {
      print('❌ [ERROR] Error al cambiar estado de vetado: $e');
      _showErrorMessage('Error al actualizar estado del usuario');
    }
  }

  // Vetar usuario completamente (eliminar comentarios y marcar como vetado)
  Future<void> _vetUserCompletely(String userId) async {
    final batch = FirebaseFirestore.instance.batch();

    // Marcar usuario como vetado
    final userRef = FirebaseFirestore.instance.collection('ciudadanos').doc(userId);
    batch.update(userRef, {'vetado': true});

    // Eliminar todos los comentarios del usuario en todos los casos
    final allCommentsQuery = await FirebaseFirestore.instance
        .collectionGroup('comments')
        .where('userId', isEqualTo: userId)
        .get();

    for (final doc in allCommentsQuery.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // Eliminar comentario específico
  Future<void> _deleteComment(String commentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('desaparecidos')
          .doc(widget.desaparecido.id)
          .collection('comments')
          .doc(commentId)
          .delete();

      _showSuccessMessage('Comentario eliminado exitosamente');
    } catch (e) {
      print('❌ [ERROR] Error al eliminar comentario: $e');
      _showErrorMessage('Error al eliminar comentario');
    }
  }

  // Mostrar diálogo de confirmación para eliminar comentario
  Future<void> _showDeleteCommentDialog(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Eliminar Comentario'),
          ],
        ),
        content: const Text(
          '¿Está seguro de que desea eliminar este comentario? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteComment(commentId);
    }
  }

  // Realizar llamada telefónica
  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty || phoneNumber == 'Sin número') {
      _showErrorMessage('Número de teléfono no disponible');
      return;
    }

    try {
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: phoneNumber,
      );
      await launchUrl(launchUri);
    } catch (e) {
      print('❌ [ERROR] Error al realizar llamada: $e');
      _showErrorMessage('Error al intentar llamar');
    }
  }

  // Abrir WhatsApp con el número del ciudadano
  Future<void> _openWhatsApp(String phoneNumber) async {
    if (phoneNumber.isEmpty || phoneNumber == 'Sin número') {
      _showErrorMessage('Número de teléfono no disponible');
      return;
    }

    try {
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
      final formattedNumber = cleanNumber.startsWith('51') ? cleanNumber : '51$cleanNumber';
      final Uri uri = Uri.parse('https://wa.me/$formattedNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorMessage('No se pudo abrir WhatsApp');
      }
    } catch (e) {
      _showErrorMessage('Error al abrir WhatsApp');
    }
  }

  // Actualizar el estado de moderación del comentario (Aprobado / Reservado / Rechazado)
  Future<void> _updateCommentModeration(String commentId, String nuevoEstado) async {
    try {
      await FirebaseFirestore.instance
          .collection('desaparecidos')
          .doc(widget.desaparecido.id)
          .collection('comments')
          .doc(commentId)
          .update({
        'estado_moderacion': nuevoEstado,
        'moderado_at': FieldValue.serverTimestamp(),
      });

      final mensaje = nuevoEstado == 'aprobado'
          ? '✅ Pista aprobada para difusión pública'
          : nuevoEstado == 'reservado'
              ? '🔒 Marcada como Pista Policial Reservada'
              : '❌ Pista descartada';
      _showSuccessMessage(mensaje);
    } catch (e) {
      print('❌ [ERROR] Error actualizando moderación: $e');
      _showErrorMessage('Error al moderar la pista');
    }
  }

  // Widget para botones de acción verticales
  Widget _buildVerticalActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 38,
        height: 38,
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
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Icon(
              icon,
              color: color,
              size: 19,
            ),
          ),
        ),
      ),
    );
  }

  // Widget para mostrar un comentario
  Widget _buildCommentBubble(DocumentSnapshot comment) {
    final data = comment.data() as Map<String, dynamic>;
    final text = data['text'] ?? '';
    final timestamp = data['timestamp'] as Timestamp?;
    final userId = data['userId'] ?? '';
    final phoneNumber = data['phoneNumber'] ?? '';
    final estadoModeracion = data['estado_moderacion'] ?? 'pendiente';

    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    switch (estadoModeracion) {
      case 'aprobado':
        badgeColor = Colors.green;
        badgeText = 'APROBADO PÚBLICO';
        badgeIcon = Icons.check_circle;
        break;
      case 'reservado':
        badgeColor = Colors.blue.shade700;
        badgeText = 'PISTA RESERVADA POLICIAL';
        badgeIcon = Icons.lock_rounded;
        break;
      case 'rechazado':
        badgeColor = Colors.red;
        badgeText = 'DESCARTADO / SPAM';
        badgeIcon = Icons.cancel;
        break;
      default:
        badgeColor = Colors.orange.shade800;
        badgeText = 'PENDIENTE DE REVISIÓN';
        badgeIcon = Icons.hourglass_top_rounded;
    }

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
          color: badgeColor.withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contenido principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge de estado de moderación
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: badgeColor.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 14, color: badgeColor),
                          const SizedBox(width: 5),
                          Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Información del usuario
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
                          // Nombre del usuario
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
                                  phoneNumber.isEmpty || phoneNumber == 'Sin número' 
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
                    
                    // Contenido del comentario
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(
                        maxHeight: 200,
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
              
              const SizedBox(width: 12),
              
              // Botones de acción policial (Llamada, WhatsApp y Moderación)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botón Aprobar para el público
                  _buildVerticalActionButton(
                    icon: Icons.check_circle_outline_rounded,
                    color: Colors.green.shade700,
                    onPressed: () => _updateCommentModeration(comment.id, 'aprobado'),
                    tooltip: 'Aprobar para el público',
                  ),
                  const SizedBox(height: 8),
                  
                  // Botón Pista Reservada
                  _buildVerticalActionButton(
                    icon: Icons.lock_outline_rounded,
                    color: Colors.blue.shade700,
                    onPressed: () => _updateCommentModeration(comment.id, 'reservado'),
                    tooltip: 'Guardar como Pista Reservada',
                  ),
                  const SizedBox(height: 8),
                  
                  // Botón WhatsApp directo
                  _buildVerticalActionButton(
                    icon: Icons.chat_rounded,
                    color: const Color(0xFF25D366),
                    onPressed: () => _openWhatsApp(phoneNumber),
                    tooltip: 'Escribir por WhatsApp',
                  ),
                  const SizedBox(height: 8),
                  
                  // Botón llamar
                  _buildVerticalActionButton(
                    icon: Icons.phone_rounded,
                    color: Colors.teal.shade700,
                    onPressed: () => _makePhoneCall(phoneNumber),
                    tooltip: 'Llamar al informante',
                  ),
                  const SizedBox(height: 8),

                  // Botón info
                  _buildVerticalActionButton(
                    icon: Icons.info_outline_rounded,
                    color: const Color(0xFF667eea),
                    onPressed: () => _showUserDetails(userId),
                    tooltip: 'Ver detalles del informante',
                  ),
                  const SizedBox(height: 8),
                  
                  // Botón descartar
                  _buildVerticalActionButton(
                    icon: Icons.delete_outline_rounded,
                    color: Colors.red.shade600,
                    onPressed: () => _showDeleteCommentDialog(comment.id),
                    tooltip: 'Descartar / Eliminar',
                  ),
                ],
              ),
            ],
          ),
        ),
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
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Mostrar mensaje de éxito
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gestión de Comentarios',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.comment, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  '${_comments.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoadingComments
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: const Color(0xFF667eea),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando comentarios...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _comments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay comentarios aún',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Los comentarios de los ciudadanos aparecerán aquí',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    return _buildCommentBubble(_comments[index]);
                  },
                ),
    );
  }
}