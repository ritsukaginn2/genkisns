import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_mark.dart';
import '../widgets/page_header.dart';
import '../data/services/llm_client.dart';
import '../data/services/iap_service.dart';
import 'entitlements_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.user,
    required this.friends,
    required this.postCount,
    required this.onOpenAbout,
    required this.onOpenUiLab,
    required this.onOpenFriends,
    required this.onOpenICloudBackup,
    required this.onClearLocalContent,
    required this.onExportData,
    required this.llmClient,
    required this.iapService,
  });

  final UserProfile user;
  final List<AiFriend> friends;
  final int postCount;
  final VoidCallback onOpenAbout;
  final VoidCallback onOpenUiLab;
  final VoidCallback onOpenFriends;
  final VoidCallback onOpenICloudBackup;
  final Future<void> Function() onClearLocalContent;
  final Future<void> Function() onExportData;
  final LLMClient llmClient;
  final IAPService iapService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            const PageHeader(title: '我的'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
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
                  const SizedBox(height: AppSpacing.sm),
                  _SettingsTile(
                    icon: Icons.workspace_premium,
                    iconColor: AppColors.teal,
                    title: '权益和额度',
                    subtitle: '查看生成配额与订阅信息',
                    onTap: () => _openEntitlements(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SettingsTile(
                    icon: Icons.cloud_queue,
                    iconColor: AppColors.coral,
                    title: 'iCloud 同步',
                    subtitle: '自动备份本机笔记与媒体',
                    onTap: onOpenICloudBackup,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SettingsTile(
                    icon: Icons.download_outlined,
                    iconColor: AppColors.teal,
                    title: '导出数据',
                    subtitle: '下载笔记和互动数据为 JSON 文件',
                    onTap: () => _exportData(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SettingsTile(
                    icon: Icons.delete_sweep_outlined,
                    iconColor: AppColors.coral,
                    title: '清空本地内容',
                    subtitle: '删除本机所有笔记和媒体（不影响 iCloud 备份）',
                    onTap: () => _confirmClear(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEntitlements(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EntitlementsPage(
          llmClient: llmClient,
          iapService: iapService,
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    await onExportData();
  }

  Future<void> _confirmClear(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ClearConfirmSheet(
        postCount: postCount,
        onCancel: () => Navigator.of(sheetContext).pop(false),
        onConfirm: () => Navigator.of(sheetContext).pop(true),
      ),
    );
    if (confirmed != true) return;

    await onClearLocalContent();
    messenger.showSnackBar(const SnackBar(content: Text('已清空本地内容')));
  }
}

class _ClearConfirmSheet extends StatelessWidget {
  const _ClearConfirmSheet({
    required this.postCount,
    required this.onCancel,
    required this.onConfirm,
  });

  final int postCount;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

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
          Text('清空本地内容？', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            postCount > 0
                ? '将删除本机 $postCount 篇笔记及其媒体，删除后不可恢复。iCloud 备份不受影响。'
                : '将删除本机所有笔记及其媒体，删除后不可恢复。iCloud 备份不受影响。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('清空'),
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
