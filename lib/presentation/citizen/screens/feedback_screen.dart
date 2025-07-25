import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:math';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({Key? key}) : super(key: key);

  @override
  _FeedbackScreenState createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with TickerProviderStateMixin {
  final TextEditingController _feedbackController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _feedbackHistory = [];
  bool _isSubmitting = false;
  String? _errorMessage;
  String _feedbackType = 'sugerencia';

  late AnimationController _submitButtonController;
  late AnimationController _successAnimationController;
  late AnimationController _responseAnimationController;
  late Animation<double> _submitButtonAnimation;
  late Animation<double> _successAnimation;
  late Animation<double> _responseAnimation;
  late Animation<Offset> _responseSlideAnimation;

  // Mensajes motivadores para respuestas automáticas
  final List<Map<String, String>> _motivationalResponses = [
    {
      'title': '¡Excelente! 🌟',
      'message': 'Tu sugerencia nos ayuda a mejorar. ¡Gracias!',
      'emoji': '🚀',
    },
    {
      'title': '¡Muy útil! 👏',
      'message': 'Gran observación. Trabajaremos en ello.',
      'emoji': '💡',
    },
    {
      'title': '¡Genial! 🦸‍♀️',
      'message': 'Tu feedback es valioso. ¡Seguimos mejorando!',
      'emoji': '❤️',
    },
    {
      'title': '¡Perfecto! ⚡',
      'message': 'Identificaste algo importante. ¡Bien hecho!',
      'emoji': '🎯',
    },
    {
      'title': '¡Increíble! 🌈',
      'message': 'Tu aporte marca la diferencia. ¡Gracias!',
      'emoji': '⭐',
    },
  ];

  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFeedbackHistory();
    });
  }

  void _initializeAnimations() {
    _submitButtonController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _successAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _responseAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _submitButtonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _submitButtonController, curve: Curves.easeInOut),
    );

    _successAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _responseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _responseAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    _responseSlideAnimation = Tween<Offset>(
      begin: Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _responseAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _submitButtonController.dispose();
    _successAnimationController.dispose();
    _responseAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFeedbackHistory() async {
    try {
      final user = _auth.currentUser;
      print('🔍 Loading feedback for user: ${user?.uid}');

      if (user != null) {
        final querySnapshot =
            await _firestore
                .collection('feedback')
                .where('userId', isEqualTo: user.uid)
                .orderBy('timestamp', descending: false)
                .get();

        print('📊 Found ${querySnapshot.docs.length} feedback documents');

        final feedbackList = <Map<String, dynamic>>[];

        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          print('📝 Feedback data: $data');

          // Agregar mensaje del usuario
          feedbackList.add({
            'id': doc.id,
            'message': data['message'],
            'text': data['message'], // Para compatibilidad
            'type': data['type'],
            'timestamp': data['timestamp'],
            'isUser': true,
          });

          // Agregar respuesta automática si existe
          if (data['responseMessage'] != null) {
            feedbackList.add({
              'id': '${doc.id}_response',
              'responseMessage': data['responseMessage'],
              'responseTitle': data['responseTitle'],
              'responseEmoji': data['responseEmoji'],
              'responseTimestamp': data['responseTimestamp'],
              'isUser': false,
              'hasResponse': true,
            });
          }
        }

        setState(() {
          _feedbackHistory = feedbackList;
        });

        print('✅ Feedback history updated: ${_feedbackHistory.length} items');
      } else {
        print('❌ No user authenticated');
      }
    } catch (e) {
      print('❌ Error loading feedback history: $e');
      setState(() {
        _errorMessage = 'Error al cargar conversaciones: ${e.toString()}';
      });
    }
  }

  Map<String, String> _getRandomMotivationalResponse() {
    final random = Random();
    return _motivationalResponses[random.nextInt(
      _motivationalResponses.length,
    )];
  }

  Future<void> _submitFeedback() async {
    if (_feedbackController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, escribe tu comentario';
      });
      return;
    }

    if (_feedbackType.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, selecciona un tipo';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      _submitButtonController.forward().then((_) {
        _submitButtonController.reverse();
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener información del usuario actual
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final userData = userDoc.data();
      final phoneNumber = userData?['phoneNumber'] ?? 'Anónimo';

      // Obtener información de la aplicación
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfoPlugin = DeviceInfoPlugin();
      String deviceInfoString = '';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceInfoString = '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceInfoString = '${iosInfo.name} ${iosInfo.model}';
      }

      // Generar respuesta motivacional automática
      final motivationalResponse = _getRandomMotivationalResponse();

      print('💾 Saving feedback to Firestore...');

      // Guardar en Firestore con respuesta automática
      final docRef = await FirebaseFirestore.instance
          .collection('feedback')
          .add({
            'userId': user.uid,
            'phoneNumber': phoneNumber,
            'type': _feedbackType,
            'message': _feedbackController.text.trim(),
            'timestamp': FieldValue.serverTimestamp(),
            'deviceInfo': deviceInfoString,
            'appVersion': packageInfo.version,
            'platform': Platform.operatingSystem,
            'responseTitle': motivationalResponse['title'],
            'responseMessage': motivationalResponse['message'],
            'responseEmoji': motivationalResponse['emoji'],
            'responseTimestamp': FieldValue.serverTimestamp(),
            'priority': _feedbackType == 'problema' ? 'alta' : 'normal',
            'sentiment': 'positive',
          });

      print('✅ Feedback saved with ID: ${docRef.id}');

      // Agregar mensaje del usuario al historial local
      final userMessage = {
        'text': _feedbackController.text.trim(),
        'isUser': true,
        'timestamp': DateTime.now(),
        'type': _feedbackType,
      };

      // Agregar respuesta automática del sistema (más corta)
      final systemMessage = {
        'text': motivationalResponse['message']!,
        'isUser': false,
        'timestamp': DateTime.now().add(Duration(seconds: 1)),
        'type': 'response',
        'emoji': motivationalResponse['emoji'],
        'title': motivationalResponse['title'],
        'hasResponse': true,
        'responseMessage': motivationalResponse['message'],
        'responseTitle': motivationalResponse['title'],
        'responseEmoji': motivationalResponse['emoji'],
        'responseTimestamp': DateTime.now().add(Duration(seconds: 1)),
      };

      setState(() {
        _feedbackHistory.add(userMessage);
        _feedbackHistory.add(systemMessage);
      });

      // Limpiar el campo de texto
      _feedbackController.clear();
      _feedbackType = '';

      // Scroll automático mejorado - ir al final después de agregar mensajes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          // Usar un delay para asegurar que el contenido se haya renderizado
          Future.delayed(Duration(milliseconds: 100), () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
              );
            }
          });
        }
      });

      // Mostrar animaciones de éxito
      if (_successAnimationController.isCompleted ||
          _successAnimationController.isDismissed) {
        _successAnimationController.forward().then((_) {
          _successAnimationController.reverse();
        });
      }

      _showSuccessMessage('¡Gracias por tu feedback! 💙');
    } catch (e) {
      print('❌ Error submitting feedback: $e');
      setState(() {
        _errorMessage = 'Error al enviar. Inténtalo de nuevo.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showMotivationalDialog(Map<String, String> response) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return SlideTransition(
          position: _responseSlideAnimation,
          child: ScaleTransition(
            scale: _responseAnimation,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.purple.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Emoji animado
                    TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 1000),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Transform.rotate(
                            angle: value * 2 * pi,
                            child: Text(
                              response['emoji']!,
                              style: TextStyle(fontSize: 60),
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 20),

                    // Título
                    Text(
                      response['title']!,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 15),

                    // Mensaje
                    Text(
                      response['message']!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 25),

                    // Botón de cerrar con gradiente
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_responseAnimationController.isCompleted) {
                            _responseAnimationController.reverse().then((_) {
                              if (mounted) {
                                Navigator.of(context).pop();
                              }
                            });
                          } else {
                            if (mounted) {
                              Navigator.of(context).pop();
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade600,
                                Colors.purple.shade600,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: Text(
                              '¡Seguiré ayudando! 💪',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F7FA), Color(0xFFE4EDF5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Contenido principal expandible
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [_buildHeader(), _buildFeedbackHistory()],
                  ),
                ),
              ),

              // Caja de envío fija en la parte inferior - más compacta
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 15,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Indicador visual flotante - más pequeño
                      Center(
                        child: Container(
                          width: 32,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),

                      // Título de la sección - más compacto
                      Row(
                        children: [
                          Icon(
                            Icons.edit_note,
                            color: Colors.blue.shade600,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Comparte tu visión',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 16),

                      // Selector de tipo
                      _buildTypeSelector(),

                      SizedBox(height: 16),

                      // Campo de texto
                      _buildTextInput(),

                      // Mensaje de error
                      if (_errorMessage != null) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade600,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.purple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.favorite, color: Colors.white, size: 30),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Centro de Recomendaciones',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Tu voz transforma vidas',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cada sugerencia tuya nos ayuda a reunir más familias. ¡Eres parte de algo extraordinario!',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.95),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackHistory() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildChatHeader(),
          // Conversación completa sin scroll interno
          _feedbackHistory.isEmpty
              ? Container(
                  height: 400,
                  child: _buildEmptyChat(),
                )
              : Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Mensaje de incentivo del sistema solo si no hay mensajes del usuario
                      if (!_hasUserMessages()) _buildWelcomeMessage(),
                      // Mensajes del chat
                      ..._buildAllChatMessages(),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  bool _hasUserMessages() {
    return _feedbackHistory.any((feedback) => feedback['isUser'] == true);
  }

  Widget _buildWelcomeMessage() {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 1000),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(-30 * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 20, right: 50),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar del sistema
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.support_agent,
                color: Colors.white,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timestamp
                  Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text(
                      'Ahora',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  // Mensaje de bienvenida
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.purple.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(5),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border.all(color: Colors.blue.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Encabezado con emoji y título
                        Row(
                          children: [
                            Text(
                              '👋',
                              style: TextStyle(fontSize: 20),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '¡Hola! Bienvenido/a',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        // Mensaje de incentivo
                        Text(
                          '¡Nos encantaría conocer tu opinión! 🌟\n\nTu primera sugerencia, reporte de problema o idea de mejora nos ayuda a hacer que esta app sea aún mejor para reunir familias.\n\n¿Qué te parece si compartes tu experiencia con nosotros?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 12),
                        // Botones de acción rápida
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildQuickActionChip(
                              '💡 Sugerencia',
                              Colors.blue,
                              () => setState(() => _feedbackType = 'sugerencia'),
                            ),
                            _buildQuickActionChip(
                              '🔧 Mejora',
                              Colors.purple,
                              () => setState(() => _feedbackType = 'mejora'),
                            ),
                            _buildQuickActionChip(
                              '⚠️ Problema',
                              Colors.red,
                              () => setState(() => _feedbackType = 'problema'),
                            ),
                          ],
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
  }

  Widget _buildQuickActionChip(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.purple.shade600],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.support_agent, color: Colors.white, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conversación con Soporte',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Siempre en línea para ayudarte',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  'En línea',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
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

  Widget _buildEmptyChat() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 20),
          TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 2000),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade100, Colors.purple.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 15,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 50,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 20),
          Text(
            '¡Inicia tu primera conversación!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Text(
            'Comparte tus ideas, reporta problemas o sugiere mejoras.\nNuestro equipo te responderá inmediatamente.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.purple.shade50],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lightbulb, color: Colors.orange.shade600, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: Cada mensaje tuyo nos ayuda a mejorar la app y reunir más familias',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  List<Widget> _buildAllChatMessages() {
    List<Widget> messages = [];

    for (int i = 0; i < _feedbackHistory.length; i++) {
      final feedback = _feedbackHistory[i];

      // Si es un mensaje del usuario
      if (feedback['isUser'] == true) {
        messages.add(_buildUserMessage(feedback, i));
      }
      // Si es una respuesta del sistema
      else if (feedback['isUser'] == false) {
        messages.add(_buildSystemResponse(feedback, i));
      }
    }

    return messages;
  }

  Widget _buildUserMessage(Map<String, dynamic> feedback, int index) {
    // Manejar tanto DateTime como Timestamp
    DateTime date;
    final timestamp = feedback['timestamp'];

    if (timestamp is Timestamp) {
      date = DateTime.fromMillisecondsSinceEpoch(
        timestamp.millisecondsSinceEpoch,
      );
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      date = DateTime.now();
    }

    // Determinar color y icono según tipo
    Color typeColor;
    IconData typeIcon;
    String typeLabel;

    switch (feedback['type']) {
      case 'problema':
        typeColor = Colors.red.shade600;
        typeIcon = Icons.error_outline;
        typeLabel = 'Problema';
        break;
      case 'mejora':
        typeColor = Colors.purple.shade600;
        typeIcon = Icons.lightbulb_outline;
        typeLabel = 'Mejora';
        break;
      case 'sugerencia':
      default:
        typeColor = Colors.blue.shade600;
        typeIcon = Icons.tips_and_updates_outlined;
        typeLabel = 'Sugerencia';
        break;
    }

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 15, left: 50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Timestamp
            Padding(
              padding: EdgeInsets.only(right: 15, bottom: 5),
              child: Text(
                '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
            // Mensaje del usuario
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [typeColor, typeColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: typeColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Etiqueta de tipo
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(typeIcon, size: 14, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  // Texto del mensaje
                  Text(
                    feedback['message'] ?? feedback['text'] ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemResponse(Map<String, dynamic> feedback, int index) {
    // Verificar si tiene respuesta (formato de Firestore o local)
    final hasResponseMessage = feedback['responseMessage'] != null || 
                              feedback['text'] != null;
    
    if (!hasResponseMessage) return SizedBox.shrink();

    // Manejar tanto DateTime como Timestamp
    DateTime date;
    final responseTimestamp = feedback['responseTimestamp'] ?? feedback['timestamp'];

    if (responseTimestamp is Timestamp) {
      date = DateTime.fromMillisecondsSinceEpoch(
        responseTimestamp.millisecondsSinceEpoch,
      );
    } else if (responseTimestamp is DateTime) {
      date = responseTimestamp;
    } else {
      date = DateTime.now();
    }

    // Obtener el mensaje de respuesta
    final responseMessage = feedback['responseMessage'] ?? feedback['text'] ?? '';
    final responseTitle = feedback['responseTitle'] ?? feedback['title'] ?? '¡Gracias por tu contribución!';
    final responseEmoji = feedback['responseEmoji'] ?? feedback['emoji'] ?? '💙';

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 500 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(-50 * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 20, right: 50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar del sistema
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.blue.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.support_agent,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timestamp
                      Padding(
                        padding: EdgeInsets.only(bottom: 5),
                        child: Text(
                          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      // Respuesta del sistema
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(5),
                            topRight: Radius.circular(20),
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Encabezado con emoji y título
                            Row(
                              children: [
                                Text(
                                  responseEmoji,
                                  style: TextStyle(fontSize: 20),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    responseTitle,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            // Mensaje de respuesta
                            Text(
                              responseMessage,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                            SizedBox(height: 8),
                            // Estado de lectura
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(
                                  Icons.done_all,
                                  size: 16,
                                  color: Colors.blue.shade400,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Leído',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade400,
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de recomendación:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTypeChip(
                label: 'Sugerencia',
                icon: Icons.tips_and_updates_outlined,
                color: Colors.blue,
                isSelected: _feedbackType == 'sugerencia',
                onTap: () => setState(() => _feedbackType = 'sugerencia'),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildTypeChip(
                label: 'Problema',
                icon: Icons.error_outline,
                color: Colors.red,
                isSelected: _feedbackType == 'problema',
                onTap: () => setState(() => _feedbackType = 'problema'),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildTypeChip(
                label: 'Mejora',
                icon: Icons.lightbulb_outline,
                color: Colors.purple,
                isSelected: _feedbackType == 'mejora',
                onTap: () => setState(() => _feedbackType = 'mejora'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextInput() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade50, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              _errorMessage != null
                  ? Colors.red.shade300
                  : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _feedbackController,
              enabled: !_isSubmitting,
              maxLines: null,
              minLines: 4,
              decoration: InputDecoration(
                hintText:
                    _isSubmitting
                        ? 'Enviando tu valiosa recomendación...'
                        : '¿Cómo podemos hacer que esta app sea aún más increíble? Tu opinión puede cambiar vidas...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(20),
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),

          // Botón de envío mejorado
          Padding(
            padding: EdgeInsets.only(right: 12, bottom: 12),
            child: AnimatedBuilder(
              animation: _submitButtonAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _submitButtonAnimation.value,
                  child: child,
                );
              },
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSubmitting ? null : _submitFeedback,
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.purple.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.4),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child:
                        _isSubmitting
                            ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : Icon(
                              Icons.rocket_launch,
                              color: Colors.white,
                              size: 24,
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

  Widget _buildTypeChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient:
              isSelected
                  ? LinearGradient(
                    colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                  : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : Colors.grey.shade600,
            ),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
