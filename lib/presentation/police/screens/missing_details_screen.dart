import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/desaparecido.dart';
import 'package:intl/intl.dart';
import '../view_models/missing_details_view_model.dart';
import '../../../domain/use_cases/marcar_como_encontrado_use_case.dart';
import '../../../data/repositories/desaparecido_repository_impl.dart';
import '../../../data/data_sources/desaparecido_remote_data_source.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

    setState(() {
      _isVettingUser = true;
      _vettingUserId = userId;
    });

    try {
      await FirebaseFirestore.instance
          .collection('ciudadanos')
          .doc(userId)
          .update({'vetado': newVetStatus});

      _showSuccessMessage(
        newVetStatus
            ? 'Usuario vetado exitosamente'
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

  // Widget para mostrar un comentario de policía
  Widget _buildPoliceCommentBubble(DocumentSnapshot comment) {
    final data = comment.data() as Map<String, dynamic>;
    final text = data['text'] ?? '';
    final timestamp = data['timestamp'] as Timestamp?;
    final userId = data['userId'] ?? '';
    final phoneNumber = data['phoneNumber'] ?? '';

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('ciudadanos').doc(userId).get(),
      builder: (context, snapshot) {
        String userName = 'Usuario';
        bool isVetado = false;

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final nombres = userData['nombres'] ?? '';
          final apellidos = userData['apellidos'] ?? '';
          userName = '$nombres $apellidos'.trim();
          if (userName.isEmpty) userName = 'Usuario';
          isVetado = userData['vetado'] ?? false;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color:
                    isVetado
                        ? Colors.red.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header del comentario
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        isVetado
                            ? Colors.red.withOpacity(0.05)
                            : const Color(0xFF667eea).withOpacity(0.05),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Avatar del usuario
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              isVetado
                                  ? Colors.red.withOpacity(0.1)
                                  : const Color(0xFF667eea).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          size: 20,
                          color:
                              isVetado ? Colors.red : const Color(0xFF667eea),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Información del usuario
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  userName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color:
                                        isVetado ? Colors.red : Colors.black87,
                                  ),
                                ),
                                if (isVetado) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'VETADO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              phoneNumber,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (timestamp != null)
                              Text(
                                DateFormat(
                                  'dd/MM/yyyy HH:mm',
                                ).format(timestamp.toDate()),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Botones de acción
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Botón para ver detalles
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF667eea).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.info_outline,
                                size: 18,
                                color: const Color(0xFF667eea),
                              ),
                              onPressed: () => _showUserDetails(userId),
                              tooltip: 'Ver detalles del usuario',
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Botón para vetar/desvetar
                          Container(
                            decoration: BoxDecoration(
                              color: (isVetado ? Colors.green : Colors.red)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon:
                                  _isVettingUser && _vettingUserId == userId
                                      ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color:
                                              isVetado
                                                  ? Colors.green
                                                  : Colors.red,
                                        ),
                                      )
                                      : Icon(
                                        isVetado
                                            ? Icons.check_circle
                                            : Icons.block,
                                        size: 18,
                                        color:
                                            isVetado
                                                ? Colors.green
                                                : Colors.red,
                                      ),
                              onPressed:
                                  _isVettingUser && _vettingUserId == userId
                                      ? null
                                      : () => _toggleUserVetStatus(
                                        userId,
                                        !isVetado,
                                      ),
                              tooltip:
                                  isVetado
                                      ? 'Desvetar usuario'
                                      : 'Vetar usuario',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Contenido del comentario
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade400,
                            Colors.green.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed:
                            viewModel.marcarEncontradoState ==
                                        RequestState.Loading ||
                                    viewModel.marcarEncontradoState ==
                                        RequestState.Loaded
                                ? null
                                : () async {
                                  await viewModel.marcarComoEncontrado(
                                    widget.desaparecido.id!,
                                  );
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child:
                            viewModel.marcarEncontradoState ==
                                    RequestState.Loading
                                ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Marcando como encontrado...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                                : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      viewModel.marcarEncontradoState ==
                                              RequestState.Loaded
                                          ? Icons.check_circle
                                          : Icons.person_search,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      viewModel.marcarEncontradoState ==
                                              RequestState.Loaded
                                          ? 'Marcado como Encontrado'
                                          : 'Marcar como Encontrado',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
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
