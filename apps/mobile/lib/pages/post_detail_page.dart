import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_mark.dart';
import '../widgets/page_header.dart';
import '../widgets/post_image_view.dart';
import 'video_player_page.dart';

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.post,
    this.initialPostLiked = false,
    this.initialLikedCommentIds = const <String>{},
    this.initialReplyTargetCommentId,
    this.initialUserRepliesByCommentId = const <String, List<String>>{},
    this.initialShowReplyDeleteConfirmation = false,
    this.onTogglePostLike,
    this.onToggleCommentLike,
    this.onAddLocalReply,
    this.onDeleteLocalReply,
  });

  final Post post;
  final bool initialPostLiked;
  final Set<String> initialLikedCommentIds;
  final String? initialReplyTargetCommentId;
  final Map<String, List<String>> initialUserRepliesByCommentId;
  final bool initialShowReplyDeleteConfirmation;
  final Future<Post> Function(String postId)? onTogglePostLike;
  final Future<Post> Function(String postId, String commentId)?
  onToggleCommentLike;
  final Future<Post> Function(String postId, String commentId, String content)?
  onAddLocalReply;
  final Future<Post> Function(String postId, String commentId, String replyId)?
  onDeleteLocalReply;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late Post post;
  String? replyTargetCommentId;
  _PendingReplyDelete? pendingReplyDelete;

  @override
  void initState() {
    super.initState();
    post = _buildInitialPost();
    replyTargetCommentId = widget.initialReplyTargetCommentId;
    if (widget.initialShowReplyDeleteConfirmation) {
      for (final comment in post.comments) {
        if (comment.replies.isNotEmpty) {
          pendingReplyDelete = _PendingReplyDelete(
            commentId: comment.id,
            reply: comment.replies.first,
          );
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final replyTarget = _replyTarget;
    final totalCommentCount = post.commentCount;
    final hasText = post.text.trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.only(
                bottom: replyTarget == null ? AppSpacing.xl : 196,
              ),
              children: [
                const PageHeader(title: '笔记详情'),
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
                      if (post.images.isNotEmpty) ...[
                        _ImageGrid(
                          images: post.images,
                          onOpenVideo: _openVideo,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (hasText) ...[
                        Text(
                          post.text,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      Row(
                        children: [
                          _MetricButton(
                            icon: post.userLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: AppColors.coral,
                            text: '${post.likeCount}',
                            active: post.userLiked,
                            onTap: () {
                              _togglePostLike();
                            },
                          ),
                          const SizedBox(width: AppSpacing.md),
                          _MetricButton(
                            icon: Icons.mode_comment_outlined,
                            color: AppColors.teal,
                            text: '$totalCommentCount',
                            active: false,
                            onTap: _openFirstCommentReply,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (post.comments.isNotEmpty) ...[
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
                          '$totalCommentCount',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (var i = 0; i < post.comments.length; i++) ...[
                    _CommentTile(
                      comment: post.comments[i],
                      onLike: () {
                        _toggleCommentLike(post.comments[i].id);
                      },
                      onReply: () => _openCommentReply(post.comments[i].id),
                      replies: post.comments[i].replies,
                      onDeleteReply: (reply) =>
                          _openDeleteReply(post.comments[i].id, reply),
                    ),
                    if (i < post.comments.length - 1)
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
                  onSubmit: (content) {
                    _submitReply(replyTarget, content);
                  },
                ),
              ),
            ],
            if (pendingReplyDelete != null) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeDeleteReplyConfirm,
                  child: Container(color: Colors.black.withValues(alpha: 0.12)),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _DeleteReplyConfirmSheet(
                  reply: pendingReplyDelete!.reply,
                  onCancel: _closeDeleteReplyConfirm,
                  onDelete: () {
                    _deletePendingReply();
                  },
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
    return _findComment(targetId);
  }

  Comment? _findComment(String targetId) {
    for (final comment in post.comments) {
      if (comment.id == targetId) return comment;
    }
    return null;
  }

  void _openFirstCommentReply() {
    if (post.comments.isEmpty) return;
    _openCommentReply(post.comments.first.id);
  }

  void _openVideo(PostImageRef video) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => VideoPlayerPage(video: video)),
    );
  }

  void _openCommentReply(String commentId) {
    setState(() => replyTargetCommentId = commentId);
  }

  Future<void> _togglePostLike() async {
    final callback = widget.onTogglePostLike;
    if (callback != null) {
      final updatedPost = await callback(post.id);
      if (!mounted) return;
      setState(() => post = updatedPost);
      return;
    }

    setState(() => post = _toggleLocalPostLike(post));
  }

  Future<void> _toggleCommentLike(String commentId) async {
    final callback = widget.onToggleCommentLike;
    if (callback != null) {
      final updatedPost = await callback(post.id, commentId);
      if (!mounted) return;
      setState(() => post = updatedPost);
      return;
    }

    setState(() {
      post = post.copyWith(
        comments: [
          for (final comment in post.comments)
            if (comment.id == commentId)
              _toggleLocalCommentLike(comment)
            else
              comment,
        ],
      );
    });
  }

  Future<void> _submitReply(Comment targetComment, String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final callback = widget.onAddLocalReply;
    if (callback != null) {
      final updatedPost = await callback(post.id, targetComment.id, trimmed);
      if (!mounted) return;
      setState(() {
        post = updatedPost;
        replyTargetCommentId = null;
      });
      return;
    }

    setState(() {
      post = _appendLocalReply(
        post: post,
        targetComment: targetComment,
        content: trimmed,
      );
      replyTargetCommentId = null;
    });
  }

  void _openDeleteReply(String commentId, LocalReply reply) {
    setState(() {
      replyTargetCommentId = null;
      pendingReplyDelete = _PendingReplyDelete(
        commentId: commentId,
        reply: reply,
      );
    });
  }

  void _closeDeleteReplyConfirm() {
    setState(() => pendingReplyDelete = null);
  }

  Future<void> _deletePendingReply() async {
    final target = pendingReplyDelete;
    if (target == null) return;

    final callback = widget.onDeleteLocalReply;
    if (callback != null) {
      final updatedPost = await callback(
        post.id,
        target.commentId,
        target.reply.id,
      );
      if (!mounted) return;
      setState(() {
        post = updatedPost;
        pendingReplyDelete = null;
      });
      return;
    }

    setState(() {
      post = _removeLocalReply(
        post: post,
        commentId: target.commentId,
        replyId: target.reply.id,
      );
      pendingReplyDelete = null;
    });
  }

  Post _buildInitialPost() {
    final initialReplies = widget.initialUserRepliesByCommentId;
    if (!widget.initialPostLiked &&
        widget.initialLikedCommentIds.isEmpty &&
        initialReplies.isEmpty) {
      return widget.post;
    }

    return widget.post.copyWith(
      likeCount: widget.initialPostLiked && !widget.post.userLiked
          ? widget.post.likeCount + 1
          : widget.post.likeCount,
      userLiked: widget.initialPostLiked || widget.post.userLiked,
      comments: [
        for (final comment in widget.post.comments)
          comment.copyWith(
            userLiked:
                widget.initialLikedCommentIds.contains(comment.id) ||
                comment.userLiked,
            likeCount:
                widget.initialLikedCommentIds.contains(comment.id) &&
                    !comment.userLiked
                ? comment.likeCount + 1
                : comment.likeCount,
            replies: [
              ...comment.replies,
              for (
                var i = 0;
                i < (initialReplies[comment.id] ?? const <String>[]).length;
                i++
              )
                LocalReply(
                  id: 'initial_reply_${comment.id}_$i',
                  commentId: comment.id,
                  authorNameSnapshot: 'Ritsuka',
                  authorAvatarSnapshot: 'R',
                  targetActorNameSnapshot: comment.actorNameSnapshot,
                  content: initialReplies[comment.id]![i],
                  createdAt: DateTime.now(),
                ),
            ],
          ),
      ],
    );
  }

  Post _toggleLocalPostLike(Post targetPost) {
    final nextLiked = !targetPost.userLiked;
    final nextLikeCount = nextLiked
        ? targetPost.likeCount + 1
        : (targetPost.likeCount - 1).clamp(0, targetPost.likeCount).toInt();
    return targetPost.copyWith(likeCount: nextLikeCount, userLiked: nextLiked);
  }

  Comment _toggleLocalCommentLike(Comment comment) {
    final nextLiked = !comment.userLiked;
    final nextLikeCount = nextLiked
        ? comment.likeCount + 1
        : (comment.likeCount - 1).clamp(0, comment.likeCount).toInt();
    return comment.copyWith(likeCount: nextLikeCount, userLiked: nextLiked);
  }

  Post _appendLocalReply({
    required Post post,
    required Comment targetComment,
    required String content,
  }) {
    return post.copyWith(
      comments: [
        for (final comment in post.comments)
          if (comment.id == targetComment.id)
            comment.copyWith(
              replies: [
                ...comment.replies,
                LocalReply(
                  id: 'reply_${DateTime.now().microsecondsSinceEpoch}',
                  commentId: comment.id,
                  authorNameSnapshot: 'Ritsuka',
                  authorAvatarSnapshot: 'R',
                  targetActorNameSnapshot: comment.actorNameSnapshot,
                  content: content,
                  createdAt: DateTime.now(),
                ),
              ],
            )
          else
            comment,
      ],
    );
  }

  Post _removeLocalReply({
    required Post post,
    required String commentId,
    required String replyId,
  }) {
    return post.copyWith(
      comments: [
        for (final comment in post.comments)
          if (comment.id == commentId)
            comment.copyWith(
              replies: [
                for (final reply in comment.replies)
                  if (reply.id != replyId) reply,
              ],
            )
          else
            comment,
      ],
    );
  }
}

@immutable
class _PendingReplyDelete {
  const _PendingReplyDelete({required this.commentId, required this.reply});

  final String commentId;
  final LocalReply reply;
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
  const _ImageGrid({required this.images, required this.onOpenVideo});

  final List<PostImageRef> images;
  final ValueChanged<PostImageRef> onOpenVideo;

  @override
  Widget build(BuildContext context) {
    if (images.length == 1 && images.single.isVideo) {
      final video = images.single;
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Semantics(
          button: true,
          label: '播放视频',
          child: GestureDetector(
            onTap: () => onOpenVideo(video),
            child: PostImageView(
              image: video,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemBuilder: (context, index) {
        final image = images[index];
        return Semantics(
          button: image.isVideo,
          label: image.isVideo ? '播放视频' : null,
          child: GestureDetector(
            onTap: image.isVideo ? () => onOpenVideo(image) : null,
            child: PostImageView(
              image: image,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
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
    required this.onLike,
    required this.onReply,
    required this.replies,
    required this.onDeleteReply,
  });

  final Comment comment;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final List<LocalReply> replies;
  final ValueChanged<LocalReply> onDeleteReply;

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
                    Semantics(
                      button: true,
                      label: '回复 ${comment.actorNameSnapshot}',
                      child: InkWell(
                        onTap: onReply,
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          child: Text(
                            '回复',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (replies.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ReplyThread(replies: replies, onDeleteReply: onDeleteReply),
                ],
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
                  comment.userLiked ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: comment.userLiked ? AppColors.coral : AppColors.muted,
                ),
              ),
              Text(
                '${comment.likeCount}',
                style: TextStyle(
                  color: comment.userLiked ? AppColors.coral : AppColors.muted,
                  fontSize: 11,
                  fontWeight: comment.userLiked
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReplyThread extends StatelessWidget {
  const _ReplyThread({required this.replies, required this.onDeleteReply});

  final List<LocalReply> replies;
  final ValueChanged<LocalReply> onDeleteReply;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < replies.length; i++) ...[
            _ReplyBubble(
              reply: replies[i],
              onDelete: () => onDeleteReply(replies[i]),
            ),
            if (i < replies.length - 1) const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _ReplyBubble extends StatelessWidget {
  const _ReplyBubble({required this.reply, required this.onDelete});

  final LocalReply reply;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AvatarMark(
          initial: reply.authorAvatarSnapshot,
          color: AppColors.coral,
          size: 24,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.labelMedium,
                  children: [
                    TextSpan(
                      text: reply.authorNameSnapshot,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(text: ' 回复 ${reply.targetActorNameSnapshot}'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                reply.content,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              Text('刚刚', style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: '删除回复',
          onPressed: onDelete,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          style: IconButton.styleFrom(
            foregroundColor: AppColors.muted,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.delete_outline, size: 17),
        ),
      ],
    );
  }
}

class _DeleteReplyConfirmSheet extends StatelessWidget {
  const _DeleteReplyConfirmSheet({
    required this.reply,
    required this.onCancel,
    required this.onDelete,
  });

  final LocalReply reply;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
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
          Text('删除这条回复？', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            reply.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('删除回复'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: onCancel, child: const Text('取消')),
          ),
        ],
      ),
    );
  }
}

class _ReplyComposer extends StatefulWidget {
  const _ReplyComposer({
    required this.comment,
    required this.onClose,
    required this.onSubmit,
  });

  final Comment comment;
  final VoidCallback onClose;
  final ValueChanged<String> onSubmit;

  @override
  State<_ReplyComposer> createState() => _ReplyComposerState();
}

class _ReplyComposerState extends State<_ReplyComposer> {
  final controller = TextEditingController();
  bool canSend = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(_syncCanSend);
  }

  @override
  void dispose() {
    controller.removeListener(_syncCanSend);
    controller.dispose();
    super.dispose();
  }

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
                initial: widget.comment.actorAvatarSnapshot,
                color: widget.comment.actorColor,
                size: 32,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '回复 ${widget.comment.actorNameSnapshot}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            autofocus: true,
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
              onPressed: canSend
                  ? () => widget.onSubmit(controller.text.trim())
                  : null,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('发送'),
            ),
          ),
        ],
      ),
    );
  }

  void _syncCanSend() {
    final next = controller.text.trim().isNotEmpty;
    if (next == canSend) return;
    setState(() => canSend = next);
  }
}
