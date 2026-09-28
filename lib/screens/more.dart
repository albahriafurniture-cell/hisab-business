import 'package:flutter/material.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../l10n/care_l10n.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/hb_chrome.dart';
import '../widgets/hb_cards.dart';
import '../widgets/hb_rows.dart';

/// Overflow menu: profile header + module grid. Also serves as the More
/// bottom-tab body, so the constructor stays `const`. Route: [Routes.more].
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final biz = HiveService.currentBusiness;
    final name = (biz?.name ?? '').trim().isEmpty
        ? careTr('care.myBusiness')
        : biz!.name;
    final phone = (biz?.phone ?? '').trim();
    final initial =
        name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Scaffold(
      body: ListView(
        children: [
          // Profile header ------------------------------------------------
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [HBColors.gradientTop, HBColors.gradientBottom],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white24,
                      child: Text(initial,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          if (phone.isNotEmpty)
                            Text(phone,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: careTr('care.editProfile'),
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.white),
                      onPressed: () => Navigator.of(context)
                          .pushNamed(Routes.businessSetup),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Module grid ----------------------------------------------------
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _tile(context, Icons.badge_outlined,
                  careTr('care.businessCard'), Routes.businessCard),
              _tile(context, Icons.account_balance_wallet_outlined,
                  careTr('care.cashBook'), Routes.cash),
              _tile(context, Icons.inventory_2_outlined,
                  careTr('care.stockBook'), Routes.stock),
              _tile(context, Icons.receipt_long_outlined,
                  careTr('care.billBook'), Routes.bills),
              _tile(context, Icons.groups_outlined,
                  careTr('care.staffBook'), Routes.staff),
              _tile(context, Icons.account_balance_outlined,
                  careTr('care.bankBook'), Routes.bank),
              _tile(context, Icons.trending_down_outlined,
                  careTr('care.expense'), Routes.expense),
              _tile(context, Icons.bar_chart_outlined,
                  careTr('care.reports'), Routes.reports),
              _tile(context, Icons.notifications_outlined,
                  careTr('care.reminders'), Routes.reminders),
              _tile(context, Icons.backup_outlined, careTr('care.backup'),
                  Routes.backup),
              _tile(context, Icons.lock_outline,
                  careTr('care.appLockTile'), Routes.lock),
              _tile(context, Icons.translate_outlined,
                  careTr('care.language'), Routes.settings),
              HBModuleTile(
                icon: Icons.delete_outline,
                label: careTr('care.recycleBin'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const _RecycleBinScreen()),
                ),
              ),
              HBModuleTile(
                icon: Icons.help_outline,
                label: careTr('care.helpFaq'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const _HelpScreen()),
                ),
              ),
              HBModuleTile(
                icon: Icons.delete_forever_outlined,
                label: careTr('care.deleteData'),
                tint: HBColors.moneyOutSoft,
                iconColor: HBColors.moneyOut,
                onTap: () => _confirmDelete(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _tile(
      BuildContext context, IconData icon, String label, String route) {
    return HBModuleTile(
      icon: icon,
      label: label,
      onTap: () => Navigator.of(context).pushNamed(route),
    );
  }

  /// [INFERRED] double-confirm destructive flow.
  Future<void> _confirmDelete(BuildContext context) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(careTr('care.deleteTitle')),
        content: Text(careTr('care.deleteBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(careTr('care.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: moneyColor(false)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(careTr('care.deleteData')),
          ),
        ],
      ),
    );
    if (first != true || !context.mounted) return;
    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(careTr('care.deleteFinalTitle')),
        content: Text(careTr('care.deleteFinalBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(careTr('care.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: moneyColor(false)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(careTr('care.yes')),
          ),
        ],
      ),
    );
    if (second != true || !context.mounted) return;
    await HiveService.resetAll();
    if (!context.mounted) return;
    HBToast.show(context,
        message: careTr('care.dataDeleted'),
        icon: Icons.delete_forever_outlined);
    Navigator.of(context)
        .pushNamedAndRemoveUntil(Routes.splash, (_) => false);
  }
}

/// [INFERRED] Recycle bin: archived parties with one-tap restore.
class _RecycleBinScreen extends StatefulWidget {
  const _RecycleBinScreen();

  @override
  State<_RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<_RecycleBinScreen> {
  List<Party> _archived() => HiveService.parties.values
      .where((p) => p.archived)
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  @override
  Widget build(BuildContext context) {
    final list = _archived();
    return Scaffold(
      appBar: HBAppBar(title: careTr('care.recycleBin')),
      body: list.isEmpty
          ? HBEmptyState(
              icon: Icons.delete_outline,
              title: careTr('care.noArchived'),
              subtitle: careTr('care.noArchivedSub'),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final p = list[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: HBColors.moneyOutSoft,
                      child: Text(
                        p.name.trim().isEmpty
                            ? '?'
                            : p.name.trim()[0].toUpperCase(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: HBColors.moneyOut),
                      ),
                    ),
                    title: Text(p.name,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: p.phone.isEmpty
                        ? null
                        : Text(p.phone),
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.restore_outlined, size: 18),
                      label: Text(careTr('care.restoreParty')),
                      onPressed: () async {
                        p.archived = false;
                        p.updatedAt = DateTime.now();
                        await HiveService.parties.put(p.id, p);
                        if (!context.mounted) return;
                        setState(() {});
                        HBToast.show(context,
                            message: careTr('care.partyRestored'),
                            icon: Icons.check_circle);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// [INFERRED] Help & FAQ: short original Q&A about the care features.
class _HelpScreen extends StatelessWidget {
  const _HelpScreen();

  @override
  Widget build(BuildContext context) {
    final faqs = [
      ('care.faq1q', 'care.faq1a'),
      ('care.faq2q', 'care.faq2a'),
      ('care.faq3q', 'care.faq3a'),
      ('care.faq4q', 'care.faq4a'),
      ('care.faq5q', 'care.faq5a'),
    ];
    return Scaffold(
      appBar: HBAppBar(title: careTr('care.helpFaq')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final f in faqs)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                title: Text(careTr(f.$1),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(careTr(f.$2),
                        style: const TextStyle(height: 1.5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
