import 'dart:io';

import 'package:flutter/material.dart';

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
    final file = File(image.localRef);
    if (!image.localRef.startsWith('preview://') && file.existsSync()) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.file(
          file,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: image.previewColor ?? const Color(0xFFE9D9E1),
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.image,
        color: Colors.white.withValues(alpha: 0.86),
        size: iconSize,
      ),
    );
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
    final thumbnailRef = image.thumbnailRef;
    final thumbnail = thumbnailRef == null ? null : File(thumbnailRef);

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnail != null && thumbnail.existsSync())
            Image.file(thumbnail, fit: fit)
          else
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: image.previewColor ?? const Color(0xFFE9D9E1),
              ),
              child: Icon(
                Icons.videocam_outlined,
                color: Colors.white.withValues(alpha: 0.86),
                size: iconSize,
              ),
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

String _formatDuration(int? durationMillis) {
  if (durationMillis == null || durationMillis <= 0) return '0:00';
  final duration = Duration(milliseconds: durationMillis);
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
