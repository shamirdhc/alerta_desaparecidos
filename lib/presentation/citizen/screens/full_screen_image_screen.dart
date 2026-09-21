import 'package:flutter/material.dart';

class FullScreenImageScreen extends StatefulWidget {
  final String imageUrl;
  final String? heroTag;

  const FullScreenImageScreen({super.key, required this.imageUrl, this.heroTag});

  @override
  State<FullScreenImageScreen> createState() => _FullScreenImageScreenState();
}

class _FullScreenImageScreenState extends State<FullScreenImageScreen>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 24), // Reducido de 28 a 24
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_map, color: Colors.white, size: 22), // Reducido de 24 a 22
            onPressed: _resetZoom,
            tooltip: 'Restablecer zoom',
          ),
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
        color: Colors.black.withOpacity(0.8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), // Reducido padding
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pinch, color: Colors.white70, size: 14), // Reducido de 16 a 14
                  SizedBox(width: 6), // Reducido de 8 a 6
                  Text(
                    'Pellizca para zoom',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12, // Reducido de 14 a 12
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 12), // Reducido de 16 a 12
                  Icon(Icons.touch_app, color: Colors.white70, size: 14), // Reducido de 16 a 14
                  SizedBox(width: 6), // Reducido de 8 a 6
                  Text(
                    'Doble toque para zoom rápido',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12, // Reducido de 14 a 12
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
      widget.imageUrl,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return SizedBox(
          width: 180, // Reducido de 200 a 180
          height: 180, // Reducido de 200 a 180
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
                  strokeWidth: 2.5, // Reducido de 3 a 2.5
                ),
                SizedBox(height: 12), // Reducido de 16 a 12
                Text(
                  'Cargando imagen...',
                  style: TextStyle(color: Colors.white70, fontSize: 12), // Reducido de 14 a 12
                ),
              ],
            ),
          ),
        );
      },
      errorBuilder:
          (context, error, stackTrace) => SizedBox(
            width: 200,
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.white, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Error al cargar la imagen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Verifica tu conexión a internet',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
