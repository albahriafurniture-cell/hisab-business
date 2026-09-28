import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/hive_service.dart';
import '../l10n/khata_l10n.dart';
import '../l10n/strings.dart';
import '../routes.dart';
import '../services/khata_service.dart';
import '../theme.dart';
import '../widgets/hb_actions.dart';
import '../widgets/hb_chrome.dart';
import '../widgets/hb_rows.dart';

/// Party list screen (route [Routes.parties]).
///
/// Tabs: Customers / Suppliers / Banks (→ bank screen) / All.
/// Summary strip with hide-balance toggle + payable/receivable totals,
/// live search, A–Z/Z–A sort, and a pill FAB to add a party.
class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  int _tab = 0; // 0 customers · 1 suppliers · 2 banks (→ bank) · 3 all
  String _query = '';
  bool _sortAsc = true;

  String? get _kind =>
      _tab == 0 ? 'customer' : _tab == 1 ? 'supplier' : null;

  Future<void> _go(String route, {Object? arguments}) async {
    await Navigator.of(context)
        .pushNamed(route, arguments: arguments);
    if (mounted) setState(() {});
  }

  void _onTab(int i) {
    if (i == 2) {
      // [INFERRED] Banks tab is a shortcut to the bank book.
      _go(Routes.bank);
      return;
    }
    setState(() => _tab = i);
  }

  // [INFERRED] sort sheet — research only shows a filter icon.
  void _showSortSheet() {
    showHBSheet<void>(
      context,
      title: khataTr('khata.sortTitle'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.arrow_upward),
            title: Text(khataTr('khata.sortAZ')),
            trailing: _sortAsc
                ? const Icon(Icons.check, color: HBColors.primary)
                : null,
            onTap: () {
              setState(() => _sortAsc = true);
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.arrow_downward),
            title: Text(khataTr('khata.sortZA')),
            trailing: !_sortAsc
                ? const Icon(Icons.check, color: HBColors.primary)
                : null,
            onTap: () {
              setState(() => _sortAsc = false);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, lang, _) {
        final hide = HiveService.hideBalances;
        final totals = KhataService.totals();
        final list = KhataService.searchParties(_query, kind: _kind)
          ..sort((a, b) => _sortAsc
              ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
              : b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        final isDark =
            Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: HBAppBar(
            title: khataTr('khata.party'),
            actions: [_collectionPill()],
          ),
          body: Column(
            children: [
              HBTabs(
                labels: [
                  khataTr('khata.customers'),
                  khataTr('khata.suppliers'),
                  khataTr('khata.banks'),
                  khataTr('khata.all'),
                ],
                index: _tab,
                onChanged: _onTab,
              ),
              _summaryStrip(hide, totals, isDark),
              HBSearchRow(
                hint: '${list.length} ${khataTr('khata.parties')}',
                onChanged: (q) => setState(() => _query = q),
                onFilter: _showSortSheet,
                onPdf: () => _go(Routes.reports),
              ),
              Expanded(
                child: list.isEmpty
                    ? HBEmptyState(
                        icon: Icons.people_outline,
                        title: khataTr('khata.noParties'),
                        subtitle: khataTr('khata.noPartiesHint'),
                        ctaLabel: khataTr('khata.addParty'),
                        onCta: () => _go(Routes.partyAdd),
                      )
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          indent: 72,
                          color: isDark
                              ? HBColors.hairlineDark
                              : HBColors.hairline,
                        ),
                        itemBuilder: (_, i) {
                          final p = list[i];
                          final bal =
                              KhataService.balanceForParty(p.id);
                          final receivable = isReceivable(bal);
                          final last = KhataService.lastEntryDate(p.id);
                          final status = bal > 0
                              ? khataTr('khata.youWillGet')
                              : bal < 0
                                  ? khataTr('khata.youWillGive')
                                  : khataTr('khata.settled');
                          return HBLedgerRow(
                            name: p.name,
                            subtitle: last == null
                                ? khataTr('khata.noEntries')
                                : DateFormat('MMM d, y').format(last),
                            amount: bal.abs(),
                            isIn: !receivable,
                            status: status,
                            hideAmount: hide,
                            onTap: () => _go(Routes.ledger,
                                arguments: {'partyId': p.id}),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: HBFab(
            label: khataTr('khata.add'),
            icon: Icons.add,
            onPressed: () => _go(Routes.partyAdd),
          ),
        );
      },
    );
  }

  /// White pill "COLLECTION" button → reminders.
  Widget _collectionPill() {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Center(
        child: InkWell(
          onTap: () => _go(Routes.reminders),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notifications,
                    size: 16, color: HBColors.primary),
                const SizedBox(width: 4),
                Text(
                  khataTr('khata.collection'),
                  style: const TextStyle(
                      color: HBColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryStrip(
      bool hide, Map<String, double> totals, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () async {
              await HiveService.setHideBalances(!hide);
              if (mounted) setState(() {});
            },
            child: Text(
              hide
                  ? khataTr('khata.showBalance')
                  : khataTr('khata.hideBalance'),
              style: const TextStyle(
                  color: HBColors.moneyOut,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: () => _go(Routes.reports),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: _summaryAmount(
                      khataTr('khata.payables'),
                      totals['payables']!,
                      true, // you owe → green
                      hide,
                      isDark,
                    ),
                  ),
                  Expanded(
                    child: _summaryAmount(
                      khataTr('khata.receivables'),
                      totals['receivables']!,
                      false, // they owe you → red
                      hide,
                      isDark,
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: HBColors.muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryAmount(
      String label, double value, bool isIn, bool hide, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color:
                    isDark ? HBColors.mutedDark : HBColors.muted)),
        const SizedBox(height: 2),
        Text(
          hide ? '••••••' : formatPKR(value),
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: moneyColor(isIn, isDark: isDark)),
        ),
      ],
    );
  }
}
