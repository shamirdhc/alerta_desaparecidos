import 'package:flutter/material.dart';
import 'package:alerta_desaparecidos/helpers/share_helper.dart';
import '../../../common/styles/app_colors.dart';
import '../../../domain/entities/desaparecido.dart';
import 'package:intl/intl.dart';
import 'full_screen_image_screen.dart';

class FoundPersonDetailsScreen extends StatefulWidget {
  final Desaparecido desaparecido;

  const FoundPersonDetailsScreen({super.key, required this.desaparecido});

  @override
  State<FoundPersonDetailsScreen> createState() => _FoundPersonDetailsScreenState();
}

class _FoundPersonDetailsScreenState extends State<FoundPersonDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _celebrationController;
  late AnimationController _pulseController;
  late Animation<double> _celebrationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _celebrationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Iniciar animaciones
    _celebrationController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '¡PERSONA ENCONTRADA!',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF047857), Color(0xFF10B981)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.share, color: Colors.white, size: 20),
              ),
              onPressed: () {
                final d = widget.desaparecido;
                final fullName = '${d.nombres} ${d.apellidos}'.trim();
                final location = '${d.distrito ?? ''}, ${d.departamento ?? ''}'.trim();
                final message =
                    '💚 *¡GRAN NOTICIA! PERSONA LOCALIZADA Y A SALVO* 💚\n\n'
                    '• Nombre: $fullName\n'
                    '• Región: $location\n\n'
                    'Gracias al trabajo coordinado de la Policía Nacional del Perú y al apoyo de la ciudadanía, el caso ha sido resuelto favorablemente.\n\n'
                    '¡Celebramos cada reencuentro familiar!';
                final String? bestImageUrl = widget.desaparecido.fotoUrl?.isNotEmpty == true
                    ? widget.desaparecido.fotoUrl
                    : (widget.desaparecido.imagenFichaUrl?.isNotEmpty == true ? widget.desaparecido.imagenFichaUrl : null);
                ShareHelper.shareCase(
                  context: context,
                  message: message,
                  subject: 'Persona Localizada: $fullName',
                  imageUrl: bestImageUrl,
                );
              },
              tooltip: 'Compartir',
            ),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A0F1D) : AppColors.backgroundColor,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: AnimatedBuilder(
                animation: _celebrationAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _celebrationAnimation.value,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                    // Header celebratorio
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF047857), Color(0xFF10B981)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.25),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.celebration,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '¡MISIÓN CUMPLIDA!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Gracias al trabajo de la Policía Nacional del Perú',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Información de la persona encontrada
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.borderSubtle,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Header con foto
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF065F46), Color(0xFF047857)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                if (widget.desaparecido.fotoUrl != null)
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FullScreenImageScreen(
                                            imageUrl: widget.desaparecido.fotoUrl!,
                                            heroTag: 'found_details_${widget.desaparecido.id}',
                                          ),
                                        ),
                                      );
                                    },
                                    child: Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        Container(
                                          height: 200,
                                          width: 200,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.3),
                                                blurRadius: 10,
                                                offset: const Offset(0, 5),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: Image.network(
                                              widget.desaparecido.fotoUrl!,
                                              fit: BoxFit.cover,
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return Container(
                                                  color: Colors.grey[200],
                                                  child: const Center(
                                                    child: CircularProgressIndicator(
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                );
                                              },
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  color: Colors.grey[200],
                                                  child: const Icon(
                                                    Icons.person,
                                                    size: 80,
                                                    color: Colors.grey,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        Container(
                                          margin: const EdgeInsets.all(8),
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.fullscreen_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                Text(
                                  '${widget.desaparecido.nombres} ${widget.desaparecido.apellidos}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (widget.desaparecido.imagenFichaUrl != null &&
                                    widget.desaparecido.imagenFichaUrl!.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FullScreenImageScreen(
                                            imageUrl: widget.desaparecido.imagenFichaUrl!,
                                            heroTag: 'found_ficha_${widget.desaparecido.id}',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.description_outlined, color: Colors.white, size: 18),
                                    label: const Text(
                                      'Ver Ficha / Nota de Alerta Oficial PNP',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF047857),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      elevation: 2,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          
                          // Información esencial
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                if (widget.desaparecido.fechaEncontrado != null)
                                  _buildInfoRow(
                                    Icons.verified_rounded,
                                    'Fecha de localización',
                                    DateFormat('dd/MM/yyyy').format(widget.desaparecido.fechaEncontrado!),
                                    const Color(0xFF10B981),
                                  ),
                                _buildInfoRow(
                                  Icons.wc,
                                  'Sexo',
                                  widget.desaparecido.sexo ?? 'No especificado',
                                  Colors.green,
                                ),
                                _buildInfoRow(
                                  Icons.location_on,
                                  'Lugar del hecho / desaparición',
                                  '${widget.desaparecido.distrito ?? ''}, ${widget.desaparecido.provincia ?? ''}, ${widget.desaparecido.departamento ?? ''}',
                                  Colors.green,
                                ),
                                if (widget.desaparecido.fechaDesaparicion != null)
                                  _buildInfoRow(
                                    Icons.calendar_today,
                                    'Fecha de desaparición',
                                    DateFormat('dd/MM/yyyy').format(widget.desaparecido.fechaDesaparicion!),
                                    Colors.green,
                                  ),
                                if (widget.desaparecido.unidadACargo != null && widget.desaparecido.unidadACargo!.isNotEmpty)
                                  _buildInfoRow(
                                    Icons.local_police_rounded,
                                    'Unidad policial a cargo',
                                    widget.desaparecido.unidadACargo!,
                                    const Color(0xFF047857),
                                  ),
                                if (widget.desaparecido.telefonoContacto != null && widget.desaparecido.telefonoContacto!.isNotEmpty)
                                  _buildInfoRow(
                                    Icons.phone_in_talk_rounded,
                                    'Teléfono de contacto',
                                    widget.desaparecido.telefonoContacto!,
                                    const Color(0xFF047857),
                                  ),
                                if (widget.desaparecido.detallesAdicionales != null && widget.desaparecido.detallesAdicionales!.isNotEmpty)
                                  _buildInfoRow(
                                    Icons.info_outline_rounded,
                                    'Información adicional',
                                    widget.desaparecido.detallesAdicionales!,
                                    Colors.green,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Detalles de cómo fue encontrado
                    if (widget.desaparecido.encontradoDetalles != null && 
                        widget.desaparecido.encontradoDetalles!.isNotEmpty)
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF064E3B).withValues(alpha: 0.25)
                              : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.search,
                                    color: Color(0xFF047857),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Detalles del hallazgo',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.desaparecido.encontradoDetalles!.trim(),
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? const Color(0xFFF8FAFC) : Colors.black87,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 20),
                    
                    // Footer celebratorio
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF065F46), Color(0xFF047857)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.verified,
                            size: 32,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'CASO CERRADO EXITOSAMENTE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Encontrado el ${widget.desaparecido.fechaEncontrado != null ? DateFormat('dd/MM/yyyy').format(widget.desaparecido.fechaEncontrado!) : 'Fecha no especificada'}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
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
}