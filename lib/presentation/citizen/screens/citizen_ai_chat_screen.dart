import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../domain/models/learning_topic_model.dart';
import '../../../services/learning_tree_service.dart';

import 'video_player_screen.dart';
import 'tutorial_screen.dart';
import '../../../common/localization/app_strings.dart';

/// Pantalla Principal de "Guías Educativas"
///
/// Academia Interactiva y Gamificada de Prevención y Protección Familiar.
/// Incorpora didácticamente los videos explicativos oficiales de la PNP,
/// doctrina cívico-legal preventiva (niños lectores, jóvenes, padres y adultos mayores)
/// con tipografía amplia, 7 ramas maestras, 28 hojas de habilidad, micro-lecciones,
/// mini-trivias express y sistema de medallas cívicas.
class CitizenAiChatScreen extends StatefulWidget {
  final String? initialQuery;
  final Function(int)? onNavigateToTab;

  const CitizenAiChatScreen({
    super.key,
    this.initialQuery,
    this.onNavigateToTab,
  });

  @override
  State<CitizenAiChatScreen> createState() => _CitizenAiChatScreenState();
}

// Alias semántico para la arquitectura del proyecto
typedef CitizenLearningTreeScreen = CitizenAiChatScreen;
typedef EducationalGuidesScreen = CitizenAiChatScreen;

class _CitizenAiChatScreenState extends State<CitizenAiChatScreen> with TickerProviderStateMixin {
  late final LearningTreeService _treeService;

  // Filtro de ramas: 0 = Todas, -1 = Solo con video, 1 a 7 = Ramas específicas
  int _selectedBranchFilter = 0;

  // Estado de respuestas de trivia en memoria {subtopicId: selectedOptionIndex}
  final Map<String, int> _answeredTrivias = {};

  // Controlador de scroll para navegación suave
  final ScrollController _scrollController = ScrollController();

  // Controlador de scroll y estado interactivo para el carrusel de ramas
  final ScrollController _filterScrollController = ScrollController();
  bool _canScrollFilterLeft = false;
  bool _canScrollFilterRight = true;

  @override
  void initState() {
    super.initState();
    _treeService = LearningTreeService();
    _treeService.addListener(_onTreeServiceUpdated);
    _treeService.initialize();

    _filterScrollController.addListener(_updateFilterScrollArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateFilterScrollArrows();
    });
  }

  void _updateFilterScrollArrows() {
    if (!_filterScrollController.hasClients) return;
    final max = _filterScrollController.position.maxScrollExtent;
    final current = _filterScrollController.offset;
    final canLeft = current > 12;
    final canRight = current < max - 12;
    if (canLeft != _canScrollFilterLeft || canRight != _canScrollFilterRight) {
      if (mounted) {
        setState(() {
          _canScrollFilterLeft = canLeft;
          _canScrollFilterRight = canRight;
        });
      }
    }
  }

  void _scrollFilterLeft() {
    if (!_filterScrollController.hasClients) return;
    final newOffset = math.max(0.0, _filterScrollController.offset - 260);
    _filterScrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    HapticFeedback.selectionClick();
  }

  void _scrollFilterRight() {
    if (!_filterScrollController.hasClients) return;
    final max = _filterScrollController.position.maxScrollExtent;
    final newOffset = math.min(max, _filterScrollController.offset + 260);
    _filterScrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    HapticFeedback.selectionClick();
  }

  void _onTreeServiceUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _treeService.removeListener(_onTreeServiceUpdated);
    _scrollController.dispose();
    _filterScrollController.removeListener(_updateFilterScrollArrows);
    _filterScrollController.dispose();
    super.dispose();
  }

  /// Lista de ramas filtradas según la selección del usuario
  List<LearningBranch> get _filteredBranches {
    if (_selectedBranchFilter == 0) {
      return LearningTopicsCatalog.branches;
    }
    if (_selectedBranchFilter == -1) {
      // Filtrar solo las ramas que contienen subtemas con video oficial
      return LearningTopicsCatalog.branches
          .where((b) => b.subtopics.any((s) => s.hasVideo))
          .map((b) => LearningBranch(
                id: b.id,
                title: b.title,
                subtitle: b.subtitle,
                iconEmoji: b.iconEmoji,
                iconData: b.iconData,
                color: b.color,
                overviewExplanation: b.overviewExplanation,
                subtopics: b.subtopics.where((s) => s.hasVideo).toList(),
              ))
          .toList();
    }
    return LearningTopicsCatalog.branches
        .where((b) => b.id == _selectedBranchFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0B131E) : const Color(0xFFF4F6F9);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: _buildCustomAppBar(isDark),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Gran Banner Hero de Progreso y Rango Cívico
                  _buildHeroProgressCard(isDark),

                  const SizedBox(height: 18),

                  // 2. Barra de Acciones Rápidas (Reto Express + Medallas)
                  _buildQuickActionButtons(isDark),

                  const SizedBox(height: 18),

                  // 3. Selector de Ramas Temáticas (Filtros Horizontales)
                  _buildBranchFilterChips(isDark),

                  const SizedBox(height: 18),

                  // 4. Lista de Ramas y sus 28 Hojas de Habilidad
                  ..._filteredBranches.map((branch) => _buildBranchSectionCard(branch, isDark)),

                  const SizedBox(height: 16),

                  // 5. Pie de Página Pedagógico Oficial
                  _buildPedagogicalFooter(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// AppBar Oficial con estilo institucional y opciones
  PreferredSizeWidget _buildCustomAppBar(bool isDark) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF131D2A) : const Color(0xFF075E54),
      foregroundColor: Colors.white,
      titleSpacing: 12,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF00A884).withOpacity(0.25),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF34D399), width: 1.5),
            ),
            child: const Center(
              child: Icon(Icons.school_rounded, color: Color(0xFF34D399), size: 24),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Guías Educativas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  'Academia de Prevención y Protección Familiar',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFD1FAE5),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Salón de Medallas',
          icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFDE047), size: 26),
          onPressed: () => _showMedalsHallModal(isDark),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          onSelected: (val) {
            if (val == 'share') {
              _shareProgress();
            } else if (val == 'reset') {
              _confirmResetProgress();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share_rounded, color: Color(0xFF00A884), size: 20),
                  SizedBox(width: 10),
                  Text('Compartir mi progreso cívico', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'reset',
              child: Row(
                children: [
                  Icon(Icons.restart_alt_rounded, color: Colors.redAccent, size: 20),
                  SizedBox(width: 10),
                  Text('Reiniciar progreso del árbol', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Gran Tarjeta Hero de Progreso y Rango Cívico
  Widget _buildHeroProgressCard(bool isDark) {
    final strings = AppStrings.of(context);
    final progress = _treeService.overallProgress;
    final percentage = (progress * 100).toInt();
    final completed = _treeService.completedCount;
    final total = _treeService.totalCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF132230), const Color(0xFF1A3245)]
              : [const Color(0xFF047857), const Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF065F46)).withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rango Cívico actual con insignia
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_rounded, color: Color(0xFFFDE047), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      _treeService.currentRankTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Porcentaje grande
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF34D399),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Título Motivacional en tipografía legible
          Text(
            strings.isQuechua ? 'Ayllupaq Yachachinakuna' : 'Tus Guías Educativas Familiares',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _treeService.currentRankDescription,
            style: const TextStyle(
              fontSize: 14.5,
              color: Color(0xFFE2E8F0),
              height: 1.4,
            ),
          ),

          const SizedBox(height: 16),

          // Barra de progreso interactiva
          LinearPercentIndicator(
            padding: EdgeInsets.zero,
            lineHeight: 12.0,
            percent: progress,
            backgroundColor: Colors.white.withOpacity(0.2),
            progressColor: const Color(0xFF34D399),
            barRadius: const Radius.circular(8),
            animation: true,
            animateFromLastPercent: true,
          ),

          const SizedBox(height: 10),

          // Contador de Hojas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings.isQuechua
                    ? '🎓 $completed / $total yachaykuna yachasqa'
                    : '🎓 $completed de $total temas dominados',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD1FAE5),
                ),
              ),
              Text(
                completed == total
                    ? (strings.isQuechua ? '¡Yachaykuna Tukusqa! 🎉' : '¡Guías Completas! 🎉')
                    : (strings.isQuechua ? '${total - completed} yachanaraq' : '${total - completed} temas por aprender'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Botones de Acción Rápida (Reto Express y Salón de Medallas)
  Widget _buildQuickActionButtons(bool isDark) {
    final strings = AppStrings.of(context);

    return Row(
      children: [
        // 1. Botón Reto Express
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _startDailyQuickQuiz,
            icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
            label: Text(
              strings.quickQuizButton,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 2. Botón Medallas
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showMedalsHallModal(isDark),
            icon: const Icon(Icons.military_tech_rounded, color: Color(0xFFFDE047), size: 20),
            label: Text(
              strings.medalsButton,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }



  /// Selector horizontal interactivo tipo Carrusel con flechas y microanimaciones
  Widget _buildBranchFilterChips(bool isDark) {
    final strings = AppStrings.of(context);
    final filters = [
      {
        'id': 0,
        'emoji': '🎓',
        'title': strings.isQuechua ? 'Tukuy Yachaykuna' : 'Todas las Guías',
        'subtitle': strings.isQuechua ? '28 yachachinakuna' : '28 temas formativos',
        'color': const Color(0xFF00A884),
      },
      {
        'id': 1,
        'emoji': '⏱️',
        'title': strings.isQuechua ? '1. Quri Pacha' : '1. Hora Dorada',
        'subtitle': strings.isQuechua ? 'Ñawpaq 60 min' : 'Primeros 60 min',
        'color': const Color(0xFFE11D48),
      },
      {
        'id': 2,
        'emoji': '🔴',
        'title': strings.isQuechua ? '2. Amber Willakuy' : '2. Alerta Amber',
        'subtitle': strings.isQuechua ? 'Wamrakuna TEA' : 'Menores y TEA',
        'color': const Color(0xFFF97316),
      },
      {
        'id': 3,
        'emoji': '📱',
        'title': strings.isQuechua ? '3. Llikapi Amachakuy' : '3. Ciberseguridad',
        'subtitle': strings.isQuechua ? 'Redes Umachay' : 'Redes y Engaños',
        'color': const Color(0xFF0284C7),
      },
      {
        'id': 4,
        'emoji': '🛡️',
        'title': strings.isQuechua ? '4. Wamrakuna Warmakuna' : '4. Niños y Jóvenes',
        'subtitle': strings.isQuechua ? 'Yachaywasi Kawsay' : 'Entorno y Colegio',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'id': 5,
        'emoji': '👵',
        'title': strings.isQuechua ? '5. Yuyaq Runakuna' : '5. Adultos Mayores',
        'subtitle': strings.isQuechua ? 'Yuyay Waqaychay' : 'Cuidados y Memoria',
        'color': const Color(0xFFEC4899),
      },
      {
        'id': 6,
        'emoji': '📢',
        'title': strings.isQuechua ? '6. Llikakunapi Willay' : '6. Difusión Redes',
        'subtitle': strings.isQuechua ? 'Oficial Afichekuna' : 'Afiches Oficiales',
        'color': const Color(0xFF10B981),
      },
      {
        'id': 7,
        'emoji': '🤝',
        'title': strings.isQuechua ? '7. Allinlla Kutimuy' : '7. Retorno Seguro',
        'subtitle': strings.isQuechua ? 'Tukuy Qespichiy' : 'Cierre y Contención',
        'color': const Color(0xFF6366F1),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera del carrusel con indicador y botones de flechas
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A884).withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  size: 15,
                  color: Color(0xFF00A884),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                strings.isQuechua ? 'YACHAYKUNATA T\'AQANMANTA QHAYWAY' : 'EXPLORAR GUÍAS POR RAMAS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                ),
              ),
              const Spacer(),
              // Flechas de navegación interactiva
              _buildScrollArrow(
                icon: Icons.chevron_left_rounded,
                isEnabled: _canScrollFilterLeft,
                onTap: _canScrollFilterLeft ? _scrollFilterLeft : null,
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _buildScrollArrow(
                icon: Icons.chevron_right_rounded,
                isEnabled: _canScrollFilterRight,
                onTap: _canScrollFilterRight ? _scrollFilterRight : null,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Carrusel horizontal interactivo
        SizedBox(
          height: 64,
          child: ListView.separated(
            controller: _filterScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, idx) {
              final item = filters[idx];
              final branchId = item['id'] as int;
              final isSelected = _selectedBranchFilter == branchId;
              final itemColor = item['color'] as Color;
              final emoji = item['emoji'] as String;
              final title = item['title'] as String;
              final subtitle = item['subtitle'] as String;

              final completedCount = branchId > 0
                  ? _treeService.getBranchCompletedCount(branchId)
                  : _treeService.completedCount;
              final isFullyCompleted = branchId > 0
                  ? _treeService.isBranchCompleted(branchId)
                  : (_treeService.completedCount == _treeService.totalCount && _treeService.totalCount > 0);

              return AnimatedScale(
                scale: isSelected ? 1.02 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedBranchFilter = branchId;
                      });
                      HapticFeedback.lightImpact();
                      // Centrar suavemente en el carrusel
                      if (_filterScrollController.hasClients) {
                        final targetOffset = (idx * 165.0 - 60.0).clamp(
                          0.0,
                          _filterScrollController.position.maxScrollExtent,
                        );
                        _filterScrollController.animateTo(
                          targetOffset,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  itemColor,
                                  Color.lerp(itemColor, Colors.black, isDark ? 0.25 : 0.15)!,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected
                            ? null
                            : (isDark
                                ? const Color(0xFF131F2E).withValues(alpha: 0.90)
                                : Colors.white),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.45)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.8 : 1.2,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: itemColor.withValues(alpha: 0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            )
                          else
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Avatar circular animado con Emoji
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.22)
                                  : itemColor.withValues(alpha: isDark ? 0.20 : 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.4)
                                    : itemColor.withValues(alpha: 0.25),
                                width: 1.2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Textos descriptivos
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                  letterSpacing: 0.1,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.90)
                                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                          // Badge de progreso si hay avance
                          if (completedCount > 0) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.28)
                                    : const Color(0xFF10B981).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.4)
                                      : const Color(0xFF10B981).withValues(alpha: 0.3),
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                isFullyCompleted
                                    ? (branchId == 0 ? '✓ COMPLETO' : '✓ 4/4')
                                    : (branchId == 0 ? '$completedCount/28' : '$completedCount/4'),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected ? Colors.white : const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Botón interactivo de flecha para el carrusel de ramas
  Widget _buildScrollArrow({
    required IconData icon,
    required bool isEnabled,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark
                ? (isEnabled ? const Color(0xFF1E293B) : const Color(0xFF131D2A).withValues(alpha: 0.3))
                : (isEnabled ? Colors.white : Colors.white.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: isEnabled ? 0.16 : 0.04)
                  : const Color(0xFFCBD5E1).withValues(alpha: isEnabled ? 0.9 : 0.3),
              width: 1.1,
            ),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Icon(
              icon,
              size: 19,
              color: isEnabled
                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                  : (isDark ? Colors.white24 : Colors.black26),
            ),
          ),
        ),
      ),
    );
  }

  /// Tarjeta de Sección para cada Rama del Árbol
  Widget _buildBranchSectionCard(LearningBranch branch, bool isDark) {
    final completedCount = _treeService.getBranchCompletedCount(branch.id);
    final isFullyCompleted = _treeService.isBranchCompleted(branch.id);
    final cardBg = isDark ? const Color(0xFF14202E) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isFullyCompleted
              ? const Color(0xFF10B981)
              : branch.color.withOpacity(0.35),
          width: isFullyCompleted ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera destacada de la Rama
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: branch.color.withOpacity(isDark ? 0.16 : 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: branch.color.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: branch.color.withOpacity(0.5), width: 1.5),
                  ),
                  child: Center(
                    child: Icon(branch.iconData, color: branch.color, size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${branch.iconEmoji} Rama ${branch.id}: ${branch.title}',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (isFullyCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    '100%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        branch.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Resumen conceptual de la rama
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D1622) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF223244) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    branch.overviewExplanation,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Progreso de hojas en esta rama
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hojas de Aprendizaje ($completedCount de 4):',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      isFullyCompleted ? '¡Rama Florecida! 🌸' : 'Toca para aprender',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isFullyCompleted ? const Color(0xFF10B981) : branch.color,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Las 4 Hojas / Subtemas didácticos
                ...branch.subtopics.map((subtopic) => _buildSubtopicLeafTile(subtopic, branch, isDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta de cada Hoja / Subtema dentro de una rama
  Widget _buildSubtopicLeafTile(
    LearningSubtopic subtopic,
    LearningBranch branch,
    bool isDark,
  ) {
    final isCompleted = _treeService.isSubtopicCompleted(subtopic.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isCompleted
            ? (isDark ? const Color(0xFF064E3B).withOpacity(0.35) : const Color(0xFFDCFCE7))
            : (isDark ? const Color(0xFF192534) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF10B981)
              : (isDark ? const Color(0xFF2A3A4E) : const Color(0xFFE2E8F0)),
          width: isCompleted ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openLessonModal(subtopic, branch, isDark),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Icono de estado (Check o Icono temático)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF10B981).withOpacity(0.2)
                        : branch.color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isCompleted ? Icons.check_circle_rounded : subtopic.icon,
                      color: isCompleted ? const Color(0xFF10B981) : branch.color,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Textos grandes y legibles
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subtopic.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isCompleted
                              ? (isDark ? const Color(0xFF34D399) : const Color(0xFF065F46))
                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtopic.shortDescription,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtopic.hasVideo) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48).withOpacity(isDark ? 0.22 : 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFE11D48).withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_circle_fill_rounded, size: 13, color: Color(0xFFE11D48)),
                              const SizedBox(width: 4),
                              Text(
                                'Video Oficial PNP • ${subtopic.video!.duration} min',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFE11D48),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Chip de estado o flecha
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : branch.color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCompleted ? 'Listo ✅' : 'Estudiar 📖',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.white : branch.color,
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

  /// Visor Didáctico Completo de la Lección (Modal con tipografía amplia, flujo continuo y Mini-Trivia)
  void _openLessonModal(
    LearningSubtopic initialSubtopic,
    LearningBranch initialBranch,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        LearningSubtopic activeSubtopic = initialSubtopic;
        LearningBranch activeBranch = initialBranch;
        final modalScrollController = ScrollController();

        return StatefulBuilder(
          builder: (context, setModalState) {
            final isCompleted = _treeService.isSubtopicCompleted(activeSubtopic.id);
            final sheetBg = isDark ? const Color(0xFF131F2E) : Colors.white;
            final nextSubtopic = LearningTopicsCatalog.getNextSubtopic(activeSubtopic.id);
            final previousSubtopic = LearningTopicsCatalog.getPreviousSubtopic(activeSubtopic.id);
            final branchSubtopicIndex = LearningTopicsCatalog.getSubtopicIndexInBranch(activeSubtopic.id);
            final totalSubtopicsInBranch = activeBranch.subtopics.length;

            void goToNextSubtopic() {
              if (nextSubtopic != null) {
                final nextBranch = LearningTopicsCatalog.getBranchForSubtopic(nextSubtopic.id) ?? activeBranch;
                setModalState(() {
                  activeSubtopic = nextSubtopic;
                  activeBranch = nextBranch;
                });
                if (modalScrollController.hasClients) {
                  modalScrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOut,
                  );
                }
              } else {
                Navigator.pop(context);
                _showMedalsHallModal(isDark);
              }
            }

            void goToPreviousSubtopic() {
              if (previousSubtopic != null) {
                final prevBranch = LearningTopicsCatalog.getBranchForSubtopic(previousSubtopic.id) ?? activeBranch;
                setModalState(() {
                  activeSubtopic = previousSubtopic;
                  activeBranch = prevBranch;
                });
                if (modalScrollController.hasClients) {
                  modalScrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOut,
                  );
                }
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Tirador táctil superior
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),

                  // Barra superior de navegación y progreso de la rama
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            if (previousSubtopic != null)
                              InkWell(
                                onTap: goToPreviousSubtopic,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.chevron_left_rounded,
                                        size: 18,
                                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Anterior',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              const SizedBox(width: 65),
                            const Spacer(),
                            // Chip de progreso dentro de la rama
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: activeBranch.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: activeBranch.color.withOpacity(0.3), width: 1.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Hoja $branchSubtopicIndex de $totalSubtopicsInBranch',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: activeBranch.color,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('•', style: TextStyle(color: activeBranch.color.withOpacity(0.6))),
                                  const SizedBox(width: 6),
                                  const Text(
                                    '⏱️ 1 min',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 24),
                              tooltip: 'Cerrar',
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Mini barra segmentada visual de la rama
                        Row(
                          children: List.generate(totalSubtopicsInBranch, (stepIdx) {
                            final isStepDone = stepIdx < branchSubtopicIndex;
                            final isCurrent = stepIdx == branchSubtopicIndex - 1;
                            return Expanded(
                              child: Container(
                                height: 3.5,
                                margin: EdgeInsets.only(right: stepIdx < totalSubtopicsInBranch - 1 ? 5 : 0),
                                decoration: BoxDecoration(
                                  color: isStepDone
                                      ? activeBranch.color
                                      : (isDark ? const Color(0xFF283A50) : const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: isCurrent
                                      ? [BoxShadow(color: activeBranch.color.withOpacity(0.4), blurRadius: 3)]
                                      : null,
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                  // Fila de título de la lección
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 16, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: activeBranch.color.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(activeSubtopic.icon, color: activeBranch.color, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${activeBranch.iconEmoji} Rama ${activeBranch.id}: ${activeBranch.title}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: activeBranch.color,
                                ),
                              ),
                              Text(
                                activeSubtopic.title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Dominado',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Contenido didáctico scrollable con tipografía grande y cómoda
                  Expanded(
                    child: ListView(
                      controller: modalScrollController,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      children: [
                        // Tarjeta 1: La Idea Clave
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: activeBranch.color.withOpacity(isDark ? 0.12 : 0.07),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: activeBranch.color.withOpacity(0.3), width: 1.2),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded, color: activeBranch.color, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  activeSubtopic.shortDescription,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Tarjeta de Video Explicativo Oficial (si el subtema cuenta con video PNP)
                        if (activeSubtopic.hasVideo) ...[
                          const SizedBox(height: 18),
                          _buildOfficialVideoCard(activeSubtopic.video!, isDark),
                        ],

                        const SizedBox(height: 18),

                        // Tarjeta 2: Explicación completa oficial
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F1824) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark ? const Color(0xFF223246) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            activeSubtopic.fullContent,
                            style: TextStyle(
                              fontSize: 15.5,
                              height: 1.55,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Tarjeta 3: Consejo de Oro para la Familia
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lightbulb_rounded, color: Color(0xFFB45309), size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Regla de Oro para la Familia:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF78350F),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      activeSubtopic.audienceTip,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        height: 1.45,
                                        color: Color(0xFF92400E),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Tarjeta de Integración y Promoción del Módulo de la App
                        if (activeSubtopic.relatedAppModuleTab != null && activeSubtopic.relatedAppModuleLabel != null) ...[
                          const SizedBox(height: 18),
                          _buildAppModulePromoCard(
                            activeSubtopic,
                            isDark,
                            () {
                              Navigator.pop(context);
                              widget.onNavigateToTab?.call(activeSubtopic.relatedAppModuleTab!);
                            },
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Tarjeta 4: El Mini-Reto Didáctico
                        _buildInteractiveTriviaBox(
                          activeSubtopic,
                          isDark,
                          setModalState,
                          goToNextSubtopic,
                          nextSubtopic != null,
                          modalScrollController,
                        ),

                        // Navegación rápida inferior
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (previousSubtopic != null)
                              TextButton.icon(
                                onPressed: goToPreviousSubtopic,
                                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                                label: const Text('Tema anterior', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              )
                            else
                              const SizedBox.shrink(),
                            if (nextSubtopic != null)
                              TextButton.icon(
                                onPressed: goToNextSubtopic,
                                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                label: const Text('Siguiente tema', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              )
                            else
                              const SizedBox.shrink(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Tarjeta interactiva de alto impacto para reproducir el video explicativo oficial PNP
  Widget _buildOfficialVideoCard(EducationalVideo video, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF0F172A), const Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: video.color.withOpacity(0.7),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: video.color.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: video.color.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: video.color.withOpacity(0.6), width: 1.2),
                  ),
                  child: Icon(video.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'VIDEO OFICIAL PNP',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 9.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(video.orientationIcon, size: 11, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  '${video.duration} min • ${video.orientationLabel}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        video.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              video.description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerScreen(video: video),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 24, color: Colors.white),
                label: Text(
                  'Ver Video Explicativo (${video.duration} min)',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: video.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta interactiva para promocionar y acceder a los módulos nativos del aplicativo
  Widget _buildAppModulePromoCard(
    LearningSubtopic subtopic,
    bool isDark,
    VoidCallback onGoToModule,
  ) {
    const modColor = Color(0xFF4F46E5);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
              : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF818CF8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: modColor.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: modColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: modColor.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  subtopic.relatedAppModuleIcon ?? Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¡HERRAMIENTA DISPONIBLE EN NUESTRA APP!',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: Color(0xFF4338CA),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtopic.relatedAppModuleLabel ?? 'Conocer Módulo',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Pon en práctica esta lección de inmediato en la aplicación. Toca el botón para ir directamente al módulo sin rodeos:',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onGoToModule,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(
                'Ir a ${subtopic.relatedAppModuleLabel} ➔',
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: modColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Caja interactiva de la Mini-Trivia con tipografía amplia, auto-scroll al feedback y opción de continuar
  Widget _buildInteractiveTriviaBox(
    LearningSubtopic subtopic,
    bool isDark,
    StateSetter setModalState,
    VoidCallback onNext,
    bool hasNext,
    ScrollController modalScrollController,
  ) {
    final trivia = subtopic.trivia;
    final selectedOption = _answeredTrivias[subtopic.id];
    final isAlreadyCompleted = _treeService.isSubtopicCompleted(subtopic.id);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B2A) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3B82F6).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Insignia del reto
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.quiz_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'MINI-RETO DIDÁCTICO',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (isAlreadyCompleted)
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                    SizedBox(width: 4),
                    Text(
                      'Hoja Florecida',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Pregunta grande y nítida
          Text(
            trivia.question,
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              height: 1.35,
            ),
          ),

          const SizedBox(height: 14),

          // Opciones de respuesta en botones anchos y legibles
          ...List.generate(trivia.options.length, (optIndex) {
            final optText = trivia.options[optIndex];
            final isSelected = selectedOption == optIndex;
            final isCorrect = optIndex == trivia.correctOptionIndex;

            Color btnBg = isDark ? const Color(0xFF152334) : Colors.white;
            Color borderCol = isDark ? const Color(0xFF283A50) : const Color(0xFFCBD5E1);
            Color textCol = isDark ? Colors.white : const Color(0xFF1E293B);

            if (selectedOption != null) {
              if (isCorrect) {
                btnBg = const Color(0xFF10B981).withOpacity(0.2);
                borderCol = const Color(0xFF10B981);
                textCol = const Color(0xFF10B981);
              } else if (isSelected) {
                btnBg = const Color(0xFFEF4444).withOpacity(0.18);
                borderCol = const Color(0xFFEF4444);
                textCol = const Color(0xFFEF4444);
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () async {
                  setModalState(() {
                    _answeredTrivias[subtopic.id] = optIndex;
                  });
                  setState(() {
                    _answeredTrivias[subtopic.id] = optIndex;
                  });

                  if (isCorrect) {
                    HapticFeedback.lightImpact();
                    Future.delayed(const Duration(milliseconds: 90), () {
                      HapticFeedback.mediumImpact();
                    });
                    await _treeService.completeSubtopic(subtopic.id);
                    if (mounted) {
                      _showSuccessSnackBar(subtopic);
                    }
                  } else {
                    HapticFeedback.heavyImpact();
                  }

                  // Auto-scroll fluido hacia abajo para mostrar de inmediato el botón Continuar
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (modalScrollController.hasClients) {
                      modalScrollController.animateTo(
                        modalScrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 480),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: btnBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol, width: 1.3),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: borderCol, width: 1.5),
                          color: isSelected ? borderCol : (selectedOption != null && isCorrect ? const Color(0xFF10B981) : Colors.transparent),
                        ),
                        child: Center(
                          child: (selectedOption != null && (isCorrect || isSelected))
                              ? Icon(
                                  isCorrect ? Icons.check_rounded : Icons.close_rounded,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : Text(
                                  String.fromCharCode(65 + optIndex),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : borderCol,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          optText,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: textCol,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Explicación de retroalimentación y botón para continuar
          if (selectedOption != null) ...[
            const SizedBox(height: 12),
            if (selectedOption == trivia.correctOptionIndex) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF064E3B).withOpacity(0.4), const Color(0xFF0F172A)]
                        : [const Color(0xFFD1FAE5), const Color(0xFFECFDF5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981), width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '✨ ¡EXCELENTE RESPUESTA! ✨',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                                ),
                              ),
                              Text(
                                '¡Hoja dominada y añadida a tu progreso!',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      trivia.feedbackExplanation,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onNext,
                        icon: Icon(
                          hasNext ? Icons.arrow_forward_rounded : Icons.emoji_events_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: Text(
                          hasNext ? '¡Continuar al siguiente tema! ➔' : '¡Completaste todo el Árbol! Ver Medallas 🏆',
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A1215) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEF4444), width: 1.4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.priority_high_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '💡 ¡CASI LO LOGRAS!',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
                                ),
                              ),
                              Text(
                                'La respuesta correcta era la opción ${String.fromCharCode(65 + trivia.correctOptionIndex)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      trivia.feedbackExplanation,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setModalState(() {
                                _answeredTrivias.remove(subtopic.id);
                              });
                              setState(() {
                                _answeredTrivias.remove(subtopic.id);
                              });
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Reintentar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: isDark ? Colors.white38 : const Color(0xFF94A3B8), width: 1.2),
                              foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onNext,
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            label: Text(
                              hasNext ? 'Avanzar ➔' : 'Medallas 🏆',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A884),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],

          // Si ya estaba completado y no se ha respondido en esta sesión, dar la opción de avanzar directamente
          if (isAlreadyCompleted && selectedOption == null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onNext,
                icon: Icon(
                  hasNext ? Icons.arrow_forward_rounded : Icons.emoji_events_rounded,
                  size: 18,
                  color: const Color(0xFF00A884),
                ),
                label: Text(
                  hasNext ? 'Continuar al siguiente tema ➔' : 'Ver Medallas del Árbol 🏆',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00A884),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00A884), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Reto Express Aleatorio del Día
  void _startDailyQuickQuiz() {
    // Buscar un subtema aún no completado
    LearningSubtopic? candidate;
    LearningBranch? candidateBranch;

    for (final b in LearningTopicsCatalog.branches) {
      for (final s in b.subtopics) {
        if (!_treeService.isSubtopicCompleted(s.id)) {
          candidate = s;
          candidateBranch = b;
          break;
        }
      }
      if (candidate != null) break;
    }

    // Si ya completó todos, elegir uno al azar para repasar
    if (candidate == null) {
      final rand = math.Random();
      final b = LearningTopicsCatalog.branches[rand.nextInt(LearningTopicsCatalog.branches.length)];
      candidate = b.subtopics[rand.nextInt(b.subtopics.length)];
      candidateBranch = b;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    _openLessonModal(candidate, candidateBranch!, isDark);
  }

  /// Notificación SnackBar festiva al florecer una hoja
  void _showSuccessSnackBar(LearningSubtopic subtopic) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.park_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '¡Hoja florecida! "${subtopic.title}" dominada (${_treeService.overallProgressPercentageString} del Árbol)',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  /// Salón de Medallas y Trofeos Cívicos (Gamificación)
  void _showMedalsHallModal(bool isDark) {
    final completed = _treeService.completedCount;
    final medals = [
      {
        'title': 'Observador Alerta 🥉',
        'desc': 'Completaste de 1 a 7 hojas. Conoces el mito de las 24h, los primeros auxilios de la Hora Dorada y comisarías.',
        'target': 7,
        'unlocked': completed >= 1,
        'icon': Icons.military_tech_rounded,
        'color': const Color(0xFFCD7F32), // Bronce
      },
      {
        'title': 'Defensor Familiar 🥈',
        'desc': 'Completaste 8 a 18 hojas. Dominas ciberseguridad, redes sociales, Alerta Amber y prevención.',
        'target': 18,
        'unlocked': completed >= 8,
        'icon': Icons.shield_rounded,
        'color': const Color(0xFF94A3B8), // Plata
      },
      {
        'title': 'Guardián Comunitario 🥇',
        'desc': 'Completaste 19 a 27 hojas. Eres un referente en el cuidado de niños, abuelitos, difusión y búsqueda cívica.',
        'target': 27,
        'unlocked': completed >= 19,
        'icon': Icons.emoji_events_rounded,
        'color': const Color(0xFFF59E0B), // Oro
      },
      {
        'title': 'Maestro Protector Alerta Desaparecidos 👑',
        'desc': '¡Las 28 hojas florecidas al 100%! Máxima sabiduría ciudadana y doctrina preventiva de Alerta Desaparecidos.',
        'target': 28,
        'unlocked': completed == 28,
        'icon': Icons.workspace_premium_rounded,
        'color': const Color(0xFF10B981), // Esmeralda corona
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bg = isDark ? const Color(0xFF131F2E) : Colors.white;

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 28),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Salón de Medallas Cívicas',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    ...medals.map((m) {
                      final isUnlocked = m['unlocked'] as bool;
                      final col = m['color'] as Color;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isUnlocked
                              ? col.withOpacity(isDark ? 0.15 : 0.08)
                              : (isDark ? const Color(0xFF192534) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isUnlocked ? col : (isDark ? const Color(0xFF2A3A4D) : const Color(0xFFCBD5E1)),
                            width: isUnlocked ? 1.6 : 1.0,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isUnlocked ? col.withOpacity(0.25) : Colors.grey.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isUnlocked ? (m['icon'] as IconData) : Icons.lock_rounded,
                                color: isUnlocked ? col : Colors.grey,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          m['title'] as String,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isUnlocked
                                                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isUnlocked ? col : Colors.grey.withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          isUnlocked ? 'DESBLOQUEADO' : 'BLOQUEADO',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    m['desc'] as String,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.35,
                                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _shareProgress();
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Compartir mi rango con mi familia'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A884),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Compartir avance de Guías Educativas en WhatsApp y Redes
  void _shareProgress() {
    final title = _treeService.currentRankTitle;
    final percent = _treeService.overallProgressPercentageString;
    final completed = _treeService.completedCount;

    Share.share(
      '🎓 ¡Estoy aprendiendo en las Guías Educativas de Alerta Desaparecidos Perú!\n'
      '🎖️ Rango: $title\n'
      '📊 Progreso: $percent ($completed de 28 temas dominados).\n'
      'Aprende tú también gratis sobre prevención familiar y qué hacer ante una desaparición:\n'
      '👉 https://pnpalerta.web.app',
      subject: 'Mi progreso en las Guías Educativas - Alerta Desaparecidos',
    );
  }

  /// Diálogo para reiniciar progreso
  void _confirmResetProgress() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Reiniciar Guías Educativas?'),
        content: const Text(
          'Se restablecerán los temas completados para que puedas volver a leer y responder los mini-retos desde cero.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              await _treeService.resetProgress();
              setState(() {
                _answeredTrivias.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Progreso reiniciado exitosamente.')),
              );
            },
            child: const Text('Reiniciar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Pie de Página Pedagógico Oficial con Accesos Rápidos
  Widget _buildPedagogicalFooter(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131F2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF223246) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, color: Color(0xFF00A884), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Recursos y Marco Normativo Oficial',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Contenidos desarrollados bajo el Decreto Legislativo N° 1428, D.S. N° 003-2019-IN modificado por D.S. N° 010-2024-IN, D.S. N° 004-2026-IN (Alerta Amber y TEA) y Ley N° 30120 de videovigilancia.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Enlaces rápidos oficiales
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // 1. Tutorial Paso a Paso
              ActionChip(
                avatar: const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF0D9488)),
                label: const Text('Tutorial Paso a Paso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                backgroundColor: isDark ? const Color(0xFF1A2B3C) : const Color(0xFFCCFBF1),
                side: BorderSide(color: const Color(0xFF0D9488).withOpacity(0.4)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TutorialScreen()),
                  );
                },
              ),
              // 2. Portal Nacional de Búsqueda
              ActionChip(
                avatar: const Icon(Icons.language_rounded, size: 16, color: Color(0xFF2563EB)),
                label: const Text('Portal Nacional PNP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFDBEAFE),
                side: BorderSide(color: const Color(0xFF2563EB).withOpacity(0.4)),
                onPressed: () {
                  _launchExternalUrl(
                    'https://desaparecidosenperu.policia.gob.pe/Desaparecidos/desaparecidos_menor_mujer_hombre',
                  );
                },
              ),
              // 3. Línea 114 PNP
              ActionChip(
                avatar: const Icon(Icons.phone_in_talk_rounded, size: 16, color: Color(0xFFDC2626)),
                label: const Text('Línea 114 (24/7)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                backgroundColor: isDark ? const Color(0xFF2E191C) : const Color(0xFFFEE2E2),
                side: BorderSide(color: const Color(0xFFDC2626).withOpacity(0.4)),
                onPressed: () => _launchPhoneCall('114'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _launchExternalUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir: $url')),
        );
      }
    }
  }

  Future<void> _launchPhoneCall(String phone) async {
    final Uri uri = Uri.parse('tel:$phone');
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo llamar al: $phone')),
        );
      }
    }
  }
}
