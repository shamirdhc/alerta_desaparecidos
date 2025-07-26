import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CitizenDashboardScreen extends StatefulWidget {
  final Function(int) onNavigateToModule;

  const CitizenDashboardScreen({
    super.key,
    required this.onNavigateToModule,
  });

  @override
  State<CitizenDashboardScreen> createState() => _CitizenDashboardScreenState();
}

class _CitizenDashboardScreenState extends State<CitizenDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late AnimationController _cardsAnimationController;
  late Animation<double> _headerAnimation;
  late Animation<double> _cardsAnimation;

  // Variables para datos del usuario
  String _userName = '';
  String _userPhone = '';
  bool _isLoadingUserData = true;

  // Variables para estadísticas
  int _totalMissingCases = 0;
  int _totalFoundCases = 0;
  int _recentCases = 0;
  bool _isLoadingStats = true;

  // Paleta de colores del tema unificado
  static const Color _primaryColor = Color(0xFF667eea);
  static const Color _secondaryColor = Color(0xFF764ba2);
  static const Color _accentColor = Color(0xFF4facfe);

  // Datos de los módulos
  final List<DashboardModule> _modules = [
    DashboardModule(
      title: 'Personas\nDesaparecidas',
      subtitle: 'Ver casos activos',
      icon: FontAwesomeIcons.userMinus,
      color: const Color(0xFFE53E3E),
      gradientColors: [const Color(0xFFE53E3E), const Color(0xFFFC8181)],
      index: 0,
    ),
    DashboardModule(
      title: 'Personas\nEncontradas',
      subtitle: 'Ver casos resueltos',
      icon: FontAwesomeIcons.userCheck,
      color: const Color(0xFF38A169),
      gradientColors: [const Color(0xFF38A169), const Color(0xFF68D391)],
      index: 1,
    ),
    DashboardModule(
      title: 'Reportar\nDesaparición',
      subtitle: 'Nuevo reporte',
      icon: FontAwesomeIcons.exclamationTriangle,
      color: _primaryColor,
      gradientColors: [_primaryColor, _accentColor],
      index: 2,
    ),
    DashboardModule(
      title: 'Buscar Mi\nComisaría',
      subtitle: 'Ubicar comisarías',
      icon: FontAwesomeIcons.mapMarkerAlt,
      color: const Color(0xFF805AD5),
      gradientColors: [const Color(0xFF805AD5), const Color(0xFFB794F6)],
      index: 3,
    ),
    DashboardModule(
      title: 'Recomendaciones',
      subtitle: 'Consejos y tips',
      icon: FontAwesomeIcons.lightbulb,
      color: const Color(0xFFED8936),
      gradientColors: [const Color(0xFFED8936), const Color(0xFFFBD38D)],
      index: 4,
    ),
    DashboardModule(
      title: 'Buscar\nEnsayos',
      subtitle: 'Contenido educativo',
      icon: FontAwesomeIcons.search,
      color: _secondaryColor,
      gradientColors: [_secondaryColor, const Color(0xFF9F7AEA)],
      index: 5,
    ),
    DashboardModule(
      title: 'Guías\nEducativas',
      subtitle: 'Material de apoyo',
      icon: FontAwesomeIcons.graduationCap,
      color: const Color(0xFF9F7AEA),
      gradientColors: [const Color(0xFF9F7AEA), const Color(0xFFD6BCFA)],
      index: 6,
    ),
    DashboardModule(
      title: 'Acerca de',
      subtitle: 'Información de la app',
      icon: FontAwesomeIcons.infoCircle,
      color: const Color(0xFF2D3748),
      gradientColors: [const Color(0xFF2D3748), const Color(0xFF4A5568)],
      index: 7,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
    _loadStatistics();
  }

  void _initializeAnimations() {
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _cardsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _headerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _cardsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardsAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    // Iniciar animaciones
    _headerAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _cardsAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _cardsAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final phoneNumber = user.phoneNumber ?? 'No disponible';

        final userDoc = await FirebaseFirestore.instance
            .collection('ciudadanos')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final nombres = userData['nombres'] ?? '';
          final apellidos = userData['apellidos'] ?? '';
          final fullName = '$nombres $apellidos'.trim();

          if (mounted) {
            setState(() {
              _userName = fullName.isNotEmpty ? fullName : 'Usuario';
              _userPhone = phoneNumber;
              _isLoadingUserData = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error al cargar datos del usuario: $e');
      if (mounted) {
        setState(() {
          _userName = 'Usuario';
          _userPhone = 'No disponible';
          _isLoadingUserData = false;
        });
      }
    }
  }

  Future<void> _loadStatistics() async {
    try {
      // Cargar estadísticas de casos desaparecidos
      final missingSnapshot = await FirebaseFirestore.instance
          .collection('desaparecidos')
          .where('estado', isNotEqualTo: 'encontrado')
          .get();

      // Cargar estadísticas de casos encontrados
      final foundSnapshot = await FirebaseFirestore.instance
          .collection('desaparecidos')
          .where('estado', isEqualTo: 'encontrado')
          .get();

      // Casos recientes (últimos 7 días)
      final DateTime weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentSnapshot = await FirebaseFirestore.instance
          .collection('desaparecidos')
          .where('fechaCreacion', isGreaterThan: weekAgo)
          .get();

      if (mounted) {
        setState(() {
          _totalMissingCases = missingSnapshot.docs.length;
          _totalFoundCases = foundSnapshot.docs.length;
          _recentCases = recentSnapshot.docs.length;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('Error al cargar estadísticas: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
            Color(0xFF667eea),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con información del usuario
              _buildUserHeader(),
              
              const SizedBox(height: 30),
              
              // Estadísticas rápidas
              _buildQuickStats(),
              
              const SizedBox(height: 30),
              
              // Título de módulos
              _buildSectionTitle('Módulos Disponibles'),
              
              const SizedBox(height: 20),
              
              // Grid de módulos
              _buildModulesGrid(),
              
              const SizedBox(height: 30),
              
              // Información adicional
              _buildAdditionalInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader() {
    return FadeTransition(
      opacity: _headerAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.5),
          end: Offset.zero,
        ).animate(_headerAnimation),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar del usuario
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  FontAwesomeIcons.user,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Información del usuario
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLoadingUserData ? 'Cargando...' : '¡Hola, $_userName!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bienvenido al sistema de alerta',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    if (!_isLoadingUserData) ...[
                      const SizedBox(height: 4),
                      Text(
                        _userPhone,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Icono de notificación
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  FontAwesomeIcons.bell,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return FadeTransition(
      opacity: _headerAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(_headerAnimation),
        child: Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Casos Activos',
                _isLoadingStats ? '...' : _totalMissingCases.toString(),
                FontAwesomeIcons.userMinus,
                const Color(0xFFE53E3E),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Encontrados',
                _isLoadingStats ? '...' : _totalFoundCases.toString(),
                FontAwesomeIcons.userCheck,
                const Color(0xFF38A169),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Recientes',
                _isLoadingStats ? '...' : _recentCases.toString(),
                FontAwesomeIcons.clock,
                const Color(0xFFED8936),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return FadeTransition(
      opacity: _cardsAnimation,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildModulesGrid() {
    return AnimatedBuilder(
      animation: _cardsAnimation,
      builder: (context, child) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2, // Aumentado de 1.1 a 1.2 para más espacio vertical
          ),
          itemCount: _modules.length,
          itemBuilder: (context, index) {
            final module = _modules[index];
            final delay = index * 100;
            
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 600 + delay),
              tween: Tween(begin: 0.0, end: _cardsAnimation.value),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                // Asegurar que el valor de opacidad esté en el rango válido
                final clampedValue = value.clamp(0.0, 1.0);
                
                return Transform.scale(
                  scale: clampedValue,
                  child: Transform.translate(
                    offset: Offset(0, 50 * (1 - clampedValue)),
                    child: Opacity(
                      opacity: clampedValue, // Usar valor limitado
                      child: _buildModuleCard(module),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildModuleCard(DashboardModule module) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => widget.onNavigateToModule(module.index),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: module.gradientColors,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: module.color.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16), // Reducido de 20 a 16
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Agregado para evitar overflow
              children: [
                // Icono del módulo
                Container(
                  padding: const EdgeInsets.all(12), // Reducido de 16 a 12
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12), // Reducido de 16 a 12
                  ),
                  child: Icon(
                    module.icon,
                    color: Colors.white,
                    size: 24, // Reducido de 28 a 24
                  ),
                ),
                
                const SizedBox(height: 12), // Reducido de 16 a 12
                
                // Título del módulo
                Flexible( // Agregado Flexible para evitar overflow
                  child: Text(
                    module.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14, // Reducido de 16 a 14
                      fontWeight: FontWeight.bold,
                      height: 1.1, // Reducido de 1.2 a 1.1
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2, // Agregado límite de líneas
                    overflow: TextOverflow.ellipsis, // Agregado manejo de overflow
                  ),
                ),
                
                const SizedBox(height: 6), // Reducido de 8 a 6
                
                // Subtítulo
                Flexible( // Agregado Flexible para evitar overflow
                  child: Text(
                    module.subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11, // Reducido de 12 a 11
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1, // Agregado límite de líneas
                    overflow: TextOverflow.ellipsis, // Agregado manejo de overflow
                  ),
                ),
                
                const SizedBox(height: 8), // Reducido de 12 a 8
                
                // Flecha de navegación
                Container(
                  padding: const EdgeInsets.all(4), // Reducido de 6 a 4
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6), // Reducido de 8 a 6
                  ),
                  child: const Icon(
                    FontAwesomeIcons.chevronRight,
                    color: Colors.white,
                    size: 10, // Reducido de 12 a 10
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    return FadeTransition(
      opacity: _cardsAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  FontAwesomeIcons.shield,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Policía Nacional del Perú',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Sistema oficial de búsqueda y reporte de personas desaparecidas. Tu seguridad es nuestra prioridad.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardModule {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Color> gradientColors;
  final int index;

  DashboardModule({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gradientColors,
    required this.index,
  });
}