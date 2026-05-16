import 'package:flutter/material.dart';

import '../mock/mock_data.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_mark.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.onComplete,
    this.initialStep = 0,
  });

  final void Function(UserProfile user, List<String> selectedFriendIds) onComplete;
  final int initialStep;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final nicknameController = TextEditingController(text: defaultUser.nickname);
  final bioController = TextEditingController(text: defaultUser.bio);
  final selectedFriendIds = presetFriends
      .take(5)
      .map((friend) => friend.id)
      .toSet();
  late int step;

  @override
  void initState() {
    super.initState();
    step = widget.initialStep;
  }

  @override
  void dispose() {
    nicknameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _IntroStep(onNext: _next),
      _ProfileStep(form: this),
      _FriendsStep(form: this),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              Row(
                children: [
                  for (var index = 0; index < pages.length; index++)
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(
                          right: index == pages.length - 1 ? 0 : AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: index <= step
                              ? AppColors.coral
                              : AppColors.line,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(child: pages[step]),
            ],
          ),
        ),
      ),
    );
  }

  void _next() {
    if (step < 2) {
      setState(() => step += 1);
      return;
    }

    widget.onComplete(
      UserProfile(
        nickname: nicknameController.text.trim().isEmpty
            ? defaultUser.nickname
            : nicknameController.text.trim(),
        avatarInitial: nicknameController.text.trim().isEmpty
            ? defaultUser.avatarInitial
            : nicknameController.text.trim().substring(0, 1).toUpperCase(),
        bio: bioController.text.trim(),
        ipLocation: defaultUser.ipLocation,
      ),
      selectedFriendIds.toList(),
    );
  }

  void _toggleFriend(String friendId, bool selected) {
    setState(() {
      if (selected) {
        selectedFriendIds.add(friendId);
      } else if (selectedFriendIds.length > 5) {
        selectedFriendIds.remove(friendId);
      }
    });
  }
}

class _IntroStep extends StatelessWidget {
  const _IntroStep({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.coral,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 34),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('只属于你的虚拟 SNS', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '发那些真实社交平台不方便发的日常。所有点赞和评论都来自 AI 好友，只为给你一个被看见的瞬间。',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.xl),
        _NoticeRow(
          icon: Icons.lock_outline,
          text: 'V1 内容保存在本地；生成评论时只发送文字给预配置 LLM。',
        ),
        const SizedBox(height: AppSpacing.md),
        const _NoticeRow(
          icon: Icons.image_not_supported_outlined,
          text: 'V1 不上传图片给 LLM，图片只在本地展示。',
        ),
        const Spacer(),
        FilledButton(onPressed: onNext, child: const Text('开始设置')),
      ],
    );
  }
}

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({required this.form});

  final _OnboardingPageState form;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text('创建你的主页', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.md),
        Text(
          'IP 属地会像其他 SNS 一样在发布时自动识别，不需要手动设置。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: form.nicknameController,
          decoration: const InputDecoration(labelText: '昵称'),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: form.bioController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '个人简介'),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _NoticeRow(icon: Icons.public, text: '当前原型会显示为“发布时自动识别”。'),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(onPressed: form._next, child: const Text('选择 AI 好友')),
      ],
    );
  }
}

class _FriendsStep extends StatelessWidget {
  const _FriendsStep({required this.form});

  final _OnboardingPageState form;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择至少 5 个 AI 好友',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'V1 会用他们来生成点赞和评论。已选 ${form.selectedFriendIds.length} / 至少 5',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: ListView.separated(
            itemCount: presetFriends.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final friend = presetFriends[index];
              final selected = form.selectedFriendIds.contains(friend.id);
              return Card(
                child: CheckboxListTile(
                  value: selected,
                  onChanged: (value) =>
                      form._toggleFriend(friend.id, value ?? false),
                  secondary: AvatarMark(
                    initial: friend.avatarInitial,
                    color: friend.color,
                  ),
                  title: Text(friend.name),
                  subtitle: Text(
                    '${friend.relationship} · ${friend.personality}',
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(onPressed: form._next, child: const Text('进入 GenkiSNS')),
      ],
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.teal, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
