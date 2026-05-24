import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/page_header.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({
    super.key,
    required this.onPublish,
    this.initialText = '',
    this.initialImageColors = const [],
    this.showBackButton = true,
    this.initialShowImageSourceSheet = false,
    this.initialShowAlbumPicker = false,
  });

  final ValueChanged<PostDraft> onPublish;
  final String initialText;
  final List<Color> initialImageColors;
  final bool showBackButton;
  final bool initialShowImageSourceSheet;
  final bool initialShowAlbumPicker;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final textController = TextEditingController();
  final List<_PickedImage> images = [];
  int nextImageId = 0;
  bool didOpenInitialPicker = false;

  static const maxImages = 9;

  static const _palette = [
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

  @override
  void initState() {
    super.initState();
    textController.text = widget.initialText;
    for (var i = 0; i < widget.initialImageColors.length; i++) {
      final color = widget.initialImageColors[i];
      final albumIndex = _palette.indexOf(color);
      images.add(
        _PickedImage(
          id: i,
          color: color,
          albumIndex: albumIndex == -1 ? null : albumIndex,
        ),
      );
    }
    nextImageId = widget.initialImageColors.length;
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPublish =
        textController.text.trim().isNotEmpty || images.isNotEmpty;
    _openInitialPickerIfNeeded();

    return Scaffold(
      body: SafeArea(
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
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Text(
                        '图片',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Text(
                        '${images.length} / 9',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ImagePickerPreview(
                    images: images,
                    canAdd: images.length < maxImages,
                    onAdd: _openImageSourceSheet,
                    onRemove: (index) => setState(() => images.removeAt(index)),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: canPublish ? _publish : null,
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('发布'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _publish() {
    widget.onPublish(
      PostDraft(
        text: textController.text.trim(),
        imageColors: images.map((image) => image.color).toList(),
      ),
    );
    if (!mounted) return;
    textController.clear();
    setState(() => images.clear());
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
    if (images.length >= maxImages) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(
        remainingSlots: maxImages - images.length,
        onCamera: () {
          Navigator.of(context).pop();
          _addImages(1);
        },
        onAlbum: () {
          Navigator.of(context).pop();
          _openAlbumPicker();
        },
      ),
    );
  }

  void _openAlbumPicker() {
    if (images.length >= maxImages) return;
    final cameraImageCount = images
        .where((image) => image.albumIndex == null)
        .length;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AlbumPickerSheet(
        maxSelectable: maxImages - cameraImageCount,
        colors: _palette,
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

  void _addImages(int count) {
    final remaining = maxImages - images.length;
    final safeCount = count.clamp(0, remaining).toInt();
    if (safeCount == 0) return;

    setState(() {
      for (var i = 0; i < safeCount; i++) {
        final imageId = nextImageId;
        images.add(
          _PickedImage(
            id: imageId,
            color: _palette[imageId % _palette.length],
            albumIndex: null,
          ),
        );
        nextImageId++;
      }
    });
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
          _PickedImage(
            id: nextImageId,
            color: _palette[index],
            albumIndex: index,
          ),
        );
        nextImageId++;
      }
    });
  }
}

@immutable
class _PickedImage {
  const _PickedImage({
    required this.id,
    required this.color,
    required this.albumIndex,
  });

  final int id;
  final Color color;
  final int? albumIndex;
}

@immutable
class PostDraft {
  const PostDraft({required this.text, required this.imageColors});

  final String text;
  final List<Color> imageColors;
}

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet({
    required this.remainingSlots,
    required this.onCamera,
    required this.onAlbum,
  });

  final int remainingSlots;
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
            title: '拍照',
            subtitle: '添加 1 张',
            onTap: onCamera,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ImageSourceOption(
            icon: Icons.photo_library_outlined,
            title: '相册',
            subtitle: '多选，最多还能选 $remainingSlots 张',
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
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
        child: Icon(icon, color: AppColors.coral),
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

class _AlbumPickerSheet extends StatefulWidget {
  const _AlbumPickerSheet({
    required this.maxSelectable,
    required this.colors,
    required this.initialSelectedIndexes,
    required this.onConfirm,
  });

  final int maxSelectable;
  final List<Color> colors;
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
            itemCount: widget.colors.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
            ),
            itemBuilder: (context, index) {
              final selected = selectedIndexes.contains(index);
              return GestureDetector(
                onTap: () => _toggle(index),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.colors[index],
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
                                '${_selectionOrder(index)}',
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

  final List<_PickedImage> images;
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
                  child: Container(
                    width: imageSize,
                    height: imageSize,
                    decoration: BoxDecoration(
                      color: images[i].color,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.image,
                      color: Colors.white.withValues(alpha: 0.86),
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
                      key: ValueKey('remove_image_${images[i].id}'),
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
