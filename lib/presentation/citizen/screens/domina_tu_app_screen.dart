import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🌟 DOMINA TU APP: GUÍA INTERACTIVA CIUDADANA Y FAMILIAR
/// Rediseñado con estética luminosa, cálida y amigable para todo público (familias, adultos mayores, jóvenes).
/// Colores accesibles, tipografía de alta legibilidad, simuladores claros y gamificación motivacional.
class DominaTuAppScreen extends StatefulWidget {
  final Function(int)? onNavigateToModule;
  final int initialModuleIndex;

  const DominaTuAppScreen({
    super.key,
    this.onNavigateToModule,
    this.initialModuleIndex = 0,
  });

  @override
  State<DominaTuAppScreen> createState() => _DominaTuAppScreenState();
}

class _DominaTuAppScreenState extends State<DominaTuAppScreen> {
  // 🏅 Claves de persistencia de medallas para los 3 pilares principales
  static const String _prefKeyPilar0 = 'domina_v3_desaparecidos';
  static const String _prefKeyPilar1 = 'domina_v3_comisarias';
  static const String _prefKeyPilar2 = 'domina_v3_familia';

  int _selectedPillar = 0; // 0: Desaparecidos & Pistas, 1: Comisarías & GPS, 2: Familia Segura
  int _currentStep = 0; // 0, 1, 2 para cada pilar

  bool _completadoDesaparecidos = false;
  bool _completadoComisarias = false;
  bool _completadoFamilia = false;

  int _xpTotal = 150;

  @override
  void initState() {
    super.initState();
    _selectedPillar = widget.initialModuleIndex.clamp(0, 2);
    _cargarProgreso();
  }

  Future<void> _cargarProgreso() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _completadoDesaparecidos = prefs.getBool(_prefKeyPilar0) ?? false;
        _completadoComisarias = prefs.getBool(_prefKeyPilar1) ?? false;
        _completadoFamilia = prefs.getBool(_prefKeyPilar2) ?? false;
        _calcularXp();
      });
    } catch (_) {}
  }

  void _calcularXp() {
    int completados = 0;
    if (_completadoDesaparecidos) completados++;
    if (_completadoComisarias) completados++;
    if (_completadoFamilia) completados++;
    _xpTotal = 150 + (completados * 150);
  }

  int get _pilaresCompletadosCount {
    int count = 0;
    if (_completadoDesaparecidos) count++;
    if (_completadoComisarias) count++;
    if (_completadoFamilia) count++;
    return count;
  }

  double get _porcentajeProgreso => (_pilaresCompletadosCount / 3.0).clamp(0.0, 1.0);

  // Paleta dinámica amigable según el pilar seleccionado
  Color get _currentAccentColor {
    switch (_selectedPillar) {
      case 0:
        return const Color(0xFF0284C7); // Sky Blue amigable
      case 1:
        return const Color(0xFF4F46E5); // Indigo policial amigable
      case 2:
      default:
        return const Color(0xFF059669); // Esmeralda / Menta familiar
    }
  }

  Color get _currentLightColor {
    switch (_selectedPillar) {
      case 0:
        return const Color(0xFFF0F9FF);
      case 1:
        return const Color(0xFFEEF2FF);
      case 2:
      default:
        return const Color(0xFFECFDF5);
    }
  }

  Future<void> _marcarPilarCompletado(int pilar) async {
    HapticFeedback.heavyImpact();
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      if (pilar == 0) {
        _completadoDesaparecidos = true;
        prefs.setBool(_prefKeyPilar0, true);
      } else if (pilar == 1) {
        _completadoComisarias = true;
        prefs.setBool(_prefKeyPilar1, true);
      } else if (pilar == 2) {
        _completadoFamilia = true;
        prefs.setBool(_prefKeyPilar2, true);
      }
      _calcularXp();
    });

    if (!mounted) return;
    _mostrarModalFelicitacion(pilar);
  }

  void _mostrarModalFelicitacion(int pilar) {
    String titulo = '';
    String sub = '';
    IconData icon = Icons.verified_rounded;
    Color accentColor = const Color(0xFF0284C7);

    if (pilar == 0) {
      titulo = '¡Ojo de Halcón Activado!';
      sub = 'Ahora sabes cómo identificar alertas oficiales de personas desaparecidas y enviar pistas confidenciales seguras a la PNP sin revelar tu identidad.';
      icon = Icons.search_rounded;
      accentColor = const Color(0xFF0284C7);
    } else if (pilar == 1) {
      titulo = '¡Escudo Policial 360°!';
      sub = 'Conoces cómo ubicar la comisaría más cercana por GPS y usar las líneas gratuitas de auxilio 105, 114 y 100 incluso sin saldo ni internet.';
      icon = Icons.local_police_rounded;
      accentColor = const Color(0xFF4F46E5);
    } else {
      titulo = '¡Guardián Familiar de Oro!';
      sub = 'Has dominado el Carnet Preventivo QR y el Afiche Express de Búsqueda para proteger a tus hijos, abuelitos y seres queridos.';
      icon = Icons.family_restroom_rounded;
      accentColor = const Color(0xFF059669);
    }

    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: accentColor.withValues(alpha: 0.4), width: 2),
          ),
          title: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.12),
                  border: Border.all(color: accentColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: accentColor, size: 40),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 18),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: 21,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 22),
                    SizedBox(width: 8),
                    Text(
                      '+150 XP GANADOS',
                      style: TextStyle(
                        color: Color(0xFFD97706),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                '¡Continuar Aprendiendo!',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Fondo amigable y luminoso
      body: Stack(
        children: [
          // 🌤️ Destellos de Luz y Ambiente Cálido (Amigables, suaves y luminosos)
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF38BDF8).withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 300,
            left: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFBBF24).withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF34D399).withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 📜 Contenido Principal Desplazable
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderHero(),
                  const SizedBox(height: 18),
                  _buildPillarsSelector(),
                  const SizedBox(height: 22),
                  _buildContextLifeCard(),
                  const SizedBox(height: 22),
                  _buildInteractivePhoneTutorial(),
                  const SizedBox(height: 24),
                  _buildDirectActionButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 1. HEADER HERO & GAMIFICACIÓN AMIGABLE
  // ==========================================
  Widget _buildHeaderHero() {
    return _FriendlyCard(
      padding: const EdgeInsets.all(22),
      borderRadius: 24,
      borderColor: const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFBAE6FD), width: 1.2),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, color: Color(0xFF0284C7), size: 15),
                      SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'GUÍA CIUDADANA',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF0284C7),
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '$_xpTotal XP',
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Domina tu Aplicación',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              fontSize: 26,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aprende de manera sencilla y en 3 pasos cómo proteger a tu familia y cómo colaborar con la Policía en cualquier momento.',
            style: TextStyle(
              color: Color(0xFF475569),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          // Barra de Progreso Luminosa y Clara
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearPercentIndicator(
                    lineHeight: 9.0,
                    percent: _porcentajeProgreso,
                    padding: EdgeInsets.zero,
                    backgroundColor: const Color(0xFFE2E8F0),
                    progressColor: const Color(0xFF10B981),
                    animation: true,
                    animationDuration: 600,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '$_pilaresCompletadosCount de 3 Aprendidos',
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. SELECTOR DE LOS 3 PILARES ESENCIALES
  // ==========================================
  Widget _buildPillarsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'ELIGE LA HERRAMIENTA QUE QUIERES CONOCER:',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildPillarTabButton(
                index: 0,
                icon: Icons.person_search_rounded,
                label: 'Desaparecidos',
                sublabel: '& Pistas',
                accentColor: const Color(0xFF0284C7),
                lightBgColor: const Color(0xFFF0F9FF),
                completado: _completadoDesaparecidos,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildPillarTabButton(
                index: 1,
                icon: Icons.local_police_rounded,
                label: 'Comisarías',
                sublabel: '& Radar GPS',
                accentColor: const Color(0xFF4F46E5),
                lightBgColor: const Color(0xFFEEF2FF),
                completado: _completadoComisarias,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildPillarTabButton(
                index: 2,
                icon: Icons.family_restroom_rounded,
                label: 'Mi Familia',
                sublabel: 'Carnet & QR',
                accentColor: const Color(0xFF059669),
                lightBgColor: const Color(0xFFECFDF5),
                completado: _completadoFamilia,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPillarTabButton({
    required int index,
    required IconData icon,
    required String label,
    required String sublabel,
    required Color accentColor,
    required Color lightBgColor,
    required bool completado,
  }) {
    final bool isSelected = _selectedPillar == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedPillar = index;
          _currentStep = 0; // Reiniciar al paso 1 al cambiar de función
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? lightBgColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.15)
                  : const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected ? accentColor : const Color(0xFF64748B),
                  size: 28,
                ),
                if (completado)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
            Text(
              sublabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? accentColor : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 3. TARJETA DE CONTEXTO DE VIDA (¿POR QUÉ Y CUÁNDO?)
  // ==========================================
  Widget _buildContextLifeCard() {
    String tituloContexto = '';
    String subtextoContexto = '';
    List<Map<String, String>> situaciones = [];
    Color accentColor = _currentAccentColor;
    Color lightBg = _currentLightColor;
    IconData iconHeader = Icons.lightbulb_rounded;

    if (_selectedPillar == 0) {
      iconHeader = Icons.person_search_rounded;
      tituloContexto = '¿En qué momentos debes usar esta función y por qué?';
      subtextoContexto =
          'Esta herramienta une la solidaridad ciudadana con la acción policial. Es vital en dos situaciones cotidianas:';
      situaciones = [
        {
          'emoji': '🚨',
          'titulo': 'Cuando un ser querido no regresa a casa',
          'desc':
              'No tienes que esperar 24 horas (eso es un mito). Conoce las alertas activadas de inmediato y difunde la ficha oficial con foto nítida en redes y grupos de WhatsApp.',
        },
        {
          'emoji': '👁️',
          'titulo': 'Cuando ves a alguien vulnerable o desorientado en la calle',
          'desc':
              'En el transporte, paradero, mercado o plaza. Si ves a un menor de edad o abuelito que parece extraviado, puedes aportar datos a la Policía Nacional de forma 100% confidencial y sin dar tu nombre.',
        },
      ];
    } else if (_selectedPillar == 1) {
      iconHeader = Icons.local_police_rounded;
      tituloContexto = '¿Por qué y cuándo debes consultar esta sección?';
      subtextoContexto =
          'En una urgencia real, buscar una dirección en internet quita minutos de vida. Este módulo te da auxilio inmediato:';
      situaciones = [
        {
          'emoji': '🧭',
          'titulo': 'Urgencia en un lugar desconocido o de noche',
          'desc':
              'Si estás fuera de tu barrio o de viaje en otra provincia y sufres un asalto, extravío o agresión, el GPS te muestra qué comisaría está a menos de 500 metros y el teléfono de la guardia.',
        },
        {
          'emoji': '🛡️',
          'titulo': 'Casos de Violencia Familiar y Auxilio a la Mujer (CEM)',
          'desc':
              'Encuentra el Centro Emergencia Mujer (CEM) más próximo con asistencia legal, psicológica y médica especializada.',
        },
        {
          'emoji': '📞',
          'titulo': 'Sin saldo ni megas en tu teléfono celular',
          'desc':
              'Las líneas 105 (PNP), 114 (Desaparecidos) y 100 (CEM) son 100% gratuitas por ley nacional y funcionan con marcación en un solo toque.',
        },
      ];
    } else {
      iconHeader = Icons.family_restroom_rounded;
      tituloContexto = '¿Por qué cada familia debe tener listo este carnet?';
      subtextoContexto =
          'El pánico de perder de vista a un niño o a un adulto mayor bloquea la mente. Esta herramienta previene antes de que ocurra una emergencia:';
      situaciones = [
        {
          'emoji': '🎪',
          'titulo': 'Antes de ir a ferias, terminales, playas o viajes',
          'desc':
              'Registras preventivamente la foto reciente y señas particulares (lunares, cicatrices, talla). Queda guardado seguro en la memoria de tu celular sin consumir internet.',
        },
        {
          'emoji': '⚡',
          'titulo': 'Los primeros 10 minutos críticos si se extravía',
          'desc':
              'En lugar de buscar fotos viejas en tu galería, generas el Carnet Oficial con Código QR y el Afiche de Búsqueda Express en 5 segundos para entregárselo a la patrulla.',
        },
      ];
    }

    return _FriendlyCard(
      padding: const EdgeInsets.all(22),
      borderRadius: 24,
      borderColor: accentColor.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: lightBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Icon(iconHeader, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROPÓSITO HUMANO Y FAMILIAR',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tituloContexto,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            subtextoContexto,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          ...situaciones.map(
            (sit) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sit['emoji']!, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sit['titulo']!,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sit['desc']!,
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. TUTORIAL INTERACTIVO CON SMARTPHONE MOCKUP
  // ==========================================
  Widget _buildInteractivePhoneTutorial() {
    final Color accentColor = _currentAccentColor;

    return _FriendlyCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 28,
      borderColor: const Color(0xFFCBD5E1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'TUTORIAL PASO A PASO',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'Paso ${_currentStep + 1} de 3',
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Stepper Selector Horizontal
          Row(
            children: [
              _buildStepIndicatorPill(step: 0, label: _getStepLabel(0)),
              const SizedBox(width: 8),
              _buildStepIndicatorPill(step: 1, label: _getStepLabel(1)),
              const SizedBox(width: 8),
              _buildStepIndicatorPill(step: 2, label: _getStepLabel(2)),
            ],
          ),
          const SizedBox(height: 18),

          // Título y Explicación del Paso Actual
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Column(
              key: ValueKey('step_header_${_selectedPillar}_$_currentStep'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getCurrentStepTitle(),
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                    fontSize: 18.5,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getCurrentStepDescription(),
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 14.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 📱 SMARTPHONE DEVICE FRAME (Diseño Claro, Moderno y Elegante)
          Center(
            child: _buildSmartphoneMockup(),
          ),
          const SizedBox(height: 20),

          // Botones de Navegación del Paso (Anterior / Siguiente)
          Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() => _currentStep--);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_back_rounded, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Anterior',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_currentStep > 0) const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    if (_currentStep < 2) {
                      setState(() => _currentStep++);
                    } else {
                      _marcarPilarCompletado(_selectedPillar);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentStep == 2
                        ? const Color(0xFF059669)
                        : accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentStep == 2
                              ? '¡Completar y Ganar +150 XP!'
                              : 'Siguiente Paso',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          _currentStep == 2
                              ? Icons.check_circle_rounded
                              : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicatorPill({required int step, required String label}) {
    final bool isCurrent = _currentStep == step;
    final bool isPassed = _currentStep > step;
    final Color accentColor = _currentAccentColor;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _currentStep = step);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isCurrent
                ? accentColor.withValues(alpha: 0.12)
                : (isPassed
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrent
                  ? accentColor
                  : (isPassed
                      ? const Color(0xFF10B981)
                      : const Color(0xFFE2E8F0)),
              width: isCurrent ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isPassed) ...[
                const Icon(Icons.check, size: 14, color: Color(0xFF059669)),
                const SizedBox(width: 4),
              ],
              Text(
                'Paso ${step + 1}',
                style: TextStyle(
                  color: isCurrent
                      ? accentColor
                      : (isPassed ? const Color(0xFF059669) : const Color(0xFF64748B)),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStepLabel(int step) {
    if (_selectedPillar == 0) {
      if (step == 0) return '1. Filtrar';
      if (step == 1) return '2. Ficha HD';
      return '3. Aportar Pista';
    } else if (_selectedPillar == 1) {
      if (step == 0) return '1. Radar GPS';
      if (step == 1) return '2. Comisaría';
      return '3. Líneas 105/114';
    } else {
      if (step == 0) return '1. Registro';
      if (step == 1) return '2. Carnet QR';
      return '3. Afiche Express';
    }
  }

  String _getCurrentStepTitle() {
    if (_selectedPillar == 0) {
      if (_currentStep == 0) return '1. Filtra Alertas por tu Región';
      if (_currentStep == 1) return '2. Revisa la Ficha y Señas Particulares';
      return '3. Aporta una Pista 100% Confidencial';
    } else if (_selectedPillar == 1) {
      if (_currentStep == 0) return '1. Radar GPS de Comisarías Cercanas';
      if (_currentStep == 1) return '2. Contacto Directo con la Guardia PNP';
      return '3. Marcación Gratuita 105, 114 y 100 sin saldo';
    } else {
      if (_currentStep == 0) return '1. Registro Preventivo con Foto Reciente';
      if (_currentStep == 1) return '2. Carnet Digital con Código QR Policial';
      return '3. Genera el Afiche de Búsqueda Express';
    }
  }

  String _getCurrentStepDescription() {
    if (_selectedPillar == 0) {
      if (_currentStep == 0) {
        return 'Al abrir la pantalla, selecciona tu departamento (ej. Apurímac o Lima) para visualizar únicamente los casos reportados en tu zona de tránsito diario.';
      }
      if (_currentStep == 1) {
        return 'Toca la tarjeta de la persona para ampliar la fotografía en alta calidad. Fíjate en los detalles: cicatrices, lunares, tatuajes y la ropa exacta con la que fue vista por última vez.';
      }
      return 'Si reconoces a la persona, presiona "Aportar Pista". Tu número de teléfono, DNI o identidad NUNCA serán revelados. La patrulla del sector recibe el aviso al instante.';
    } else if (_selectedPillar == 1) {
      if (_currentStep == 0) {
        return 'Tu celular calcula automáticamente la distancia en metros a las comisarías y centros CEM de tu entorno, mostrándote la ruta más rápida.';
      }
      if (_currentStep == 1) {
        return 'Al seleccionar la comisaría, obtienes el número directo de la mesa de guardia y patrullaje de tu barrio, sin pasar por largas derivaciones.';
      }
      return 'En extrema urgencia, la botonera de emergencia te comunica gratis con la Central 105 (Policía), 114 (Desaparecidos) y 100 (Violencia Familiar) sin necesidad de megas.';
    } else {
      if (_currentStep == 0) {
        return 'Ingresa una foto nítida de frente de tu hijo, abuelito o familiar, registrando su tipo de sangre y señas únicas. Los datos quedan en tu propio teléfono, 100% privados.';
      }
      if (_currentStep == 1) {
        return 'El sistema genera una credencial digital con Código QR de emergencia. Si la persona se extravía, la Policía en la comisaría escanea este QR e inicia la denuncia en 10 segundos.';
      }
      return 'Si el familiar no aparece, pulsa "Generar Afiche Oficial". Obtendrás el cartel con formato oficial PNP listo para imprimir o enviar por WhatsApp de inmediato.';
    }
  }

  // ==========================================
  // 5. VECTOR SMARTPHONE FRAME MOCKUP (Amigable & Luminoso)
  // ==========================================
  Widget _buildSmartphoneMockup() {
    return Container(
      width: 310,
      height: 480,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0), // Chasis moderno estilo titanio plateado
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: _currentAccentColor.withValues(alpha: 0.12),
            blurRadius: 36,
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Pantalla interior simulada limpia y clara
            Positioned.fill(
              child: Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  children: [
                    // Barra de estado simulada (9:41, WiFi, Batería en negro claro)
                    const SizedBox(height: 18),
                    _buildSimulatedStatusBar(),
                    const SizedBox(height: 12),
                    // Contenido visual según el pilar y paso
                    Expanded(
                      child: _buildSimulatedScreenContent(),
                    ),
                  ],
                ),
              ),
            ),

            // Isla Dinámica / Notch superior minimalista
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 80,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF64748B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Hotspot pulsante interactivo ("Toca Aquí")
            _buildPulsingHotspotOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulatedStatusBar() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '9:41',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        Row(
          children: [
            Icon(Icons.signal_cellular_alt_rounded, color: Color(0xFF1E293B), size: 13),
            SizedBox(width: 4),
            Icon(Icons.wifi_rounded, color: Color(0xFF1E293B), size: 13),
            SizedBox(width: 4),
            Icon(Icons.battery_full_rounded, color: Color(0xFF1E293B), size: 15),
          ],
        ),
      ],
    );
  }

  // --- CONTENIDOS ESPECÍFICOS DE CADA PANTALLA SIMULADA ---
  Widget _buildSimulatedScreenContent() {
    if (_selectedPillar == 0) {
      return _buildDesaparecidosSimulatedScreen();
    } else if (_selectedPillar == 1) {
      return _buildComisariasSimulatedScreen();
    } else {
      return _buildFamiliaSimulatedScreen();
    }
  }

  // A. SIMULACIÓN DE DESAPARECIDOS & PISTAS
  Widget _buildDesaparecidosSimulatedScreen() {
    if (_currentStep == 0) {
      // Paso 1: Filtros de departamento
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.location_on_rounded, color: Color(0xFF0284C7), size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Apurímac (Abancay)',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Tarjeta de alerta simulada
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: const Icon(Icons.person, color: Color(0xFF0284C7), size: 30),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.circle, color: Color(0xFFEF4444), size: 8),
                          SizedBox(width: 4),
                          Text(
                            'ALERTA ACTIVA',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Lucía Quispe M. (15a)',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Vista por última vez: Tamburco',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 55,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person, color: Color(0xFF94A3B8), size: 30),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Carlos Mendoza (72a)',
                        style: TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        'Desorientado / Casaca azul',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (_currentStep == 1) {
      // Paso 2: Ficha HD expandida
      return Column(
        children: [
          Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.person, color: Color(0xFF94A3B8), size: 70),
                Positioned(
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('Foto Oficial HD', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SEÑAS PARTICULARES:',
                  style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.w900, fontSize: 11),
                ),
                SizedBox(height: 4),
                Text(
                  '• Cicatriz pequeña en la frente derecha\n• Vestía polera roja con capucha y zapatillas blancas\n• Talla aprox. 1.58m',
                  style: TextStyle(color: Color(0xFF1E293B), fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // Paso 3: Aportar Pista Anónima
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_rounded, color: Color(0xFF059669), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pista 100% Cifrada y Anónima (No pedimos DNI)',
                    style: TextStyle(
                      color: Color(0xFF065F46),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Dónde y cómo la viste?',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  'La vi cerca del mercado central de Abancay en el paradero con polera roja...',
                  style: TextStyle(color: Color(0xFF1E293B), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF059669),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Enviar Pista a la Central PNP',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
  }

  // B. SIMULACIÓN DE COMISARÍAS & GPS 360°
  Widget _buildComisariasSimulatedScreen() {
    if (_currentStep == 0) {
      // Radar GPS
      return Column(
        children: [
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC7D2FE), width: 1.5),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Círculos de radar suaves
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.35), width: 1.5),
                  ),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                    border: Border.all(color: const Color(0xFF4F46E5), width: 2),
                  ),
                  child: const Icon(Icons.my_location_rounded, color: Color(0xFF4F46E5), size: 22),
                ),
                Positioned(
                  top: 15,
                  right: 40,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.local_police_rounded, color: Color(0xFF4F46E5), size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC7D2FE)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, color: Color(0xFF4F46E5), size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comisaría PNP Bellavista',
                        style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      Text(
                        'A solo 350 metros • Abierto 24h',
                        style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w700, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (_currentStep == 1) {
      // Ficha de guardia
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC7D2FE), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.badge_rounded, color: Color(0xFF4F46E5), size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Comisaría Sectorial', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 14)),
                          Text('Guardia y Patrullero de Turno', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Teléfono de Guardia:', style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w600)),
                      Text('(083) 321-222', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w900, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Llamar a la Guardia Ahora', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // Líneas gratuitas
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
            ),
            child: const Row(
              children: [
                Icon(Icons.sim_card_alert_rounded, color: Color(0xFFDC2626), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'FUNCIONAN SIN SALDO NI INTERNET',
                    style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w900, fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildQuickCallItem(number: '105', title: 'Central PNP Emergencias', color: const Color(0xFFDC2626)),
          const SizedBox(height: 6),
          _buildQuickCallItem(number: '114', title: 'Línea Desaparecidos PNP', color: const Color(0xFF0284C7)),
          const SizedBox(height: 6),
          _buildQuickCallItem(number: '100', title: 'Centro Emergencia Mujer (CEM)', color: const Color(0xFFDB2777)),
        ],
      );
    }
  }

  Widget _buildQuickCallItem({required String number, required String title, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              number,
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13.5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w700, fontSize: 11.5),
            ),
          ),
          Icon(Icons.phone_forwarded_rounded, color: color, size: 16),
        ],
      ),
    );
  }

  // C. SIMULACIÓN DE FAMILIA SEGURA (CARNET Y AFICHE)
  Widget _buildFamiliaSimulatedScreen() {
    if (_currentStep == 0) {
      // Registro preventivo
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Icon(Icons.face_rounded, color: Color(0xFF059669), size: 36),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mateo (Hijo menor, 8a)', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 13.5)),
                      SizedBox(height: 2),
                      Text('Sangre: O+ • Talla: 1.25m', style: TextStyle(color: Color(0xFF475569), fontSize: 11)),
                      Text('Lunar pequeño en cuello', style: TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.offline_pin_rounded, color: Color(0xFF059669), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Guardado seguro en tu celular (100% privado y sin internet)',
                    style: TextStyle(color: Color(0xFF065F46), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (_currentStep == 1) {
      // Carnet con QR
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF0FDF4), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF059669), width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('CARNET FAMILIA SEGURA', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w900, fontSize: 11)),
                    Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 16),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, color: Colors.black, size: 58),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MATEO QUISPE', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 13)),
                          Text('Código de Emergencia:', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                          Text('POLICÍA ESCANEA AQUÍ', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w900, fontSize: 10.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // Afiche Express
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
            ),
            child: Column(
              children: [
                const Text(
                  '¡SE BUSCA! ALERTA INMEDIATA',
                  style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w900, fontSize: 11.5),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 55,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.face_rounded, color: Color(0xFF64748B), size: 36),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MATEO (8 AÑOS)', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 12)),
                          Text('Llamar urgente al 114 PNP o a su familia', style: TextStyle(color: Color(0xFF334155), fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF059669),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('Compartir en WhatsApp (5 seg)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      );
    }
  }

  // --- HOTSPOT PULSANTE INTERACTIVO ("TOCA AQUÍ") ---
  Widget _buildPulsingHotspotOverlay() {
    double topPos = 110;
    double leftPos = 40;
    String mensaje = 'Toca aquí';

    if (_selectedPillar == 0) {
      if (_currentStep == 0) {
        topPos = 70;
        leftPos = 120;
        mensaje = '👇 Elige tu región';
      } else if (_currentStep == 1) {
        topPos = 150;
        leftPos = 90;
        mensaje = '👇 Amplía la foto';
      } else {
        topPos = 210;
        leftPos = 80;
        mensaje = '👇 Pulsa para aportar';
      }
    } else if (_selectedPillar == 1) {
      if (_currentStep == 0) {
        topPos = 110;
        leftPos = 120;
        mensaje = '👇 Comisaría a 350m';
      } else if (_currentStep == 1) {
        topPos = 190;
        leftPos = 90;
        mensaje = '👇 Llama directo';
      } else {
        topPos = 120;
        leftPos = 110;
        mensaje = '👇 Toca 105 o 114 gratis';
      }
    } else {
      if (_currentStep == 0) {
        topPos = 90;
        leftPos = 100;
        mensaje = '👇 Guarda datos y foto';
      } else if (_currentStep == 1) {
        topPos = 130;
        leftPos = 70;
        mensaje = '👇 QR para la Policía';
      } else {
        topPos = 175;
        leftPos = 75;
        mensaje = '👇 Enviar por WhatsApp';
      }
    }

    return Positioned(
      top: topPos,
      left: leftPos,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD97706).withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              mensaje,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Anillo concéntrico pulsante cálido y visible
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
              border: Border.all(color: const Color(0xFFD97706), width: 2.5),
            ),
            child: const Center(
              child: CircleAvatar(
                radius: 4,
                backgroundColor: Color(0xFFD97706),
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1.25, 1.25),
                duration: 900.ms,
                curve: Curves.easeInOut,
              ),
        ],
      ),
    );
  }

  // ==========================================
  // 6. BOTÓN DE ACCIÓN DIRECTA (PROBAR EN LA APP)
  // ==========================================
  Widget _buildDirectActionButton() {
    String tituloBoton = '';
    String subBoton = '';
    Color colorGradiente = _currentAccentColor;
    Color lightBg = _currentLightColor;
    int targetModuleIndex = 1;

    if (_selectedPillar == 0) {
      tituloBoton = 'Ir a Personas Desaparecidas';
      subBoton = 'Explora las alertas reales y prueba el aporte de pistas';
      colorGradiente = const Color(0xFF0284C7);
      targetModuleIndex = 1; // Index 1: ViewMissingScreen
    } else if (_selectedPillar == 1) {
      tituloBoton = 'Abrir Central 360° y Comisarías';
      subBoton = 'Verifica las comisarías y centros CEM en tu zona con GPS';
      colorGradiente = const Color(0xFF4F46E5);
      targetModuleIndex = 6; // Index 6: CentralAuxilioScreen
    } else {
      tituloBoton = 'Crear Carnet en Mi Familia Segura';
      subBoton = 'Registra hoy a tus seres queridos y ten listo su carnet QR';
      colorGradiente = const Color(0xFF059669);
      targetModuleIndex = 4; // Index 4: MiFamiliaScreen
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            lightBg,
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colorGradiente.withValues(alpha: 0.4), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: colorGradiente.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            HapticFeedback.heavyImpact();
            widget.onNavigateToModule?.call(targetModuleIndex);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorGradiente.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: colorGradiente.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Icon(Icons.rocket_launch_rounded, color: colorGradiente, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tituloBoton,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w900,
                          fontSize: 16.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subBoton,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: colorGradiente, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 🔮 WIDGET REUTILIZABLE: TARJETA AMIGABLE ELEVADA (Luminosa, Limpia y Accesible)
class _FriendlyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? borderColor;

  const _FriendlyCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
