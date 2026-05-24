import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_mark.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.user,
    required this.posts,
    required this.onOpenPost,
    required this.onCreatePost,
    required this.onOpenProfile,
  });

  final UserProfile user;
  final List<Post> posts;
  final ValueChanged<Post> onOpenPost;
  final VoidCallback onCreatePost;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final totalLikes = posts.fold<int>(0, (sum, p) => sum + p.likeCount);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _ProfileHeader(
                user: user,
                postCount: posts.length,
                totalLikes: totalLikes,
                onCreatePost: onCreatePost,
                onOpenProfile: onOpenProfile,
              ),
            ),
            if (posts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  child: _MasonryPostGrid(
                    user: user,
                    posts: posts,
                    onOpenPost: onOpenPost,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.postCount,
    required this.totalLikes,
    required this.onCreatePost,
    required this.onOpenProfile,
  });

  final UserProfile user;
  final int postCount;
  final int totalLikes;
  final VoidCallback onCreatePost;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: '打开我的',
                child: GestureDetector(
                  onTap: onOpenProfile,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AvatarMark(
                        initial: user.avatarInitial,
                        color: AppColors.coral,
                        size: 72,
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.background,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            color: AppColors.coral,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatItem(value: '$postCount', label: '笔记'),
                    _StatItem(value: '$totalLikes', label: '获赞'),
                    const _StatItem(value: '0', label: '收藏'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(user.nickname, style: Theme.of(context).textTheme.titleLarge),
          if (user.bio.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              user.bio,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreatePost,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('发布笔记'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.coral, size: 40),
          const SizedBox(height: AppSpacing.lg),
          Text('还没有笔记', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '发布第一篇，让 AI 好友来回应。',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MasonryPostGrid extends StatelessWidget {
  const _MasonryPostGrid({
    required this.user,
    required this.posts,
    required this.onOpenPost,
  });

  final UserProfile user;
  final List<Post> posts;
  final ValueChanged<Post> onOpenPost;

  @override
  Widget build(BuildContext context) {
    final left = <Post>[];
    final right = <Post>[];
    for (var i = 0; i < posts.length; i++) {
      (i.isEven ? left : right).add(posts[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PostColumn(
            user: user,
            posts: left,
            onOpenPost: onOpenPost,
            startTall: true,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _PostColumn(
            user: user,
            posts: right,
            onOpenPost: onOpenPost,
            startTall: false,
          ),
        ),
      ],
    );
  }
}

class _PostColumn extends StatelessWidget {
  const _PostColumn({
    required this.user,
    required this.posts,
    required this.onOpenPost,
    required this.startTall,
  });

  final UserProfile user;
  final List<Post> posts;
  final ValueChanged<Post> onOpenPost;
  final bool startTall;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < posts.length; i++) ...[
          _PostTile(
            user: user,
            post: posts[i],
            imageHeight: (i.isEven == startTall) ? 178 : 124,
            onTap: () => onOpenPost(posts[i]),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({
    required this.user,
    required this.post,
    required this.imageHeight,
    required this.onTap,
  });

  final UserProfile user;
  final Post post;
  final double imageHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImages = post.imageColors.isNotEmpty;
    final hasText = post.text.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImages)
              _ImagePreview(color: post.imageColors.first, height: imageHeight),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                hasImages ? AppSpacing.sm : AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasText) ...[
                    Text(
                      post.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Row(
                    children: [
                      AvatarMark(
                        initial: user.avatarInitial,
                        color: AppColors.coral,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          user.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      const Icon(
                        Icons.favorite,
                        color: AppColors.coral,
                        size: 14,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${post.likeCount}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Icon(
        Icons.image,
        color: Colors.white.withValues(alpha: 0.86),
        size: 30,
      ),
    );
  }
}
