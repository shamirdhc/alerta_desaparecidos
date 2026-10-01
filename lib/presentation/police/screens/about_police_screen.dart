import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import '../../../core/services/error_telemetry_service.dart';
import '../../superadmin/screens/superadmin_analytics_screen.dart';
import '../../superadmin/screens/superadmin_sync_monitor_screen.dart';

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
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkSuperAdminStatus();
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

  Future<void> _checkSuperAdminStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('userRole') ?? prefs.getString('user_role');
      if (role != 'police') {
        if (mounted) {
          setState(() {
            _isSuperAdmin = false;
          });
        }
        return;
      }
      final isSuperAdminPref = prefs.getBool('is_superadmin') ?? false;
      final currentUser = FirebaseAuth.instance.currentUser;
      final email = (currentUser?.email ?? '').trim().toLowerCase();
      final isOwnerEmail = email == 'shamirdhc2022@gmail.com';

      if (mounted) {
        setState(() {
          _isSuperAdmin = isSuperAdminPref || isOwnerEmail;
        });
      }
    } catch (_) {}
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Column(
            children: [
              _buildHeroSection(),
              const SizedBox(height: 30),
              _buildDisclaimerCard(), // NUEVO: Disclaimer de independencia
              const SizedBox(height: 20),
              _buildDeveloperCard(),
              const SizedBox(height: 20),
              _buildLogisticsCard(),
              const SizedBox(height: 20),
              _buildSystemInfoCard(),
              const SizedBox(height: 20),
              _buildTechStackCard(),
              const SizedBox(height: 20),
              _buildMissionCard(),
              if (_isSuperAdmin) ...[
                const SizedBox(height: 20),
                _buildDiagnosticCard(),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
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
                'assets/icons/icon_police.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const FaIcon(
                    FontAwesomeIcons.search, // CAMBIADO: Icono genérico de búsqueda
                    color: Colors.white,
                    size: 40,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Alerta Desaparecidos Perú', // CAMBIADO: Removido "PNP"
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
            'Sistema Nacional de Búsqueda\nPersonas Desaparecidas', // CAMBIADO: Removido referencias a PNP
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
          _buildInfoRow('Grado y Nombre', 'S2 PNP Shamir Deyvis\nHUERTA CCARHUAS'),
          _buildInfoRow('Rol', 'Desarrollador y Creador del Sistema'),
          _buildInfoRow('Unidad Policial', 'DEPITPTIM Andahuaylas\n(Trata de Personas y Tráfico Ilícito de Migrantes)'),
          _buildInfoRow('Jurisdicción', 'Distrito Andahuaylas, Prov. Andahuaylas, Apurímac'),
          _buildInfoRow('Institución', 'Policía Nacional del Perú'),
        ],
      ),
    );
  }

  Widget _buildLogisticsCard() {
    return _buildGlassCard(
      title: 'APOYO LOGÍSTICO Y DIFUSIÓN',
      icon: FontAwesomeIcons.bullhorn,
      gradient: const LinearGradient(
        colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
      ),
      child: Column(
        children: [
          _buildInfoRow('Grado y Nombre', 'S2 PNP Noé\nHURTADO CCARHUAS'),
          _buildInfoRow('Rol', 'Apoyo Logístico y Difusión del Aplicativo'),
          _buildInfoRow('Unidad Policial', 'Comisaría PNP Talavera'),
          _buildInfoRow('Jurisdicción', 'Distrito Talavera, Prov. Andahuaylas, Apurímac'),
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

  Widget _buildDisclaimerCard() {
    return _buildGlassCard(
      title: 'AVISO IMPORTANTE',
      icon: FontAwesomeIcons.exclamationTriangle,
      gradient: const LinearGradient(
        colors: [Color(0xFFE63946), Color(0xFFDC2626)],
      ),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: const Column(
          children: [
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.info,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'APLICACIÓN INDEPENDIENTE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            Text(
              'IMPORTANTE: Esta es una aplicación ciudadana independiente que facilita la comunicación con autoridades competentes. NO es una aplicación oficial de ninguna institución gubernamental.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 10),
            Text(
              'Esta aplicación fue desarrollada de forma independiente con el objetivo de ayudar en la búsqueda de personas desaparecidas.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticCard() {
    return _buildGlassCard(
      title: 'PANEL SUPERADMIN: DIAGNÓSTICO',
      icon: FontAwesomeIcons.terminal,
      gradient: const LinearGradient(
        colors: [Color(0xFF0F3443), Color(0xFF34E89E)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Herramienta de soporte y telemetría de errores del sistema en Firestore. Exclusivo para SuperAdministrador.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final summary = await ErrorTelemetryService().generateDiagnosticSummary();
                await Clipboard.setData(ClipboardData(text: summary));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: const [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text('¡Diagnóstico copiado al portapapeles! Puedes pegarlo al desarrollador.'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.teal.shade700,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy, color: Colors.black87, size: 18),
              label: const Text(
                'Copiar Diagnóstico del Dispositivo',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34E89E),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SuperAdminSyncMonitorScreen()),
                );
              },
              icon: const Icon(Icons.sync_alt_rounded, color: Colors.black87, size: 20),
              label: const Text(
                'Centro de Sincronización PNP (En Vivo)',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SuperAdminAnalyticsScreen()),
                );
              },
              icon: const Icon(Icons.bar_chart, color: Colors.cyanAccent, size: 20),
              label: const Text(
                'Panel de Estadísticas y Reportes PDF',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.cyanAccent),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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