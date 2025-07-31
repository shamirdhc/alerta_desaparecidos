import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../view_models/tutorial_view_model.dart';
import 'pdf_viewer_screen.dart';

class TutorialLibraryScreen extends StatelessWidget {
  const TutorialLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TutorialViewModel(),
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
                _buildPoliceAppBar(context),
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoliceAppBar(BuildContext context) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROTOCOLOS OPERATIVOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Manuales y Procedimientos PNP',
                  style: TextStyle(
                    color: const Color(0xFF778DA9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Consumer<TutorialViewModel>(
            builder: (context, viewModel, child) {
              return GestureDetector(
                onTap: viewModel.toggleShowOnlyRequired,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: viewModel.showOnlyRequired 
                        ? const Color(0xFFFF6B35).withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: viewModel.showOnlyRequired 
                          ? const Color(0xFFFF6B35)
                          : Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: FaIcon(
                    viewModel.showOnlyRequired 
                        ? FontAwesomeIcons.solidStar 
                        : FontAwesomeIcons.star,
                    color: viewModel.showOnlyRequired 
                        ? const Color(0xFFFF6B35)
                        : Colors.white,
                    size: 16,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<TutorialViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.tutorials.isEmpty) {
          return _buildEmptyState();
        }

        return _buildTutorialList(viewModel);
      },
    );
  }

  Widget _buildTutorialList(TutorialViewModel viewModel) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: viewModel.tutorials.length,
      itemBuilder: (context, index) {
        final tutorial = viewModel.tutorials[index];
        return _buildTutorialCard(context, tutorial);
      },
    );
  }

  Widget _buildTutorialCard(BuildContext context, tutorial) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B263B).withOpacity(0.8),
            const Color(0xFF415A77).withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tutorial.isRequired 
              ? const Color(0xFFFF6B35).withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
          width: tutorial.isRequired ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openPdfViewer(context, tutorial),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: tutorial.isRequired 
                              ? [const Color(0xFFFF6B35), const Color(0xFFFF8C42)]
                              : [const Color(0xFF415A77), const Color(0xFF778DA9)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (tutorial.isRequired 
                                ? const Color(0xFFFF6B35) 
                                : const Color(0xFF415A77)).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: FaIcon(
                        _getIconForTutorial(tutorial),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tutorial.title.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tutorial.category.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFF778DA9),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (tutorial.isRequired)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B35).withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'OBLIGATORIO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  tutorial.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoChip(
                      icon: FontAwesomeIcons.clock,
                      label: '${tutorial.estimatedReadTime} MIN',
                      color: const Color(0xFF778DA9),
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      icon: FontAwesomeIcons.calendarAlt,
                      label: _formatDate(tutorial.lastUpdated),
                      color: const Color(0xFF778DA9),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const FaIcon(
                        FontAwesomeIcons.chevronRight,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            icon,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const FaIcon(
              FontAwesomeIcons.folderOpen,
              size: 48,
              color: Color(0xFF778DA9),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'NO HAY PROTOCOLOS DISPONIBLES',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contacte con el administrador del sistema',
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF778DA9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForTutorial(tutorial) {
    switch (tutorial.iconName) {
      case 'gavel':
        return FontAwesomeIcons.gavel;
      case 'update':
        return FontAwesomeIcons.sync;
      case 'warning':
        return FontAwesomeIcons.exclamationTriangle;
      case 'computer':
        return FontAwesomeIcons.desktop;
      case 'people':
        return FontAwesomeIcons.users;
      default:
        return FontAwesomeIcons.fileAlt;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _openPdfViewer(BuildContext context, tutorial) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(tutorial: tutorial),
      ),
    );
  }
}