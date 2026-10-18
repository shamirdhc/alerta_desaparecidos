import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'package:intl/intl.dart';

class PoliceProfileScreen extends StatefulWidget {
  const PoliceProfileScreen({super.key});

  @override
  State<PoliceProfileScreen> createState() => _PoliceProfileScreenState();
}

class _PoliceProfileScreenState extends State<PoliceProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Map<String, dynamic>? userProfile;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserProfile();
  }

  void _initializeAnimations() {
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

  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. Buscar en la colección 'policias' usando el UID del usuario
        DocumentSnapshot<Map<String, dynamic>> doc =
            await FirebaseFirestore.instance
                .collection('policias')
                .doc(user.uid)
                .get();

        Map<String, dynamic>? data;

        if (doc.exists && doc.data() != null) {
          data = doc.data();
        } else if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
          // 2. Fallback: Buscar por número de teléfono del usuario
          final phoneQuery = await FirebaseFirestore.instance
              .collection('policias')
              .where('telefono', isEqualTo: user.phoneNumber)
              .limit(1)
              .get();

          if (phoneQuery.docs.isNotEmpty) {
            data = phoneQuery.docs.first.data();
            // Sincronizar documento bajo doc(user.uid)
            try {
              await FirebaseFirestore.instance
                  .collection('policias')
                  .doc(user.uid)
                  .set(data, SetOptions(merge: true));
            } catch (_) {}
          }
        }

        if (!mounted) return;
        if (data != null) {
          setState(() {
            userProfile = data;
            isLoading = false;
          });
        } else {
          // Si no se encuentra en policias, mostrar datos genéricos de emergencia
          setState(() {
            userProfile = {
              'nombre': 'Oficial',
              'apellido': 'PNP',
              'rango': 'Efectivo Policial',
              'unidad': 'Unidad de Investigación Policial',
              'numero_cip': 'CIP-${user.uid.substring(0, 6).toUpperCase()}',
              'telefono': user.phoneNumber ?? 'No especificado',
              'departamento': 'No especificado',
              'admin': false,
              'rol': 'policia',
            };
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar perfil: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'No especificado';

    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return DateFormat('dd/MM/yyyy HH:mm').format(date);
      } else if (timestamp is String) {
        return timestamp;
      }
      return 'Formato no válido';
    } catch (e) {
      return 'Error en fecha';
    }
  }

  String _getFullName() {
    final nombre = userProfile?['nombre'] ?? '';
    final apellido = userProfile?['apellido'] ?? '';
    return '$nombre $apellido'.trim();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF415A77)],
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
                  child:
                      isLoading
                          ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : FadeTransition(
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
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
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
              'MI PERFIL POLICIAL',
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
            child: FaIcon(
              userProfile?['admin'] == true
                  ? FontAwesomeIcons.userShield
                  : FontAwesomeIcons.userTie,
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
          _buildProfileHeader(),
          const SizedBox(height: 30),
          _buildPersonalInfoCard(),
          const SizedBox(height: 20),
          _buildProfessionalInfoCard(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              userProfile?['admin'] == true
                  ? [const Color(0xFFFF6B35), const Color(0xFFE63946)]
                  : [const Color(0xFF1B998B), const Color(0xFF2D5016)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: (userProfile?['admin'] == true
                    ? const Color(0xFFFF6B35)
                    : const Color(0xFF1B998B))
                .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 3,
              ),
            ),
            child: CircleAvatar(
              radius: 47,
              backgroundColor: Colors.transparent,
              child: FaIcon(
                userProfile?['admin'] == true
                    ? FontAwesomeIcons.userShield
                    : FontAwesomeIcons.userTie,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _getFullName().isNotEmpty ? _getFullName() : 'Usuario Policial',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            userProfile?['rango'] ?? 'Oficial de Policía',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (userProfile?['admin'] == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.3),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.red.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: const Text(
                'ADMINISTRADOR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'CIP: ${userProfile?['numero_cip'] ?? 'No especificado'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return _buildGlassCard(
      title: 'INFORMACIÓN PERSONAL',
      icon: FontAwesomeIcons.idCard,
      gradient: const LinearGradient(
        colors: [Color(0xFF457B9D), Color(0xFF1D3557)],
      ),
      child: Column(
        children: [
          _buildInfoRow('Nombre', userProfile?['nombre'] ?? 'No especificado'),
          _buildInfoRow(
            'Apellido',
            userProfile?['apellido'] ?? 'No especificado',
          ),
          _buildInfoRow(
            'Teléfono',
            userProfile?['telefono'] ?? 'No especificado',
          ),
          _buildInfoRow(
            'Departamento',
            userProfile?['departamento'] ?? 'No especificado',
          ),
          _buildInfoRow(
            'Fecha de Registro',
            _formatDate(userProfile?['fecha_registro']),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalInfoCard() {
    return _buildGlassCard(
      title: 'INFORMACIÓN PROFESIONAL',
      icon: FontAwesomeIcons.shield,
      gradient: const LinearGradient(
        colors: [Color(0xFF8E44AD), Color(0xFF6A4C93)],
      ),
      child: Column(
        children: [
          _buildInfoRow('Rango', userProfile?['rango'] ?? 'No especificado'),
          _buildInfoRow('Unidad', userProfile?['unidad'] ?? 'No especificado'),
          _buildInfoRow(
            'Número CIP',
            userProfile?['numero_cip'] ?? 'No especificado',
          ),
          _buildInfoRow('Rol', userProfile?['rol'] ?? 'policia'),
          _buildInfoRow(
            'Privilegios',
            userProfile?['admin'] == true
                ? 'Administrador'
                : 'Usuario estándar',
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
              gradient:
                  gradient.colors.isNotEmpty
                      ? LinearGradient(
                        colors:
                            gradient.colors
                                .map((c) => c.withOpacity(0.2))
                                .toList(),
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
          const Text(': ', style: TextStyle(color: Colors.white, fontSize: 14)),
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

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}
