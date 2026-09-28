import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../l10n/billing_l10n.dart';
import '../l10n/strings.dart';
import '../routes.dart';
import '../services/billing_service.dart';
import '../theme.dart';
import '../widgets/hb_actions.dart';
import '../widgets/hb_cards.dart';
import '../widgets/hb_chrome.dart';
import '../widgets/hb_rows.dart';

/// Bill book: list of issued bills with month-sales summary, search,
/// status filter and a PDF report action.
///
/// Also used as the "Bills" bottom-tab body — keep the constructor
/// `const BillsScreen({super.key})` so the coordinator can wire it in.
class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  String _query = '';
  String _filter = 'all'; // all | paid | due | new

  /// [INFERRED] "New" = an unpaid bill created in the last 24h.
  bool _isNew(Bill bill) =>
      bill.status != 'paid' &&
      DateTime.now().difference(bill.createdAt).inHours < 24;

  String _pillKind(Bill bill) {
    if (bill.status == 'paid') return 'paid';
    return _isNew(bill) ? 'new' : 'due';
  }

  List<Bill> _filtered(List<Bill> bills) {
    final q = _query.trim().toLowerCase();
    return bills.where((b) {
      switch (_filter) {
        case 'paid':
          if (b.status != 'paid') return false;
        case 'due':
          if (b.status == 'paid' || _isNew(b)) return false;
        case 'new':
          if (!_isNew(b)) return false;
        default:
          break;
      }
      if (q.isEmpty) return true;
      final party = BillingService.partyForBill(b)?.name.toLowerCase() ?? '';
      return b.billNo.toLowerCase().contains(q) ||
          party.contains(q) ||
          b.note.toLowerCase().contains(q);
    }).toList();
  }

  int _seqOf(Bill bill) {
    final m = RegExp(r'^HB-(\d+)$').firstMatch(bill.billNo);
    return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
  }

  Future<void> _openFilterSheet() async {
    final options = [
      ('all', billingTr('billing.filterAll')),
      ('paid', billingTr('billing.filterPaid')),
      ('due', billingTr('billing.filterDue')),
      ('new', billingTr('billing.filterNew')),
    ];
    final picked = await showHBSheet<String>(
      context,
      title: billingTr('billing.filterStatus'),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (value, label) in options)
            HBChip(
              label: label,
              selected: _filter == value,
              onTap: () => Navigator.pop(context, value),
            ),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => _filter = picked);
  }

  Future<void> _sharePdfReport(List<Bill> bills) async {
    try {
      final bytes = await BillingService.buildBillsReportPdf(bills);
      final dir = await Directory.systemTemp.createTemp('hb_bills');
      final file = File('${dir.path}/bills-report.pdf');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: billingTr('billing.shareText'),
        ),
      );
    } catch (_) {
      if (mounted) {
        HBToast.show(context,
            message: billingTr('billing.pdfFailed'),
            icon: Icons.error_outline,
            tint: HBColors.primarySoft);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild on locale change so billingTr() picks up the new language.
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, lang, _) {
        return ValueListenableBuilder<Box<Bill>>(
          valueListenable: HiveService.bills.listenable(),
          builder: (context, box, _) {
            final all = BillingService.allBills();
            final bills = _filtered(all);
            return Scaffold(
              appBar: HBAppBar(title: billingTr('billing.book')),
              floatingActionButton: HBFab(
                label: billingTr('billing.createNew'),
                icon: Icons.add,
                onPressed: () =>
                    Navigator.pushNamed(context, Routes.billCreate),
              ),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: HBSummaryCard(
                      stats: [
                        HBStat(
                          billingTr('billing.salesThisMonth'),
                          formatPKR(BillingService.monthSalesTotal()),
                          true,
                        ),
                      ],
                      actionLabel: billingTr('billing.report'),
                      onAction: () =>
                          Navigator.pushNamed(context, Routes.reports),
                    ),
                  ),
                  HBSearchRow(
                    hint: billingTr('billing.searchHint'),
                    onChanged: (v) => setState(() => _query = v),
                    onFilter: _openFilterSheet,
                    onPdf: () => _sharePdfReport(bills),
                  ),
                  Expanded(
                    child: bills.isEmpty
                        ? HBEmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: billingTr('billing.emptyTitle'),
                            subtitle: billingTr('billing.emptySub'),
                            ctaLabel: billingTr('billing.createNew'),
                            onCta: () => Navigator.pushNamed(
                                context, Routes.billCreate),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 4, 16, 96),
                            itemCount: bills.length,
                            itemBuilder: (context, i) {
                              final bill = bills[i];
                              return _BillRow(
                                bill: bill,
                                seq: _seqOf(bill),
                                dateText: BillingService.formatDateTime(bill.date),
                                pillKind: _pillKind(bill),
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  Routes.billPreview,
                                  arguments: {'billId': bill.id},
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _BillRow extends StatelessWidget {
  final Bill bill;
  final int seq;
  final String dateText;
  final String pillKind; // paid | due | new
  final VoidCallback onTap;

  const _BillRow({
    required this.bill,
    required this.seq,
    required this.dateText,
    required this.pillKind,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (pillLabel, pillBg, pillFg) = switch (pillKind) {
      'paid' => (
          billingTr('billing.statusPaid'),
          const Color(0xFFE2F5E9),
          const Color(0xFF127A3C),
        ),
      'new' => (
          billingTr('billing.statusNew'),
          const Color(0xFFE3EDFF),
          const Color(0xFF1D4ED8),
        ),
      _ => (
          billingTr('billing.statusDue'),
          const Color(0xFFFDE5E3),
          const Color(0xFFB3261E),
        ),
    };
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? HBColors.cardDark : HBColors.card,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: HBColors.primarySoft,
                child: Text(
                  seq > 0 ? '$seq' : '#',
                  style: const TextStyle(
                    color: HBColors.primaryDeep,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${billingTr('billing.billPrefix')}${seq > 0 ? seq : bill.billNo}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateText • ${billingItemsLabel(bill.items.length)}',
                      style: const TextStyle(
                          fontSize: 12, color: HBColors.muted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // A bill is a receivable (they owe you) -> red per
                  // money-direction semantics.
                  HBAmountText(bill.grandTotal, isIn: false, size: 15),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      pillLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: pillFg),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
