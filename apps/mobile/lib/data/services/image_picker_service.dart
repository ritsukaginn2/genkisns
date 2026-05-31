import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../models.dart';

enum DeviceAlbumLoadStatus { ready, denied, empty }

@immutable
class DeviceAlbumLoadResult {
  const DeviceAlbumLoadResult({required this.status, this.options = const []});

  final DeviceAlbumLoadStatus status;
  final List<DeviceAlbumImageOption> options;
}

@immutable
class DeviceAlbumImageOption {
  const DeviceAlbumImageOption({
    required this.assetId,
    required this.type,
    required this.thumbnailBytes,
    required this.asset,
    this.durationMillis,
  });

  final String assetId;
  final PostMediaType type;
  final Uint8List thumbnailBytes;
  final AssetEntity asset;
  final int? durationMillis;

  bool get isVideo => type == PostMediaType.video;
}

@immutable
class AlbumImageOption {
  const AlbumImageOption({
    required this.index,
    required this.previewColor,
    required this.localRef,
  });

  final int index;
  final Color previewColor;
  final String localRef;
}

@immutable
class PickedImageDraft {
  const PickedImageDraft({
    required this.id,
    this.type = PostMediaType.image,
    this.previewColor,
    required this.albumIndex,
    required this.source,
    required this.localRef,
    this.thumbnailRef,
    this.durationMillis,
    this.assetId,
  });

  final int id;
  final PostMediaType type;
  final Color? previewColor;
  final int? albumIndex;
  final PostImageSource source;
  final String localRef;
  final String? thumbnailRef;
  final int? durationMillis;
  final String? assetId;

  PostImageRef toPostImageRef({required int sortIndex}) {
    return PostImageRef(
      id: 'image_$id',
      type: type,
      source: source,
      localRef: localRef,
      thumbnailRef: thumbnailRef,
      durationMillis: durationMillis,
      sortIndex: sortIndex,
      previewColor: previewColor,
    );
  }
}

class ImagePickerService {
  const ImagePickerService();

  static const albumPreviewColors = [
    Color(0xFFDF7F5F),
    Color(0xFF4A8C85),
    Color(0xFF4C6F9D),
    Color(0xFFE0B44B),
    Color(0xFF8E6BBE),
    Color(0xFF5E8C61),
    Color(0xFFB95D7A),
    Color(0xFF668DA8),
    Color(0xFFB27C46),
  ];

  List<AlbumImageOption> listAlbumOptions() {
    return [
      for (var index = 0; index < albumPreviewColors.length; index++)
        AlbumImageOption(
          index: index,
          previewColor: albumPreviewColors[index],
          localRef: 'album://image/$index',
        ),
    ];
  }

  PickedImageDraft fromInitialPreviewColor({
    required int id,
    required Color color,
  }) {
    final albumIndex = albumPreviewColors.indexOf(color);
    return PickedImageDraft(
      id: id,
      type: PostMediaType.image,
      previewColor: color,
      albumIndex: albumIndex == -1 ? null : albumIndex,
      source: PostImageSource.preview,
      localRef: 'preview://initial/$id',
    );
  }

  PickedImageDraft fromCamera({required int id}) {
    return PickedImageDraft(
      id: id,
      type: PostMediaType.image,
      previewColor: albumPreviewColors[id % albumPreviewColors.length],
      albumIndex: null,
      source: PostImageSource.camera,
      localRef: 'camera://image/$id',
    );
  }

  PickedImageDraft fromCameraVideo({required int id}) {
    return PickedImageDraft(
      id: id,
      type: PostMediaType.video,
      previewColor: albumPreviewColors[id % albumPreviewColors.length],
      albumIndex: null,
      source: PostImageSource.camera,
      localRef: 'camera://video/$id',
      durationMillis: 18 * 1000,
    );
  }

  PickedImageDraft fromAlbum({required int id, required int albumIndex}) {
    final options = listAlbumOptions();
    final option = options.firstWhere(
      (candidate) => candidate.index == albumIndex,
      orElse: () => options.first,
    );
    return PickedImageDraft(
      id: id,
      type: PostMediaType.image,
      previewColor: option.previewColor,
      albumIndex: option.index,
      source: PostImageSource.album,
      localRef: option.localRef,
    );
  }

  Future<List<PickedImageDraft>> pickFromCamera({required int id}) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
      requestFullMetadata: false,
    );
    if (picked == null) return const [];

    return [
      PickedImageDraft(
        id: id,
        type: PostMediaType.image,
        albumIndex: null,
        source: PostImageSource.camera,
        localRef: await _persistPickedFile(
          picked,
          source: PostImageSource.camera,
          id: id,
        ),
      ),
    ];
  }

  Future<List<PickedImageDraft>> pickVideoFromCamera({required int id}) async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.camera);
    if (picked == null) return const [];

    final localRef = await _persistPickedFile(
      picked,
      source: PostImageSource.camera,
      id: id,
    );
    return [
      PickedImageDraft(
        id: id,
        type: PostMediaType.video,
        albumIndex: null,
        source: PostImageSource.camera,
        localRef: localRef,
        thumbnailRef: await _generateVideoThumbnail(localRef),
      ),
    ];
  }

  Future<List<PickedImageDraft>> pickFromAlbum({
    required int nextId,
    required int limit,
  }) async {
    if (limit <= 0) return const [];

    final pickedFiles = await ImagePicker().pickMultiImage(
      imageQuality: 92,
      limit: limit,
      requestFullMetadata: false,
    );
    final drafts = <PickedImageDraft>[];
    for (var index = 0; index < pickedFiles.length; index++) {
      final id = nextId + index;
      drafts.add(
        PickedImageDraft(
          id: id,
          type: PostMediaType.image,
          albumIndex: null,
          source: PostImageSource.album,
          localRef: await _persistPickedFile(
            pickedFiles[index],
            source: PostImageSource.album,
            id: id,
          ),
        ),
      );
    }
    return drafts;
  }

  Future<DeviceAlbumLoadResult> listDeviceAlbumOptions({
    int limit = 120,
  }) async {
    final permission = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.common,
          mediaLocation: false,
        ),
      ),
    );
    if (!permission.hasAccess) {
      return const DeviceAlbumLoadResult(status: DeviceAlbumLoadStatus.denied);
    }

    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.common,
    );
    if (paths.isEmpty) {
      return const DeviceAlbumLoadResult(status: DeviceAlbumLoadStatus.empty);
    }

    final assets = await paths.first.getAssetListPaged(page: 0, size: limit);
    final options = <DeviceAlbumImageOption>[];
    for (final asset in assets) {
      final type = switch (asset.type) {
        AssetType.video => PostMediaType.video,
        AssetType.image => PostMediaType.image,
        _ => null,
      };
      if (type == null) continue;

      final thumbnailBytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(300),
        quality: 82,
      );
      if (thumbnailBytes == null) continue;
      options.add(
        DeviceAlbumImageOption(
          assetId: asset.id,
          type: type,
          thumbnailBytes: thumbnailBytes,
          asset: asset,
          durationMillis: type == PostMediaType.video
              ? asset.videoDuration.inMilliseconds
              : null,
        ),
      );
    }

    return DeviceAlbumLoadResult(
      status: options.isEmpty
          ? DeviceAlbumLoadStatus.empty
          : DeviceAlbumLoadStatus.ready,
      options: List.unmodifiable(options),
    );
  }

  Future<PickedImageDraft?> fromDeviceAlbumOption({
    required int id,
    required DeviceAlbumImageOption option,
  }) async {
    final sourceFile = await option.asset.originFile ?? await option.asset.file;
    if (sourceFile == null) return null;

    return PickedImageDraft(
      id: id,
      type: option.type,
      albumIndex: null,
      source: PostImageSource.album,
      localRef: await _copyFileToMediaDirectory(
        sourceFile,
        source: PostImageSource.album,
        id: id,
      ),
      thumbnailRef: option.isVideo
          ? await _persistThumbnailBytes(option.thumbnailBytes, id: id)
          : null,
      durationMillis: option.durationMillis,
      assetId: option.assetId,
    );
  }

  Future<void> openAlbumSettings() => PhotoManager.openSetting();

  Future<void> deletePickedDraft(PickedImageDraft image) async {
    if (image.localRef.startsWith('preview://') ||
        image.localRef.startsWith('camera://') ||
        image.localRef.startsWith('album://')) {
      return;
    }
    final file = File(image.localRef);
    if (await file.exists()) {
      await file.delete();
    }
    final thumbnailRef = image.thumbnailRef;
    if (thumbnailRef != null) {
      final thumbnail = File(thumbnailRef);
      if (await thumbnail.exists()) {
        await thumbnail.delete();
      }
    }
  }

  Future<String> _persistPickedFile(
    XFile pickedFile, {
    required PostImageSource source,
    required int id,
  }) async {
    return _copyFileToMediaDirectory(
      File(pickedFile.path),
      source: source,
      id: id,
    );
  }

  Future<String> _copyFileToMediaDirectory(
    File sourceFile, {
    required PostImageSource source,
    required int id,
  }) async {
    final mediaDir = await _mediaDirectory();

    final extension = p.extension(sourceFile.path).isEmpty
        ? '.jpg'
        : p.extension(sourceFile.path);
    final filename =
        '${DateTime.now().microsecondsSinceEpoch}_${source.name}_$id$extension';
    final targetPath = p.join(mediaDir.path, filename);
    await sourceFile.copy(targetPath);
    return targetPath;
  }

  Future<String?> _generateVideoThumbnail(String videoPath) async {
    try {
      final mediaDir = await _mediaDirectory();
      return VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: mediaDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 640,
        quality: 82,
      );
    } on Object {
      return null;
    }
  }

  Future<String> _persistThumbnailBytes(
    Uint8List bytes, {
    required int id,
  }) async {
    final mediaDir = await _mediaDirectory();
    final filename = '${DateTime.now().microsecondsSinceEpoch}_thumb_$id.jpg';
    final targetPath = p.join(mediaDir.path, filename);
    await File(targetPath).writeAsBytes(bytes, flush: true);
    return targetPath;
  }

  Future<Directory> _mediaDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(documentsDir.path, 'post_media'));
    await mediaDir.create(recursive: true);
    return mediaDir;
  }
}
