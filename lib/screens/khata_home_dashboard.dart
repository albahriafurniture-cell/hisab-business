import 'package:flutter/material.dart';

import '../data/hive_service.dart';
import '../l10n/khata_l10n.dart';
import '../l10n/strings.dart';
import '../routes.dart';
import '../services/khata_service.dart';
import '../theme.dart';
import '../widgets/hb_cards.dart';

/// Home-tab dashboard for the khata module.
///
/// Constructor: `const HomeDashboard({super.key})`.
/// The coordinator wires this into HomeShell's Home tab — this file only
/// defines the widget. Hero banner + KHATA module tile grid + give/get
/// summary card, all original copy.
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  void _go(BuildContext context, String route) {
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, lang, _) {
        final gaveGot = KhataService.gaveGot();
        final hide = HiveService.hideBalances;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heroCard(context),
              const SizedBox(height: 16),
              HBSectionLabel(khataTr('khata.khata')),
              const SizedBox(height: 8),
              _moduleGrid(context),
              const SizedBox(height: 16),
              HBSummaryCard(
                stats: [
                  HBStat(
                    khataTr('khata.totalGave'),
                    hide ? '••••••' : formatPKR(gaveGot['gave']!),
                    false, // gave → red
                  ),
                  HBStat(
                    khataTr('khata.totalGot'),
                    hide ? '••••••' : formatPKR(gaveGot['got']!),
                    true, // got → green
                  ),
                ],
                actionLabel: khataTr('khata.viewReport'),
                onAction: () => _go(context, Routes.reports),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _heroCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [HBColors.gradientTop, HBColors.gradientBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  khataTr('khata.heroTitle'),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  khataTr('khata.heroSub'),
                  style: const TextStyle(
                      fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () => _go(context, Routes.parties),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      khataTr('khata.viewParties'),
                      style: const TextStyle(
                          color: HBColors.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.account_balance_wallet,
              size: 72, color: Colors.white54),
        ],
      ),
    );
  }

  Widget _moduleGrid(BuildContext context) {
    final tiles = [
      (Icons.people_alt, khataTr('khata.party'), Routes.parties),
      (Icons.account_balance_wallet, khataTr('khata.cash'), Routes.cash),
      (Icons.inventory_2, khataTr('khata.stock'), Routes.stock),
      (Icons.receipt_long, khataTr('khata.bills'), Routes.bills),
      (Icons.badge, khataTr('khata.staff'), Routes.staff),
      (Icons.payments, khataTr('khata.expense'), Routes.expense),
    ];
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      color: isDark ? HBColors.cardDark : HBColors.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final t in tiles)
              HBModuleTile(
                icon: t.$1,
                label: t.$2,
                onTap: () => _go(context, t.$3),
              ),
          ],
        ),
      ),
    );
  }
}
