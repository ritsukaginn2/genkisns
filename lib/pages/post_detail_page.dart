import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_mark.dart';

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.post,
    this.initialPostLiked = false,
    this.initialLikedCommentIds = const <String>{},
    this.initialReplyTargetCommentId,
  });

  final Post post;
  final bool initialPostLiked;
  final Set<String> initialLikedCommentIds;
  final String? initialReplyTargetCommentId;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late bool postLiked;
  late Set<String> likedCommentIds;
  String? replyTargetCommentId;

  @override
  void initState() {
    super.initState();
    postLiked = widget.initialPostLiked;
    likedCommentIds = {...widget.initialLikedCommentIds};
    replyTargetCommentId = widget.initialReplyTargetCommentId;
  }

  @override
  Widget build(BuildContext context) {
    final replyTarget = _replyTarget;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.only(
                bottom: replyTarget == null ? AppSpacing.xl : 196,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.sm,
                    top: AppSpacing.sm,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _AuthorHeader(),
                      const SizedBox(height: AppSpacing.lg),
                      if (widget.post.imageColors.isNotEmpty) ...[
                        _ImageGrid(colors: widget.post.imageColors),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      Text(
                        widget.post.text,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          _MetricButton(
                            icon: postLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: AppColors.coral,
                            text:
                                '${widget.post.likeCount + (postLiked ? 1 : 0)}',
                            active: postLiked,
                            onTap: () => setState(() => postLiked = !postLiked),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          _MetricButton(
                            icon: Icons.mode_comment_outlined,
                            color: AppColors.teal,
                            text: '${widget.post.commentCount}',
                            active: false,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.post.comments.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '评论',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${widget.post.comments.length}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (var i = 0; i < widget.post.comments.length; i++) ...[
                    _CommentTile(
                      comment: widget.post.comments[i],
                      liked: likedCommentIds.contains(
                        widget.post.comments[i].id,
                      ),
                      onLike: () =>
                          _toggleCommentLike(widget.post.comments[i].id),
                      onReply: () => setState(
                        () => replyTargetCommentId = widget.post.comments[i].id,
                      ),
                    ),
                    if (i < widget.post.comments.length - 1)
                      const Divider(
                        height: 1,
                        indent: 68,
                        endIndent: AppSpacing.lg,
                      ),
                  ],
                ],
              ],
            ),
            if (replyTarget != null) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => replyTargetCommentId = null),
                  child: Container(color: Colors.black.withValues(alpha: 0.12)),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _ReplyComposer(
                  comment: replyTarget,
                  onClose: () => setState(() => replyTargetCommentId = null),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Comment? get _replyTarget {
    final targetId = replyTargetCommentId;
    if (targetId == null) return null;
    for (final comment in widget.post.comments) {
      if (comment.id == targetId) return comment;
    }
    return null;
  }

  void _toggleCommentLike(String commentId) {
    setState(() {
      if (likedCommentIds.contains(commentId)) {
        likedCommentIds.remove(commentId);
      } else {
        likedCommentIds.add(commentId);
      }
    });
  }
}

class _AuthorHeader extends StatelessWidget {
  const _AuthorHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AvatarMark(initial: 'R', color: AppColors.coral, size: 42),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ritsuka', style: Theme.of(context).textTheme.titleMedium),
              Text('刚刚', style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: colors.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: colors[index],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.image, color: Colors.white.withValues(alpha: 0.86)),
        );
      },
    );
  }
}

class _MetricButton extends StatelessWidget {
  const _MetricButton({
    required this.icon,
    required this.color,
    required this.text,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String text;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: active ? AppColors.softPink : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? color : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: active ? 1.12 : 1,
              duration: const Duration(milliseconds: 160),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.liked,
    required this.onLike,
    required this.onReply,
  });

  final Comment comment;
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarMark(
            initial: comment.actorAvatarSnapshot,
            color: comment.actorColor,
            size: 36,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.actorNameSnapshot,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  comment.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text(
                      '刚刚',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    GestureDetector(
                      onTap: onReply,
                      child: Text(
                        '回复',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            children: [
              IconButton(
                onPressed: onLike,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: liked ? AppColors.coral : AppColors.muted,
                ),
              ),
              Text(
                liked ? '13' : '12',
                style: TextStyle(
                  color: liked ? AppColors.coral : AppColors.muted,
                  fontSize: 11,
                  fontWeight: liked ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReplyComposer extends StatelessWidget {
  const _ReplyComposer({required this.comment, required this.onClose});

  final Comment comment;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md + MediaQuery.of(context).padding.bottom,
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
              AvatarMark(
                initial: comment.actorAvatarSnapshot,
                color: comment.actorColor,
                size: 32,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '回复 ${comment.actorNameSnapshot}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '说点什么...',
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.all(AppSpacing.md),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.line),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('发送'),
            ),
          ),
        ],
      ),
    );
  }
}
