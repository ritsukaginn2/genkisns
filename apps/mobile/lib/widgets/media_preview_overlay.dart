import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import 'post_image_view.dart';

/// Fullscreen, swipeable gallery for a post's media. Images can be pinch-zoomed;
/// videos auto-play (with sound) on the active page and expose a mute toggle.
class MediaPreviewOverlay extends StatefulWidget {
  const MediaPreviewOverlay({
    super.key,
    required this.media,
    required this.onClose,
    this.initialIndex = 0,
  });

  final List<PostImageRef> media;
  final int initialIndex;
  final VoidCallback onClose;

  @override
  State<MediaPreviewOverlay> createState() => _MediaPreviewOverlayState();
}

class _MediaPreviewOverlayState extends State<MediaPreviewOverlay> {
  late final PageController pageController;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.media.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.media.length - 1);
    pageController = PageController(initialPage: currentIndex);
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;

    return Material(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: pageController,
              itemCount: media.length,
              onPageChanged: (index) => setState(() => currentIndex = index),
              itemBuilder: (context, index) {
                final item = media[index];
                if (item.isVideo) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: VideoSurface(
                        media: item,
                        active: index == currentIndex,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: PostImageView(
                        image: item,
                        borderRadius: BorderRadius.circular(4),
                        fit: BoxFit.contain,
                        iconSize: 42,
                      ),
                    ),
                  ),
                );
              },
            ),
            if (media.length > 1)
              Positioned(
                top: AppSpacing.md,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${currentIndex + 1} / ${media.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: IconButton.filled(
                tooltip: '关闭预览',
                onPressed: widget.onClose,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A self-contained video surface that owns its [VideoPlayerController].
///
/// Used both inline on the detail page (auto-play in the post's media frame) and
/// inside [MediaPreviewOverlay] (fullscreen page). It loops, exposes a mute
/// toggle, and pauses itself whenever [active] becomes false so off-screen or
/// backgrounded pages do not keep playing audio.
class VideoSurface extends StatefulWidget {
  const VideoSurface({
    super.key,
    required this.media,
    this.active = true,
    this.initiallyMuted = false,
    this.borderRadius = BorderRadius.zero,
    this.onTap,
  });

  final PostImageRef media;

  /// When false the video pauses; flipping back to true resumes it.
  final bool active;
  final bool initiallyMuted;
  final BorderRadius borderRadius;

  /// If provided, a tap calls this (e.g. open fullscreen) instead of toggling
  /// play/pause.
  final VoidCallback? onTap;

  @override
  State<VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<VideoSurface> {
  VideoPlayerController? controller;
  Object? error;
  late bool muted;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    muted = widget.initiallyMuted;
    _initialize();
  }

  @override
  void didUpdateWidget(VideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final readyController = controller;
    if (readyController != null && widget.active != oldWidget.active) {
      if (widget.active) {
        readyController.play();
      } else {
        readyController.pause();
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readyController = controller;
    if (error != null) {
      // Fall back to the static cover so a decode failure still looks intentional.
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: AspectRatio(
          aspectRatio: widget.media.aspectRatio,
          child: PostImageView(
            image: widget.media,
            borderRadius: widget.borderRadius,
          ),
        ),
      );
    }
    if (readyController == null || !readyController.value.isInitialized) {
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: AspectRatio(
          aspectRatio: widget.media.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PostImageView(
                image: widget.media,
                borderRadius: widget.borderRadius,
              ),
              const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final aspectRatio = readyController.value.aspectRatio > 0
        ? readyController.value.aspectRatio
        : widget.media.aspectRatio;

    return GestureDetector(
      onTap: _handleTap,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoPlayer(readyController),
              if (widget.onTap == null && !isPlaying)
                Container(
                  color: Colors.black.withValues(alpha: 0.18),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 76,
                    ),
                  ),
                ),
              Positioned(
                right: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: _MuteButton(muted: muted, onTap: _toggleMute),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initialize() async {
    final file = File(widget.media.localRef);
    if (!await file.exists()) {
      if (mounted) setState(() => error = StateError('Video file not found.'));
      return;
    }

    final nextController = VideoPlayerController.file(file);
    try {
      await nextController.initialize();
      await nextController.setLooping(true);
      await nextController.setVolume(muted ? 0 : 1);
      if (widget.active) {
        await nextController.play();
      }
      if (!mounted) {
        await nextController.dispose();
        return;
      }
      // Repaint on play/pause so the overlay play icon stays in sync.
      nextController.addListener(_handleControllerTick);
      setState(() {
        controller = nextController;
        isPlaying = nextController.value.isPlaying;
      });
    } on Object catch (caught) {
      await nextController.dispose();
      if (mounted) setState(() => error = caught);
    }
  }

  void _handleControllerTick() {
    final readyController = controller;
    if (readyController == null) return;
    final nextIsPlaying = readyController.value.isPlaying;
    if (nextIsPlaying == isPlaying) return;
    if (mounted) setState(() => isPlaying = nextIsPlaying);
  }

  void _handleTap() {
    final onTap = widget.onTap;
    if (onTap != null) {
      onTap();
      return;
    }
    final readyController = controller;
    if (readyController == null) return;
    if (readyController.value.isPlaying) {
      readyController.pause();
    } else {
      readyController.play();
    }
  }

  void _toggleMute() {
    final readyController = controller;
    if (readyController == null) return;
    setState(() {
      muted = !muted;
      readyController.setVolume(muted ? 0 : 1);
    });
  }
}

class _MuteButton extends StatelessWidget {
  const _MuteButton({required this.muted, required this.onTap});

  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: muted ? '取消静音' : '静音',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
