import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../data/services/llm_client.dart';

class EntitlementsPage extends StatefulWidget {
  const EntitlementsPage({
    super.key,
    required this.llmClient,
  });

  final LLMClient llmClient;

  @override
  State<EntitlementsPage> createState() => _EntitlementsPageState();
}

class _EntitlementsPageState extends State<EntitlementsPage> {
  late Future<EntitlementResponse> _entitlementsFuture;

  @override
  void initState() {
    super.initState();
    _entitlementsFuture = widget.llmClient.getEntitlements();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('权益和额度'),
        centerTitle: true,
      ),
      body: FutureBuilder<EntitlementResponse>(
        future: _entitlementsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.coral, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text('加载失败: ${snapshot.error}'),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: () => setState(() => _entitlementsFuture = widget.llmClient.getEntitlements()),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          final entitlements = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _entitlementsFuture = widget.llmClient.getEntitlements());
              await _entitlementsFuture;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Plan Card
                    _PlanCard(
                      isPro: entitlements.isPro,
                      quotaRemaining: entitlements.quotaRemaining,
                      quotaTotal: entitlements.quotaTotal,
                      nextResetAt: entitlements.nextResetAt,
                      expiresAt: entitlements.subscriptionExpiresAt,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Quota Usage
                    _QuotaWidget(
                      remaining: entitlements.quotaRemaining,
                      total: entitlements.quotaTotal,
                      resetAt: entitlements.nextResetAt,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Pro Plan Info
                    if (!entitlements.isPro)
                      _ProPlanCard(
                        onPurchase: () => _showPurchaseDialog(context),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('升级到 Pro'),
        content: const Text(
          'Pro 套餐包含:\n'
          '• 每天 3000 条生成配额\n'
          '• 优先生成\n'
          '• 无限制生成期限\n\n'
          '价格: ¥99/年',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // TODO: Integrate with Apple IAP
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('IAP 集成开发中...')),
              );
            },
            child: const Text('购买'),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.isPro,
    required this.quotaRemaining,
    required this.quotaTotal,
    required this.nextResetAt,
    required this.expiresAt,
  });

  final bool isPro;
  final int quotaRemaining;
  final int quotaTotal;
  final DateTime nextResetAt;
  final DateTime? expiresAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isPro ? AppColors.teal : AppColors.blue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isPro ? AppColors.teal : AppColors.blue).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPro ? 'Pro 套餐' : '免费套餐',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (expiresAt != null)
                    Text(
                      '过期于 ${expiresAt!.year}-${expiresAt!.month.toString().padLeft(2, '0')}-${expiresAt!.day.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPro ? '✓ 活跃' : '试用',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuotaWidget extends StatelessWidget {
  const _QuotaWidget({
    required this.remaining,
    required this.total,
    required this.resetAt,
  });

  final int remaining;
  final int total;
  final DateTime resetAt;

  @override
  Widget build(BuildContext context) {
    final hoursUntilReset = resetAt.difference(DateTime.now()).inHours;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今日生成配额',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: remaining / total,
            minHeight: 12,
            backgroundColor: AppColors.line,
            valueColor: AlwaysStoppedAnimation<Color>(
              remaining > total * 0.3 ? AppColors.teal : AppColors.coral,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$remaining / $total',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              '约 $hoursUntilReset 小时后重置',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _ProPlanCard extends StatelessWidget {
  const _ProPlanCard({
    required this.onPurchase,
  });

  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.teal),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '升级到 Pro',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          const _PlanFeature(
            icon: Icons.flash_on,
            text: '每天 3000 条生成次数',
          ),
          const _PlanFeature(
            icon: Icons.priority_high,
            text: '优先处理生成请求',
          ),
          const _PlanFeature(
            icon: Icons.favorite,
            text: '无限期使用权限',
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPurchase,
              icon: const Icon(Icons.shopping_cart),
              label: const Text('¥99/年 - 立即购买'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanFeature extends StatelessWidget {
  const _PlanFeature({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: AppColors.teal, size: 20),
          const SizedBox(width: AppSpacing.md),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
