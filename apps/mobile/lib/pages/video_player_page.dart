import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/page_header.dart';

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key, required this.video});

  final PostImageRef video;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? controller;
  Object? error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final file = File(widget.video.localRef);
    if (!await file.exists()) {
      setState(() => error = StateError('Video file not found.'));
      return;
    }

    final nextController = VideoPlayerController.file(file);
    try {
      await nextController.initialize();
      await nextController.setLooping(true);
      if (!mounted) {
        await nextController.dispose();
        return;
      }
      setState(() => controller = nextController);
    } on Object catch (caught) {
      await nextController.dispose();
      if (!mounted) return;
      setState(() => error = caught);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readyController = controller;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PageHeader(title: '视频'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: error != null
                      ? const _VideoStateMessage(
                          icon: Icons.error_outline,
                          text: '视频暂时无法播放',
                        )
                      : readyController == null
                      ? const CircularProgressIndicator()
                      : _VideoPlayerSurface(controller: readyController),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPlayerSurface extends StatefulWidget {
  const _VideoPlayerSurface({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_VideoPlayerSurface> createState() => _VideoPlayerSurfaceState();
}

class _VideoPlayerSurfaceState extends State<_VideoPlayerSurface> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _VideoPlayerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isPlaying = controller.value.isPlaying;

    return GestureDetector(
      onTap: _togglePlayback,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoPlayer(controller),
              AnimatedOpacity(
                opacity: isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 160),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.16),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 72,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _togglePlayback() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }
}

class _VideoStateMessage extends StatelessWidget {
  const _VideoStateMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.muted, size: 40),
        const SizedBox(height: AppSpacing.md),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
