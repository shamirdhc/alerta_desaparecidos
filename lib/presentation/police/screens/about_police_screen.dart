import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:ui';

class AboutPoliceScreen extends StatefulWidget {
  const AboutPoliceScreen({super.key});

  @override
  State<AboutPoliceScreen> createState() => _AboutPoliceScreenState();
}

class _AboutPoliceScreenState extends State<AboutPoliceScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0D1B2A), // Azul marino oscuro
              Color(0xFF1B263B), // Azul marino medio
              Color(0xFF415A77), // Azul grisáceo
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildCustomAppBar(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF415A77), Color(0xFF778DA9)],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const FaIcon(
                FontAwesomeIcons.arrowLeft,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Text(
              'ACERCA DEL SISTEMA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B998B), Color(0xFF2D5016)],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const FaIcon(
              FontAwesomeIcons.shield,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildHeroSection(),
          const SizedBox(height: 30),
          _buildDeveloperCard(),
          const SizedBox(height: 20),
          _buildSystemInfoCard(),
          const SizedBox(height: 20),
          _buildTechStackCard(),
          const SizedBox(height: 20),
          _buildMissionCard(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1B998B),
            Color(0xFF2D5016),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B998B).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/icons/logo_pnp_policia.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const FaIcon(
                    FontAwesomeIcons.shield,
                    color: Colors.white,
                    size: 40,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Alerta Desaparecidos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),
          const Text(
            'Sistema Integrado de Búsqueda\nPolicia Nacional del Perú',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperCard() {
    return _buildGlassCard(
      title: 'DESARROLLADOR',
      icon: FontAwesomeIcons.code,
      gradient: const LinearGradient(
        colors: [Color(0xFF457B9D), Color(0xFF1D3557)],
      ),
      child: Column(
        children: [
          _buildInfoRow('Grado y Nombre', 'S3 PNP Shamir Deyvis\nHUERTA CCARHUAS'),
          _buildInfoRow('Unidad', 'Departamento de Investigación\nCriminal de Andahuaylas'),
          _buildInfoRow('Jurisdicción', 'Andahuaylas, Apurímac'),
          _buildInfoRow('Institución', 'Policía Nacional del Perú'),
        ],
      ),
    );
  }

  Widget _buildSystemInfoCard() {
    return _buildGlassCard(
      title: 'INFORMACIÓN DE LA APP',
      icon: FontAwesomeIcons.microchip,
      gradient: const LinearGradient(
        colors: [Color(0xFF8E44AD), Color(0xFF6A4C93)],
      ),
      child: Column(
        children: [
          _buildInfoRow('Versión', '1.0.0+1'),
          _buildInfoRow('Fecha de Lanzamiento', 'Diciembre 2024'),
          _buildInfoRow('Última Actualización', 'Diciembre 2024'),
          _buildInfoRow('Estado', 'Versión Estable'),
        ],
      ),
    );
  }

  Widget _buildTechStackCard() {
    return _buildGlassCard(
      title: 'TECNOLOGÍAS UTILIZADAS',
      icon: FontAwesomeIcons.layerGroup,
      gradient: const LinearGradient(
        colors: [Color(0xFFFF6B35), Color(0xFFE63946)],
      ),
      child: Column(
        children: [
          _buildTechItem('Flutter', 'Framework de desarrollo móvil', FontAwesomeIcons.mobile),
          _buildTechItem('Firebase', 'Backend y base de datos', FontAwesomeIcons.server),
          _buildTechItem('Dart', 'Lenguaje de programación', FontAwesomeIcons.code),
          _buildTechItem('Cloud Firestore', 'Base de datos en tiempo real', FontAwesomeIcons.database),
          _buildTechItem('Firebase Auth', 'Autenticación de usuarios', FontAwesomeIcons.lock),
          _buildTechItem('Google Maps', 'Servicios de geolocalización', FontAwesomeIcons.mapLocationDot),
        ],
      ),
    );
  }

  Widget _buildMissionCard() {
    return _buildGlassCard(
      title: 'MISIÓN INSTITUCIONAL',
      icon: FontAwesomeIcons.bullseye,
      gradient: const LinearGradient(
        colors: [Color(0xFF2D5016), Color(0xFF1B998B)],
      ),
      child: const Column(
        children: [
          Text(
            'Facilitar la búsqueda y localización de personas desaparecidas mediante tecnología innovadora, conectando a las familias con las autoridades competentes y la comunidad en general.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.6,
            ),
            textAlign: TextAlign.justify,
          ),
          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(
                FontAwesomeIcons.heart,
                color: Colors.red,
                size: 20,
              ),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Desarrollado con el compromiso de servir y proteger',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({
    required String title,
    required IconData icon,
    required Gradient gradient,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: gradient.colors.isNotEmpty
                  ? LinearGradient(
                      colors: gradient.colors.map((c) => c.withOpacity(0.2)).toList(),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: FaIcon(icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechItem(String name, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FaIcon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}