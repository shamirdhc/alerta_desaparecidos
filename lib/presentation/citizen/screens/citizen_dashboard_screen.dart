import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CitizenDashboardScreen extends StatefulWidget {
  final Function(int) onNavigateToModule;

  const CitizenDashboardScreen({super.key, required this.onNavigateToModule});

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

  // Datos de los módulos con iconos apropiados y colores vibrantes
  final List<DashboardModule> _modules = [
    DashboardModule(
      title: 'Personas\nDesaparecidas',
      subtitle: 'Ver casos activos',
      icon: FontAwesomeIcons.userMinus,
      color: const Color(0xFFE74C3C), // Rojo vibrante
      gradientColors: [const Color(0xFFE74C3C), const Color(0xFFFF6B6B)],
      index: 0,
    ),
    DashboardModule(
      title: 'Personas\nEncontradas',
      subtitle: 'Ver casos resueltos',
      icon: FontAwesomeIcons.userCheck,
      color: const Color(0xFF27AE60), // Verde vibrante
      gradientColors: [const Color(0xFF27AE60), const Color(0xFF2ECC71)],
      index: 1,
    ),
    DashboardModule(
      title: 'Reportar\nDesaparición',
      subtitle: 'Nuevo reporte',
      icon: FontAwesomeIcons.triangleExclamation,
      color: const Color(0xFFF39C12), // Naranja vibrante
      gradientColors: [const Color(0xFFF39C12), const Color(0xFFE67E22)],
      index: 2,
    ),
    DashboardModule(
      title: 'Buscar Mi\nComisaría',
      subtitle: 'Ubicar comisarías',
      icon: FontAwesomeIcons.locationDot,
      color: const Color(0xFF3498DB), // Azul vibrante
      gradientColors: [const Color(0xFF3498DB), const Color(0xFF5DADE2)],
      index: 3,
    ),
    DashboardModule(
      title: 'Recomendaciones',
      subtitle: 'Consejos y tips',
      icon: FontAwesomeIcons.lightbulb,
      color: const Color(0xFF9B59B6), // Púrpura vibrante
      gradientColors: [const Color(0xFF9B59B6), const Color(0xFFAB7AC7)],
      index: 4,
    ),
    DashboardModule(
      title: 'Agenda de\nComisarías',
      subtitle: 'Directorio policial',
      icon: FontAwesomeIcons.addressBook,
      color: const Color(0xFF1ABC9C), // Verde azulado vibrante
      gradientColors: [const Color(0xFF1ABC9C), const Color(0xFF48C9B0)],
      index: 5,
    ),
    DashboardModule(
      title: 'Guías\nEducativas',
      subtitle: 'Material de apoyo',
      icon: FontAwesomeIcons.graduationCap,
      color: const Color(0xFFE91E63), // Rosa vibrante
      gradientColors: [const Color(0xFFE91E63), const Color(0xFFF06292)],
      index: 6,
    ),
    DashboardModule(
      title: 'Acerca de',
      subtitle: 'Información de la app',
      icon: FontAwesomeIcons.circleInfo,
      color: const Color(0xFF34495E), // Gris azulado vibrante
      gradientColors: [const Color(0xFF34495E), const Color(0xFF5D6D7E)],
      index: 7,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
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
        curve: Curves.easeOutBack, // Cambiar de elasticOut a easeOutBack para más estabilidad
      ),
    );

    // Iniciar animaciones con un pequeño delay para estabilidad
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headerAnimationController.forward();
      Future.delayed(const Duration(milliseconds: 300), () {
        _cardsAnimationController.forward();
      });
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

        final userDoc =
            await FirebaseFirestore.instance
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFF667eea)],
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

              const SizedBox(height: 40),

              // Grid de módulos (sin título)
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
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
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
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
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
                      _isLoadingUserData ? 'Cargando...' : 'Bienvenido',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isLoadingUserData ? '' : _userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isLoadingUserData ? '' : _userPhone,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Icono de notificaciones
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

  Widget _buildModulesGrid() {
    return FadeTransition(
      opacity: _cardsAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(_cardsAnimation),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.9,
          ),
          itemCount: _modules.length,
          itemBuilder: (context, index) {
            final module = _modules[index];
            final delay = index * 100;

            return AnimatedBuilder(
              animation: _cardsAnimation,
              builder: (context, child) {
                // Calcular el progreso de la animación para este elemento específico
                final rawProgress = (_cardsAnimation.value * 1000 - delay) / 600.0;
                final progress = rawProgress.clamp(0.0, 1.0); // IMPORTANTE: Clamp aquí
                final clampedProgress = Curves.elasticOut.transform(progress);

                return Transform.scale(
                  scale: clampedProgress.clamp(0.0, 1.0), // Clamp adicional para scale
                  child: Transform.translate(
                    offset: Offset(0, 50 * (1 - clampedProgress)),
                    child: Opacity(
                      opacity: clampedProgress.clamp(0.0, 1.0), // CRÍTICO: Clamp para opacity
                      child: _buildModuleCard(module),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
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
                color: module.color.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12), // Reducido para más espacio
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono del módulo
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    module.icon,
                    color: Colors.white,
                    size: 22, // Tamaño optimizado
                  ),
                ),

                const SizedBox(height: 4),

                // Título del módulo
                Flexible(
                  child: Text(
                    module.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15, // Aún más grande
                      fontWeight: FontWeight.w800, // Extra bold
                      height: 1.1,
                      letterSpacing: 0.3, // Espaciado entre letras para mejor legibilidad
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 2),

                // Subtítulo
                Flexible(
                  child: Text(
                    module.subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 10, // Tamaño muy reducido
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 4),

                // Flecha de navegación
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(
                    FontAwesomeIcons.chevronRight,
                    color: Colors.white,
                    size: 8, // Tamaño muy pequeño
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
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
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
