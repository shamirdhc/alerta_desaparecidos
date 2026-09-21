import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CommentBubble extends StatefulWidget {
  final String text;
  final Timestamp? timestamp;
  final String phoneNumber;
  final String userId;
  final bool isCurrentUser;
  final bool isLastSent;
  final String? userName;
  final String? estadoModeracion;

  String get getUserId => userId;

  const CommentBubble({
    super.key,
    required this.text,
    required this.timestamp,
    required this.phoneNumber,
    required this.userId,
    required this.isCurrentUser,
    this.isLastSent = false,
    this.userName,
    this.estadoModeracion,
  });

  @override
  State<CommentBubble> createState() => _CommentBubbleState();
}

class _CommentBubbleState extends State<CommentBubble>
    with TickerProviderStateMixin {
  // ⚡ Caché en memoria compartido para eliminar 100% las lecturas N+1 a Firestore
  static final Map<String, String> _userCache = {};

  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  String _displayName = "";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutQuad),
    );

    _scaleController.forward();

    _resolveUserName();
  }

  Future<void> _resolveUserName() async {
    // 1. Si el nombre vino directamente en el documento del comentario (desnormalizado)
    if (widget.userName != null && widget.userName!.trim().isNotEmpty) {
      if (mounted) {
        setState(() {
          _displayName = widget.userName!.trim();
          _isLoading = false;
        });
      }
      return;
    }

    if (widget.userId.isEmpty) {
      if (mounted) {
        setState(() {
          _displayName = "Ciudadano";
          _isLoading = false;
        });
      }
      return;
    }

    // 2. Si ya está en la memoria caché, reutilizarlo al instante (0 lecturas a Firestore)
    if (_userCache.containsKey(widget.userId)) {
      if (mounted) {
        setState(() {
          _displayName = _userCache[widget.userId]!;
          _isLoading = false;
        });
      }
      return;
    }

    // 3. Consulta de rescate para registros antiguos sin desnormalizar
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('ciudadanos')
          .doc(widget.userId)
          .get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data()!;
        final nombres = userData['nombres'] as String? ?? "";
        final apellidos = userData['apellidos'] as String? ?? "";

        final primerNombre = nombres.isNotEmpty ? nombres.split(' ').first : "";
        final primerApellido = apellidos.isNotEmpty ? apellidos.split(' ').first : "";
        final resolved = "$primerNombre $primerApellido".trim();
        final finalName = resolved.isNotEmpty ? resolved : "Ciudadano";

        // Guardar en caché estático
        _userCache[widget.userId] = finalName;

        if (mounted) {
          setState(() {
            _displayName = finalName;
            _isLoading = false;
          });
        }
      } else {
        _userCache[widget.userId] = "Ciudadano";
        if (mounted) {
          setState(() {
            _displayName = "Ciudadano";
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _displayName = "Ciudadano";
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Widget _buildModerationBadge() {
    final estado = widget.estadoModeracion?.toLowerCase();
    if (estado == null) return const SizedBox.shrink();

    Color badgeBg;
    Color badgeFg;
    IconData badgeIcon;
    String badgeLabel;

    switch (estado) {
      case 'aprobado':
        badgeBg = const Color(0xFFD1FAE5);
        badgeFg = const Color(0xFF065F46);
        badgeIcon = Icons.verified_user_rounded;
        badgeLabel = 'Verificada por PNP';
        break;
      case 'reservado':
        badgeBg = const Color(0xFFE0E7FF);
        badgeFg = const Color(0xFF3730A3);
        badgeIcon = Icons.lock_outline_rounded;
        badgeLabel = 'Pista Reservada';
        break;
      case 'pendiente':
      default:
        badgeBg = const Color(0xFFFEF3C7);
        badgeFg = const Color(0xFF92400E);
        badgeIcon = Icons.hourglass_top_rounded;
        badgeLabel = 'En revisión policial';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeFg.withOpacity(0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 12, color: badgeFg),
          const SizedBox(width: 4),
          Text(
            badgeLabel,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: badgeFg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedTimestamp = widget.timestamp != null
        ? DateFormat('dd/MM/yyyy • HH:mm').format(widget.timestamp!.toDate())
        : 'Reciente';

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: EdgeInsets.only(
              left: widget.isCurrentUser ? 44 : 8,
              right: widget.isCurrentUser ? 8 : 44,
              bottom: 10,
            ),
            child: Row(
              mainAxisAlignment: widget.isCurrentUser
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!widget.isCurrentUser) ...[
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF1E3E62),
                    child: Text(
                      _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isCurrentUser
                          ? const Color(0xFF0F2027)
                          : Colors.white,
                      border: Border.all(
                        color: widget.isCurrentUser
                            ? const Color(0xFF1E3E62)
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: widget.isCurrentUser
                            ? const Radius.circular(16)
                            : const Radius.circular(3),
                        bottomRight: widget.isCurrentUser
                            ? const Radius.circular(3)
                            : const Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Moderation Badge si aplica
                        _buildModerationBadge(),

                        // Nombre de autor
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 10,
                                  width: 60,
                                  child: LinearProgressIndicator(
                                    backgroundColor: Color(0xFFE2E8F0),
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _displayName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: widget.isCurrentUser
                                            ? const Color(0xFFFFB300)
                                            : const Color(0xFF1E3E62),
                                      ),
                                    ),
                                    if (widget.isCurrentUser) ...[
                                      const SizedBox(width: 4),
                                      const Text(
                                        '(Tú)',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),

                        // Texto del comentario
                        Text(
                          widget.text,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w400,
                            color: widget.isCurrentUser
                                ? Colors.white
                                : const Color(0xFF1E293B),
                            height: 1.35,
                          ),
                        ),

                        const SizedBox(height: 5),

                        // Fecha y hora
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 11,
                              color: widget.isCurrentUser
                                  ? Colors.white54
                                  : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              formattedTimestamp,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: widget.isCurrentUser
                                    ? Colors.white54
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.isCurrentUser) ...[
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFFFB300),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF0F2027),
                      size: 18,
                    ),
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
