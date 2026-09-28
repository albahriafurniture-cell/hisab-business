import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../l10n/bank_l10n.dart';
import '../l10n/strings.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/hb_actions.dart';
import '../widgets/hb_cards.dart';
import '../widgets/hb_chrome.dart';
import '../widgets/hb_rows.dart';

/// Bank Book: list of bank accounts with a total-balance summary band.
/// Follows the researched bank-tab pattern (logo avatar rows, masked
/// account number, last-transaction date, right balance) rewritten in our
/// own words and widgets.
class BankScreen extends StatelessWidget {
  const BankScreen({super.key});

  static const routeName = Routes.bank;

  String _masked(String accountNo) {
    final digits = accountNo.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '••••';
    final last4 = digits.length <= 4 ? digits : digits.substring(digits.length - 4);
    return '•••• $last4';
  }

  DateTime? _lastTxnDate(String accountId) {
    DateTime? last;
    for (final t in HiveService.bankTxns.values) {
      if (t.bankAccountId != accountId) continue;
      if (last == null || t.date.isAfter(last)) last = t.date;
    }
    return last;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, _, _) => Scaffold(
        appBar: HBAppBar(title: bankTr('bank.title')),
        floatingActionButton: HBFab(
          label: bankTr('bank.addBank'),
          icon: Icons.account_balance,
          onPressed: () => Navigator.of(context).pushNamed(Routes.bankAdd),
        ),
        body: ValueListenableBuilder<Box<BankAccount>>(
          valueListenable: HiveService.bankAccounts.listenable(),
          builder: (context, accountsBox, _) =>
              ValueListenableBuilder<Box<BankTxn>>(
            valueListenable: HiveService.bankTxns.listenable(),
            builder: (context, txnsBox, _) {
              final accounts = accountsBox.values.toList()
                ..sort((a, b) => a.bankName.compareTo(b.bankName));
              final total = accounts.fold<double>(
                  0, (s, a) => s + HiveService.bankBalance(a.id));
              final hide = HiveService.hideBalances;

              if (accounts.isEmpty) {
                return HBEmptyState(
                  icon: Icons.account_balance,
                  title: bankTr('bank.noBanks'),
                  subtitle: bankTr('bank.noBanksSub'),
                  ctaLabel: bankTr('bank.addBank'),
                  onCta: () =>
                      Navigator.of(context).pushNamed(Routes.bankAdd),
                );
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: HBSummaryCard(
                      stats: [
                        HBStat(bankTr('bank.totalBalance'),
                            hide ? '••••••' : formatPKR(total), true),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(top: 8, bottom: 96),
                      itemCount: accounts.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (context, i) {
                        final a = accounts[i];
                        final bal = HiveService.bankBalance(a.id);
                        final last = _lastTxnDate(a.id);
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        final initials = a.bankName.trim().isEmpty
                            ? '?'
                            : a.bankName
                                .trim()
                                .split(RegExp(r'\s+'))
                                .take(2)
                                .map((w) => w[0])
                                .join()
                                .toUpperCase();
                        return InkWell(
                          onTap: () => Navigator.of(context).pushNamed(
                            Routes.bankLedger,
                            arguments: {'bankAccountId': a.id},
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isDark
                                      ? HBColors.primarySoftDark
                                      : HBColors.primarySoft,
                                  child: Text(initials,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: HBColors.primary)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(a.bankName,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${a.title.isEmpty ? '' : '${a.title} • '}${_masked(a.accountNo)}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? HBColors.mutedDark
                                                : HBColors.muted),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        last == null
                                            ? bankTr('bank.never')
                                            : '${bankTr('bank.lastTxn')}: '
                                                '${last.day}/${last.month}/${last.year}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? HBColors.mutedDark
                                                : HBColors.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    HBAmountText(bal,
                                        isIn: bal >= 0,
                                        size: 16,
                                        hide: hide),
                                    const SizedBox(height: 2),
                                    Text(bankTr('bank.balance'),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? HBColors.mutedDark
                                                : HBColors.muted)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}