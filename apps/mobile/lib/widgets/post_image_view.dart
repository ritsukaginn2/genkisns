import 'dart:io';

import 'package:flutter/material.dart';

import '../data/services/media_storage.dart';
import '../models.dart';

class PostImageView extends StatelessWidget {
  const PostImageView({
    super.key,
    required this.image,
    required this.borderRadius,
    this.fit = BoxFit.cover,
    this.iconSize = 30,
  });

  final PostImageRef image;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (image.isVideo) {
      return _VideoCover(
        image: image,
        borderRadius: borderRadius,
        fit: fit,
        iconSize: iconSize,
      );
    }

    return _ImageCover(
      image: image,
      borderRadius: borderRadius,
      fit: fit,
      iconSize: iconSize,
    );
  }
}

class _ImageCover extends StatelessWidget {
  const _ImageCover({
    required this.image,
    required this.borderRadius,
    required this.fit,
    required this.iconSize,
  });

  final PostImageRef image;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final path = MediaStorage.resolve(image.localRef);
    if (path != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Image.file(
              File(path),
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              cacheWidth: _decodeCacheWidth(context, constraints),
              filterQuality: FilterQuality.low,
              errorBuilder: (_, _, _) => _MediaPlaceholder(
                image: image,
                icon: Icons.image,
                size: iconSize,
              ),
            );
          },
        ),
      );
    }

    return _MediaPlaceholder(image: image, icon: Icons.image, size: iconSize);
  }
}

class _VideoCover extends StatelessWidget {
  const _VideoCover({
    required this.image,
    required this.borderRadius,
    required this.fit,
    required this.iconSize,
  });

  final PostImageRef image;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final thumbnailPath = image.thumbnailRef == null
        ? null
        : MediaStorage.resolve(image.thumbnailRef!);

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailPath != null)
            LayoutBuilder(
              builder: (context, constraints) {
                return Image.file(
                  File(thumbnailPath),
                  fit: fit,
                  gaplessPlayback: true,
                  cacheWidth: _decodeCacheWidth(context, constraints),
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, _, _) => _MediaPlaceholder(
                    image: image,
                    icon: Icons.videocam_outlined,
                    size: iconSize,
                  ),
                );
              },
            )
          else
            _MediaPlaceholder(
              image: image,
              icon: Icons.videocam_outlined,
              size: iconSize,
            ),
          Container(color: Colors.black.withValues(alpha: 0.12)),
          Center(
            child: Container(
              width: iconSize + 18,
              height: iconSize + 18,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.50),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: iconSize + 6,
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _formatDuration(image.durationMillis),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({
    required this.image,
    required this.icon,
    required this.size,
  });

  final PostImageRef image;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: image.previewColor ?? const Color(0xFFE9D9E1),
      child: Icon(
        icon,
        color: Colors.white.withValues(alpha: 0.86),
        size: size,
      ),
    );
  }
}

/// Decodes file-backed images at roughly their on-screen size instead of full
/// resolution. A 4000px camera photo shown in a ~180px tile otherwise decodes a
/// ~48MB bitmap and uploads a huge GPU texture, which janks list scrolling and
/// starves later animations. Aspect ratio is preserved (only width is hinted).
int? _decodeCacheWidth(BuildContext context, BoxConstraints constraints) {
  final width = constraints.maxWidth;
  if (!width.isFinite || width <= 0) return null;
  final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  return (width * devicePixelRatio).ceil();
}

String _formatDuration(int? durationMillis) {
  if (durationMillis == null || durationMillis <= 0) return '0:00';
  final duration = Duration(milliseconds: durationMillis);
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
