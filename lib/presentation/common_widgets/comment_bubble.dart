import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CommentBubble extends StatefulWidget {
  final String text;
  final Timestamp? timestamp;
  final String phoneNumber;
  final String userId; // Propiedad userId
  final bool isCurrentUser;
  final bool isLastSent;

  // Getter para userId (ya existe en tu código)
  String get getUserId => userId;

  // Eliminar esta línea que causa el error de duplicación
  // String get userId => userId;

  const CommentBubble({
    Key? key,
    required this.text,
    required this.timestamp,
    required this.phoneNumber,
    required this.userId,
    required this.isCurrentUser,
    this.isLastSent = false,
  }) : super(key: key);

  @override
  State<CommentBubble> createState() => _CommentBubbleState();
}

class _CommentBubbleState extends State<CommentBubble>
    with TickerProviderStateMixin {
  late AnimationController _highlightController;
  late AnimationController _scaleController;
  late Animation<Color?> _highlightAnimation;
  late Animation<double> _scaleAnimation;
  String _userName = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _highlightAnimation = ColorTween(
      begin:
          widget.isCurrentUser
              ? const Color(0xFF4CAF50)
              : const Color(0xFF2196F3),
      end:
          widget.isCurrentUser
              ? const Color(0xFFDCF8C6)
              : const Color(0xFFE3F2FD),
    ).animate(
      CurvedAnimation(parent: _highlightController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Iniciar animaciones si es el último comentario enviado
    if (widget.isLastSent) {
      _scaleController.forward();
      _highlightController.forward();
    } else {
      _scaleController.forward();
    }

    // Obtener el nombre del usuario
    _getUserName();
  }

  // Método para obtener el nombre y apellido del usuario
  Future<void> _getUserName() async {
    if (widget.userId.isEmpty) {
      print('⚠️ [DEBUG] userId está vacío en CommentBubble');
      setState(() {
        _userName = "Usuario";
        _isLoading = false;
      });
      return;
    }

    try {
      print('🔍 [DEBUG] Buscando usuario con ID: ${widget.userId}');
      // Buscar en la colección de ciudadanos por userId
      final docSnapshot =
          await FirebaseFirestore.instance
              .collection('ciudadanos')
              .doc(widget.userId)
              .get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data()!;
        final nombres = userData['nombres'] as String? ?? "";
        final apellidos = userData['apellidos'] as String? ?? "";

        print(
          '✅ [DEBUG] Datos encontrados - nombres: $nombres, apellidos: $apellidos',
        );

        // Obtener el primer nombre y el primer apellido
        final primerNombre = nombres.isNotEmpty ? nombres.split(' ').first : "";
        final primerApellido =
            apellidos.isNotEmpty ? apellidos.split(' ').first : "";

        setState(() {
          _userName = "$primerNombre $primerApellido".trim();
          if (_userName.isEmpty) _userName = "Usuario";
          _isLoading = false;
        });
      } else {
        print(
          '⚠️ [DEBUG] No se encontró documento para userId: ${widget.userId}',
        );
        setState(() {
          _userName = "Usuario";
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ [ERROR] Error al obtener el nombre del usuario: $e');
      setState(() {
        _userName = "Usuario";
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String formattedTimestamp =
        widget.timestamp != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(widget.timestamp!.toDate())
            : 'Unknown time';

    return AnimatedBuilder(
      animation: Listenable.merge([_highlightController, _scaleController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: EdgeInsets.only(
              left: widget.isCurrentUser ? 50 : 8,
              right: widget.isCurrentUser ? 8 : 50,
              bottom: 12,
            ),
            child: Row(
              mainAxisAlignment:
                  widget.isCurrentUser
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!widget.isCurrentUser) ...[
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF2196F3),
                    child: Icon(Icons.person, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient:
                          widget.isLastSent
                              ? LinearGradient(
                                colors:
                                    widget.isCurrentUser
                                        ? [
                                          _highlightAnimation.value ??
                                              const Color(0xFF4CAF50),
                                          const Color(0xFF66BB6A),
                                        ]
                                        : [
                                          _highlightAnimation.value ??
                                              const Color(0xFF2196F3),
                                          const Color(0xFF42A5F5),
                                        ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                              : LinearGradient(
                                colors:
                                    widget.isCurrentUser
                                        ? [
                                          const Color(0xFFDCF8C6),
                                          const Color(0xFFC8E6C9),
                                        ]
                                        : [
                                          const Color(0xFFE3F2FD),
                                          const Color(0xFFBBDEFB),
                                        ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft:
                            widget.isCurrentUser
                                ? const Radius.circular(20)
                                : const Radius.circular(4),
                        bottomRight:
                            widget.isCurrentUser
                                ? const Radius.circular(4)
                                : const Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              widget.isLastSent
                                  ? (widget.isCurrentUser
                                      ? Colors.green.withOpacity(0.3)
                                      : Colors.blue.withOpacity(0.3))
                                  : Colors.black.withOpacity(0.1),
                          blurRadius: widget.isLastSent ? 12 : 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Mostrar nombre y apellido del usuario en lugar del número de teléfono
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child:
                              _isLoading
                                  ? SizedBox(
                                    height: 12,
                                    width: 80,
                                    child: LinearProgressIndicator(
                                      backgroundColor: Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        widget.isCurrentUser
                                            ? Colors.green.shade300
                                            : Colors.blue.shade300,
                                      ),
                                    ),
                                  )
                                  : Text(
                                    _userName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          widget.isLastSent
                                              ? Colors.white.withOpacity(0.9)
                                              : (widget.isCurrentUser
                                                  ? Colors.green.shade700
                                                  : Colors.blue.shade700),
                                    ),
                                  ),
                        ),
                        // Texto del comentario
                        Text(
                          widget.text,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color:
                                widget.isLastSent
                                    ? Colors.white
                                    : Colors.black87,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Fecha y hora en negrita
                        Text(
                          formattedTimestamp,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold, // En negrita
                            color:
                                widget.isLastSent
                                    ? Colors.white.withOpacity(0.8)
                                    : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.isCurrentUser) ...[
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF4CAF50),
                    child: Icon(Icons.person, color: Colors.white, size: 18),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
