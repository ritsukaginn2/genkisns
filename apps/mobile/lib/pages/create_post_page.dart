import 'dart:async';

import 'package:flutter/material.dart';

import '../data/services/image_picker_service.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/media_preview_overlay.dart';
import '../widgets/page_header.dart';
import '../widgets/post_image_view.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({
    super.key,
    required this.onPublish,
    this.initialText = '',
    this.initialImageColors = const [],
    this.showBackButton = true,
    this.initialShowImageSourceSheet = false,
    this.initialShowAlbumPicker = false,
    this.imagePickerService = const ImagePickerService(),
    this.useMockMediaPicker = false,
    this.mockCameraMediaType = PostMediaType.image,
  });

  final FutureOr<void> Function(PostDraft draft) onPublish;
  final String initialText;
  final List<Color> initialImageColors;
  final bool showBackButton;
  final bool initialShowImageSourceSheet;
  final bool initialShowAlbumPicker;
  final ImagePickerService imagePickerService;
  final bool useMockMediaPicker;
  final PostMediaType mockCameraMediaType;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final textController = TextEditingController();
  final textFocusNode = FocusNode();
  final List<PickedImageDraft> images = [];
  int nextImageId = 0;
  Animation<double>? transitionAnimation;
  bool didOpenInitialPicker = false;
  bool isPublishing = false;
  bool hasText = false;

  static const maxImages = 9;

  @override
  void initState() {
    super.initState();
    textController.text = widget.initialText;
    hasText = widget.initialText.trim().isNotEmpty;
    for (var i = 0; i < widget.initialImageColors.length; i++) {
      final color = widget.initialImageColors[i];
      images.add(
        widget.imagePickerService.fromInitialPreviewColor(id: i, color: color),
      );
    }
    nextImageId = widget.initialImageColors.length;
    _scheduleInitialTextFocus();
  }

  @override
  void dispose() {
    transitionAnimation?.removeStatusListener(_handleTransitionStatus);
    textFocusNode.dispose();
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPublish = !isPublishing && (hasText || images.isNotEmpty);
    final selectedVideo = _selectedVideo;
    _openInitialPickerIfNeeded();

    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _unfocusTextField(),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              PageHeader(title: '发布笔记', showBackButton: widget.showBackButton),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: TextField(
                        controller: textController,
                        focusNode: textFocusNode,
                        minLines: 7,
                        maxLines: 12,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: '今天有什么想被看见的小事？',
                          alignLabelWithHint: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onTapOutside: (_) => _unfocusTextField(),
                        onChanged: _handleTextChanged,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Text(
                          '媒体',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          selectedVideo == null
                              ? '${images.length} / 9'
                              : '1 个视频',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ImagePickerPreview(
                      images: images,
                      canAdd: _canAddMedia,
                      onAdd: _openImageSourceSheet,
                      onRemove: _removeImage,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: canPublish ? _publish : null,
                        icon: const Icon(Icons.send_rounded),
                        label: Text(isPublishing ? '发布中' : '发布'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _shouldAutofocusTextField =>
      !widget.initialShowImageSourceSheet && !widget.initialShowAlbumPicker;

  bool get _hasImageMedia =>
      images.any((image) => image.type == PostMediaType.image);

  PickedImageDraft? get _selectedVideo {
    for (final image in images) {
      if (image.type == PostMediaType.video) return image;
    }
    return null;
  }

  bool get _canAddMedia => _selectedVideo == null && images.length < maxImages;

  void _unfocusTextField() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _scheduleInitialTextFocus() {
    if (!_shouldAutofocusTextField) return;
    // Raise the keyboard only after the push transition finishes. Focusing
    // mid-animation makes the soft keyboard slide up on top of the route
    // transition, which is the visible "卡一下" when entering this page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.isCompleted) {
        _focusTextFieldIfNeeded();
        return;
      }
      transitionAnimation = animation
        ..addStatusListener(_handleTransitionStatus);
    });
  }

  void _handleTransitionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    transitionAnimation?.removeStatusListener(_handleTransitionStatus);
    transitionAnimation = null;
    _focusTextFieldIfNeeded();
  }

  void _focusTextFieldIfNeeded() {
    if (!mounted || !_shouldAutofocusTextField) return;
    textFocusNode.requestFocus();
  }

  void _handleTextChanged(String value) {
    final nextHasText = value.trim().isNotEmpty;
    if (nextHasText == hasText) return;
    setState(() => hasText = nextHasText);
  }

  Future<void> _publish() async {
    setState(() => isPublishing = true);
    try {
      await widget.onPublish(
        PostDraft(
          text: textController.text.trim(),
          images: [
            for (var index = 0; index < images.length; index++)
              images[index].toPostImageRef(sortIndex: index),
          ],
        ),
      );
      if (!mounted) return;
      textController.clear();
      setState(() {
        hasText = false;
        images.clear();
      });
    } finally {
      if (mounted) {
        setState(() => isPublishing = false);
      }
    }
  }

  void _openInitialPickerIfNeeded() {
    if (didOpenInitialPicker) return;
    if (!widget.initialShowImageSourceSheet && !widget.initialShowAlbumPicker) {
      return;
    }
    didOpenInitialPicker = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialShowAlbumPicker) {
        _openAlbumPicker();
      } else {
        _openImageSourceSheet();
      }
    });
  }

  void _openImageSourceSheet() {
    if (!_canAddMedia) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(
        onCamera: () {
          Navigator.of(context).pop();
          if (widget.useMockMediaPicker) {
            _addMockCameraMedia();
          } else {
            _captureCameraMedia();
          }
        },
        onAlbum: () {
          Navigator.of(context).pop();
          _openAlbumPicker();
        },
      ),
    );
  }

  void _openAlbumPicker() {
    if (!_canAddMedia) return;
    if (!widget.useMockMediaPicker) {
      _openDeviceAlbumPicker();
      return;
    }

    final cameraImageCount = images
        .where((image) => image.albumIndex == null)
        .length;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AlbumPickerSheet(
        maxSelectable: maxImages - cameraImageCount,
        options: widget.imagePickerService.listAlbumOptions(),
        initialSelectedIndexes: {
          for (final image in images)
            if (image.albumIndex != null) image.albumIndex!,
        },
        onConfirm: (selectedIndexes) {
          Navigator.of(context).pop();
          _syncAlbumImages(selectedIndexes);
        },
      ),
    );
  }

  void _openDeviceAlbumPicker() {
    final cameraImageCount = images
        .where(
          (image) =>
              image.type == PostMediaType.image &&
              image.source != PostImageSource.album,
        )
        .length;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeviceAlbumPickerSheet(
        maxSelectable: maxImages - cameraImageCount,
        imagePickerService: widget.imagePickerService,
        allowVideoSelection: !_hasImageMedia,
        initialSelectionType: images.isEmpty ? null : images.first.type,
        initialSelectedAssetIds: {
          for (final image in images)
            if (image.source == PostImageSource.album && image.assetId != null)
              image.assetId!,
        },
        onConfirm: (selection) {
          Navigator.of(context).pop();
          unawaited(_syncDeviceAlbumMedia(selection));
        },
      ),
    );
  }

  Future<void> _captureCameraMedia() async {
    final picked = await widget.imagePickerService.captureFromCamera(
      id: nextImageId,
    );
    if (!mounted || picked.isEmpty) return;

    _applyCapturedCameraMedia(picked);
  }

  void _applyCapturedCameraMedia(List<PickedImageDraft> picked) {
    setState(() {
      final hasVideo = picked.any((image) => image.type == PostMediaType.video);
      if (hasVideo) {
        for (final image in images) {
          unawaited(widget.imagePickerService.deletePickedDraft(image));
        }
        images.clear();
      }
      final remainingSlots = maxImages - images.length;
      final safePicked = hasVideo
          ? picked.take(1)
          : picked.take(remainingSlots);
      images.addAll(safePicked);
      nextImageId += safePicked.length;
    });
  }

  Future<void> _syncDeviceAlbumMedia(DeviceAlbumSelection selection) async {
    final selectedOptions = selection.loadedOptions;
    final selectedAssetIds = selection.assetIds;
    DeviceAlbumImageOption? selectedVideo;
    for (final option in selectedOptions) {
      if (option.type == PostMediaType.video) {
        selectedVideo = option;
        break;
      }
    }

    if (selectedVideo != null) {
      for (final image in images) {
        unawaited(widget.imagePickerService.deletePickedDraft(image));
      }
      final draft = await widget.imagePickerService.fromDeviceAlbumOption(
        id: nextImageId,
        option: selectedVideo,
      );
      if (!mounted || draft == null) return;
      setState(() {
        images
          ..clear()
          ..add(draft);
        nextImageId++;
      });
      return;
    }

    final removedImages = [
      for (final image in images)
        if (image.source == PostImageSource.album &&
            image.type == PostMediaType.image &&
            image.assetId != null &&
            !selectedAssetIds.contains(image.assetId))
          image,
    ];
    for (final image in removedImages) {
      unawaited(widget.imagePickerService.deletePickedDraft(image));
    }

    if (!mounted) return;
    setState(() {
      images.removeWhere(
        (image) =>
            image.source == PostImageSource.album &&
            image.type == PostMediaType.image &&
            image.assetId != null &&
            !selectedAssetIds.contains(image.assetId),
      );
    });

    final existingAssetIds = {
      for (final image in images)
        if (image.source == PostImageSource.album &&
            image.type == PostMediaType.image &&
            image.assetId != null)
          image.assetId!,
    };
    final newOptions = [
      for (final option in selectedOptions)
        if (option.type == PostMediaType.image &&
            !existingAssetIds.contains(option.assetId))
          option,
    ];

    final newImages = <PickedImageDraft>[];
    for (final option in newOptions) {
      final draft = await widget.imagePickerService.fromDeviceAlbumOption(
        id: nextImageId + newImages.length,
        option: option,
      );
      if (draft != null) {
        newImages.add(draft);
      }
    }

    if (!mounted || newImages.isEmpty) return;
    setState(() {
      images.addAll(newImages);
      nextImageId += newImages.length;
    });
  }

  void _addMockCameraImages(int count) {
    final remaining = maxImages - images.length;
    final safeCount = count.clamp(0, remaining).toInt();
    if (safeCount == 0) return;

    setState(() {
      for (var i = 0; i < safeCount; i++) {
        final imageId = nextImageId;
        images.add(widget.imagePickerService.fromCamera(id: imageId));
        nextImageId++;
      }
    });
  }

  void _addMockCameraMedia() {
    if (widget.mockCameraMediaType == PostMediaType.video) {
      _applyCapturedCameraMedia([
        widget.imagePickerService.fromCameraVideo(id: nextImageId),
      ]);
      return;
    }
    _addMockCameraImages(1);
  }

  void _removeImage(int index) {
    final image = images[index];
    unawaited(widget.imagePickerService.deletePickedDraft(image));
    setState(() => images.removeAt(index));
  }

  void _syncAlbumImages(List<int> selectedIndexes) {
    final selected = selectedIndexes.toSet();

    setState(() {
      images.removeWhere(
        (image) =>
            image.albumIndex != null && !selected.contains(image.albumIndex),
      );
      final existingIndexes = {
        for (final image in images)
          if (image.albumIndex != null) image.albumIndex!,
      };
      for (final index in selectedIndexes.toList()..sort()) {
        if (existingIndexes.contains(index)) continue;
        images.add(
          widget.imagePickerService.fromAlbum(
            id: nextImageId,
            albumIndex: index,
          ),
        );
        nextImageId++;
      }
    });
  }
}

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet({required this.onCamera, required this.onAlbum});

  final VoidCallback onCamera;
  final VoidCallback onAlbum;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 26,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ImageSourceOption(
            icon: Icons.photo_camera_outlined,
            title: '相机',
            subtitle: '拍照或拍视频',
            onTap: onCamera,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ImageSourceOption(
            icon: Icons.photo_library_outlined,
            title: '相册',
            subtitle: '图片多选或视频单选',
            onTap: onAlbum,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageSourceOption extends StatelessWidget {
  const _ImageSourceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: onTap != null,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.line),
      ),
      tileColor: AppColors.background,
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.softPink,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(
          icon,
          color: onTap == null ? AppColors.muted : AppColors.coral,
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _DeviceAlbumPickerSheet extends StatefulWidget {
  const _DeviceAlbumPickerSheet({
    required this.maxSelectable,
    required this.imagePickerService,
    required this.allowVideoSelection,
    required this.initialSelectionType,
    required this.initialSelectedAssetIds,
    required this.onConfirm,
  });

  final int maxSelectable;
  final ImagePickerService imagePickerService;
  final bool allowVideoSelection;
  final PostMediaType? initialSelectionType;
  final Set<String> initialSelectedAssetIds;
  final ValueChanged<DeviceAlbumSelection> onConfirm;

  @override
  State<_DeviceAlbumPickerSheet> createState() =>
      _DeviceAlbumPickerSheetState();
}

class _DeviceAlbumPickerSheetState extends State<_DeviceAlbumPickerSheet> {
  static const pageSize = 60;

  final scrollController = ScrollController();
  final selectedAssetIds = <String>{};
  final selectedOptionsById = <String, DeviceAlbumImageOption>{};
  final options = <DeviceAlbumImageOption>[];
  List<DeviceAlbumPathOption> albums = const [];
  DeviceAlbumPathOption? selectedAlbum;
  PostMediaType? selectedMediaType;
  DeviceAlbumLoadStatus? status;
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = false;
  int page = 0;

  @override
  void initState() {
    super.initState();
    selectedAssetIds.addAll(widget.initialSelectedAssetIds);
    selectedMediaType = widget.initialSelectionType;
    scrollController.addListener(_maybeLoadMore);
    unawaited(_loadFirstPage());
  }

  @override
  void dispose() {
    scrollController.removeListener(_maybeLoadMore);
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.82;

    return Container(
      height: sheetHeight,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 26,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeviceAlbumHeader(
            selectedCount: selectedAssetIds.length,
            selectedMediaType: selectedMediaType,
            maxSelectable: selectedMediaType == PostMediaType.video
                ? 1
                : widget.maxSelectable,
            albumTitle: selectedAlbum?.name ?? '相册',
            onOpenAlbums: albums.isEmpty ? null : _openAlbumList,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: _buildBody()),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: status == DeviceAlbumLoadStatus.ready
                  ? () => widget.onConfirm(_selectedOptions())
                  : null,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                selectedAssetIds.isEmpty
                    ? '完成'
                    : selectedMediaType == PostMediaType.video
                    ? '完成 · 已选 1 个视频'
                    : '完成 · 已选 ${selectedAssetIds.length} 张',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final currentStatus = status;
    if (currentStatus == null) {
      return const _AlbumStateMessage(
        icon: Icons.error_outline,
        title: '相册暂时打不开',
        subtitle: '稍后再试一次。',
      );
    }
    if (currentStatus == DeviceAlbumLoadStatus.denied) {
      return _AlbumStateMessage(
        icon: Icons.lock_outline,
        title: '需要相册权限',
        subtitle: '开启权限后，才能从相册选择图片或视频。',
        action: OutlinedButton.icon(
          onPressed: widget.imagePickerService.openAlbumSettings,
          icon: const Icon(Icons.settings_outlined, size: 18),
          label: const Text('去设置'),
        ),
      );
    }
    if (currentStatus == DeviceAlbumLoadStatus.empty && options.isEmpty) {
      return const _AlbumStateMessage(
        icon: Icons.photo_library_outlined,
        title: '这个相簿里还没有可选媒体',
        subtitle: '可以切换相簿，或先用相机添加。',
      );
    }

    return GridView.builder(
      controller: scrollController,
      itemCount: options.length + (hasMore || isLoadingMore ? 1 : 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemBuilder: (context, index) {
        if (index >= options.length) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final option = options[index];
        final selected = selectedAssetIds.contains(option.assetId);
        final disabled = option.isVideo && !widget.allowVideoSelection;
        // Tapping the tile previews (zoom image / play video); only the
        // top-right corner hot zone toggles selection.
        return GestureDetector(
          onTap: () => _openOptionPreview(option),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.memory(option.thumbnailBytes, fit: BoxFit.cover),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? AppColors.coral : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: _AlbumMediaBadge(option: option),
              ),
              if (disabled)
                IgnorePointer(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      '不可混排',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 0,
                top: 0,
                child: IgnorePointer(
                  ignoring: disabled,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toggle(option),
                    child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.coral
                                : Colors.black.withValues(alpha: 0.32),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: selected
                              ? Text(
                                  '${_selectionOrder(option.assetId)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadFirstPage({DeviceAlbumPathOption? album}) async {
    setState(() {
      isLoading = true;
      isLoadingMore = false;
      hasMore = false;
      page = 0;
      options.clear();
      selectedAlbum = album ?? selectedAlbum;
    });
    final result = await widget.imagePickerService.listDeviceAlbumOptions(
      path: selectedAlbum?.path,
      page: 0,
      pageSize: pageSize,
      includeAlbums: selectedAlbum == null || albums.isEmpty,
    );
    if (!mounted) return;
    setState(() {
      if (result.albums.isNotEmpty) {
        albums = result.albums;
      }
      selectedAlbum ??= albums.isEmpty ? null : albums.first;
      status = result.status;
      options.addAll(result.options);
      for (final option in result.options) {
        if (selectedAssetIds.contains(option.assetId)) {
          selectedOptionsById[option.assetId] = option;
        }
      }
      hasMore = result.hasMore;
      isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (isLoading || isLoadingMore || !hasMore) return;
    setState(() => isLoadingMore = true);
    final nextPage = page + 1;
    final result = await widget.imagePickerService.listDeviceAlbumOptions(
      path: selectedAlbum?.path,
      page: nextPage,
      pageSize: pageSize,
      includeAlbums: false,
    );
    if (!mounted) return;
    setState(() {
      page = nextPage;
      status = result.status;
      options.addAll(result.options);
      for (final option in result.options) {
        if (selectedAssetIds.contains(option.assetId)) {
          selectedOptionsById[option.assetId] = option;
        }
      }
      hasMore = result.hasMore;
      isLoadingMore = false;
    });
  }

  void _maybeLoadMore() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    if (position.pixels > position.maxScrollExtent - 420) {
      unawaited(_loadMore());
    }
  }

  Future<void> _openAlbumList() async {
    final album = await showModalBottomSheet<DeviceAlbumPathOption>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _AlbumListSheet(albums: albums, selectedAlbumId: selectedAlbum?.id),
    );
    if (album == null || album.id == selectedAlbum?.id) return;
    await _loadFirstPage(album: album);
  }

  void _openOptionPreview(DeviceAlbumImageOption option) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => _AlbumOptionPreview(
          option: option,
          imagePickerService: widget.imagePickerService,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _toggle(DeviceAlbumImageOption option) {
    setState(() {
      if (selectedAssetIds.contains(option.assetId)) {
        selectedAssetIds.remove(option.assetId);
        selectedOptionsById.remove(option.assetId);
        if (selectedAssetIds.isEmpty) {
          selectedMediaType = null;
        }
      } else if (option.type == PostMediaType.video) {
        if (!widget.allowVideoSelection) return;
        selectedAssetIds
          ..clear()
          ..add(option.assetId);
        selectedOptionsById.clear();
        selectedOptionsById[option.assetId] = option;
        selectedMediaType = PostMediaType.video;
      } else {
        if (selectedMediaType == PostMediaType.video) {
          selectedAssetIds.clear();
          selectedOptionsById.clear();
        }
        selectedMediaType = PostMediaType.image;
        if (selectedAssetIds.length < widget.maxSelectable) {
          selectedAssetIds.add(option.assetId);
          selectedOptionsById[option.assetId] = option;
        }
      }
    });
  }

  DeviceAlbumSelection _selectedOptions() {
    return DeviceAlbumSelection(
      assetIds: Set.unmodifiable(selectedAssetIds),
      loadedOptions: [
        for (final assetId in selectedAssetIds)
          if (selectedOptionsById[assetId] != null)
            selectedOptionsById[assetId]!,
      ],
    );
  }

  int _selectionOrder(String assetId) {
    return selectedAssetIds.toList().indexOf(assetId) + 1;
  }
}

@immutable
class DeviceAlbumSelection {
  const DeviceAlbumSelection({
    required this.assetIds,
    required this.loadedOptions,
  });

  final Set<String> assetIds;
  final List<DeviceAlbumImageOption> loadedOptions;
}

class _AlbumOptionPreview extends StatefulWidget {
  const _AlbumOptionPreview({
    required this.option,
    required this.imagePickerService,
  });

  final DeviceAlbumImageOption option;
  final ImagePickerService imagePickerService;

  @override
  State<_AlbumOptionPreview> createState() => _AlbumOptionPreviewState();
}

class _AlbumOptionPreviewState extends State<_AlbumOptionPreview> {
  PostImageRef? media;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    final file = await widget.imagePickerService.resolvePreviewFile(
      widget.option,
    );
    if (!mounted) return;
    if (file == null) {
      setState(() => failed = true);
      return;
    }
    setState(() {
      media = PostImageRef(
        id: widget.option.assetId,
        type: widget.option.type,
        source: PostImageSource.album,
        localRef: file.path,
        durationMillis: widget.option.durationMillis,
        width: widget.option.width,
        height: widget.option.height,
        sortIndex: 0,
      );
    });
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final ready = media;
    if (ready != null) {
      return MediaPreviewOverlay(media: [ready], onClose: _close);
    }

    // While the full file resolves, show the already-loaded thumbnail so the
    // preview feels instant.
    return Material(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: failed
                  ? const Text(
                      '打不开这个文件',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.memory(
                          widget.option.thumbnailBytes,
                          fit: BoxFit.contain,
                        ),
                        const CircularProgressIndicator(color: Colors.white),
                      ],
                    ),
            ),
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: IconButton.filled(
                tooltip: '关闭预览',
                onPressed: _close,
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

class _AlbumMediaBadge extends StatelessWidget {
  const _AlbumMediaBadge({required this.option});

  final DeviceAlbumImageOption option;

  @override
  Widget build(BuildContext context) {
    if (!option.isVideo) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 2),
          Text(
            _formatDuration(option.durationMillis),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceAlbumHeader extends StatelessWidget {
  const _DeviceAlbumHeader({
    required this.selectedCount,
    required this.selectedMediaType,
    required this.maxSelectable,
    required this.albumTitle,
    required this.onOpenAlbums,
  });

  final int selectedCount;
  final PostMediaType? selectedMediaType;
  final int maxSelectable;
  final String albumTitle;
  final VoidCallback? onOpenAlbums;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onOpenAlbums,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      albumTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (onOpenAlbums != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(Icons.expand_more, size: 20),
                  ],
                ],
              ),
            ),
          ),
        ),
        Text(
          selectedMediaType == PostMediaType.video
              ? '$selectedCount / 1'
              : '$selectedCount / $maxSelectable',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          tooltip: '关闭',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, size: 20),
        ),
      ],
    );
  }
}

class _AlbumListSheet extends StatelessWidget {
  const _AlbumListSheet({required this.albums, required this.selectedAlbumId});

  final List<DeviceAlbumPathOption> albums;
  final String? selectedAlbumId;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.64,
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 26,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '选择相簿',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: albums.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final album = albums[index];
                final selected = album.id == selectedAlbumId;
                return ListTile(
                  onTap: () => Navigator.of(context).pop(album),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: selected ? AppColors.coral : AppColors.line,
                    ),
                  ),
                  tileColor: selected
                      ? AppColors.softPink
                      : AppColors.background,
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: selected ? AppColors.coral : AppColors.teal,
                  ),
                  title: Text(album.name),
                  subtitle: Text('${album.assetCount} 个项目'),
                  trailing: selected
                      ? const Icon(Icons.check_circle, color: AppColors.coral)
                      : const Icon(Icons.chevron_right),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumStateMessage extends StatelessWidget {
  const _AlbumStateMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: AppColors.muted),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _AlbumPickerSheet extends StatefulWidget {
  const _AlbumPickerSheet({
    required this.maxSelectable,
    required this.options,
    required this.initialSelectedIndexes,
    required this.onConfirm,
  });

  final int maxSelectable;
  final List<AlbumImageOption> options;
  final Set<int> initialSelectedIndexes;
  final ValueChanged<List<int>> onConfirm;

  @override
  State<_AlbumPickerSheet> createState() => _AlbumPickerSheetState();
}

class _AlbumPickerSheetState extends State<_AlbumPickerSheet> {
  final selectedIndexes = <int>{};

  @override
  void initState() {
    super.initState();
    selectedIndexes.addAll(widget.initialSelectedIndexes);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 26,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '相册',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '${selectedIndexes.length} / ${widget.maxSelectable}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.options.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
            ),
            itemBuilder: (context, index) {
              final option = widget.options[index];
              final selected = selectedIndexes.contains(option.index);
              return GestureDetector(
                onTap: () => _toggle(option.index),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: option.previewColor,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.image,
                          color: Colors.white.withValues(alpha: 0.86),
                        ),
                      ),
                    ),
                    Positioned(
                      right: AppSpacing.sm,
                      top: AppSpacing.sm,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.coral
                              : Colors.white.withValues(alpha: 0.88),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: selected
                            ? Text(
                                '${_selectionOrder(option.index)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  widget.onConfirm(selectedIndexes.toList()..sort()),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                selectedIndexes.isEmpty
                    ? '完成'
                    : '完成 · 已选 ${selectedIndexes.length} 张',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(int index) {
    setState(() {
      if (selectedIndexes.contains(index)) {
        selectedIndexes.remove(index);
      } else if (selectedIndexes.length < widget.maxSelectable) {
        selectedIndexes.add(index);
      }
    });
  }

  int _selectionOrder(int index) {
    final sorted = selectedIndexes.toList()..sort();
    return sorted.indexOf(index) + 1;
  }
}

class _ImagePickerPreview extends StatelessWidget {
  const _ImagePickerPreview({
    required this.images,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
  });

  final List<PickedImageDraft> images;
  final bool canAdd;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    const imageSize = 88.0;
    const tileSize = 96.0;
    const removeButtonSize = 30.0;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < images.length; i++)
          SizedBox(
            key: ValueKey(images[i].id),
            width: tileSize,
            height: tileSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: SizedBox(
                    width: imageSize,
                    height: imageSize,
                    child: PostImageView(
                      image: images[i].toPostImageRef(sortIndex: i),
                      borderRadius: BorderRadius.circular(18),
                      iconSize: 24,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.30),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: removeButtonSize,
                    height: removeButtonSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFF231722),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      key: ValueKey('remove_media_${images[i].id}'),
                      onPressed: () => onRemove(i),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: removeButtonSize,
                        height: removeButtonSize,
                      ),
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.close, size: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (canAdd)
          SizedBox(
            width: tileSize,
            height: tileSize,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: OutlinedButton(
                onPressed: onAdd,
                style: OutlinedButton.styleFrom(
                  fixedSize: const Size(imageSize, imageSize),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Icon(Icons.add_photo_alternate_outlined),
              ),
            ),
          ),
      ],
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
