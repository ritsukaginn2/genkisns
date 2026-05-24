import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_mark.dart';
import '../widgets/page_header.dart';

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.post,
    this.initialPostLiked = false,
    this.initialLikedCommentIds = const <String>{},
    this.initialReplyTargetCommentId,
    this.initialUserRepliesByCommentId = const <String, List<String>>{},
    this.initialShowReplyDeleteConfirmation = false,
  });

  final Post post;
  final bool initialPostLiked;
  final Set<String> initialLikedCommentIds;
  final String? initialReplyTargetCommentId;
  final Map<String, List<String>> initialUserRepliesByCommentId;
  final bool initialShowReplyDeleteConfirmation;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late bool postLiked;
  late Set<String> likedCommentIds;
  final Map<String, List<_LocalReply>> repliesByCommentId = {};
  String? replyTargetCommentId;
  _PendingReplyDelete? pendingReplyDelete;

  @override
  void initState() {
    super.initState();
    postLiked = widget.initialPostLiked;
    likedCommentIds = {...widget.initialLikedCommentIds};
    replyTargetCommentId = widget.initialReplyTargetCommentId;
    for (final entry in widget.initialUserRepliesByCommentId.entries) {
      final target = _findComment(entry.key);
      if (target == null) continue;
      repliesByCommentId[entry.key] = [
        for (var i = 0; i < entry.value.length; i++)
          _LocalReply(
            id: 'initial_reply_${entry.key}_$i',
            targetName: target.actorNameSnapshot,
            content: entry.value[i],
            createdAt: DateTime.now(),
          ),
      ];
    }
    if (widget.initialShowReplyDeleteConfirmation) {
      for (final entry in repliesByCommentId.entries) {
        if (entry.value.isNotEmpty) {
          pendingReplyDelete = _PendingReplyDelete(
            commentId: entry.key,
            reply: entry.value.first,
          );
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final replyTarget = _replyTarget;
    final totalCommentCount = widget.post.comments.length + _replyCount;
    final hasText = widget.post.text.trim().isNotEmpty;

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
                      if (widget.post.imageColors.isNotEmpty) ...[
                        _ImageGrid(colors: widget.post.imageColors),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (hasText) ...[
                        Text(
                          widget.post.text,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
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
                            text: '$totalCommentCount',
                            active: false,
                            onTap: _openFirstCommentReply,
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
                          '$totalCommentCount',
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
                      onReply: () =>
                          _openCommentReply(widget.post.comments[i].id),
                      replies:
                          repliesByCommentId[widget.post.comments[i].id] ??
                          const [],
                      onDeleteReply: (reply) =>
                          _openDeleteReply(widget.post.comments[i].id, reply),
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
                  onSubmit: (content) => _submitReply(replyTarget, content),
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
                  onDelete: _deletePendingReply,
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
    for (final comment in widget.post.comments) {
      if (comment.id == targetId) return comment;
    }
    return null;
  }

  int get _replyCount {
    var count = 0;
    for (final replies in repliesByCommentId.values) {
      count += replies.length;
    }
    return count;
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

  void _openFirstCommentReply() {
    if (widget.post.comments.isEmpty) return;
    _openCommentReply(widget.post.comments.first.id);
  }

  void _openCommentReply(String commentId) {
    setState(() => replyTargetCommentId = commentId);
  }

  void _submitReply(Comment targetComment, String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      repliesByCommentId
          .putIfAbsent(targetComment.id, () => [])
          .add(
            _LocalReply(
              id: 'reply_${DateTime.now().microsecondsSinceEpoch}',
              targetName: targetComment.actorNameSnapshot,
              content: trimmed,
              createdAt: DateTime.now(),
            ),
          );
      replyTargetCommentId = null;
    });
  }

  void _openDeleteReply(String commentId, _LocalReply reply) {
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

  void _deletePendingReply() {
    final target = pendingReplyDelete;
    if (target == null) return;

    setState(() {
      final replies = repliesByCommentId[target.commentId];
      replies?.removeWhere((reply) => reply.id == target.reply.id);
      if (replies == null || replies.isEmpty) {
        repliesByCommentId.remove(target.commentId);
      }
      pendingReplyDelete = null;
    });
  }
}

@immutable
class _LocalReply {
  const _LocalReply({
    required this.id,
    required this.targetName,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String targetName;
  final String content;
  final DateTime createdAt;
}

@immutable
class _PendingReplyDelete {
  const _PendingReplyDelete({required this.commentId, required this.reply});

  final String commentId;
  final _LocalReply reply;
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
    required this.replies,
    required this.onDeleteReply,
  });

  final Comment comment;
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final List<_LocalReply> replies;
  final ValueChanged<_LocalReply> onDeleteReply;

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

class _ReplyThread extends StatelessWidget {
  const _ReplyThread({required this.replies, required this.onDeleteReply});

  final List<_LocalReply> replies;
  final ValueChanged<_LocalReply> onDeleteReply;

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

  final _LocalReply reply;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AvatarMark(initial: 'R', color: AppColors.coral, size: 24),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.labelMedium,
                  children: [
                    const TextSpan(
                      text: 'Ritsuka',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(text: ' 回复 ${reply.targetName}'),
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

  final _LocalReply reply;
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
