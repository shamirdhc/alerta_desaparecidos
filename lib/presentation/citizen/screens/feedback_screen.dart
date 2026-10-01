import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../services/session_service.dart';
import 'package:alerta_desaparecidos/services/police_preview_mode_service.dart';
import '../../../services/spectator_mode_service.dart';
import '../../../common/localization/app_strings.dart';

class FeedbackScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const FeedbackScreen({super.key, this.onBack});

  @override
  _FeedbackScreenState createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _feedbackController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TabController _tabController;

  // Estado del formulario
  String _selectedPillar = 'idea'; // 'bien', 'fallando', 'idea'
  String _selectedCategory = '📱 Toda la aplicación';
  bool _isSubmitting = false;
  bool _hasText = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _myFeedbackList = [];
  bool _isLoadingHistory = true;

  // Categorías de módulos de la aplicación
  final List<String> _categories = [
    '📱 Toda la aplicación',
    '🔍 Búsqueda y Filtros',
    '🗺️ Mapa y Ubicación',
    '📸 Fotos y Afiches',
    '💬 Pistas y Comentarios',
    '⚡ Rapidez y Rendimiento',
    '🎨 Diseño y Letras',
    '🔔 Alertas y Notificaciones',
  ];

  // Plantillas de 1-toque según el pilar
  final Map<String, List<String>> _quickTemplates = {
    'bien': [
      '👏 Muy fácil de usar',
      '⚡ La app es rápida y clara',
      '💙 Gran iniciativa para salvar vidas',
      '🗺️ El mapa de casos es excelente',
      '📸 Los afiches se ven nítidos',
    ],
    'fallando': [
      '⏳ Tarda mucho en cargar algunas pantallas',
      '📍 El mapa no detecta bien mi ubicación',
      '🔤 Algunas letras se ven pequeñas o difíciles de leer',
      '⚠️ Tuve un error al enviar un comentario',
      '📶 A veces pide conexión aun teniendo internet',
    ],
    'idea': [
      '📲 Botón para compartir directo en grupos de WhatsApp',
      '🔔 Notificación sonora especial para casos urgentes',
      '🔎 Filtro por mi distrito o comisaría más cercana',
      '📷 Permitir subir varias fotos en una pista',
      '🤝 Modo offline para ver alertas guardadas sin datos',
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserFeedback();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadUserFeedback() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final querySnapshot = await _firestore
            .collection('feedback')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .get();

        final list = <Map<String, dynamic>>[];
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          list.add({
            'id': doc.id,
            ...data,
          });
        }

        if (mounted) {
          setState(() {
            _myFeedbackList = list;
            _isLoadingHistory = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingHistory = false;
          });
        }
      }
    } catch (e) {
      print('Error loading feedback: $e');
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _submitFeedback() async {
    if (SpectatorModeService.isSpectator) {
      SpectatorModeService.showLimitationModal(
        context,
        actionTitle: 'Enviar Aporte Cívico',
        description: 'Para enviar sugerencias o aportes cívicos a la PNP, inicia sesión con tu cuenta Google.',
      );
      return;
    }

    if (PolicePreviewModeService.isPreviewActive) {
      PolicePreviewModeService.showRestrictedActionSnackbar(
        context,
        customMessage:
            'Modo Vista Previa: El envío de aportes cívicos está reservado a ciudadanos.',
      );
      return;
    }

    final message = _feedbackController.text.trim();
    if (message.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, escribe un breve detalle de tu aporte.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final isAuthenticated = await SessionService.ensureUserAuthenticated();
      if (!isAuthenticated) {
        throw Exception('Sesión expirada. Por favor, vuelve a iniciar sesión.');
      }

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado.');
      }

      // Obtener datos del ciudadano para guardar solo primer nombre por privacidad
      String citizenName = 'Ciudadano';
      String phoneNumber = 'Sin número';

      try {
        final userDoc = await _firestore
            .collection('ciudadanos')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 8));

        if (userDoc.exists) {
          final data = userDoc.data()!;
          phoneNumber = data['telefono'] ?? 'Sin número';
          final rawNombres = data['nombres'] as String? ?? '';
          if (rawNombres.trim().isNotEmpty) {
            final parts = rawNombres.trim().split(RegExp(r'\s+'));
            if (parts.isNotEmpty) {
              citizenName = parts.first[0].toUpperCase() +
                  (parts.first.length > 1
                      ? parts.first.substring(1).toLowerCase()
                      : '');
            }
          }
        }
      } catch (_) {}

      // Información del dispositivo y versión
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfoPlugin = DeviceInfoPlugin();
      String deviceInfoString = 'Web / Móvil';
      String platformString = 'web';

      if (kIsWeb) {
        final webInfo = await deviceInfoPlugin.webBrowserInfo;
        deviceInfoString = '${webInfo.browserName.name} (Web)';
        platformString = 'web';
      } else {
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfoPlugin.androidInfo;
          deviceInfoString = '${androidInfo.brand} ${androidInfo.model}';
          platformString = 'android';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfoPlugin.iosInfo;
          deviceInfoString = '${iosInfo.name} ${iosInfo.model}';
          platformString = 'ios';
        }
      }

      // Guardar en Firestore con estructura clara
      final feedbackDoc = {
        'userId': user.uid,
        'citizenName': citizenName,
        'phoneNumber': phoneNumber,
        'type': _selectedPillar, // 'bien', 'fallando', 'idea'
        'category': _selectedCategory,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'recibido', // 'recibido', 'en_revision', 'implementado'
        'platform': platformString,
        'deviceInfo': deviceInfoString,
        'appVersion': packageInfo.version,
        'responseMessage': _selectedPillar == 'bien'
            ? '¡Muchas gracias por tus palabras! Nos motivan a seguir dándolo todo.'
            : _selectedPillar == 'fallando'
                ? 'Hemos derivado este incidente al equipo técnico para solucionarlo.'
                : '¡Excelente propuesta! Evaluaremos su viabilidad para las próximas actualizaciones.',
      };

      await _firestore
          .collection('feedback')
          .add(feedbackDoc)
          .timeout(const Duration(seconds: 12));

      _feedbackController.clear();
      await _loadUserFeedback();

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ocurrió un error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '¡Aporte Recibido!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedPillar == 'bien'
                  ? '¡Gracias por tus palabras de aliento! Tu apoyo impulsa a todo el equipo policial.'
                  : _selectedPillar == 'fallando'
                      ? 'Tu reporte fue registrado para que el equipo técnico lo resuelva de inmediato.'
                      : '¡Gran idea! Las mejores funciones de Alerta PNP nacen de sugerencias como la tuya.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.workspace_premium_rounded,
                      color: Color(0xFF2563EB), size: 18),
                  SizedBox(width: 8),
                  Text(
                    '🏅 Colaborador Cívico PNP',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _tabController.animateTo(1); // Ir a la pestaña de "Mis Aportes"
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Ver Mis Aportes',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50 ultra limpio
      body: SafeArea(
        child: Column(
          children: [
            // Cabecera Vanguardista
            _buildHeroHeader(),

            // Barra de pestañas segmentada moderna
            _buildTabBar(),

            // Contenido dinámico según la pestaña
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Pestaña 1: Crear nuevo aporte
                  _buildCreateFeedbackTab(),

                  // Pestaña 2: Historial y trazabilidad de aportes
                  _buildMyFeedbackHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Cabecera Hero con diseño moderno PNP
  Widget _buildHeroHeader() {
    final strings = AppStrings.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                tooltip: strings.isQuechua ? 'Qallariyman kutiy' : 'Volver al Inicio',
                onPressed: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.12),
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withOpacity(0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome,
                              color: Color(0xFF38BDF8), size: 12),
                          const SizedBox(width: 5),
                          Text(
                            strings.coCreationBadge,
                            style: const TextStyle(
                              color: Color(0xFFBAE6FD),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.yourVoiceSavesLives,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            strings.sendYourIdea,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.blue.shade100,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // Barra de pestañas segmentada moderna
  Widget _buildTabBar() {
    final strings = AppStrings.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: const Color(0xFF0F172A),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline_rounded, size: 17),
                const SizedBox(width: 6),
                Text(strings.newContribution),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inbox_rounded, size: 17),
                const SizedBox(width: 6),
                Text(
                  _myFeedbackList.isNotEmpty
                      ? '${strings.myContributions} (${_myFeedbackList.length})'
                      : strings.myContributions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== PESTAÑA 1: NUEVO APORTE ====================
  Widget _buildCreateFeedbackTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (PolicePreviewModeService.isPreviewActive) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF06B6D4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF06B6D4)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Modo Vista Previa: Esta bandeja es para sugerencias ciudadanas. Como policía, el envío está restringido.',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (SpectatorModeService.isSpectator) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1929),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF38BDF8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_rounded, color: Color(0xFF38BDF8), size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Modo Espectador: Puedes leer y navegar las guías y sugerencias. Para enviar un aporte cívico, inicia sesión.',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => SpectatorModeService.promptLogin(context),
                    child: const Text('Acceder', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],

          // PASO 1: Selector de 3 Pilares
          const Text(
            '1. ¿Qué deseas compartir hoy?',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _buildPillarCard(
                  id: 'bien',
                  title: 'Qué hacemos bien',
                  subtitle: 'Elogios y funciones útiles',
                  icon: Icons.thumb_up_alt_rounded,
                  activeGradient: const [Color(0xFF10B981), Color(0xFF059669)],
                  activeColor: const Color(0xFF10B981),
                  badgeEmoji: '💚',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPillarCard(
                  id: 'fallando',
                  title: 'Qué está fallando',
                  subtitle: 'Errores, lentitud o fallas',
                  icon: Icons.warning_amber_rounded,
                  activeGradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                  activeColor: const Color(0xFFF59E0B),
                  badgeEmoji: '⚠️',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPillarCard(
                  id: 'idea',
                  title: 'Tengo una idea',
                  subtitle: 'Nuevas propuestas',
                  icon: Icons.lightbulb_rounded,
                  activeGradient: const [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  activeColor: const Color(0xFF6366F1),
                  badgeEmoji: '💡',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // PASO 2: ¿En qué parte del aplicativo?
          const Text(
            '2. ¿En qué parte del aplicativo?',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                    selectedColor: const Color(0xFF2563EB).withOpacity(0.12),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFCBD5E1),
                      width: isSelected ? 1.5 : 1,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF1E40AF)
                          : const Color(0xFF334155),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // PASO 3: Atajos Rápidos (Zero Friction)
          Row(
            children: const [
              Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 18),
              SizedBox(width: 6),
              Text(
                '3. Atajos rápidos con 1 toque (opcional)',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (_quickTemplates[_selectedPillar] ?? []).map((template) {
              return ActionChip(
                label: Text(template),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                labelStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
                onPressed: () {
                  if (_feedbackController.text.trim().isEmpty) {
                    _feedbackController.text = template;
                  } else {
                    _feedbackController.text =
                        '${_feedbackController.text.trim()} • $template';
                  }
                  setState(() {
                    _hasText = _feedbackController.text.trim().isNotEmpty;
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // PASO 4: Caja de texto descriptiva
          const Text(
            '4. Cuéntanos en detalle tu experiencia',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _hasText
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _feedbackController,
              enabled: !_isSubmitting,
              maxLines: 5,
              minLines: 3,
              cursorColor: const Color(0xFF2563EB),
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF0F172A), // Slate 900 súper nítido
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: _selectedPillar == 'bien'
                    ? '¿Qué función te gustó más o te ayudó recientemente?...'
                    : _selectedPillar == 'fallando'
                        ? 'Describe qué ocurrió, en qué pantalla y qué esperabas ver...'
                        : 'Escribe tu propuesta o sugerencia para mejorar la app...',
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (val) {
                final has = val.trim().isNotEmpty;
                if (has != _hasText) {
                  setState(() {
                    _hasText = has;
                  });
                }
              },
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFDC2626), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Botón de Envío Vanguardista
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitFeedback,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedPillar == 'bien'
                    ? const Color(0xFF059669)
                    : _selectedPillar == 'fallando'
                        ? const Color(0xFFD97706)
                        : const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                shadowColor: const Color(0xFF2563EB).withOpacity(0.4),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Enviar mi aporte a la PNP',
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

          const SizedBox(height: 14),

          // Nota de privacidad y seguridad ciudadana
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_outline_rounded,
                    color: Color(0xFF94A3B8), size: 14),
                SizedBox(width: 6),
                Text(
                  'Tu privacidad está protegida. Solo tu primer nombre es visible.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tarjeta de Pilar (3 opciones clave)
  Widget _buildPillarCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> activeGradient,
    required Color activeColor,
    required String badgeEmoji,
  }) {
    final isSelected = _selectedPillar == id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPillar = id;
          });
        },
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: activeColor.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(colors: activeGradient)
                      : null,
                  color: isSelected ? null : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isSelected
                      ? Icon(icon, color: Colors.white, size: 22)
                      : Text(badgeEmoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? activeColor : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? activeColor.withOpacity(0.85) : const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== PESTAÑA 2: MIS APORTES ====================
  Widget _buildMyFeedbackHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }

    if (_myFeedbackList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Icon(
                  Icons.inbox_outlined,
                  size: 40,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Aún no tienes aportes enviados',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tus opiniones, elogios e ideas para mejorar Alerta PNP aparecerán aquí con su estado de revisión por la Policía.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  _tabController.animateTo(0);
                },
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                label: const Text(
                  'Crear mi primer aporte',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _myFeedbackList.length,
      itemBuilder: (context, index) {
        final item = _myFeedbackList[index];
        final type = item['type'] ?? 'idea';
        final category = item['category'] ?? 'General';
        final message = item['message'] ?? '';
        final response = item['responseMessage'] as String?;
        final status = item['status'] ?? 'recibido';

        Color badgeColor;
        IconData badgeIcon;
        String badgeText;

        if (type == 'bien') {
          badgeColor = const Color(0xFF10B981);
          badgeIcon = Icons.thumb_up_alt_rounded;
          badgeText = 'Lo que hacemos bien';
        } else if (type == 'fallando') {
          badgeColor = const Color(0xFFF59E0B);
          badgeIcon = Icons.warning_amber_rounded;
          badgeText = 'Reporte de fallo';
        } else {
          badgeColor = const Color(0xFF6366F1);
          badgeIcon = Icons.lightbulb_rounded;
          badgeText = 'Idea / Sugerencia';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila de encabezado: Tipo y Estado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, color: badgeColor, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            badgeText,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: status == 'implementado'
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: status == 'implementado'
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            status == 'implementado'
                                ? Icons.task_alt_rounded
                                : Icons.radio_button_checked_rounded,
                            size: 11,
                            color: status == 'implementado'
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            status == 'implementado'
                                ? '¡Implementado! ✨'
                                : 'Recibido por PNP',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: status == 'implementado'
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Categoría
                Row(
                  children: [
                    const Icon(Icons.folder_outlined,
                        color: Color(0xFF94A3B8), size: 14),
                    const SizedBox(width: 5),
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Mensaje del usuario
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF0F172A),
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                // Respuesta del equipo / sistema
                if (response != null && response.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          color: Color(0xFF2563EB),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Equipo Tecnológico PNP:',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E40AF),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                response,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF334155),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
