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
      'title': '¡Increíble contribución! 🌟',
      'message':
          'Tu sugerencia es exactamente lo que necesitábamos. Personas como tú hacen que esta aplicación sea mejor cada día. ¡Eres parte del cambio que ayuda a reunir familias!',
      'emoji': '🚀',
    },
    {
      'title': '¡Qué gran observación! 👏',
      'message':
          'Has identificado algo muy importante. Tu atención al detalle nos ayuda a crear una herramienta más efectiva para encontrar personas desaparecidas. ¡Gracias por cuidar de nuestra comunidad!',
      'emoji': '💡',
    },
    {
      'title': '¡Eres un héroe silencioso! 🦸‍♀️',
      'message':
          'Cada recomendación tuya nos acerca más a nuestro objetivo de reunir familias. Tu compromiso con mejorar esta aplicación salva vidas. ¡Estamos orgullosos de tenerte en nuestro equipo!',
      'emoji': '❤️',
    },
    {
      'title': '¡Impacto real! ✨',
      'message':
          'Tu feedback no solo mejora la app, sino que directamente ayuda a las familias que buscan a sus seres queridos. Cada mejora que sugieres puede ser la diferencia entre la desesperanza y el reencuentro.',
      'emoji': '🌈',
    },
    {
      'title': '¡Agente de cambio! 🔥',
      'message':
          'Con usuarios como tú, estamos construyendo la mejor herramienta de búsqueda de personas. Tu visión y dedicación transforman vidas. ¡Sigues siendo increíble!',
      'emoji': '⭐',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
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
    super.dispose();
  }

  Future<void> _loadFeedbackHistory() async {
    try {
      final user = _auth.currentUser;
      print('🔍 Loading feedback for user: ${user?.uid}');
      
      if (user != null) {
        final querySnapshot = await _firestore
            .collection('feedback')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: false)
            .get();

        print('📊 Found ${querySnapshot.docs.length} feedback documents');
        
        final feedbackList = querySnapshot.docs.map((doc) {
          final data = doc.data();
          print('📝 Feedback data: $data');
          return {...data, 'id': doc.id};
        }).toList();

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

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    if (_submitButtonController.isCompleted || _submitButtonController.isDismissed) {
      _submitButtonController.forward();
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener información del usuario
      final prefs = await SharedPreferences.getInstance();
      final phoneNumber = prefs.getString('phone_number') ?? '';

      // Obtener ubicación
      Position? position;
      String departamento = '';
      String provincia = '';
      String distrito = '';

      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (e) {
        print('Error getting location: $e');
      }

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
      final docRef = await _firestore.collection('feedback').add({
        'userId': user.uid,
        'phoneNumber': phoneNumber,
        'text': _feedbackController.text.trim(),
        'type': _feedbackType,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'recibido',
        'latitude': position?.latitude,
        'longitude': position?.longitude,
        'departamento': departamento,
        'provincia': provincia,
        'distrito': distrito,
        'appVersion': packageInfo.version,
        'deviceInfo': deviceInfoString,
        'hasResponse': true,
        'responseTitle': motivationalResponse['title'],
        'responseMessage': motivationalResponse['message'],
        'responseEmoji': motivationalResponse['emoji'],
        'responseTimestamp': FieldValue.serverTimestamp(),
        'priority': _feedbackType == 'problema' ? 'alta' : 'normal',
        'sentiment': 'positive',
      });

      print('✅ Feedback saved with ID: ${docRef.id}');

      // Limpiar el campo de texto
      _feedbackController.clear();

      // Mostrar animaciones de éxito
      if (_successAnimationController.isCompleted || _successAnimationController.isDismissed) {
        _successAnimationController.forward().then((_) {
          _successAnimationController.reverse();
        });
      }

      // Mostrar respuesta motivacional con animación
      await Future.delayed(Duration(milliseconds: 500));
      
      if (_responseAnimationController.isCompleted || _responseAnimationController.isDismissed) {
        _responseAnimationController.forward();
      }

      _showMotivationalDialog(motivationalResponse);

      // Recargar historial después de un pequeño delay para asegurar que se guardó
      await Future.delayed(Duration(milliseconds: 1000));
      await _loadFeedbackHistory();
      
    } catch (e) {
      print('❌ Error submitting feedback: $e');
      setState(() {
        _errorMessage = 'Error al enviar: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
      if (_submitButtonController.isCompleted) {
        _submitButtonController.reverse();
      }
    }
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
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(),
                _buildFeedbackHistory(),
                _buildInputPanel(),
              ],
            ),
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
      height: _feedbackHistory.isEmpty ? 450 : 500,
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
          Expanded(
            child: _feedbackHistory.isEmpty 
                ? _buildEmptyChat() 
                : _buildChatMessages(),
          ),
        ],
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
                        colors: [
                          Colors.blue.shade100,
                          Colors.purple.shade100,
                        ],
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

  Widget _buildChatMessages() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FA),
      ),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        reverse: false,
        itemCount: _feedbackHistory.length * 2, // Mensaje del usuario + respuesta
        itemBuilder: (context, index) {
          final feedbackIndex = index ~/ 2;
          final isUserMessage = index % 2 == 0;
          
          if (feedbackIndex >= _feedbackHistory.length) return SizedBox.shrink();
          
          final feedback = _feedbackHistory[feedbackIndex];
          
          if (isUserMessage) {
            return _buildUserMessage(feedback, feedbackIndex);
          } else {
            return _buildSystemResponse(feedback, feedbackIndex);
          }
        },
      ),
    );
  }

  Widget _buildUserMessage(Map<String, dynamic> feedback, int index) {
    final timestamp = feedback['timestamp'] as Timestamp?;
    final date = timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp.millisecondsSinceEpoch)
        : DateTime.now();

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
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
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
                    feedback['text'] ?? '',
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
    if (feedback['hasResponse'] != true) return SizedBox.shrink();

    final responseTimestamp = feedback['responseTimestamp'] as Timestamp?;
    final date = responseTimestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(responseTimestamp.millisecondsSinceEpoch)
        : DateTime.now();

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
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                  feedback['responseEmoji'] ?? '💙',
                                  style: TextStyle(fontSize: 20),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    feedback['responseTitle'] ?? '¡Gracias por tu contribución!',
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
                              feedback['responseMessage'] ?? 'Tu feedback es muy valioso para nosotros.',
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

  Widget _buildInputPanel() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de la sección
          Row(
            children: [
              Icon(Icons.edit_note, color: Colors.blue.shade600, size: 24),
              SizedBox(width: 10),
              Text(
                'Comparte tu visión',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // Selector de tipo
          _buildTypeSelector(),

          SizedBox(height: 20),

          // Campo de texto
          _buildTextInput(),

          // Mensaje de error
          if (_errorMessage != null) ...[
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(12),
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
