import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/page_header.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, AppSpacing.xl),
          children: [
            const PageHeader(title: '关于 GenkiSNS'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  const _AboutCard(
                    icon: Icons.auto_awesome,
                    title: 'AI 互动',
                    body: '点赞和评论会先在本机生成；配置后端后，可经审核升级为真实 LLM 结果。',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _AboutCard(
                    icon: Icons.text_snippet_outlined,
                    title: '文本审核',
                    body: '未配置后端时文字只在本机使用；配置后端时，仅文本和媒体数量等元数据会发送给后端审核与生成。',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _AboutCard(
                    icon: Icons.perm_media_outlined,
                    title: '媒体本地优先',
                    body: '图片和视频文件保存在本机，V1.6 不会把图片或视频文件发送给后端或 LLM。',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _AboutCard(
                    icon: Icons.cloud_queue,
                    title: 'iCloud 备份',
                    body: '开启 iCloud 后，可以备份和恢复本机笔记与媒体；V1 不做账号云同步。',
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

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.teal),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
