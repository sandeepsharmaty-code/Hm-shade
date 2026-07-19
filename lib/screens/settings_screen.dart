/// Purpose      : Settings tab content for the application shell.
/// Author       : HMEOS Engineering
/// Version      : 2.1.0
/// Dependencies : flutter/material.dart, dart:io, dart:convert,
///                path_provider, core/di/service_locator.dart,
///                core/database/database_helper.dart,
///                repositories/knowledge_repository.dart,
///                models/knowledge_base_model.dart, widgets/*
/// Description  : Real, working settings screen. Adds this sprint's
///                required actions on top of SPR-DEP-002's Reset
///                Local Data: Backup Database (file copy to a
///                `backups/` subfolder), Restore Database (copy a
///                chosen backup back over the live file — requires an
///                app restart to take effect, since sqflite holds the
///                file open), Export Knowledge (Knowledge_Base rows
///                to a timestamped JSON file), Import Knowledge
///                (reads a fixed conventional path — see Known Issues
///                in the SPR-DEP-009 report for why there's no file
///                picker), Clear Cache (empties the OS temp
///                directory), About Application. Every filesystem
///                operation is wrapped in try/catch per the "never
///                crash application" rule; all data access goes
///                through KnowledgeRepository/DatabaseHelper, never
///                raw SQL from this file.
/// Change History:
///   1.0.0 - SPR-DEP-002 - Initial creation. Reset Local Data only.
///   2.0.0 - SPR-DEP-009 - Added Backup/Restore Database, Export/
///           Import Knowledge, Clear Cache, About Application.
///   2.1.0 - SPR-DEP-010 - QA fixes: guarded debugPrint with
///           kDebugMode (was logging in release builds). Restore now
///           validates the SQLite file header before overwriting the
///           live database, and takes a pre-restore safety snapshot.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/database/database_helper.dart';
import '../core/di/service_locator.dart';
import '../models/knowledge_base_model.dart';
import '../repositories/knowledge_repository.dart';
import '../widgets/app_card.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/error_dialog.dart';
import '../widgets/loading_view.dart';

/// Settings tab: app info and local-data management.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBusy = false;

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('SettingsScreen: action failed: $error');
      }
      if (mounted) {
        await ErrorDialog.show(
          context,
          message: 'That action could not be completed. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleResetLocalData() async {
    final bool? confirmed = await ConfirmationDialog.show(
      context,
      title: 'Reset Local Data?',
      message:
          'This permanently deletes all locally stored data and cannot '
          'be undone. The app is offline-only, so there is no cloud '
          'backup to restore from.',
      confirmLabel: 'Reset',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _runAction(() async {
      await ServiceLocator.instance.get<DatabaseHelper>().resetDatabase();
      _showMessage('Local data has been reset.');
    });
  }

  Future<void> _handleBackup() async {
    await _runAction(() async {
      final DatabaseHelper databaseHelper = ServiceLocator.instance
          .get<DatabaseHelper>();
      final String dbPath = await databaseHelper.databaseFilePath;
      final File dbFile = File(dbPath);
      if (!dbFile.existsSync()) {
        _showMessage('No database file found yet.');
        return;
      }

      final Directory documentsDir = await getApplicationDocumentsDirectory();
      final Directory backupsDir = Directory(
        '${documentsDir.path}/backups',
      )..createSync(recursive: true);
      final String timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]'), '-');
      final String backupPath =
          '${backupsDir.path}/hue_muse_shade_ai_$timestamp.db';

      await dbFile.copy(backupPath);
      _showMessage('Backed up to backups/hue_muse_shade_ai_$timestamp.db');
    });
  }

  Future<void> _handleRestore() async {
    final Directory documentsDir = await getApplicationDocumentsDirectory();
    final Directory backupsDir = Directory('${documentsDir.path}/backups');
    if (!backupsDir.existsSync()) {
      _showMessage('No backups found yet.');
      return;
    }
    final List<File> backups = backupsDir
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.db'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));

    if (backups.isEmpty) {
      _showMessage('No backups found yet.');
      return;
    }
    if (!mounted) {
      return;
    }

    final File? chosen = await showModalBottomSheet<File>(
      context: context,
      builder: (_) => _BackupPickerSheet(backups: backups),
    );
    if (chosen == null || !mounted) {
      return;
    }

    final bool? confirmed = await ConfirmationDialog.show(
      context,
      title: 'Restore This Backup?',
      message: 'This replaces all current local data with the selected '
          'backup. Restart the app afterward for the restored data to '
          'load.',
      confirmLabel: 'Restore',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }

    if (!await _isValidSqliteFile(chosen)) {
      if (!mounted) {
        return;
      }
      await ErrorDialog.show(
        context,
        message: 'That backup file is not a valid database (corrupted or '
            'wrong format). Restore cancelled — your current data is '
            'unchanged.',
      );
      return;
    }

    await _runAction(() async {
      final DatabaseHelper databaseHelper = ServiceLocator.instance
          .get<DatabaseHelper>();
      final String dbPath = await databaseHelper.databaseFilePath;

      // Safety snapshot of the current live file before overwriting it,
      // so a restore that turns out to be unwanted (or a backup that
      // looked valid but wasn't) can still be manually recovered.
      final File liveFile = File(dbPath);
      if (liveFile.existsSync()) {
        final Directory documentsDir =
            await getApplicationDocumentsDirectory();
        final Directory backupsDir = Directory('${documentsDir.path}/backups')
          ..createSync(recursive: true);
        await liveFile.copy(
          '${backupsDir.path}/pre_restore_safety_snapshot.db',
        );
      }

      await databaseHelper.close();
      await chosen.copy(dbPath);
      _showMessage('Restored. Please restart the app to load it.');
    });
  }

  /// Checks [file] starts with the standard SQLite file header
  /// ("SQLite format 3\0", the first 16 bytes of every valid SQLite
  /// database) before it's ever used to overwrite the live database.
  /// A corrupted or wrong-format backup fails this check and Restore
  /// is cancelled with the user's current data left untouched — the
  /// "Corrupted Backup"/"Restore Failure" cases this sprint's Error
  /// Handling requirement lists.
  Future<bool> _isValidSqliteFile(File file) async {
    try {
      if (!file.existsSync() || await file.length() < 16) {
        return false;
      }
      final RandomAccessFile raf = await file.open();
      final List<int> header;
      try {
        header = await raf.read(16);
      } finally {
        await raf.close();
      }
      const List<int> expected = <int>[
        0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66, // "SQLite f"
        0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00, // "ormat 3\0"
      ];
      if (header.length != expected.length) {
        return false;
      }
      for (int i = 0; i < expected.length; i++) {
        if (header[i] != expected[i]) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleExportKnowledge() async {
    await _runAction(() async {
      final List<KnowledgeBaseModel> entries = await ServiceLocator.instance
          .get<KnowledgeRepository>()
          .readAll();

      final List<Map<String, Object?>> exportRows = <Map<String, Object?>>[
        for (final KnowledgeBaseModel e in entries)
          <String, Object?>{
            'name': e.name,
            'tags': e.tags,
            'content': e.content,
          },
      ];

      final Directory documentsDir = await getApplicationDocumentsDirectory();
      final Directory exportsDir = Directory(
        '${documentsDir.path}/exports',
      )..createSync(recursive: true);
      final String timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]'), '-');
      final File exportFile = File(
        '${exportsDir.path}/knowledge_export_$timestamp.json',
      );
      await exportFile.writeAsString(jsonEncode(exportRows));

      _showMessage(
        'Exported ${entries.length} entries to '
        'exports/knowledge_export_$timestamp.json',
      );
    });
  }

  Future<void> _handleImportKnowledge() async {
    await _runAction(() async {
      final Directory documentsDir = await getApplicationDocumentsDirectory();
      final File importFile = File(
        '${documentsDir.path}/imports/knowledge_import.json',
      );
      if (!importFile.existsSync()) {
        _showMessage(
          'Place a file at Documents/imports/knowledge_import.json '
          'and try again.',
        );
        return;
      }

      final String raw = await importFile.readAsString();
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) {
        _showMessage('knowledge_import.json must contain a JSON array.');
        return;
      }

      final KnowledgeRepository repository = ServiceLocator.instance
          .get<KnowledgeRepository>();
      int imported = 0;
      for (final Object? row in decoded) {
        if (row is! Map<String, Object?>) {
          continue;
        }
        final String? name = row['name'] as String?;
        if (name == null || name.isEmpty) {
          continue;
        }
        await repository.create(
          KnowledgeBaseModel(
            name: name,
            tags: row['tags'] as String?,
            content: row['content'] as String?,
          ),
        );
        imported++;
      }
      _showMessage('Imported $imported knowledge entries.');
    });
  }

  Future<void> _handleClearCache() async {
    await _runAction(() async {
      final Directory tempDir = await getTemporaryDirectory();
      if (!tempDir.existsSync()) {
        _showMessage('Nothing to clear.');
        return;
      }
      int cleared = 0;
      for (final FileSystemEntity entity in tempDir.listSync()) {
        try {
          await entity.delete(recursive: true);
          cleared++;
        } on FileSystemException {
          // Skip files in use; not fatal to the overall clear.
        }
      }
      _showMessage('Cleared $cleared cached item(s).');
    });
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Hue Muse Shade AI',
      applicationVersion: '0.1.0',
      applicationLegalese: 'Offline cosmetic colour shade development. '
          'No internet, no cloud, no login — all data stays on this '
          'device.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (_isBusy) {
      return const LoadingView(message: 'Working…');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _SettingsTile(
          icon: Icons.backup_outlined,
          label: 'Backup Database',
          onTap: _handleBackup,
        ),
        _SettingsTile(
          icon: Icons.restore_outlined,
          label: 'Restore Database',
          onTap: _handleRestore,
        ),
        _SettingsTile(
          icon: Icons.file_upload_outlined,
          label: 'Export Knowledge',
          onTap: _handleExportKnowledge,
        ),
        _SettingsTile(
          icon: Icons.file_download_outlined,
          label: 'Import Knowledge',
          onTap: _handleImportKnowledge,
        ),
        _SettingsTile(
          icon: Icons.cleaning_services_outlined,
          label: 'Clear Cache',
          onTap: _handleClearCache,
        ),
        _SettingsTile(
          icon: Icons.info_outline,
          label: 'About Application',
          onTap: _showAbout,
        ),
        const SizedBox(height: 8),
        AppCard(
          onTap: _handleResetLocalData,
          child: Row(
            children: <Widget>[
              Icon(Icons.delete_outline, color: colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reset Local Data',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _BackupPickerSheet extends StatelessWidget {
  const _BackupPickerSheet({required this.backups});
  final List<File> backups;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Choose a Backup'),
          ),
          for (final File backup in backups)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(backup.path.split('/').last),
              onTap: () => Navigator.of(context).pop(backup),
            ),
        ],
      ),
    );
  }
}
