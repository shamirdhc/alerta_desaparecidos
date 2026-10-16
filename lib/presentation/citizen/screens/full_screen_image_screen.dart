import 'package:flutter/material.dart';

class FullScreenImageScreen extends StatefulWidget {
  final String imageUrl;
  final String? fallbackImageUrl;
  final String? heroTag;

  const FullScreenImageScreen({
    super.key,
    required this.imageUrl,
    this.fallbackImageUrl,
    this.heroTag,
  });

  @override
  State<FullScreenImageScreen> createState() => _FullScreenImageScreenState();
}

class _FullScreenImageScreenState extends State<FullScreenImageScreen>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  Key _imageKey = UniqueKey();
  late String _currentUrl;
  bool _switchedToFallback = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.imageUrl;
    // Si la URL es del servidor de la PNP (sin CORS en Web) y hay respaldo en Storage, usarlo
    if (_currentUrl.contains('sistemas.policia.gob.pe') &&
        widget.fallbackImageUrl != null &&
        widget.fallbackImageUrl!.contains('firebasestorage.googleapis.com')) {
      _currentUrl = widget.fallbackImageUrl!;
      _switchedToFallback = true;
    }
    _transformationController = TransformationController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250), // Más rápido y fluido
      vsync: this,
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic, // Curva más suave
      ),
    );
    _animationController.forward(from: 0);
  }

  void _onDoubleTap() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final targetScale = currentScale > 1.2 ? 1.0 : 1.8; // Zoom más moderado
    
    // Obtener el centro de la pantalla
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;
    
    Matrix4 targetMatrix;
    if (targetScale == 1.0) {
      // Volver al zoom original centrado
      targetMatrix = Matrix4.identity();
    } else {
      // Aplicar zoom centrado en la pantalla
      targetMatrix = Matrix4.identity()
        ..translate(centerX, centerY)
        ..scale(targetScale)
        ..translate(-centerX, -centerY);
    }
    
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward(from: 0);
  }

  void _zoomIn() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * 1.4).clamp(0.5, 5.0);
    _zoomToScale(targetScale);
  }

  void _zoomOut() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final targetScale = (currentScale / 1.4).clamp(0.5, 5.0);
    _zoomToScale(targetScale);
  }

  void _zoomToScale(double targetScale) {
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;
    final targetMatrix = Matrix4.identity()
      ..translate(centerX, centerY)
      ..scale(targetScale)
      ..translate(-centerX, -centerY);

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.85),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Cerrar',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in, color: Colors.white, size: 24),
            onPressed: _zoomIn,
            tooltip: 'Acercar (+)',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out, color: Colors.white, size: 24),
            onPressed: _zoomOut,
            tooltip: 'Alejar (-)',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out_map, color: Colors.white, size: 22),
            onPressed: _resetZoom,
            tooltip: 'Restablecer zoom',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          if (_animation != null) {
            _transformationController.value = _animation!.value;
          }
          return InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.5,
            maxScale: 5.0,
            panEnabled: true,
            scaleEnabled: true,
            trackpadScrollCausesScale: true,
            child: GestureDetector(
              onDoubleTap: _onDoubleTap,
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child:
                      widget.heroTag != null
                          ? Hero(tag: widget.heroTag!, child: _buildImage())
                          : _buildImage(),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        color: Colors.black.withOpacity(0.85),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (isDesktop) ...[
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mouse, color: Colors.white70, size: 15),
                        SizedBox(width: 6),
                        Text(
                          'Arrastra para mover • Doble clic para zoom',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in, color: Colors.white70, size: 15),
                        SizedBox(width: 6),
                        Text(
                          'Botones superiores para acercar / alejar',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pinch, color: Colors.white70, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Pellizca para zoom',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app, color: Colors.white70, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Doble toque para zoom rápido',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    return Image.network(
      _currentUrl,
      key: _imageKey,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return SizedBox(
          width: 180,
          height: 180,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  value:
                      loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2.5,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cargando imagen...',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        // Si falló y tenemos una URL de respaldo válida diferente (como la Nota Oficial en Storage)
        if (!_switchedToFallback &&
            widget.fallbackImageUrl != null &&
            widget.fallbackImageUrl!.trim().isNotEmpty &&
            widget.fallbackImageUrl != _currentUrl) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _switchedToFallback = true;
                _currentUrl = widget.fallbackImageUrl!;
                _imageKey = UniqueKey();
              });
            }
          });
          return const SizedBox(
            width: 180,
            height: 180,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2.5,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Cargando documento oficial...',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        return SizedBox(
          width: 260,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.white70, size: 56),
                const SizedBox(height: 14),
                const Text(
                  'No se pudo cargar la imagen',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Verifica tu conexión a internet o reintenta',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _imageKey = UniqueKey();
                        });
                      },
                      icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
                      label: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                    if (widget.fallbackImageUrl != null &&
                        widget.fallbackImageUrl!.trim().isNotEmpty &&
                        widget.fallbackImageUrl != _currentUrl) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _switchedToFallback = true;
                            _currentUrl = widget.fallbackImageUrl!;
                            _imageKey = UniqueKey();
                          });
                        },
                        icon: const Icon(Icons.description_rounded, size: 18, color: Colors.white),
                        label: const Text('Ver Nota PNP', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
