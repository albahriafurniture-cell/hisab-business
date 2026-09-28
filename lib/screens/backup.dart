import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/hive_service.dart';
import '../l10n/care_l10n.dart';
import '../services/care_service.dart';
import '../theme.dart';
import '../widgets/hb_chrome.dart';
import '../widgets/hb_actions.dart';

/// Backup & restore: status card, "Backup Now" (file + share), and restore
/// from previously created backup files. Route: [Routes.backup].
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  List<File> _files = [];
  bool _loadingFiles = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final files = await CareService.backupFiles();
    if (!mounted) return;
    setState(() {
      _files = files;
      _loadingFiles = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final last = CareService.lastBackupAt;
    return Scaffold(
      appBar: HBAppBar(title: careTr('care.backupTitle')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card --------------------------------------------------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDark
                              ? HBColors.primarySoftDark
                              : HBColors.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cloud_upload_outlined,
                            color: HBColors.primary, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(careTr('care.lastBackup'),
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? HBColors.mutedDark
                                        : HBColors.muted)),
                            const SizedBox(height: 2),
                            Text(
                              last == null
                                  ? careTr('care.never')
                                  : '${careDateShort(last)} · '
                                      '${last.hour.toString().padLeft(2, '0')}:'
                                      '${last.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Text(careTr('care.dataInApp'),
                      style: TextStyle(
                          fontSize: 13,
                          color:
                              isDark ? HBColors.mutedDark : HBColors.muted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _count(careTr('care.parties'),
                          HiveService.parties.length),
                      _count(careTr('care.khataEntries'),
                          HiveService.khataEntries.length),
                      _count(careTr('care.cashEntries'),
                          HiveService.cashEntries.length),
                      _count(careTr('care.bills'), HiveService.bills.length),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          HBPillButton(
            label: _busy ? '…' : careTr('care.backupNow'),
            icon: Icons.backup_outlined,
            onPressed: _busy ? null : _backupNow,
          ),
          const SizedBox(height: 12),
          // Safety note (own words) --------------------------------------
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? HBColors.moneyInSoftDark : HBColors.moneyInSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined,
                    size: 20, color: moneyColor(true, isDark: isDark)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    careTr('care.keepCopySafe'),
                    style: TextStyle(
                        fontSize: 13,
                        color: moneyColor(true, isDark: isDark),
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(careTr('care.restore'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_loadingFiles)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 8),
          if (!_loadingFiles && _files.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.folder_off_outlined,
                      size: 40,
                      color:
                          isDark ? HBColors.mutedDark : HBColors.muted),
                  const SizedBox(height: 8),
                  Text(careTr('care.noBackups'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(careTr('care.noBackupsSub'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color:
                              isDark ? HBColors.mutedDark : HBColors.muted)),
                ],
              ),
            ),
          for (final f in _files) _backupTile(context, f),
        ],
      ),
    );
  }

  Widget _count(String label, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _backupTile(BuildContext context, File file) {
    final name = file.path.split('/').last;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.description_outlined,
            color: HBColors.primary),
        title: Text(name, style: const TextStyle(fontSize: 14)),
        subtitle: FutureBuilder<int>(
          future: file.length(),
          builder: (ctx, snap) => Text(
            snap.hasData
                ? '${(snap.data! / 1024).toStringAsFixed(1)} KB'
                : '',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        trailing: TextButton(
          onPressed: () => _confirmRestore(context, file),
          child: Text(careTr('care.restore')),
        ),
      ),
    );
  }

  Future<void> _backupNow() async {
    if (kIsWeb) {
      if (mounted) {
        HBToast.show(context,
            message: careTr('care.backupFailed'),
            icon: Icons.error_outline);
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final path = await HiveService.exportBackupToFile();
      await CareService.recordBackupNow();
      await _loadFiles();
      if (!mounted) return;
      setState(() => _busy = false);
      HBToast.show(context,
          message: careTr('care.backupDone'), icon: Icons.check_circle);
      // Hand the file to the user so they can keep a copy somewhere safe.
      await SharePlus.instance.share(ShareParams(
          files: [XFile(path)], text: careTr('care.backupShareText')));
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      HBToast.show(context,
          message: careTr('care.backupFailed'),
          icon: Icons.error_outline);
    }
  }

  Future<void> _confirmRestore(BuildContext context, File file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(careTr('care.restoreConfirmTitle')),
        content: Text(careTr('care.restoreConfirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(careTr('care.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: moneyColor(false)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(careTr('care.restore')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final json = await file.readAsString();
      await HiveService.restoreFromJson(json);
      await _loadFiles();
      if (!context.mounted) return;
      setState(() => _busy = false);
      HBToast.show(context,
          message: careTr('care.restoreDone'), icon: Icons.check_circle);
    } catch (_) {
      if (!context.mounted) return;
      setState(() => _busy = false);
      HBToast.show(context,
          message: careTr('care.invalidBackup'),
          icon: Icons.error_outline);
    }
  }
}
