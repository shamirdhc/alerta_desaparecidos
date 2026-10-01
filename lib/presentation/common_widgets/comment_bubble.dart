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

  String _sanitizeToOnlyFirstNames(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return "Ciudadano";
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return "Ciudadano";

    if (parts.length == 1) {
      return _capitalize(parts[0]);
    }

    // Detección de nombres compuestos legítimos (ej: "Juan Carlos", "María José", "Ana Paula")
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
      return '${_capitalize(parts[0])} ${_capitalize(parts[1])}';
    }

    // En cualquier otro caso, la segunda palabra es un apellido (ej: "Shamir Huamanchumo", "Pedro Castillo")
    // por lo que mostramos EXCLUSIVAMENTE el primer nombre para preservar privacidad absoluta
    return _capitalize(parts[0]);
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + (s.length > 1 ? s.substring(1).toLowerCase() : '');
  }

  Future<void> _resolveUserName() async {
    // 1. Si el nombre vino directamente en el documento del comentario (desnormalizado)
    if (widget.userName != null && widget.userName!.trim().isNotEmpty) {
      if (mounted) {
        setState(() {
          _displayName = _sanitizeToOnlyFirstNames(widget.userName!);
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

    // 2. Si ya está en la memoria caché, reutilizarlo al instante
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
        String cleanNombres = nombres;
        if (apellidos.trim().isNotEmpty) {
          cleanNombres = cleanNombres.replaceAll(RegExp(RegExp.escape(apellidos.trim()), caseSensitive: false), '').trim();
        }
        final resolved = _sanitizeToOnlyFirstNames(cleanNombres.isNotEmpty ? cleanNombres : nombres);
        final finalName = resolved.isNotEmpty ? resolved : "Ciudadano";

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
    if (estado == 'rechazado') return const SizedBox.shrink();

    // Insignia estética de IA PNP para comentarios validados
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.35),
          width: 0.8,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 11, color: Color(0xFF059669)),
          SizedBox(width: 4),
          Text(
            'Validado por IA PNP',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF059669),
              letterSpacing: 0.2,
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
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withOpacity(0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
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
                      gradient: widget.isCurrentUser
                          ? const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: widget.isCurrentUser ? null : Colors.white,
                      border: Border.all(
                        color: widget.isCurrentUser
                            ? const Color(0xFF3B82F6).withOpacity(0.5)
                            : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: widget.isCurrentUser
                            ? const Radius.circular(18)
                            : const Radius.circular(4),
                        bottomRight: widget.isCurrentUser
                            ? const Radius.circular(4)
                            : const Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.isCurrentUser
                              ? const Color(0xFF2563EB).withOpacity(0.22)
                              : Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
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
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.1,
                                        color: widget.isCurrentUser
                                            ? Colors.white
                                            : const Color(0xFF1E40AF),
                                      ),
                                    ),
                                    if (widget.isCurrentUser) ...[
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.25),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Tú',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
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
                                : const Color(0xFF0F172A),
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Fecha y hora
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 11,
                              color: widget.isCurrentUser
                                ? Colors.white70
                                : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              formattedTimestamp,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: widget.isCurrentUser
                                    ? Colors.white70
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
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1D4ED8).withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 19,
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
