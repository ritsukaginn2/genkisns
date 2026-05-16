import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key, required this.onPublish});

  final ValueChanged<PostDraft> onPublish;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final textController = TextEditingController();
  final List<_PickedImage> images = [];
  int nextImageId = 0;

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
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPublish =
        textController.text.trim().isNotEmpty || images.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            const SizedBox(height: AppSpacing.sm),
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
                Text('图片', style: Theme.of(context).textTheme.titleMedium),
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
              canAdd: images.length < 9,
              onAdd: _addImage,
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
    );
  }

  void _publish() {
    widget.onPublish(
      PostDraft(
        text: textController.text.trim(),
        imageColors: images.map((image) => image.color).toList(),
      ),
    );
    textController.clear();
    setState(() => images.clear());
  }

  void _addImage() {
    if (images.length >= 9) {
      return;
    }

    final imageId = nextImageId;
    setState(() {
      images.add(
        _PickedImage(id: imageId, color: _palette[imageId % _palette.length]),
      );
      nextImageId++;
    });
  }
}

@immutable
class _PickedImage {
  const _PickedImage({required this.id, required this.color});

  final int id;
  final Color color;
}

@immutable
class PostDraft {
  const PostDraft({required this.text, required this.imageColors});

  final String text;
  final List<Color> imageColors;
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
