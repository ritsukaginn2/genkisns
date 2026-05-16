import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.zero,
              onPressed: () {
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            const _AboutCard(
              icon: Icons.auto_awesome,
              title: 'AI 互动',
              body: '点赞和评论由 AI 好友生成，给你一个被看见的感觉。',
            ),
            const SizedBox(height: AppSpacing.md),
            const _AboutCard(
              icon: Icons.text_snippet_outlined,
              title: '文字会发送给 LLM',
              body: '为了生成评论，发帖文字会发送给开发者预配置的 OpenAI 兼容 LLM 供应商。',
            ),
            const SizedBox(height: AppSpacing.md),
            const _AboutCard(
              icon: Icons.image_not_supported_outlined,
              title: '图片不会发送',
              body: '图片只保存在本地，用于笔记展示，不发送给 LLM。',
            ),
            const SizedBox(height: AppSpacing.md),
            const _AboutCard(
              icon: Icons.lock_outline,
              title: '本地优先',
              body: '笔记和评论保存在设备本地。',
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.icon, required this.title, required this.body});

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
