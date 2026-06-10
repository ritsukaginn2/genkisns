import 'package:flutter/material.dart';

import '../data/services/icloud_backup_service.dart';
import '../theme/app_theme.dart';
import '../widgets/page_header.dart';

class ICloudBackupPage extends StatefulWidget {
  const ICloudBackupPage({
    super.key,
    required this.loadStatus,
    required this.onSetSyncEnabled,
  });

  final Future<ICloudBackupStatus> Function() loadStatus;
  final Future<ICloudBackupStatus> Function(bool enabled) onSetSyncEnabled;

  @override
  State<ICloudBackupPage> createState() => _ICloudBackupPageState();
}

class _ICloudBackupPageState extends State<ICloudBackupPage> {
  ICloudBackupStatus? status;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    final current = status;
    final unavailable = current != null && !current.available;
    final switchEnabled = !busy && current != null && current.available;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            const PageHeader(title: 'iCloud 同步'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatusCard(status: current, busy: busy),
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    child: SwitchListTile.adaptive(
                      value: current?.syncEnabled ?? false,
                      onChanged: switchEnabled ? _setEnabled : null,
                      title: const Text('iCloud 同步'),
                      subtitle: Text(
                        unavailable
                            ? '请先登录 iCloud 并开启 iCloud Drive。'
                            : '开启后，笔记和媒体会自动备份到 iCloud；'
                                  '换机或重装时会自动恢复。',
                      ),
                      secondary: const Icon(Icons.cloud_sync_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadStatus() async {
    final next = await widget.loadStatus();
    if (!mounted) return;
    setState(() => status = next);
  }

  Future<void> _setEnabled(bool enabled) async {
    setState(() => busy = true);
    try {
      final next = await widget.onSetSyncEnabled(enabled);
      if (!mounted) return;
      setState(() {
        status = next;
        busy = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        status = ICloudBackupStatus(
          available: false,
          hasBackup: false,
          syncEnabled: enabled,
          message: '操作失败，请稍后再试。',
        );
        busy = false;
      });
    }
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.busy});

  final ICloudBackupStatus? status;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final current = status;
    final title = busy
        ? '正在处理'
        : current == null
        ? '正在检查'
        : current.available
        ? 'iCloud 可用'
        : 'iCloud 不可用';
    final body = busy
        ? '请保持 App 打开，正在同步本机笔记和媒体。'
        : current == null
        ? '正在读取 iCloud 状态。'
        : current.message ??
              (!current.syncEnabled
                  ? '同步已关闭。'
                  : current.hasBackup
                  ? '最近备份：${_formatDateTime(current.updatedAt)}'
                  : '已开启，等待第一次备份。');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              busy ? Icons.sync : Icons.cloud_queue,
              color: current?.available == false
                  ? AppColors.coral
                  : AppColors.teal,
            ),
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

String _formatDateTime(DateTime? value) {
  if (value == null) return '未知';
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$month-$day $hour:$minute';
}
