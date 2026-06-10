import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../models.dart';

enum DeviceAlbumLoadStatus { ready, denied, empty }

@immutable
class DeviceAlbumLoadResult {
  const DeviceAlbumLoadResult({
    required this.status,
    this.albums = const [],
    this.options = const [],
    this.hasMore = false,
  });

  final DeviceAlbumLoadStatus status;
  final List<DeviceAlbumPathOption> albums;
  final List<DeviceAlbumImageOption> options;
  final bool hasMore;
}

@immutable
class DeviceAlbumPathOption {
  const DeviceAlbumPathOption({
    required this.id,
    required this.name,
    required this.assetCount,
    required this.path,
  });

  final String id;
  final String name;
  final int assetCount;
  final AssetPathEntity path;
}

@immutable
class DeviceAlbumImageOption {
  const DeviceAlbumImageOption({
    required this.assetId,
    required this.type,
    required this.thumbnailBytes,
    required this.asset,
    this.durationMillis,
    this.width,
    this.height,
  });

  final String assetId;
  final PostMediaType type;
  final Uint8List thumbnailBytes;
  final AssetEntity asset;
  final int? durationMillis;
  final int? width;
  final int? height;

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
    this.width,
    this.height,
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
  final int? width;
  final int? height;
  final String? assetId;

  PostImageRef toPostImageRef({required int sortIndex}) {
    return PostImageRef(
      id: 'image_$id',
      type: type,
      source: source,
      localRef: localRef,
      thumbnailRef: thumbnailRef,
      durationMillis: durationMillis,
      width: width,
      height: height,
      sortIndex: sortIndex,
      previewColor: previewColor,
    );
  }
}

class ImagePickerService {
  const ImagePickerService();

  static const _cameraChannel = MethodChannel('genki_sns/camera');

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
      width: 16,
      height: 9,
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
        width: await _imageWidth(picked.path),
        height: await _imageHeight(picked.path),
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
        width: 16,
        height: 9,
      ),
    ];
  }

  Future<List<PickedImageDraft>> captureFromCamera({required int id}) async {
    try {
      final result = await _cameraChannel.invokeMapMethod<String, Object?>(
        'capture',
      );
      if (result == null) return const [];

      final path = result['path'] as String?;
      final typeValue = result['type'] as String?;
      if (path == null || path.isEmpty || typeValue == null) return const [];

      final type = typeValue == 'video'
          ? PostMediaType.video
          : PostMediaType.image;
      final localRef = await _copyFileToMediaDirectory(
        File(path),
        source: PostImageSource.camera,
        id: id,
      );
      return [
        PickedImageDraft(
          id: id,
          type: type,
          albumIndex: null,
          source: PostImageSource.camera,
          localRef: localRef,
          thumbnailRef: type == PostMediaType.video
              ? await _generateVideoThumbnail(localRef)
              : null,
          width: result['width'] as int?,
          height: result['height'] as int?,
        ),
      ];
    } on MissingPluginException {
      return pickFromCamera(id: id);
    } on PlatformException {
      return const [];
    }
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
          width: await _imageWidth(pickedFiles[index].path),
          height: await _imageHeight(pickedFiles[index].path),
        ),
      );
    }
    return drafts;
  }

  Future<DeviceAlbumLoadResult> listDeviceAlbumOptions({
    AssetPathEntity? path,
    int page = 0,
    int pageSize = 60,
    bool includeAlbums = true,
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
      onlyAll: false,
      type: RequestType.common,
    );
    if (paths.isEmpty) {
      return const DeviceAlbumLoadResult(status: DeviceAlbumLoadStatus.empty);
    }

    final albumOptions = includeAlbums
        ? await _buildAlbumOptions(paths)
        : const <DeviceAlbumPathOption>[];

    final activePath = path ?? paths.first;
    final assetCount = await activePath.assetCountAsync;
    final assets = await activePath.getAssetListPaged(
      page: page,
      size: pageSize,
    );
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
          width: asset.width,
          height: asset.height,
        ),
      );
    }

    return DeviceAlbumLoadResult(
      status: options.isEmpty
          ? DeviceAlbumLoadStatus.empty
          : DeviceAlbumLoadStatus.ready,
      albums: List.unmodifiable(albumOptions),
      options: List.unmodifiable(options),
      hasMore: (page + 1) * pageSize < assetCount,
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
      width: option.width,
      height: option.height,
      assetId: option.assetId,
    );
  }

  /// Resolves the on-disk file for an album option so it can be previewed
  /// (zoomed / played) without first copying it into the post media directory.
  Future<File?> resolvePreviewFile(DeviceAlbumImageOption option) async {
    return await option.asset.file ?? await option.asset.originFile;
  }

  Future<List<DeviceAlbumPathOption>> _buildAlbumOptions(
    List<AssetPathEntity> paths,
  ) async {
    final albumOptions = <DeviceAlbumPathOption>[];
    for (final albumPath in paths) {
      albumOptions.add(
        DeviceAlbumPathOption(
          id: albumPath.id,
          name: albumPath.name,
          assetCount: await albumPath.assetCountAsync,
          path: albumPath,
        ),
      );
    }
    return albumOptions;
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
    return p.join('post_media', filename);
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
    return p.join('post_media', filename);
  }

  Future<Directory> _mediaDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(documentsDir.path, 'post_media'));
    await mediaDir.create(recursive: true);
    return mediaDir;
  }

  Future<int?> _imageWidth(String path) async {
    final size = await _imageSize(path);
    return size?.width.toInt();
  }

  Future<int?> _imageHeight(String path) async {
    final size = await _imageSize(path);
    return size?.height.toInt();
  }

  Future<ui.Size?> _imageSize(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      return ui.Size(image.width.toDouble(), image.height.toDouble());
    } on Object {
      return null;
    }
  }
}
