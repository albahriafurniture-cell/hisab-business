import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../l10n/billing_l10n.dart';
import '../l10n/strings.dart';
import '../services/billing_service.dart';
import '../theme.dart';
import '../widgets/hb_actions.dart';
import '../widgets/hb_cards.dart';
import '../widgets/hb_chrome.dart';
import '../widgets/hb_rows.dart';

/// Invoice preview for a bill (route arguments: `{'billId': id}`).
///
/// ORIGINAL invoice design [INFERRED]: tandoor-orange header band with
/// "INVOICE", receipt no, invoice date, bill-to block, ITEM/QTY/RATE/TOTAL
/// table, totals, payment-info + terms blocks (fresh wording), signature
/// line. Accent swatches re-theme the header; share row offers WhatsApp
/// text, PDF file and print-via-share.
class BillPreviewScreen extends StatefulWidget {
  const BillPreviewScreen({super.key});

  @override
  State<BillPreviewScreen> createState() => _BillPreviewScreenState();
}

class _BillPreviewScreenState extends State<BillPreviewScreen> {
  /// [INFERRED] original accent palette for the invoice header.
  static const _accents = [
    0xFFEB5E1C, // tandoor orange (default)
    0xFF0F766E, // deep teal
    0xFF6D28D9, // plum indigo
    0xFF166534, // forest green
  ];

  int _accent = _accents[0];
  bool _busy = false;

  String? _billId(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final id = args['billId'];
      if (id is String && id.isNotEmpty) return id;
    }
    return null;
  }

  Future<void> _setStatus(Bill bill, String status) async {
    await BillingService.updateBillStatus(bill.id, status);
    if (mounted) setState(() {});
  }

  String _whatsAppText(Bill bill, Party? party) {
    final dateStr = BillingService.formatDate(bill.date);
    final business = HiveService.currentBusiness?.name ?? 'Hisab Business';
    final lines = [
      '*${billingTr('billing.invoice')} ${bill.billNo}*',
      business,
      '${billingTr('billing.invoiceDate')}: $dateStr',
      '${billingTr('billing.billTo')}: ${party?.name ?? billingTr('billing.walkIn')}',
      '${billingTr('billing.items')}: ${bill.items.length}',
      '${billingTr('billing.grandTotal')}: ${formatPKR(bill.grandTotal)}',
      billingTr(bill.status == 'paid'
          ? 'billing.statusPaid'
          : 'billing.statusDue'),
    ];
    return lines.join('\n');
  }

  Future<void> _shareWhatsApp(Bill bill) async {
    final party = BillingService.partyForBill(bill);
    await SharePlus.instance.share(ShareParams(
      text: _whatsAppText(bill, party),
      subject: '${billingTr('billing.invoice')} ${bill.billNo}',
    ));
  }

  Future<File?> _pdfFile(Bill bill) async {
    try {
      final bytes =
          await BillingService.buildBillPdf(bill, accent: _accent);
      final dir = await Directory.systemTemp.createTemp('hb_invoice');
      final safeNo = bill.billNo.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final file = File('${dir.path}/invoice-$safeNo.pdf');
      await file.writeAsBytes(bytes);
      return file;
    } catch (_) {
      return null;
    }
  }

  Future<void> _sharePdf(Bill bill) async {
    setState(() => _busy = true);
    final file = await _pdfFile(bill);
    if (!mounted) return;
    setState(() => _busy = false);
    if (file == null) {
      HBToast.show(context,
          message: billingTr('billing.pdfFailed'),
          icon: Icons.error_outline,
          tint: HBColors.primarySoft);
      return;
    }
    HBToast.show(context,
        message: billingTr('billing.pdfShared'),
        icon: Icons.picture_as_pdf);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      text:
          '${billingTr('billing.invoice')} ${bill.billNo} — ${billingTr('billing.shareText')}',
    ));
  }

  /// share_plus has no direct print API: share the PDF so the user can
  /// print it from any print-capable app.
  Future<void> _print(Bill bill) async {
    setState(() => _busy = true);
    final file = await _pdfFile(bill);
    if (!mounted) return;
    setState(() => _busy = false);
    if (file == null) {
      HBToast.show(context,
          message: billingTr('billing.pdfFailed'),
          icon: Icons.error_outline,
          tint: HBColors.primarySoft);
      return;
    }
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      text: '${billingTr('billing.print')} — ${bill.billNo}',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, lang, _) {
        final billId = _billId(context);
        return ValueListenableBuilder<Box<Bill>>(
          valueListenable: HiveService.bills.listenable(),
          builder: (context, box, _) {
            final bill =
                billId == null ? null : box.get(billId);
            if (bill == null) {
              return Scaffold(
                appBar:
                    HBAppBar(title: billingTr('billing.invoice')),
                body: HBEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: billingTr('billing.emptyTitle'),
                  subtitle: billingTr('billing.emptySub'),
                  ctaLabel: billingTr('billing.createNew'),
                  onCta: () => Navigator.pop(context),
                ),
              );
            }
            return _buildPreview(context, bill);
          },
        );
      },
    );
  }

  Widget _buildPreview(BuildContext context, Bill bill) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final dateStr = BillingService.formatDate(bill.date);
    final party = BillingService.partyForBill(bill);
    final accent = Color(_accent);
    final isPaid = bill.status == 'paid';

    return Scaffold(
      appBar: HBAppBar(
          title:
              '${billingTr('billing.invoice')} ${bill.billNo}'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ------------------------------------------------ invoice card
          Card(
            elevation: 2,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            color: isDark ? HBColors.cardDark : HBColors.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // header band
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        billingTr('billing.invoice'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${billingTr('billing.receiptNo')}: ${bill.billNo}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${billingTr('billing.invoiceDate')}: $dateStr',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      // bill-to
                      Text(billingTr('billing.billTo').toUpperCase(),
                          style: const TextStyle(
                              fontSize: 11,
                              color: HBColors.muted,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 4),
                      Text(
                        party?.name ??
                            billingTr('billing.walkIn'),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      if (party != null &&
                          party.address.isNotEmpty)
                        Text(party.address,
                            style: const TextStyle(
                                fontSize: 12,
                                color: HBColors.muted)),
                      if (party != null &&
                          party.phone.isNotEmpty)
                        Text(party.phone,
                            style: const TextStyle(
                                fontSize: 12,
                                color: HBColors.muted)),
                      const SizedBox(height: 16),
                      // item table
                      _TableHeader(accent: accent),
                      for (final item in bill.items)
                        _TableRow(item: item),
                      const SizedBox(height: 12),
                      // totals
                      _TotalLine(
                          billingTr('billing.subtotal'),
                          formatPKR(bill.subtotal)),
                      _TotalLine(
                          '${billingTr('billing.taxPct')} (${_pct(bill.taxPct)})',
                          formatPKR(
                              bill.subtotal * bill.taxPct / 100)),
                      _TotalLine(billingTr('billing.discount'),
                          formatPKR(bill.discount)),
                      const Divider(height: 18),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(billingTr('billing.grandTotal'),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Text(formatPKR(bill.grandTotal),
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: accent)),
                        ],
                      ),
                      if (bill.note.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(billingTr('billing.note').toUpperCase(),
                            style: const TextStyle(
                                fontSize: 11,
                                color: HBColors.muted,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 2),
                        Text(bill.note,
                            style:
                                const TextStyle(fontSize: 13)),
                      ],
                      const SizedBox(height: 16),
                      // payment info + terms
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _InfoBlock(
                              title: billingTr(
                                  'billing.paymentInfo'),
                              body: billingTr(
                                  'billing.paymentInfoBody'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _InfoBlock(
                              title:
                                  billingTr('billing.terms'),
                              body: billingTr(
                                  'billing.termsBody'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),
                      // signature line
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.end,
                        children: [
                          Column(
                            children: [
                              Container(
                                  width: 150,
                                  height: 1,
                                  color: HBColors.muted),
                              const SizedBox(height: 4),
                              Text(
                                  billingTr(
                                      'billing.signature'),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: HBColors.muted)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ------------------------------------------------ colour theme
          HBSectionLabel(billingTr('billing.theme')),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final c in _accents)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () =>
                        setState(() => _accent = c),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _accent == c
                              ? HBColors.ink
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: _accent == c
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // ------------------------------------------------ paid/due toggle
          Center(
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'paid',
                  label: Text(billingTr('billing.markPaid')),
                  icon: const Icon(Icons.check_circle_outline,
                      size: 18),
                ),
                ButtonSegment(
                  value: 'due',
                  label: Text(billingTr('billing.markDue')),
                  icon: const Icon(Icons.schedule_outlined,
                      size: 18),
                ),
              ],
              selected: {isPaid ? 'paid' : 'due'},
              onSelectionChanged: (s) =>
                  _setStatus(bill, s.first),
            ),
          ),
          const SizedBox(height: 16),
          // ------------------------------------------------ share row
          Row(
            children: [
              Expanded(
                child: HBPillButton(
                  label: billingTr('billing.whatsapp'),
                  icon: Icons.chat_outlined,
                  outlined: true,
                  color: const Color(0xFF1FA855),
                  onPressed:
                      _busy ? null : () => _shareWhatsApp(bill),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HBPillButton(
                  label: billingTr('billing.pdf'),
                  icon: Icons.picture_as_pdf_outlined,
                  outlined: true,
                  onPressed:
                      _busy ? null : () => _sharePdf(bill),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HBPillButton(
                  label: billingTr('billing.print'),
                  icon: Icons.print_outlined,
                  outlined: true,
                  onPressed:
                      _busy ? null : () => _print(bill),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _pct(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _TableHeader extends StatelessWidget {
  final Color accent;

  const _TableHeader({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 5,
              child: Text(billingTr('billing.itemName').toUpperCase(),
                  style: _headStyle(accent))),
          Expanded(
              flex: 2,
              child: Text(billingTr('billing.qty').toUpperCase(),
                  style: _headStyle(accent),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 3,
              child: Text(billingTr('billing.rate').toUpperCase(),
                  style: _headStyle(accent),
                  textAlign: TextAlign.right)),
          Expanded(
              flex: 3,
              child: Text(billingTr('billing.total').toUpperCase(),
                  style: _headStyle(accent),
                  textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  TextStyle _headStyle(Color accent) => TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: accent,
      letterSpacing: 0.8);
}

class _TableRow extends StatelessWidget {
  final BillItem item;

  const _TableRow({required this.item});

  String _num(double v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toString();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Colors.black12, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 5,
              child: Text(item.name,
                  style: const TextStyle(fontSize: 13))),
          Expanded(
              flex: 2,
              child: Text(_num(item.qty),
                  style: const TextStyle(fontSize: 13),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 3,
              child: Text(formatPKR(item.rate),
                  style: const TextStyle(fontSize: 13),
                  textAlign: TextAlign.right)),
          Expanded(
              flex: 3,
              child: Text(formatPKR(item.total),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  final String label;
  final String value;

  const _TotalLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: HBColors.muted)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String title;
  final String body;

  const _InfoBlock({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                color: HBColors.muted,
                letterSpacing: 1.2)),
        const SizedBox(height: 4),
        Text(body,
            style: const TextStyle(
                fontSize: 11, color: HBColors.muted, height: 1.4)),
      ],
    );
  }
}
