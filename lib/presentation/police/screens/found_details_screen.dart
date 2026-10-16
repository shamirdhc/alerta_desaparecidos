import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/desaparecido.dart';
import '../../../helpers/share_helper.dart';
import '../../common_widgets/theme_sun_moon_toggle.dart';
import '../../citizen/screens/full_screen_image_screen.dart';

class FoundDetailsScreen extends StatefulWidget {
  final Desaparecido encontrado;

  const FoundDetailsScreen({super.key, required this.encontrado});

  @override
  State<FoundDetailsScreen> createState() => _FoundDetailsScreenState();
}

class _FoundDetailsScreenState extends State<FoundDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: FaIcon(
            FontAwesomeIcons.arrowLeft,
            color: isDark ? Colors.white : const Color(0xFF003366),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EXPEDIENTE DE PERSONA UBICADA',
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const Text(
              'Policía Nacional del Perú • Caso Resuelto',
              style: TextStyle(
                color: Color(0xFF10B981),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: const [
          ThemeSunMoonToggle(),
          SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    _buildSuccessBanner(isDark),
                    const SizedBox(height: 20),
                    if (widget.encontrado.imagenFichaUrl != null &&
                        widget.encontrado.imagenFichaUrl!.isNotEmpty)
                      _buildFichaOficialSection(isDark),
                    const SizedBox(height: 20),
                    _buildPersonalInfo(isDark),
                    const SizedBox(height: 16),
                    _buildFoundInfo(isDark),
                    const SizedBox(height: 16),
                    _buildLocationInfo(isDark),
                    if (widget.encontrado.encontradoDetalles != null &&
                        widget.encontrado.encontradoDetalles!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildFoundDetails(isDark),
                    ],
                    const SizedBox(height: 24),
                    _buildActionButtons(context, isDark),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B), const Color(0xFF047857)]
              : [const Color(0xFF059669), const Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: widget.encontrado.fotoUrl != null &&
                          widget.encontrado.fotoUrl!.isNotEmpty
                      ? Image.network(
                          widget.encontrado.fotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            color: Colors.white.withOpacity(0.2),
                            child: const Center(
                              child: FaIcon(FontAwesomeIcons.user,
                                  color: Colors.white, size: 40),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.white.withOpacity(0.2),
                          child: const Center(
                            child: FaIcon(FontAwesomeIcons.user,
                                color: Colors.white, size: 40),
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.check,
                    color: Color(0xFF10B981),
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '¡CASO RESUELTO CON ÉXITO!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${widget.encontrado.nombres} ${widget.encontrado.apellidos}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Persona ubicada y reintegrada a su entorno familiar',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFichaOficialSection(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.fileLines,
                  color: Color(0xFF0284C7),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NOTA DE ALERTA / FICHA OFICIAL PNP',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Documento oficial registrado en el Sistema de Alerta',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullScreenImageScreen(
                    imageUrl: widget.encontrado.imagenFichaUrl!,
                  ),
                ),
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.encontrado.imagenFichaUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 100,
                      color: Colors.grey.withOpacity(0.1),
                      child: const Center(
                        child: Text('Documento registrado en expediente'),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(FontAwesomeIcons.magnifyingGlassPlus,
                          color: Colors.white, size: 14),
                      SizedBox(width: 8),
                      Text(
                        'Tocar para ampliar con zoom',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo(bool isDark) {
    return _buildSectionCard(
      title: 'INFORMACIÓN PERSONAL',
      icon: FontAwesomeIcons.idCard,
      color: const Color(0xFF0284C7),
      isDark: isDark,
      children: [
        if (widget.encontrado.dni != null &&
            widget.encontrado.dni!.trim().isNotEmpty)
          _buildInfoItem('DNI', widget.encontrado.dni!, isDark),
        if (widget.encontrado.edadCalculada != null && widget.encontrado.edadCalculada! > 0)
          _buildInfoItem('Edad', '${widget.encontrado.edadCalculada} años', isDark),
        if (widget.encontrado.sexo != null &&
            widget.encontrado.sexo!.trim().isNotEmpty)
          _buildInfoItem('Sexo', widget.encontrado.sexo!, isDark),
        if (widget.encontrado.fechaNacimiento != null)
          _buildInfoItem(
            'Fecha de Nacimiento',
            DateFormat('dd/MM/yyyy').format(widget.encontrado.fechaNacimiento!),
            isDark,
          ),
      ],
    );
  }

  Widget _buildFoundInfo(bool isDark) {
    return _buildSectionCard(
      title: 'DATOS DE LA LOCALIZACIÓN',
      icon: FontAwesomeIcons.circleCheck,
      color: const Color(0xFF10B981),
      isDark: isDark,
      children: [
        _buildInfoItem('Estado Actual', 'UBICADO / RESUELTO', isDark,
            valueColor: const Color(0xFF10B981)),
        if (widget.encontrado.fechaEncontrado != null)
          _buildInfoItem(
            'Fecha de Localización',
            DateFormat('dd/MM/yyyy HH:mm')
                .format(widget.encontrado.fechaEncontrado!),
            isDark,
          ),
        if (widget.encontrado.fechaDesaparicion != null)
          _buildInfoItem(
            'Fecha de Desaparición Original',
            DateFormat('dd/MM/yyyy HH:mm')
                .format(widget.encontrado.fechaDesaparicion!),
            isDark,
          ),
      ],
    );
  }

  Widget _buildLocationInfo(bool isDark) {
    return _buildSectionCard(
      title: 'JURISDICCIÓN POLICIAL',
      icon: FontAwesomeIcons.locationDot,
      color: const Color(0xFF6366F1),
      isDark: isDark,
      children: [
        if (widget.encontrado.departamento != null &&
            widget.encontrado.departamento!.trim().isNotEmpty)
          _buildInfoItem('Departamento', widget.encontrado.departamento!, isDark),
        if (widget.encontrado.provincia != null &&
            widget.encontrado.provincia!.trim().isNotEmpty)
          _buildInfoItem('Provincia', widget.encontrado.provincia!, isDark),
        if (widget.encontrado.distrito != null &&
            widget.encontrado.distrito!.trim().isNotEmpty)
          _buildInfoItem('Distrito', widget.encontrado.distrito!, isDark),
      ],
    );
  }

  Widget _buildFoundDetails(bool isDark) {
    return _buildSectionCard(
      title: 'ACTA / CIRCUNSTANCIAS DEL HALLAZGO',
      icon: FontAwesomeIcons.fileSignature,
      color: const Color(0xFFF59E0B),
      isDark: isDark,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            widget.encontrado.encontradoDetalles!,
            style: TextStyle(
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required bool isDark,
    required List<Widget> children,
  }) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                FaIcon(icon, color: color, size: 14),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, bool isDark,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ??
                    (isDark ? Colors.white : const Color(0xFF0F172A)),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _shareFoundCase(context),
        icon: const FaIcon(FontAwesomeIcons.shareNodes, size: 16),
        label: const Text(
          'Compartir Comunicado de Ubicación',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Future<void> _shareFoundCase(BuildContext context) async {
    final e = widget.encontrado;
    final fullName = '${e.nombres} ${e.apellidos}'.trim();
    final dniText = (e.dni != null && e.dni!.isNotEmpty) ? '(DNI: ${e.dni}) ' : '';
    final message =
        '🟢 *PERSONA UBICADA - CASO RESUELTO*\n\n'
        'La Policía Nacional del Perú comunica con satisfacción que *$fullName* $dniText'
        'ha sido *UBICADO(A)* y se encuentra a buen recaudo con sus familiares.\n\n'
        'Agradecemos a la ciudadanía y a los medios de comunicación por su valiosa colaboración.';

    final String? notaUrl = (e.imagenFichaUrl?.isNotEmpty == true)
        ? e.imagenFichaUrl
        : (e.fotoUrl?.isNotEmpty == true ? e.fotoUrl : null);

    await ShareHelper.shareCase(
      context: context,
      message: message,
      subject: 'Persona Ubicada: $fullName',
      imageUrl: notaUrl,
    );
  }
}