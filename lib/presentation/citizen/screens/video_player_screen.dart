import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'educational_guides_screen.dart';

class VideoPlayerScreen extends StatefulWidget {
  final EducationalVideo video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // Obtener URL de descarga de Firebase Storage
      final ref = FirebaseStorage.instance.refFromURL(widget.video.videoUrl);
      final downloadUrl = await ref.getDownloadURL();
      
      _controller = VideoPlayerController.network(downloadUrl);
      await _controller.initialize();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        _controller.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            // Back Button
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
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
          SizedBox(height: 20),
          Text(
            'Cargando video...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      );
    }

    if (_hasError) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 60),
          const SizedBox(height: 20),
          const Text(
            'Error al cargar el video',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
              _initializeVideo();
            },
            child: const Text('Reintentar'),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width,
        ),
        child: AspectRatio(
          aspectRatio: widget.video.orientation == VideoOrientation.vertical 
              ? 9/16 
              : 16/9,
          child: VideoPlayer(_controller),
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
            // Top Info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    widget.video.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.video.subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Bottom Controls
            if (!_isLoading && !_hasError)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress Bar
                    VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.orange,
                        bufferedColor: Colors.grey,
                        backgroundColor: Colors.white24,
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
                            _controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: () {
                            setState(() {
                              _controller.value.isPlaying
                                  ? _controller.pause()
                                  : _controller.play();
                            });
                          },
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: const Icon(
                            Icons.replay_10,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: () {
                            final position = _controller.value.position;
                            _controller.seekTo(
                              Duration(
                                seconds: (position.inSeconds - 10).clamp(0, _controller.value.duration.inSeconds),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: const Icon(
                            Icons.forward_10,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: () {
                            final position = _controller.value.position;
                            _controller.seekTo(
                              Duration(
                                seconds: (position.inSeconds + 10).clamp(0, _controller.value.duration.inSeconds),
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
    _controller.dispose();
    super.dispose();
  }
}