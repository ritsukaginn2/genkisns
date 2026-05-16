import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_mark.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.user,
    required this.friends,
    required this.postCount,
    required this.onOpenAbout,
    required this.onOpenUiLab,
    required this.onOpenFriends,
  });

  final UserProfile user;
  final List<AiFriend> friends;
  final int postCount;
  final VoidCallback onOpenAbout;
  final VoidCallback onOpenUiLab;
  final VoidCallback onOpenFriends;

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
          children: [
            Row(
              children: [
                AvatarMark(
                  initial: user.avatarInitial,
                  color: AppColors.coral,
                  size: 44,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    user.nickname,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _SettingsTile(
              icon: Icons.people_outline,
              iconColor: AppColors.teal,
              title: 'AI 好友',
              subtitle: '${friends.length} 位好友会来点赞和评论',
              onTap: onOpenFriends,
            ),
            const SizedBox(height: AppSpacing.sm),
            _SettingsTile(
              icon: Icons.palette_outlined,
              iconColor: AppColors.coral,
              title: 'UI 实验室',
              subtitle: 'A / B / C 设计方向',
              onTap: onOpenUiLab,
            ),
            const SizedBox(height: AppSpacing.sm),
            _SettingsTile(
              icon: Icons.info_outline,
              iconColor: AppColors.teal,
              title: '关于 GenkiSNS',
              subtitle: 'AI 生成说明与隐私提示',
              onTap: onOpenAbout,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.line),
      ),
      tileColor: AppColors.surface,
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
