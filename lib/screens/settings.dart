import 'package:flutter/material.dart';

import '../data/hive_service.dart';
import '../l10n/care_l10n.dart';
import '../l10n/strings.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/hb_chrome.dart';

/// App settings: language, theme, hide-balances, app lock, backup shortcut,
/// about. Route: [Routes.settings].
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = HiveService.language;
    final theme = HiveService.themeMode;
    return Scaffold(
      appBar: HBAppBar(title: careTr('care.settingsTitle')),
      body: ListView(
        children: [
          _tile(
            icon: Icons.translate_outlined,
            title: careTr('care.language'),
            subtitle: lang == 'ur' ? 'اردو' : 'English',
            onTap: _pickLanguage,
            isDark: isDark,
          ),
          _tile(
            icon: Icons.palette_outlined,
            title: careTr('care.theme'),
            subtitle: _themeLabel(theme),
            onTap: _pickTheme,
            isDark: isDark,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off_outlined,
                color: HBColors.primary),
            title: Text(careTr('care.hideBalances')),
            subtitle: Text(careTr('care.hideBalancesSub')),
            value: HiveService.hideBalances,
            activeThumbColor: HBColors.primary,
            onChanged: (v) async {
              await HiveService.setHideBalances(v);
              if (mounted) setState(() {});
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline,
                color: HBColors.primary),
            title: Text(careTr('care.appLock')),
            subtitle: Text(careTr('care.appLockSub')),
            value: HiveService.hasPin,
            activeThumbColor: HBColors.primary,
            onChanged: (v) => v ? _enableLock() : _disableLock(),
          ),
          _tile(
            icon: Icons.backup_outlined,
            title: careTr('care.backup'),
            subtitle: null,
            onTap: () => Navigator.of(context).pushNamed(Routes.backup),
            isDark: isDark,
          ),
          _tile(
            icon: Icons.info_outline,
            title: careTr('care.about'),
            subtitle: careTr('care.version'),
            onTap: _showAbout,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String? subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      leading: Icon(icon, color: HBColors.primary),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Icon(Icons.chevron_right,
          color: isDark ? HBColors.mutedDark : HBColors.muted),
      onTap: onTap,
    );
  }

  String _themeLabel(String theme) => switch (theme) {
        'light' => careTr('care.themeLight'),
        'dark' => careTr('care.themeDark'),
        _ => careTr('care.themeSystem'),
      };

  Future<void> _pickLanguage() async {
    final current = HiveService.language;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(careTr('care.selectLanguage')),
        content: RadioGroup<String>(
          groupValue: current,
          onChanged: (v) => Navigator.of(ctx).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                value: 'en',
                title: const Text('English'),
                activeColor: HBColors.primary,
              ),
              RadioListTile<String>(
                value: 'ur',
                title: const Text('اردو'),
                activeColor: HBColors.primary,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(careTr('care.cancel')),
          ),
        ],
      ),
    );
    if (picked == null || picked == current) return;
    await HiveService.setLanguage(picked);
    // Rebuilds the whole app (MaterialApp listens on this notifier).
    AppLocale.current.value = picked;
    if (mounted) setState(() {});
  }

  Future<void> _pickTheme() async {
    final current = HiveService.themeMode;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(careTr('care.theme')),
        children: [
          RadioGroup<String>(
            groupValue: current,
            onChanged: (v) => Navigator.of(ctx).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in [
                  ('system', careTr('care.themeSystem')),
                  ('light', careTr('care.themeLight')),
                  ('dark', careTr('care.themeDark')),
                ])
                  RadioListTile<String>(
                    value: e.$1,
                    title: Text(e.$2),
                    activeColor: HBColors.primary,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null || picked == current) return;
    await HiveService.setThemeMode(picked);
    if (!mounted) return;
    setState(() {});
    // ThemeMode is read once when MaterialApp builds (foundation), so a
    // restart is needed for the new theme to take effect.
    HBToast.show(context,
        message: careTr('care.themeRestartNote'), icon: Icons.palette_outlined);
  }

  /// [DEVIATION] LockScreen (another crew's file) has no setup mode yet —
  /// we navigate to Routes.lock; the lock crew must add PIN creation there.
  Future<void> _enableLock() async {
    await Navigator.of(context).pushNamed(Routes.lock);
    if (mounted) setState(() {});
  }

  Future<void> _disableLock() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(careTr('care.disableLockTitle')),
        content: Text(careTr('care.disableLockBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(careTr('care.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(careTr('care.confirm')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await HiveService.setPinHash('');
    if (!mounted) return;
    setState(() {});
    HBToast.show(context,
        message: careTr('care.lockDisabled'), icon: Icons.lock_open_outlined);
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(careTr('care.aboutTitle')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(careTr('care.aboutBody'),
                  style: const TextStyle(height: 1.5)),
              const SizedBox(height: 12),
              Text(careTr('care.version'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(careTr('care.close')),
          ),
        ],
      ),
    );
  }
}
