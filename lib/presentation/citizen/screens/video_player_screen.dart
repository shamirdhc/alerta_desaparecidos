import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../domain/models/educational_video_model.dart';

class VideoPlayerScreen extends StatefulWidget {
  final EducationalVideo video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      String downloadUrl = '';

      if (widget.video.videoUrl.startsWith('http://') ||
          widget.video.videoUrl.startsWith('https://')) {
        downloadUrl = widget.video.videoUrl;
      } else {
        try {
          final ref = FirebaseStorage.instance.refFromURL(widget.video.videoUrl);
          downloadUrl = await ref.getDownloadURL();
        } catch (e1) {
          debugPrint('Aviso refFromURL: $e1. Intentando fallback directo...');
          // Construir URL pública directa
          String path = widget.video.videoUrl;
          if (path.startsWith('gs://')) {
            final slashIndex = path.indexOf('/', 5);
            if (slashIndex != -1) {
              path = path.substring(slashIndex + 1);
            }
          }
          final encodedPath = Uri.encodeComponent(path);
          downloadUrl =
              'https://firebasestorage.googleapis.com/v0/b/alerta-desaparecidos-pnp.firebasestorage.app/o/$encodedPath?alt=media';
        }
      }

      final uri = Uri.parse(downloadUrl);
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;

      await controller.initialize();

      controller.addListener(() {
        if (mounted) setState(() {});
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Intentar autoplay; si el navegador bloquea audio/video automático, permitir play manual
        try {
          await controller.play();
        } catch (playErr) {
          debugPrint('Autoplay no permitido por política del navegador: $playErr');
        }
      }
    } catch (e, stack) {
      debugPrint('Error inicializando video: $e\n$stack');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
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
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Video Player
              Center(
                child: _buildVideoContent(),
              ),
              // Controls Overlay
              if (_showControls) _buildControlsOverlay(),
              // Back Button - más compacto
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                    tooltip: 'Volver',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_isLoading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.orange),
          SizedBox(height: 16),
          Text(
            'Cargando video...',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      );
    }

    if (_hasError || _controller == null || !_controller!.value.isInitialized) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 50),
          const SizedBox(height: 16),
          const Text(
            'Error al cargar el video',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              _initializeVideo();
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reintentar', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
          ),
        ],
      );
    }

    final isPlaying = _controller!.value.isPlaying;

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: MediaQuery.of(context).size.width,
        ),
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio > 0
              ? _controller!.value.aspectRatio
              : (widget.video.orientation == VideoOrientation.vertical ? 9 / 16 : 16 / 9),
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller!),
              // Botón central de play cuando está pausado
              if (!isPlaying && !_isLoading)
                GestureDetector(
                  onTap: () {
                    _controller!.play();
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.3),
              Colors.transparent,
              Colors.black.withOpacity(0.3),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Top Info - más compacto
            Padding(
              padding: const EdgeInsets.all(16), // Reducido de 20 a 16
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 32), // Reducido de 40 a 32
                  Text(
                    widget.video.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18, // Reducido de 20 a 18
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.video.subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12, // Reducido de 14 a 12
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Bottom Controls
            if (!_isLoading &&
                !_hasError &&
                _controller != null &&
                _controller!.value.isInitialized)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress Bar
                    VideoProgressIndicator(
                      _controller!,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFF00E5FF),
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Control Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _controller!.value.isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            color: const Color(0xFF00E5FF),
                            size: 38,
                          ),
                          onPressed: () {
                            setState(() {
                              _controller!.value.isPlaying
                                  ? _controller!.pause()
                                  : _controller!.play();
                            });
                          },
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: const Icon(
                            Icons.replay_10_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () {
                            final position = _controller!.value.position;
                            _controller!.seekTo(
                              Duration(
                                seconds: (position.inSeconds - 10)
                                    .clamp(0, _controller!.value.duration.inSeconds),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: const Icon(
                            Icons.forward_10_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () {
                            final position = _controller!.value.position;
                            _controller!.seekTo(
                              Duration(
                                seconds: (position.inSeconds + 10)
                                    .clamp(0, _controller!.value.duration.inSeconds),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}