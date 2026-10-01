import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../services/gps_location_service.dart';
import '../../../common/styles/app_colors.dart';
import '../../../core/services/analytics_telemetry_service.dart';

class SosDialog extends StatefulWidget {
  const SosDialog({super.key});

  static Future<void> show(BuildContext context) {
    AnalyticsTelemetryService().logModuleUsage('Boton SOS');
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SosDialog(),
    );
  }

  @override
  State<SosDialog> createState() => _SosDialogState();
}

class _SosDialogState extends State<SosDialog> {
  bool _isSirenActive = false;
  bool _sirenColorState = false;
  Timer? _sirenTimer;
  bool _isGettingLocation = false;

  @override
  void dispose() {
    _sirenTimer?.cancel();
    super.dispose();
  }

  void _toggleSiren() {
    if (_isSirenActive) {
      _sirenTimer?.cancel();
      setState(() {
        _isSirenActive = false;
      });
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _isSirenActive = true;
      });
      _sirenTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _sirenColorState = !_sirenColorState;
        });
        HapticFeedback.vibrate();
      });
    }
  }

  Future<void> _makeCall(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _shareCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final loc = await GpsLocationService.getCurrentLocation();
      if (loc != null) {
        final mapsUrl = 'https://maps.google.com/?q=${loc.latitude},${loc.longitude}';
        final message =
            '🚨 *¡ALERTA DE EMERGENCIA - AUXILIO!* 🚨\n'
            'Necesito ayuda urgente. Mi ubicación actual en tiempo real es:\n'
            '$mapsUrl\n'
            '📍 Departamento: ${loc.departamento}, Provincia: ${loc.provincia}\n'
            'Por favor envía ayuda o comunícate a la Policía (105 / 114).';

        await Share.share(message, subject: 'ALERTA DE EMERGENCIA SOS');
      } else {
        final message =
            '🚨 *¡ALERTA DE EMERGENCIA - AUXILIO!* 🚨\n'
            'Necesito ayuda urgente. Por favor comunícate a la Policía (105 / 114) o a mis contactos de emergencia.';
        await Share.share(message, subject: 'ALERTA DE EMERGENCIA SOS');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo obtener la ubicación GPS: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sirenBg = _sirenColorState
        ? const Color(0xFFDC2626) // Rojo vivo
        : const Color(0xFF1D4ED8); // Azul patrulla

    final baseBg = _isSirenActive ? sirenBg : (isDark ? const Color(0xFF0F172A) : Colors.white);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: baseBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(_isSirenActive ? 0.6 : 0.25),
            blurRadius: 30,
            spreadRadius: _isSirenActive ? 10 : 2,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de agarre
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: _isSirenActive ? Colors.white70 : Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cabecera SOS
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isSirenActive ? Colors.white24 : const Color(0xFFEF4444).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emergency_rounded,
                  color: _isSirenActive ? Colors.white : const Color(0xFFEF4444),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CENTRAL DE AUXILIO SOS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _isSirenActive ? Colors.white : (isDark ? Colors.white : AppColors.textColorPrimary),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Marcación inmediata y auxilio ciudadano',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isSirenActive ? Colors.white70 : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: _isSirenActive ? Colors.white : Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Botón Sirena Disuasiva
          GestureDetector(
            onTap: _toggleSiren,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isSirenActive
                      ? [Colors.white, const Color(0xFFF1F5F9)]
                      : [const Color(0xFFDC2626), const Color(0xFFB91C1C)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (_isSirenActive ? Colors.black : const Color(0xFFDC2626)).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isSirenActive ? Icons.volume_off_rounded : Icons.campaign_rounded,
                    color: _isSirenActive ? const Color(0xFFDC2626) : Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isSirenActive ? 'APAGAR ALARMA DESTELLANTE' : 'ACTIVAR ALARMA DESTELLANTE SOS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _isSirenActive ? const Color(0xFFDC2626) : Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Botón Enviar Ubicación GPS por WhatsApp
          ElevatedButton.icon(
            onPressed: _isGettingLocation ? null : _shareCurrentLocation,
            icon: _isGettingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.share_location_rounded, color: Colors.white),
            label: Text(
              _isGettingLocation ? 'Obteniendo GPS...' : 'Enviar Mi Ubicación Exacta por WhatsApp',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981), // Verde WhatsApp
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 3,
            ),
          ),
          const SizedBox(height: 20),

          // Grid de teléfonos de auxilio 105, 114, 116, 106
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Llamada Directa de Emergencia (Gratis):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildEmergencyPhoneCard(
                  number: '105',
                  title: 'Policía Nacional',
                  subtitle: 'Central de Emergencias',
                  icon: Icons.local_police_rounded,
                  color: const Color(0xFF1E3A8A),
                  onTap: () => _makeCall('105'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildEmergencyPhoneCard(
                  number: '114',
                  title: 'Desaparecidos',
                  subtitle: 'Línea Exclusiva PNP',
                  icon: Icons.person_search_rounded,
                  color: const Color(0xFFDC2626),
                  onTap: () => _makeCall('114'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildEmergencyPhoneCard(
                  number: '116',
                  title: 'Bomberos',
                  subtitle: 'Incendios y Rescate',
                  icon: Icons.fire_truck_rounded,
                  color: const Color(0xFFD97706),
                  onTap: () => _makeCall('116'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildEmergencyPhoneCard(
                  number: '100',
                  title: 'Línea 100',
                  subtitle: 'Violencia Familiar / MIMP',
                  icon: Icons.volunteer_activism_rounded,
                  color: const Color(0xFFDB2777),
                  onTap: () => _makeCall('100'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyPhoneCard({
    required String number,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.35), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          number,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.phone_in_talk_rounded, color: color, size: 14),
                      ],
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
