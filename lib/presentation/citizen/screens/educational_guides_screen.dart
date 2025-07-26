import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'video_player_screen.dart';
import 'tutorial_screen.dart'; // Agregar este import

class EducationalGuidesScreen extends StatefulWidget {
  const EducationalGuidesScreen({super.key});

  @override
  State<EducationalGuidesScreen> createState() =>
      _EducationalGuidesScreenState();
}

class _EducationalGuidesScreenState extends State<EducationalGuidesScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  final List<EducationalVideo> _videos = [
    EducationalVideo(
      id: 'quick_guide',
      title: 'Guía Rápida',
      subtitle: 'Pasos esenciales para denunciar',
      description:
          'Todo lo que necesitas saber para actuar rápidamente ante una desaparición. Video optimizado para dispositivos móviles.',
      thumbnailUrl: 'assets/icons/missing-icon.png',
      videoUrl:
          'gs://alerta-desaparecidos-pnp.firebasestorage.app/recursos/videos/denunciar_mininter.mp4',
      duration: '2:30',
      orientation: VideoOrientation.vertical,
      category: VideoCategory.prevention,
      icon: Icons.flash_on,
      color: const Color(0xFF4CAF50),
    ),
    EducationalVideo(
      id: 'complete_guide',
      title: 'Guía Completa',
      subtitle: 'Proceso detallado paso a paso',
      description:
          'Información completa sobre documentación, procedimientos y recursos disponibles para la búsqueda de personas.',
      thumbnailUrl: 'assets/icons/reportar_desaparecido_icon.png',
      videoUrl:
          'gs://alerta-desaparecidos-pnp.firebasestorage.app/recursos/videos/denunciar_web.mp4',
      duration: '8:45',
      orientation: VideoOrientation.horizontal,
      category: VideoCategory.information,
      icon: Icons.info_outline,
      color: const Color(0xFF2196F3),
    ),
    EducationalVideo(
      id: 'alerta_amber',
      title: 'Alerta Amber',
      subtitle: 'Sistema de alerta temprana',
      description:
          'Conoce el sistema de Alerta Amber y cómo funciona para la búsqueda inmediata de menores desaparecidos.',
      thumbnailUrl: 'assets/icons/llamada_icon.png',
      videoUrl:
          'gs://alerta-desaparecidos-pnp.firebasestorage.app/recursos/videos/alerta_amber.mp4',
      duration: '5:15',
      orientation: VideoOrientation.vertical,
      category: VideoCategory.information,
      icon: Icons.warning_amber,
      color: const Color(0xFFFF9800),
    ),
    EducationalVideo(
      id: 'consejos_desaparicion',
      title: 'Consejos de Prevención',
      subtitle: 'Medidas preventivas esenciales',
      description:
          'Consejos prácticos y medidas preventivas para evitar situaciones de desaparición y mantener la seguridad.',
      thumbnailUrl: 'assets/icons/search_icon.png',
      videoUrl:
          'gs://alerta-desaparecidos-pnp.firebasestorage.app/recursos/videos/consejos_desaparicion.mp4',
      duration: '6:30',
      orientation: VideoOrientation.vertical,
      category: VideoCategory.prevention,
      icon: Icons.security,
      color: const Color(0xFF9C27B0),
    ),
    EducationalVideo(
      id: 'consejos_desaparicion2',
      title: 'Consejos Avanzados',
      subtitle: 'Estrategias de seguridad familiar',
      description:
          'Estrategias avanzadas de seguridad familiar y protocolos de comunicación para prevenir desapariciones.',
      thumbnailUrl: 'assets/icons/profile_icon.png',
      videoUrl:
          'gs://alerta-desaparecidos-pnp.firebasestorage.app/recursos/videos/consejos_desaparicion2.mp4',
      duration: '7:45',
      orientation: VideoOrientation.vertical,
      category: VideoCategory.prevention,
      icon: Icons.family_restroom,
      color: const Color(0xFF607D8B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fadeController.forward();
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _slideController.forward();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child:
            _fadeAnimation == null
                ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF1976D2),
                    ),
                  ),
                )
                : FadeTransition(
                  opacity: _fadeAnimation!,
                  child: Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: SlideTransition(
                          position: _slideAnimation!,
                          child: _buildContent(),
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
      width: double.infinity,
      padding: const EdgeInsets.all(20), // Reducido de 24 a 20
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24), // Reducido de 30 a 24
          bottomRight: Radius.circular(24), // Reducido de 30 a 24
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(10), // Reducido de 12 a 10
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 24), // Reducido de 28 a 24
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16), // Reducido de 20 a 16
          const Text(
            'GUÍAS INFORMATIVAS',
            style: TextStyle(
              fontSize: 24, // Reducido de 28 a 24
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2, // Reducido de 1.5 a 1.2
            ),
          ),
          const SizedBox(height: 6), // Reducido de 8 a 6
          const Text(
            'Información esencial para la prevención\ny búsqueda de personas desaparecidas',
            style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.3), // Reducido de 16 a 14 y height de 1.4 a 1.3
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16), // Reducido de 20 a 16
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Reducido de 16,8 a 12,6
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16), // Reducido de 20 a 16
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.security, color: Colors.white, size: 14), // Reducido de 16 a 14
                SizedBox(width: 6), // Reducido de 8 a 6
                Text(
                  'PREVENCIÓN Y SEGURIDAD',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10, // Reducido de 12 a 10
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16), // Reducido de 20 a 16
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Videos Section - más compacto
          const Text(
            'Videos Educativos',
            style: TextStyle(
              fontSize: 20, // Reducido de 22 a 20
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 6), // Reducido de 8 a 6
          Text(
            'Recursos audiovisuales para aprender sobre prevención y procedimientos',
            style: TextStyle(
              fontSize: 12, // Reducido de 14 a 12
              color: Colors.grey[600],
              height: 1.3, // Reducido de 1.4 a 1.3
            ),
          ),
          const SizedBox(height: 20), // Reducido de 24 a 20

          // Video Cards
          ...List.generate(
            _videos.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 16), // Reducido de 20 a 16
              child: _buildVideoCard(_videos[index], index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortalSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(20), // Reducido de 24 a 20
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.25), // Reducido opacidad
            blurRadius: 16, // Reducido de 20 a 16
            spreadRadius: 0,
            offset: const Offset(0, 6), // Reducido de 8 a 6
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20), // Reducido de 24 a 20
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10), // Reducido de 12 a 10
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 24, // Reducido de 28 a 24
                  ),
                ),
                const SizedBox(width: 12), // Reducido de 16 a 12
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Portal Oficial PNP',
                        style: TextStyle(
                          fontSize: 20, // Reducido de 22 a 20
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Registro Nacional de Personas Desaparecidas',
                        style: TextStyle(fontSize: 12, color: Colors.white70), // Reducido de 14 a 12
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20), // Reducido de 24 a 20

            // Portal Principal - Búsqueda de Personas
            _buildContactOption(
              icon: Icons.search,
              title: 'Portal de Búsqueda',
              subtitle: 'desaparecidosenperu.policia.gob.pe',
              color: const Color(0xFF4CAF50),
              onTap:
                  () => _launchUrl(
                    'https://desaparecidosenperu.policia.gob.pe/Desaparecidos/desaparecidos_menor_mujer_hombre',
                  ),
              isEmergency: false,
            ),

            const SizedBox(height: 12), // Reducido de 16 a 12
            // Tutorial Paso a Paso
            _buildContactOption(
              icon: Icons.school,
              title: 'Tutorial Paso a Paso',
              subtitle: 'Guía visual completa para denunciar',
              color: const Color(0xFF4CAF50),
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TutorialScreen(),
                    ),
                  ),
              isEmergency: false,
            ),

            const SizedBox(height: 12), // Reducido de 16 a 12

            // Emergency Contact - Línea 114
            _buildContactOption(
              icon: Icons.phone,
              title: 'Línea 114',
              subtitle: 'Central Única de Denuncias - Disponible 24/7',
              color: const Color(0xFFD32F2F),
              onTap: () => _launchPhone('114'),
              isEmergency: true,
            ),

            const SizedBox(height: 16), // Reducido de 20 a 16

            // Help Text - más compacto
            Container(
              padding: const EdgeInsets.all(12), // Reducido de 16 a 12
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10), // Reducido de 12 a 10
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white70, size: 18), // Reducido de 20 a 18
                  SizedBox(width: 10), // Reducido de 12 a 10
                  Expanded(
                    child: Text(
                      'Registro Nacional con marco legal del Decreto Legislativo N° 1428',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11, // Reducido de 13 a 11
                        fontStyle: FontStyle.italic,
                      ),
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

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isEmergency = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                isEmergency
                    ? color.withOpacity(0.15)
                    : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isEmergency
                      ? color.withOpacity(0.5)
                      : Colors.white.withOpacity(0.2),
              width: isEmergency ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      isEmergency
                          ? color.withOpacity(0.2)
                          : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isEmergency ? color : Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isEmergency ? color : Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color:
                            isEmergency
                                ? color.withOpacity(0.8)
                                : Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: isEmergency ? color.withOpacity(0.7) : Colors.white54,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(EducationalVideo video, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _playVideo(video),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: video.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(video.icon, color: video.color, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            video.subtitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
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
                        color: video.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        video.duration,
                        style: TextStyle(
                          color: video.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  video.description,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildFeatureTag(
                      _getOrientationText(video.orientation),
                      _getOrientationIcon(video.orientation),
                      video.color,
                    ),
                    const SizedBox(width: 12),
                    _buildFeatureTag(
                      _getCategoryText(video.category),
                      Icons.bookmark_outline,
                      video.color,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: video.color,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: video.color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow, color: Colors.white, size: 20),
                          SizedBox(width: 4),
                          Text(
                            'Ver',
                            style: TextStyle(
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTag(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // URL Launcher Methods
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir: $url'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final Uri uri = Uri.parse('tel:$phoneNumber');
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo llamar a: $phoneNumber'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchEmail(String email) async {
    final Uri uri = Uri.parse('mailto:$email');
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir el correo: $email'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _playVideo(EducationalVideo video) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VideoPlayerScreen(video: video)),
    );
  }

  // Helper methods
  String _getOrientationText(VideoOrientation orientation) {
    switch (orientation) {
      case VideoOrientation.vertical:
        return 'Móvil';
      case VideoOrientation.horizontal:
        return 'Pantalla';
    }
  }

  IconData _getOrientationIcon(VideoOrientation orientation) {
    switch (orientation) {
      case VideoOrientation.vertical:
        return Icons.smartphone;
      case VideoOrientation.horizontal:
        return Icons.desktop_windows;
    }
  }

  String _getCategoryText(VideoCategory category) {
    switch (category) {
      case VideoCategory.prevention:
        return 'Prevención';
      case VideoCategory.information:
        return 'Información';
      default:
        return 'General';
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}

// Modelos de datos
class EducationalVideo {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String thumbnailUrl;
  final String videoUrl;
  final String duration;
  final VideoOrientation orientation;
  final VideoCategory category;
  final IconData icon;
  final Color color;

  EducationalVideo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.duration,
    required this.orientation,
    required this.category,
    required this.icon,
    required this.color,
  });
}

enum VideoOrientation { vertical, horizontal }

enum VideoCategory { prevention, information }
