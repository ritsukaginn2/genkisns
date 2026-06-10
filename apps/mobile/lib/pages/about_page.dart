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
                    body: '点赞和评论由 AI 好友生成，给你一个被看见的感觉。',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _AboutCard(
                    icon: Icons.text_snippet_outlined,
                    title: '文字只在本机使用',
                    body: 'V1 的评论由本地模板生成，不会把发帖文字发送到云端 LLM。',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _AboutCard(
                    icon: Icons.perm_media_outlined,
                    title: '媒体本地优先',
                    body: '图片和视频保存在本机，用于笔记展示。',
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
