import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

@immutable
class ICloudBackupStatus {
  const ICloudBackupStatus({
    required this.available,
    required this.hasBackup,
    this.syncEnabled = false,
    this.message,
    this.updatedAt,
  });

  final bool available;
  final bool hasBackup;
  final bool syncEnabled;
  final String? message;
  final DateTime? updatedAt;
}

class ICloudBackupService {
  const ICloudBackupService();

  static const _channel = MethodChannel('genki_sns/icloud');
  static const _databaseName = 'genki_sns_v1.db';

  Future<ICloudBackupStatus> status() async {
    final enabled = await isSyncEnabled();
    final backupRoot = await _backupRootDirectory();
    if (backupRoot == null) {
      return ICloudBackupStatus(
        available: false,
        hasBackup: false,
        syncEnabled: enabled,
        message: 'iCloud 不可用，请确认已登录 iCloud 且 App 已启用 iCloud Drive。',
      );
    }

    if (!enabled) {
      // Sync is off; don't touch iCloud beyond reporting availability.
      return const ICloudBackupStatus(
        available: true,
        hasBackup: false,
        syncEnabled: false,
      );
    }

    // iCloud Drive only keeps placeholders on disk until contents are pulled
    // down, so force the gating files local before checking existence.
    await _ensureBackupDownloaded();

    final marker = _backupMarker(backupRoot);
    if (!await marker.exists() || !await _backupDatabase(backupRoot).exists()) {
      return const ICloudBackupStatus(
        available: true,
        hasBackup: false,
        syncEnabled: true,
      );
    }

    return ICloudBackupStatus(
      available: true,
      hasBackup: true,
      syncEnabled: true,
      updatedAt: await marker.lastModified(),
    );
  }

  Future<ICloudBackupStatus> backupNow() async {
    final backupRoot = await _backupRootDirectory();
    if (backupRoot == null) {
      return const ICloudBackupStatus(
        available: false,
        hasBackup: false,
        message: 'iCloud 不可用。',
      );
    }

    final tmpRoot = Directory('${backupRoot.path}.tmp');
    final previousRoot = Directory('${backupRoot.path}.previous');
    await _deleteDirectoryIfExists(tmpRoot);
    await _deleteDirectoryIfExists(previousRoot);
    await tmpRoot.create(recursive: true);

    await _replaceDirectory(
      source: await _localDatabaseDirectory(),
      target: Directory(p.join(tmpRoot.path, 'database')),
      includeNames: _databaseFilenames,
    );
    await _replaceDirectory(
      source: await _localMediaDirectory(),
      target: Directory(p.join(tmpRoot.path, 'post_media')),
    );

    if (!await _backupDatabase(tmpRoot).exists()) {
      await _deleteDirectoryIfExists(tmpRoot);
      return const ICloudBackupStatus(
        available: true,
        hasBackup: false,
        message: '本机数据库还没有可备份内容。',
      );
    }

    final marker = _backupMarker(tmpRoot);
    await marker.writeAsString(DateTime.now().toIso8601String(), flush: true);
    await _replaceDirectoryAtomically(
      source: tmpRoot,
      target: backupRoot,
      previous: previousRoot,
    );
    return status();
  }

  Future<ICloudBackupStatus> restoreNow() async {
    final backupRoot = await _backupRootDirectory();
    if (backupRoot == null) {
      return const ICloudBackupStatus(
        available: false,
        hasBackup: false,
        message: 'iCloud 不可用。',
      );
    }

    // Pull the cloud copy down (placeholders -> real files) before reading it;
    // this is what makes restore work after a reinstall or on a new device.
    await _ensureBackupDownloaded(timeoutMillis: 60000);

    if (!await _isValidBackup(backupRoot)) {
      return const ICloudBackupStatus(
        available: true,
        hasBackup: false,
        message: '还没有可恢复的 iCloud 备份。',
      );
    }

    final localDatabaseDir = await _localDatabaseDirectory();
    final localMediaDir = await _localMediaDirectory();
    final databaseRestoreTmp = Directory(
      p.join(localDatabaseDir.path, 'genki_sns_restore_database_tmp'),
    );
    final mediaRestoreTmp = Directory('${localMediaDir.path}.restore_tmp');
    final databaseRestorePrevious = Directory(
      p.join(localDatabaseDir.path, 'genki_sns_restore_database_previous'),
    );
    final mediaRestorePrevious = Directory(
      '${localMediaDir.path}.restore_previous',
    );

    await _replaceDirectory(
      source: Directory(p.join(backupRoot.path, 'database')),
      target: databaseRestoreTmp,
      includeNames: _databaseFilenames,
    );
    await _replaceDirectory(
      source: Directory(p.join(backupRoot.path, 'post_media')),
      target: mediaRestoreTmp,
    );

    if (!await File(p.join(databaseRestoreTmp.path, _databaseName)).exists()) {
      await _deleteDirectoryIfExists(databaseRestoreTmp);
      await _deleteDirectoryIfExists(mediaRestoreTmp);
      return const ICloudBackupStatus(
        available: true,
        hasBackup: false,
        message: 'iCloud 备份不完整，无法恢复。',
      );
    }

    await _replaceFilesAtomically(
      source: databaseRestoreTmp,
      target: localDatabaseDir,
      previous: databaseRestorePrevious,
      names: _databaseFilenames,
      cleanupPrevious: false,
    );
    try {
      await _replaceDirectoryAtomically(
        source: mediaRestoreTmp,
        target: localMediaDir,
        previous: mediaRestorePrevious,
      );
    } catch (_) {
      await _restorePreviousFiles(
        previous: databaseRestorePrevious,
        target: localDatabaseDir,
        names: _databaseFilenames,
      );
      rethrow;
    }
    await _deleteDirectoryIfExists(databaseRestoreTmp);
    await _deleteDirectoryIfExists(mediaRestoreTmp);
    await _deleteDirectoryIfExists(databaseRestorePrevious);
    await _deleteDirectoryIfExists(mediaRestorePrevious);
    return status();
  }

  Future<void> restoreIfLocalDataMissing() async {
    if (!await isSyncEnabled()) return;

    final database = File(p.join(await getDatabasesPath(), _databaseName));
    if (await database.exists()) return;

    final current = await status();
    if (!current.available || !current.hasBackup) return;
    await restoreNow();
  }

  /// Whether iCloud sync is turned on. Defaults to on so a reinstall (where the
  /// local preference file is gone) still auto-restores without user action.
  Future<bool> isSyncEnabled() async {
    try {
      final file = await _syncPreferenceFile();
      if (!await file.exists()) return true;
      return (await file.readAsString()).trim() != '0';
    } on Object {
      return true;
    }
  }

  Future<void> setSyncEnabled(bool enabled) async {
    final file = await _syncPreferenceFile();
    await file.writeAsString(enabled ? '1' : '0', flush: true);
  }

  Future<File> _syncPreferenceFile() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    return File(p.join(documentsDir.path, 'icloud_sync_enabled'));
  }

  /// Asks the native side to download the iCloud backup's placeholder files so
  /// `File.exists()` reflects the cloud contents. Best-effort: failures just
  /// leave the existing local state untouched.
  Future<void> _ensureBackupDownloaded({int timeoutMillis = 20000}) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<bool>('downloadBackup', {
        'timeoutMillis': timeoutMillis,
      });
    } on PlatformException {
      // Best-effort download; reading falls back to whatever is already local.
    } on MissingPluginException {
      // Native handler not available (e.g. older build) — skip.
    }
  }

  Future<Directory?> _backupRootDirectory() async {
    if (!Platform.isIOS) return null;
    try {
      final containerPath = await _channel.invokeMethod<String>(
        'containerPath',
      );
      if (containerPath == null || containerPath.isEmpty) return null;
      return Directory(
        p.join(containerPath, 'Documents', 'GenkiSNS', 'V1Backup'),
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<Directory> _localDatabaseDirectory() async {
    return Directory(await getDatabasesPath());
  }

  Future<Directory> _localMediaDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(documentsDir.path, 'post_media'));
  }

  List<String> get _databaseFilenames => const [
    _databaseName,
    '$_databaseName-wal',
  ];

  File _backupMarker(Directory backupRoot) {
    return File(p.join(backupRoot.path, 'backup.marker'));
  }

  File _backupDatabase(Directory backupRoot) {
    return File(p.join(backupRoot.path, 'database', _databaseName));
  }

  Future<bool> _isValidBackup(Directory backupRoot) async {
    return await _backupMarker(backupRoot).exists() &&
        await _backupDatabase(backupRoot).exists();
  }

  Future<void> _replaceDirectory({
    required Directory source,
    required Directory target,
    List<String>? includeNames,
  }) async {
    if (await target.exists()) {
      await target.delete(recursive: true);
    }
    await target.create(recursive: true);
    if (!await source.exists()) return;

    await for (final entity in source.list(recursive: false)) {
      final name = p.basename(entity.path);
      if (includeNames != null && !includeNames.contains(name)) continue;
      final nextTarget = p.join(target.path, name);
      if (entity is File) {
        await entity.copy(nextTarget);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(nextTarget));
      }
    }
  }

  Future<void> _restoreDirectory({
    required Directory source,
    required Directory target,
  }) async {
    if (!await source.exists()) return;
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final nextTarget = p.join(target.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(nextTarget);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(nextTarget));
      }
    }
  }

  Future<void> _deleteFiles({
    required Directory directory,
    required List<String> names,
  }) async {
    for (final name in names) {
      final file = File(p.join(directory.path, name));
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _replaceFilesAtomically({
    required Directory source,
    required Directory target,
    required Directory previous,
    required List<String> names,
    bool cleanupPrevious = true,
  }) async {
    await _deleteDirectoryIfExists(previous);
    await previous.create(recursive: true);
    await target.create(recursive: true);

    for (final name in names) {
      final current = File(p.join(target.path, name));
      if (await current.exists()) {
        await current.copy(p.join(previous.path, name));
      }
    }

    try {
      await _deleteFiles(directory: target, names: names);
      await _restoreDirectory(source: source, target: target);
      if (cleanupPrevious) {
        await _deleteDirectoryIfExists(previous);
      }
    } catch (_) {
      await _restorePreviousFiles(
        previous: previous,
        target: target,
        names: names,
      );
      rethrow;
    }
  }

  Future<void> _restorePreviousFiles({
    required Directory previous,
    required Directory target,
    required List<String> names,
  }) async {
    await _deleteFiles(directory: target, names: names);
    await _restoreDirectory(source: previous, target: target);
  }

  Future<void> _replaceDirectoryAtomically({
    required Directory source,
    required Directory target,
    required Directory previous,
  }) async {
    if (await previous.exists()) {
      await previous.delete(recursive: true);
    }
    var movedCurrent = false;
    try {
      if (await target.exists()) {
        await target.rename(previous.path);
        movedCurrent = true;
      }
      await source.rename(target.path);
      if (await previous.exists()) {
        await previous.delete(recursive: true);
      }
    } catch (_) {
      if (!await target.exists() && movedCurrent && await previous.exists()) {
        await previous.rename(target.path);
      }
      rethrow;
    } finally {
      await _deleteDirectoryIfExists(source);
    }
  }

  Future<void> _deleteDirectoryIfExists(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final nextTarget = p.join(target.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(nextTarget);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(nextTarget));
      }
    }
  }
}
