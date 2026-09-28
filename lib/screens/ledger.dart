import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../l10n/khata_l10n.dart';
import '../l10n/strings.dart';
import '../routes.dart';
import '../services/khata_service.dart';
import '../theme.dart';
import '../widgets/hb_actions.dart';
import '../widgets/hb_cards.dart';
import '../widgets/hb_chrome.dart';
import '../widgets/hb_rows.dart';

/// Party ledger detail (route [Routes.ledger], arguments `{'partyId': id}`).
///
/// Header with avatar/name/phone + call/SMS/WhatsApp actions, a
/// gave/got summary band, searchable entry list, footer totals, and a
/// sticky YOU GAVE / YOU GOT bottom bar.
class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  String _query = '';

  String? _partyId() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) return args['partyId'] as String?;
    return null;
  }

  Future<void> _goTxn(String direction, String partyId) async {
    await Navigator.of(context).pushNamed(
      Routes.transactionAdd,
      arguments: {'partyId': partyId, 'direction': direction},
    );
    if (mounted) setState(() {});
  }

  Future<void> _contact(String mode, String phone) async {
    final number = phone.trim();
    if (number.isEmpty) {
      HBToast.show(context,
          message: khataTr('khata.noPhone'), icon: Icons.phone_disabled);
      return;
    }
    Uri uri;
    if (mode == 'wa') {
      final digits = number.replaceAll(RegExp(r'\D'), '');
      uri = Uri.parse('https://wa.me/$digits');
    } else {
      uri = Uri(scheme: mode, path: number);
    }
    try {
      final ok = await launchUrl(uri,
          mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        HBToast.show(context,
            message: khataTr('khata.cantOpen'),
            icon: Icons.error_outline);
      }
    } catch (_) {
      if (mounted) {
        HBToast.show(context,
            message: khataTr('khata.cantOpen'),
            icon: Icons.error_outline);
      }
    }
  }

  // [INFERRED] long-press delete — research shows no entry-delete UI.
  Future<void> _deleteEntry(KhataEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(khataTr('khata.deleteEntry')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(tr(c, 'action.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(tr(c, 'action.delete'),
                style:
                    const TextStyle(color: HBColors.moneyOut)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await KhataService.deleteEntry(entry.id);
      if (mounted) {
        HBToast.show(context,
            message: tr(context, 'msg.deleted'),
            icon: Icons.delete_outline);
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, lang, _) {
        final party = HiveService.parties.get(_partyId() ?? '');
        if (party == null) {
          return Scaffold(
            appBar: HBAppBar(title: khataTr('khata.ledger')),
            body: HBEmptyState(
              icon: Icons.person_off_outlined,
              title: khataTr('khata.noParties'),
              subtitle: khataTr('khata.noPartiesHint'),
            ),
          );
        }

        final all = KhataService.entriesForParty(party.id);
        double gave = 0;
        double got = 0;
        for (final e in all) {
          if (e.direction == 'gave') {
            gave += e.amount;
          } else {
            got += e.amount;
          }
        }
        final balance = KhataService.balanceForParty(party.id);
        final entries = _query.isEmpty
            ? all
            : all
                .where((e) => e.detail
                    .toLowerCase()
                    .contains(_query.toLowerCase()))
                .toList();
        final hide = HiveService.hideBalances;
        final isDark =
            Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: HBAppBar(title: party.name),
          body: Column(
            children: [
              _headerCard(party, isDark),
              _summaryBand(
                  gave, got, balance, hide, isDark),
              HBSearchRow(
                hint: khataTr('khata.searchEntries'),
                onChanged: (q) => setState(() => _query = q),
              ),
              Expanded(
                child: entries.isEmpty
                    ? HBEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: khataTr('khata.noEntries'),
                        subtitle: khataTr('khata.noEntriesHint'),
                      )
                    : ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: isDark
                              ? HBColors.hairlineDark
                              : HBColors.hairline,
                        ),
                        itemBuilder: (_, i) =>
                            _entryRow(entries[i], isDark),
                      ),
              ),
              _footerTotals(gave, got, balance, hide, isDark),
            ],
          ),
          bottomNavigationBar: HBStickyBottomBar(
            outLabel: khataTr('khata.youGave'),
            inLabel: khataTr('khata.youGot'),
            onOut: () => _goTxn('gave', party.id),
            onIn: () => _goTxn('got', party.id),
          ),
        );
      },
    );
  }

  Widget _headerCard(Party party, bool isDark) {
    final initials = party.name.trim().isEmpty
        ? '?'
        : party.name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w[0])
            .join()
            .toUpperCase();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? HBColors.cardDark : HBColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: isDark
                ? HBColors.primarySoftDark
                : HBColors.primarySoft,
            child: Text(initials,
                style: const TextStyle(
                    color: HBColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(party.name,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                if (party.phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(party.phone,
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? HBColors.mutedDark
                              : HBColors.muted)),
                ],
              ],
            ),
          ),
          _contactButton(Icons.call, khataTr('khata.call'),
              () => _contact('tel', party.phone)),
          _contactButton(Icons.sms, khataTr('khata.sms'),
              () => _contact('sms', party.phone)),
          _contactButton(Icons.chat_bubble_outline,
              khataTr('khata.whatsapp'),
              () => _contact('wa', party.phone)),
        ],
      ),
    );
  }

  Widget _contactButton(
      IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 22),
      color: HBColors.primary,
      tooltip: tooltip,
      onPressed: onTap,
    );
  }

  /// Gave/got summary band per PROJECT_STATUS money semantics:
  /// green = money you will give (payable), red = money you will get.
  Widget _summaryBand(
      double gave, double got, double balance, bool hide, bool isDark) {
    final payable = balance < 0 ? -balance : 0.0;
    final receivable = balance > 0 ? balance : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: HBSummaryCard(
        stats: [
          HBStat(
            khataTr('khata.youWillGive'),
            hide ? '••••••' : formatPKR(payable),
            true, // green
          ),
          HBStat(
            khataTr('khata.youWillGet'),
            hide ? '••••••' : formatPKR(receivable),
            false, // red
          ),
        ],
        actionLabel: khataTr('khata.viewReport'),
        onAction: () =>
            Navigator.of(context).pushNamed(Routes.reports),
      ),
    );
  }

  Widget _entryRow(KhataEntry e, bool isDark) {
    final isGave = e.direction == 'gave';
    return InkWell(
      onLongPress: () => _deleteEntry(e),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM d, y · h:mm a')
                        .format(e.date),
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? HBColors.mutedDark
                            : HBColors.muted),
                  ),
                  if (e.detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(e.detail,
                        style: const TextStyle(fontSize: 15)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatPKR(e.amount),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: moneyColor(!isGave,
                          isDark: isDark)),
                ),
                const SizedBox(height: 2),
                Text(
                  isGave
                      ? khataTr('khata.gave')
                      : khataTr('khata.got'),
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? HBColors.mutedDark
                          : HBColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerTotals(double gave, double got, double balance,
      bool hide, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? HBColors.cardDark : HBColors.card,
        border: Border(
          top: BorderSide(
              color: isDark
                  ? HBColors.hairlineDark
                  : HBColors.hairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(
              child: _footTotal(khataTr('khata.totalGave'), gave,
                  false, hide, isDark)),
          Expanded(
              child: _footTotal(khataTr('khata.totalGot'), got,
                  true, hide, isDark)),
          Expanded(
              child: _footTotal(
                  khataTr('khata.netBalance'),
                  balance.abs(),
                  !isReceivable(balance),
                  hide,
                  isDark)),
        ],
      ),
    );
  }

  Widget _footTotal(
      String label, double value, bool isIn, bool hide, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color:
                    isDark ? HBColors.mutedDark : HBColors.muted)),
        const SizedBox(height: 2),
        Text(
          hide ? '••••••' : formatPKR(value),
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: moneyColor(isIn, isDark: isDark)),
        ),
      ],
    );
  }
}
