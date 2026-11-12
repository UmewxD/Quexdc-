import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

const String? welcomeMontageVideoUrl = null;

enum WelcomeDestination { feed, boards, spaces }

class WelcomeMontageScreen extends StatefulWidget {
  const WelcomeMontageScreen({
    super.key,
    required this.onExplore,
    required this.onLookAround,
    this.videoUrl = welcomeMontageVideoUrl,
  });

  final ValueChanged<WelcomeDestination> onExplore;
  final VoidCallback onLookAround;
  final String? videoUrl;

  @override
  State<WelcomeMontageScreen> createState() => _WelcomeMontageScreenState();
}

class _WelcomeMontageScreenState extends State<WelcomeMontageScreen> {
  VideoPlayerController? _controller;
  bool _showOutro = false;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.videoUrl != null && widget.videoUrl!.trim().isNotEmpty) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    final uri = Uri.tryParse(widget.videoUrl!);
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty) {
      setState(() => _error = 'The welcome video needs a valid HTTPS URL.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    final controller = VideoPlayerController.networkUrl(uri);
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_handleVideoUpdate);
      setState(() {
        _controller = controller;
        _isLoading = false;
      });
    } catch (error) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load the welcome montage: $error';
      });
    }
  }

  void _handleVideoUpdate() {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isPlaying) {
      return;
    }
    final duration = controller.value.duration;
    if (duration > Duration.zero && controller.value.position >= duration) {
      _openOutro();
    }
  }

  void _openOutro() {
    if (!mounted || _showOutro) return;
    setState(() => _showOutro = true);
    _controller?.pause();
  }

  Future<void> _replay() async {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      await controller.seekTo(Duration.zero);
      await controller.play();
    } else {
      setState(() => _showOutro = false);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_showOutro ? 'Welcome to Quexdc' : 'Inside Quexdc'),
      actions: [
        if (_showOutro)
          IconButton(
            tooltip: 'Replay welcome montage',
            onPressed: _replay,
            icon: const Icon(Icons.replay),
          ),
      ],
    ),
    body: AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _showOutro ? _buildOutro(context) : _buildVideoSlot(context),
    ),
  );

  Widget _buildVideoSlot(BuildContext context) {
    final controller = _controller;
    return Center(
      key: const ValueKey('welcome-video-slot'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller != null && controller.value.isInitialized)
                AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                )
              else
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 220),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF101A3A), Color(0xFF35165E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : Icon(
                            _error == null
                                ? Icons.play_circle_outline
                                : Icons.error_outline,
                            color: Colors.white,
                            size: 76,
                          ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'The World , The Space , The Universe & . . . The Multiverse Of Us All',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _error ??
                    (widget.videoUrl == null || widget.videoUrl!.trim().isEmpty
                        ? 'Your welcome montage slot is ready. Add the finished video when you have it.'
                        : 'A welcome for humans, AI, animals, art, music, aliens & more.'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (controller != null && controller.value.isInitialized)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      tooltip: controller.value.isPlaying
                          ? 'Pause montage'
                          : 'Play montage',
                      onPressed: () {
                        setState(() {
                          controller.value.isPlaying
                              ? controller.pause()
                              : controller.play();
                        });
                      },
                      icon: Icon(
                        controller.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _openOutro,
                      child: const Text('Skip to the end'),
                    ),
                  ],
                )
              else if (_error != null)
                FilledButton(
                  onPressed: _openOutro,
                  child: const Text('Continue to the end'),
                )
              else
                FilledButton.icon(
                  onPressed: _isLoading
                      ? null
                      : widget.videoUrl == null ||
                            widget.videoUrl!.trim().isEmpty
                      ? _openOutro
                      : _initializeVideo,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(
                    widget.videoUrl == null || widget.videoUrl!.trim().isEmpty
                        ? 'Play welcome montage'
                        : 'Load welcome montage',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutro(BuildContext context) => Center(
    key: const ValueKey('welcome-outro'),
    child: SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.blur_on, size: 64),
              const SizedBox(height: 20),
              Text(
                'So / Aye . . . What now , wanderer ?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'This place is still being made. Explore, make something, or just look around.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => widget.onExplore(WelcomeDestination.feed),
                  icon: const Icon(Icons.dynamic_feed),
                  label: const Text('Explore the Feed'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => widget.onExplore(WelcomeDestination.boards),
                  icon: const Icon(Icons.dashboard_outlined),
                  label: const Text('Open the Boards'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => widget.onExplore(WelcomeDestination.spaces),
                  icon: const Icon(Icons.blur_on_outlined),
                  label: const Text('Visit Community Spaces'),
                ),
              ),
              TextButton(
                onPressed: widget.onLookAround,
                child: const Text('Just look around'),
              ),
              TextButton.icon(
                onPressed: _replay,
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('Replay welcome'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
