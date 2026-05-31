import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.titleStyle,
    this.showBackButton = true,
    this.foregroundColor,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.md,
    ),
  });

  final String title;
  final TextStyle? titleStyle;
  final bool showBackButton;
  final Color? foregroundColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (showBackButton) ...[
            IconButton(
              tooltip: '返回',
              color: foregroundColor,
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: Text(
              title,
              style: (titleStyle ?? Theme.of(context).textTheme.titleLarge)
                  ?.copyWith(color: foregroundColor),
            ),
          ),
        ],
      ),
    );
  }
}
