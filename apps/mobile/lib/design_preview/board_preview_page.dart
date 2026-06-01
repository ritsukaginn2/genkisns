import 'package:flutter/material.dart';

import '../mock/mock_data.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_mark.dart';

enum BoardPreviewKind {
  navigation,
  feedback,
  components,
  componentsCore,
  componentsContent,
}

class BoardPreviewPage extends StatelessWidget {
  const BoardPreviewPage({super.key, required this.kind});

  final BoardPreviewKind kind;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: switch (kind) {
            BoardPreviewKind.navigation => const [
              _BoardHeader(title: '入口与子状态', subtitle: 'V1 无底部导航路由模型'),
              SizedBox(height: AppSpacing.lg),
              _NavigationPreview(),
            ],
            BoardPreviewKind.feedback => const [
              _BoardHeader(title: '弹窗与反馈', subtitle: '发布、失败、满图状态'),
              SizedBox(height: AppSpacing.lg),
              _FeedbackPreview(),
            ],
            BoardPreviewKind.components => const [
              _BoardHeader(title: '组件库', subtitle: 'Phase 3b 抽取候选'),
              SizedBox(height: AppSpacing.lg),
              _ComponentsPreview(),
            ],
            BoardPreviewKind.componentsCore => const [
              _BoardHeader(title: '基础组件', subtitle: '头像、按钮、输入、图片'),
              SizedBox(height: AppSpacing.lg),
              _CoreComponentsPreview(),
            ],
            BoardPreviewKind.componentsContent => const [
              _BoardHeader(title: '内容组件', subtitle: '笔记、评论、入口、空状态'),
              SizedBox(height: AppSpacing.lg),
              _ContentComponentsPreview(),
            ],
          },
        ),
      ),
    );
  }
}

class _BoardHeader extends StatelessWidget {
  const _BoardHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.coral,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.widgets_rounded, color: Colors.white),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavigationPreview extends StatelessWidget {
  const _NavigationPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _RouteCard(
          from: '首页',
          action: '点发布按钮',
          to: '发布笔记页',
          badge: 'Push',
          icon: Icons.add_circle_outline,
          color: AppColors.teal,
        ),
        SizedBox(height: AppSpacing.sm),
        _RouteCard(
          from: '首页',
          action: '点头像',
          to: '我的页',
          badge: 'Push',
          icon: Icons.person_outline,
          color: AppColors.coral,
        ),
        SizedBox(height: AppSpacing.sm),
        _RouteCard(
          from: '首页',
          action: '点笔记卡片',
          to: '笔记详情页',
          badge: 'Push',
          icon: Icons.article_outlined,
          color: AppColors.blue,
        ),
        SizedBox(height: AppSpacing.sm),
        _RouteCard(
          from: '发布页',
          action: '点添加图片',
          to: '媒体来源选择层',
          badge: 'Sheet',
          icon: Icons.add_photo_alternate_outlined,
          color: AppColors.teal,
        ),
        SizedBox(height: AppSpacing.sm),
        _RouteCard(
          from: '媒体来源选择层',
          action: '点相册',
          to: '相册多选层',
          badge: 'Sheet',
          icon: Icons.photo_library_outlined,
          color: AppColors.teal,
        ),
        SizedBox(height: AppSpacing.sm),
        _RouteCard(
          from: '已选图片发布页',
          action: '再次打开相册',
          to: '已选图片保持勾选',
          badge: 'State',
          icon: Icons.check_circle_outline,
          color: AppColors.teal,
        ),
        SizedBox(height: AppSpacing.sm),
        _RouteCard(
          from: '发布页',
          action: '发布成功',
          to: '首页',
          badge: 'Pop',
          icon: Icons.check_circle_outline,
          color: AppColors.blue,
        ),
        SizedBox(height: AppSpacing.sm),
        _RouteCard(
          from: '我的',
          action: '点 AI 好友 / 关于 / UI 实验室',
          to: '对应子页面',
          badge: 'Push',
          icon: Icons.chevron_right_rounded,
          color: AppColors.coral,
        ),
        SizedBox(height: AppSpacing.sm),
        _RouteCard(
          from: '笔记详情',
          action: '点帖子喜欢 / 评论喜欢',
          to: '原地切换状态',
          badge: 'State',
          icon: Icons.favorite_border,
          color: AppColors.coral,
        ),
        SizedBox(height: AppSpacing.sm),
        _RouteCard(
          from: '笔记详情',
          action: '点评论回复',
          to: '回复输入层',
          badge: 'Sheet',
          icon: Icons.reply_rounded,
          color: AppColors.teal,
        ),
        SizedBox(height: AppSpacing.sm),
        _RouteCard(
          from: '回复输入层',
          action: '点发送',
          to: '评论下方二级回复',
          badge: 'State',
          icon: Icons.subdirectory_arrow_right_rounded,
          color: AppColors.teal,
        ),
        SizedBox(height: AppSpacing.sm),
        _RouteCard(
          from: '自己的回复',
          action: '点删除',
          to: '删除确认层',
          badge: 'Sheet',
          icon: Icons.delete_outline,
          color: AppColors.coral,
        ),
        SizedBox(height: AppSpacing.sm),
        _RouteCard(
          from: '删除确认层',
          action: '确认删除',
          to: '回复从评论下方移除',
          badge: 'State',
          icon: Icons.check_circle_outline,
          color: AppColors.coral,
        ),
      ],
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.from,
    required this.action,
    required this.to,
    required this.badge,
    required this.icon,
    required this.color,
  });

  final String from;
  final String action;
  final String to;
  final String badge;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          _IconBubble(icon: icon, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(from, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(Icons.arrow_forward, size: 15),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        to,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(action, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _Badge(text: badge),
        ],
      ),
    );
  }
}

class _FeedbackPreview extends StatelessWidget {
  const _FeedbackPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _PublishFeedbackMock(),
        SizedBox(height: AppSpacing.md),
        _LikeStateMock(),
        SizedBox(height: AppSpacing.md),
        _ReplySheetMock(),
        SizedBox(height: AppSpacing.md),
        _ImageFullMock(),
        SizedBox(height: AppSpacing.md),
        _FallbackMock(),
        SizedBox(height: AppSpacing.md),
        _BackMock(),
      ],
    );
  }
}

class _PublishFeedbackMock extends StatelessWidget {
  const _PublishFeedbackMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      decoration: _panelDecoration(),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      AvatarMark(
                        initial: 'R',
                        color: AppColors.coral,
                        size: 34,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        '发布后回到首页',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.softPink,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '已发布，AI 评论会陆续出现',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LikeStateMock extends StatelessWidget {
  const _LikeStateMock();

  @override
  Widget build(BuildContext context) {
    Widget pill({
      required IconData icon,
      required String text,
      required bool active,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: active ? AppColors.softPink : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? AppColors.coral : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active ? AppColors.coral : AppColors.muted,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              text,
              style: TextStyle(
                color: active ? AppColors.coral : AppColors.ink,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _panelDecoration(),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          pill(icon: Icons.favorite_border, text: '18', active: false),
          pill(icon: Icons.favorite, text: '19', active: true),
          pill(icon: Icons.favorite, text: '13', active: true),
        ],
      ),
    );
  }
}

class _ReplySheetMock extends StatelessWidget {
  const _ReplySheetMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              AvatarMark(initial: '美', color: AppColors.coral, size: 32),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '回复 美香',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.close, size: 18, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            height: 72,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            alignment: Alignment.topLeft,
            child: const Text(
              '说点什么...',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('发送'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageFullMock extends StatelessWidget {
  const _ImageFullMock();

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.coral,
      AppColors.teal,
      AppColors.blue,
      AppColors.yellow,
      const Color(0xFF8E6BBE),
      const Color(0xFF5E8C61),
      const Color(0xFFB95D7A),
      const Color(0xFF668DA8),
      const Color(0xFFB27C46),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionRow(title: '图片满状态', trailing: '9 / 9'),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < colors.length; i++)
                _MiniImageTile(color: colors[i], removable: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _FallbackMock extends StatelessWidget {
  const _FallbackMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionRow(title: '本地模板评论', trailing: '不阻塞'),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              AvatarMark(initial: '美', color: AppColors.coral, size: 34),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '这条真的很适合发出来，被我刷到会停下来看的那种。',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackMock extends StatelessWidget {
  const _BackMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text(
              '子页面直接返回，不做二次确认弹窗',
              style: TextStyle(color: AppColors.ink, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentsPreview extends StatelessWidget {
  const _ComponentsPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _ComponentBlock(title: '头像 / 角色标识', child: _AvatarSample()),
        SizedBox(height: AppSpacing.md),
        _ComponentBlock(title: '按钮', child: _ButtonSample()),
        SizedBox(height: AppSpacing.md),
        _ComponentBlock(title: '输入框', child: _InputSample()),
        SizedBox(height: AppSpacing.md),
        _ComponentBlock(title: '图片选择格', child: _ImagePickerSample()),
        SizedBox(height: AppSpacing.md),
        _ComponentBlock(title: '笔记卡片', child: _PostCardSample()),
        SizedBox(height: AppSpacing.md),
        _ComponentBlock(title: '评论项', child: _CommentSample()),
        SizedBox(height: AppSpacing.md),
        _ComponentBlock(title: '设置入口', child: _SettingsSample()),
        SizedBox(height: AppSpacing.md),
        _ComponentBlock(title: '空状态', child: _EmptySample()),
      ],
    );
  }
}

class _CoreComponentsPreview extends StatelessWidget {
  const _CoreComponentsPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _ComponentBlock(title: '头像 / 角色标识', child: _AvatarSample()),
        SizedBox(height: AppSpacing.md),
        _ComponentBlock(title: '按钮', child: _ButtonSample()),
        SizedBox(height: AppSpacing.md),
        _ComponentBlock(title: '输入框', child: _InputSample()),
        SizedBox(height: AppSpacing.md),
        _ComponentBlock(title: '图片选择格', child: _ImagePickerSample()),
      ],
    );
  }
}

class _ContentComponentsPreview extends StatelessWidget {
  const _ContentComponentsPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _ComponentBlock(title: '笔记卡片', child: _PostCardSample()),
        SizedBox(height: AppSpacing.md),
        _ComponentBlock(title: '评论项', child: _CommentSample()),
        SizedBox(height: AppSpacing.md),
        _ComponentBlock(title: '设置入口', child: _SettingsSample()),
        SizedBox(height: AppSpacing.md),
        _ComponentBlock(title: 'AI 好友项', child: _FriendSample()),
        SizedBox(height: AppSpacing.md),
        _ComponentBlock(title: '说明卡片', child: _InfoSample()),
        SizedBox(height: AppSpacing.md),
        _ComponentBlock(title: '空状态', child: _EmptySample()),
      ],
    );
  }
}

class _ComponentBlock extends StatelessWidget {
  const _ComponentBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _AvatarSample extends StatelessWidget {
  const _AvatarSample();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        AvatarMark(initial: 'R', color: AppColors.coral, size: 46),
        SizedBox(width: AppSpacing.sm),
        AvatarMark(initial: '美', color: AppColors.teal, size: 40),
        SizedBox(width: AppSpacing.sm),
        AvatarMark(initial: '乔', color: AppColors.blue, size: 40),
        SizedBox(width: AppSpacing.sm),
        AvatarMark(initial: 'A', color: AppColors.yellow, size: 40),
      ],
    );
  }
}

class _ButtonSample extends StatelessWidget {
  const _ButtonSample();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 18),
            label: const Text('发布笔记'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('添加图片'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton(onPressed: null, child: const Text('发布')),
            ),
          ],
        ),
      ],
    );
  }
}

class _InputSample extends StatelessWidget {
  const _InputSample();

  @override
  Widget build(BuildContext context) {
    return const TextField(
      enabled: false,
      minLines: 3,
      maxLines: 3,
      decoration: InputDecoration(hintText: '今天有什么想被看见的小事？'),
    );
  }
}

class _ImagePickerSample extends StatelessWidget {
  const _ImagePickerSample();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: const [
        _MiniImageTile(color: AppColors.coral, removable: true),
        _MiniImageTile(color: AppColors.teal, removable: true),
        _MiniImageTile(color: AppColors.blue, removable: true),
        _AddImageTile(),
      ],
    );
  }
}

class _PostCardSample extends StatelessWidget {
  const _PostCardSample();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 96,
            decoration: const BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: const Center(
              child: Icon(Icons.image, color: Colors.white, size: 24),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '心心念念几个月的东西终于到手了。',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: const [
                    AvatarMark(initial: 'R', color: AppColors.coral, size: 20),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      'Ritsuka',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                    Spacer(),
                    Icon(Icons.favorite, color: AppColors.coral, size: 14),
                    SizedBox(width: 2),
                    Text(
                      '18',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentSample extends StatelessWidget {
  const _CommentSample();

  @override
  Widget build(BuildContext context) {
    final comment = mockPosts.first.comments.first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AvatarMark(
          initial: comment.actorAvatarSnapshot,
          color: comment.actorColor,
          size: 34,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comment.actorNameSnapshot,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                comment.content,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                '刚刚 · 回复',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const Icon(Icons.favorite_border, size: 18, color: AppColors.muted),
      ],
    );
  }
}

class _SettingsSample extends StatelessWidget {
  const _SettingsSample();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _SettingsRow(icon: Icons.people_outline, title: 'AI 好友'),
        SizedBox(height: AppSpacing.sm),
        _SettingsRow(icon: Icons.palette_outlined, title: 'UI 实验室'),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.coral, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _FriendSample extends StatelessWidget {
  const _FriendSample();

  @override
  Widget build(BuildContext context) {
    final friend = presetFriends.first;
    return Row(
      children: [
        AvatarMark(
          initial: friend.avatarInitial,
          color: friend.color,
          size: 42,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    friend.name,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _Badge(text: friend.relationship),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                friend.speakingStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoSample extends StatelessWidget {
  const _InfoSample();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Icon(Icons.auto_awesome, color: AppColors.teal, size: 22),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            '点赞和评论由 AI 好友生成，给你一个被看见的感觉。',
            style: TextStyle(color: AppColors.ink, fontSize: 13, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _EmptySample extends StatelessWidget {
  const _EmptySample();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: const [
          Icon(Icons.auto_awesome, color: AppColors.coral, size: 32),
          SizedBox(height: AppSpacing.sm),
          Text(
            '还没有笔记',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            '发布第一篇，让 AI 好友来回应。',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MiniImageTile extends StatelessWidget {
  const _MiniImageTile({required this.color, this.removable = false});

  final Color color;
  final bool removable;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.image,
                color: Colors.white.withValues(alpha: 0.86),
                size: 18,
              ),
            ),
          ),
          if (removable)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 1.5),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddImageTile extends StatelessWidget {
  const _AddImageTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: const Icon(
        Icons.add_photo_alternate_outlined,
        color: AppColors.coral,
        size: 18,
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.softPink,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.coral,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Text(trailing, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.line),
  );
}
