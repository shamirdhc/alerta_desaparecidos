import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/desaparecido.dart';

class FoundDetailsScreen extends StatefulWidget {
  final Desaparecido encontrado;

  const FoundDetailsScreen({super.key, required this.encontrado});

  @override
  State<FoundDetailsScreen> createState() => _FoundDetailsScreenState();
}

class _FoundDetailsScreenState extends State<FoundDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));
    
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
            colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF415A77)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildDetailsContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
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
                  colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PERSONA ENCONTRADA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Text(
                  'Detalles del caso resuelto',
                  style: TextStyle(
                    color: Color(0xFF27AE60),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF27AE60).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF27AE60),
                width: 1,
              ),
            ),
            child: const FaIcon(
              FontAwesomeIcons.userCheck,
              color: Color(0xFF27AE60),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSuccessHeader(),
          const SizedBox(height: 30),
          _buildPersonalInfo(),
          const SizedBox(height: 20),
          _buildLocationInfo(),
          const SizedBox(height: 20),
          _buildFoundInfo(),
          const SizedBox(height: 20),
          if (widget.encontrado.encontradoDetalles != null && 
              widget.encontrado.encontradoDetalles!.isNotEmpty)
            _buildFoundDetails(),
        ],
      ),
    );
  }

  Widget _buildSuccessHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF27AE60).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Foto de la persona
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: widget.encontrado.fotoUrl != null && widget.encontrado.fotoUrl!.isNotEmpty
                  ? Image.network(
                      widget.encontrado.fotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.white.withOpacity(0.2),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 60,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.white.withOpacity(0.2),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Icono de éxito
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const FaIcon(
              FontAwesomeIcons.check,
              color: Colors.white,
              size: 32,
            ),
          ),
          
          const SizedBox(height: 16),
          
          const Text(
            '¡CASO RESUELTO!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          Text(
            '${widget.encontrado.nombres} ${widget.encontrado.apellidos}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          const Text(
            'Persona encontrada exitosamente',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo() {
    return _buildInfoSection(
      title: 'INFORMACIÓN PERSONAL',
      icon: FontAwesomeIcons.user,
      color: const Color(0xFF457B9D),
      children: [
        if (widget.encontrado.dni != null)
          _buildInfoItem('DNI', widget.encontrado.dni!, FontAwesomeIcons.idCard),
        if (widget.encontrado.sexo != null)
          _buildInfoItem('Sexo', widget.encontrado.sexo!, FontAwesomeIcons.venusMars),
        if (widget.encontrado.fechaNacimiento != null)
          _buildInfoItem(
            'Fecha de Nacimiento',
            DateFormat('dd/MM/yyyy').format(widget.encontrado.fechaNacimiento!),
            FontAwesomeIcons.cakeCandles,
          ),
        if (widget.encontrado.telefonoContacto != null)
          _buildInfoItem(
            'Teléfono de Contacto',
            widget.encontrado.telefonoContacto!,
            FontAwesomeIcons.phone,
          ),
      ],
    );
  }

  Widget _buildLocationInfo() {
    return _buildInfoSection(
      title: 'INFORMACIÓN DE UBICACIÓN',
      icon: FontAwesomeIcons.locationDot,
      color: const Color(0xFF778DA9),
      children: [
        if (widget.encontrado.departamento != null)
          _buildInfoItem('Departamento', widget.encontrado.departamento!, FontAwesomeIcons.mapLocationDot),
        if (widget.encontrado.provincia != null)
          _buildInfoItem('Provincia', widget.encontrado.provincia!, FontAwesomeIcons.map),
        if (widget.encontrado.distrito != null)
          _buildInfoItem('Distrito', widget.encontrado.distrito!, FontAwesomeIcons.mapPin),
      ],
    );
  }

  Widget _buildFoundInfo() {
    return _buildInfoSection(
      title: 'INFORMACIÓN DEL HALLAZGO',
      icon: FontAwesomeIcons.magnifyingGlass,
      color: const Color(0xFF27AE60),
      children: [
        if (widget.encontrado.fechaDesaparicion != null)
          _buildInfoItem(
            'Fecha de Desaparición',
            DateFormat('dd/MM/yyyy HH:mm').format(widget.encontrado.fechaDesaparicion!),
            FontAwesomeIcons.calendarXmark,
          ),
        if (widget.encontrado.fechaEncontrado != null)
          _buildInfoItem(
            'Fecha de Hallazgo',
            DateFormat('dd/MM/yyyy HH:mm').format(widget.encontrado.fechaEncontrado!),
            FontAwesomeIcons.calendarCheck,
          ),
        _buildInfoItem('Estado', 'ENCONTRADO', FontAwesomeIcons.checkCircle),
      ],
    );
  }

  Widget _buildFoundDetails() {
    return _buildInfoSection(
      title: 'DETALLES DEL HALLAZGO',
      icon: FontAwesomeIcons.fileLines,
      color: const Color(0xFFFF6B35),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Text(
            widget.encontrado.encontradoDetalles!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                FaIcon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF778DA9).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FaIcon(
              icon,
              color: const Color(0xFF778DA9),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}