import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';

import '../data/hive_service.dart';
import '../data/models.dart';

/// Billing feature service: bill numbering, totals math, persistence
/// queries and PDF invoice generation. Pure logic — no widgets.
class BillingService {
  static const _billPrefix = 'HB-';
  static final _billNoRe = RegExp(r'^HB-(\d+)$');

  /// Next bill number in the `HB-0001` sequence (max existing + 1).
  static String nextBillNo() {
    var max = 0;
    for (final bill in HiveService.bills.values) {
      final match = _billNoRe.firstMatch(bill.billNo);
      if (match != null) {
        final n = int.tryParse(match.group(1)!) ?? 0;
        if (n > max) max = n;
      }
    }
    return '$_billPrefix${(max + 1).toString().padLeft(4, '0')}';
  }

  /// (subtotal, taxAmount, grandTotal).
  /// `taxPct` is a percentage of the subtotal; `discount` is a flat amount.
  /// Negative inputs are treated as zero; the grand total never goes below 0.
  static ({double subtotal, double taxAmount, double grandTotal}) computeTotals(
    List<BillItem> items,
    double taxPct,
    double discount,
  ) {
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.total);
    final taxAmount = subtotal * (taxPct < 0 ? 0 : taxPct) / 100;
    var grandTotal = subtotal + taxAmount - (discount < 0 ? 0 : discount);
    if (grandTotal < 0) grandTotal = 0;
    return (subtotal: subtotal, taxAmount: taxAmount, grandTotal: grandTotal);
  }

  /// Persist a new bill (status defaults to `due`) and return it.
  static Future<Bill> createBill({
    required List<BillItem> items,
    String partyId = '',
    DateTime? date,
    double taxPct = 0,
    double discount = 0,
    String note = '',
    String status = 'due',
  }) async {
    final totals = computeTotals(items, taxPct, discount);
    final now = DateTime.now();
    final bill = Bill(
      id: const Uuid().v4(),
      billNo: nextBillNo(),
      partyId: partyId,
      date: date ?? now,
      items: items,
      subtotal: totals.subtotal,
      taxPct: taxPct < 0 ? 0 : taxPct,
      discount: discount < 0 ? 0 : discount,
      grandTotal: totals.grandTotal,
      status: status,
      note: note,
      createdAt: now,
    );
    await HiveService.bills.put(bill.id, bill);
    return bill;
  }

  /// A single bill by id, or null.
  static Bill? getBill(String id) => HiveService.bills.get(id);

  /// All bills for a party, newest first.
  static List<Bill> billsForParty(String partyId) {
    final bills = HiveService.bills.values
        .where((b) => b.partyId == partyId)
        .toList(growable: false);
    bills.sort((a, b) => b.date.compareTo(a.date));
    return bills;
  }

  /// All bills, newest first.
  static List<Bill> allBills() {
    final bills = HiveService.bills.values.toList(growable: false);
    bills.sort((a, b) => b.date.compareTo(a.date));
    return bills;
  }

  /// Sum of grand totals for bills dated in the current calendar month.
  static double monthSalesTotal() {
    final now = DateTime.now();
    return HiveService.bills.values
        .where((b) => b.date.year == now.year && b.date.month == now.month)
        .fold<double>(0, (sum, b) => sum + b.grandTotal);
  }

  /// Update a bill's payment status (`paid` / `due` / `partial`).
  static Future<Bill?> updateBillStatus(String id, String status) async {
    final bill = getBill(id);
    if (bill == null) return null;
    bill.status = status;
    // Bill is a plain model (not a HiveObject), so persist via put().
    await HiveService.bills.put(bill.id, bill);
    return bill;
  }

  /// Delete a bill permanently.
  static Future<void> deleteBill(String id) =>
      HiveService.bills.delete(id);

  /// Party behind a bill, or null for walk-in bills.
  static Party? partyForBill(Bill bill) {
    if (bill.partyId.isEmpty) return null;
    return HiveService.parties.get(bill.partyId);
  }

  static const _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "Fri, 18 Mar 22 • 02:56 PM" — hand-rolled (no intl locale data needed,
  /// works offline everywhere, same approach as `formatPKR`).
  static String formatDateTime(DateTime d) {
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    final min = d.minute.toString().padLeft(2, '0');
    final yy = (d.year % 100).toString().padLeft(2, '0');
    return '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} $yy • $h12:$min $ampm';
  }

  /// "18 Mar 2026" — hand-rolled, no intl locale data needed.
  static String formatDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  /// Build an A4 invoice PDF for [bill] with an original Hisab Business
  /// layout. [accent] is an ARGB int used for the header band and accents.
  ///
  /// NOTE: the PDF is rendered in English only — the bundled PDF core fonts
  /// have no Urdu/Arabic glyphs.
  static Future<Uint8List> buildBillPdf(Bill bill,
      {int accent = 0xFFEB5E1C}) async {
    final doc = pw.Document();
    final accentColor = PdfColor.fromInt(accent);
    final accentSoft = PdfColor.fromInt(accent).shade(0.92);
    const ink = PdfColors.grey900;
    const muted = PdfColors.grey600;

    final business = HiveService.currentBusiness;
    final party = partyForBill(bill);
    final dateStr =
        '${bill.date.day} ${_monthName(bill.date.month)} ${bill.date.year}';
    final statusLabel = bill.status == 'paid' ? 'PAID' : 'DUE';

    pw.Widget label(String text) => pw.Text(text.toUpperCase(),
        style: pw.TextStyle(
            font: pw.Font.helveticaBold(), fontSize: 9, color: muted));

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // -- header band (original design) ---------------------------
            pw.Container(
              color: accentColor,
              padding: const pw.EdgeInsets.fromLTRB(36, 30, 36, 26),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('INVOICE',
                          style: pw.TextStyle(
                              font: pw.Font.helveticaBold(),
                              fontSize: 30,
                              color: PdfColors.white,
                              letterSpacing: 3)),
                      pw.SizedBox(height: 6),
                      pw.Text(
                          business?.name.isNotEmpty == true
                              ? business!.name
                              : 'Hisab Business',
                          style: pw.TextStyle(
                              font: pw.Font.helvetica(),
                              fontSize: 13,
                              color: PdfColors.white)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Receipt no  ${bill.billNo}',
                          style: pw.TextStyle(
                              font: pw.Font.helveticaBold(),
                              fontSize: 11,
                              color: PdfColors.white)),
                      pw.SizedBox(height: 4),
                      pw.Text(dateStr,
                          style: pw.TextStyle(
                              font: pw.Font.helvetica(),
                              fontSize: 11,
                              color: PdfColors.white)),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius:
                              pw.BorderRadius.circular(10),
                        ),
                        child: pw.Text(statusLabel,
                            style: pw.TextStyle(
                                font: pw.Font.helveticaBold(),
                                fontSize: 9,
                                color: accentColor)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(36, 20, 36, 0),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // -- bill-to ------------------------------------------------
                  label('Bill to'),
                  pw.SizedBox(height: 4),
                  pw.Text(party?.name ?? 'Walk-in customer',
                      style: pw.TextStyle(
                          font: pw.Font.helveticaBold(),
                          fontSize: 14,
                          color: ink)),
                  if (party != null && party.address.isNotEmpty)
                    pw.Text(party.address,
                        style: pw.TextStyle(
                            font: pw.Font.helvetica(),
                            fontSize: 10,
                            color: muted)),
                  if (party != null && party.phone.isNotEmpty)
                    pw.Text(party.phone,
                        style: pw.TextStyle(
                            font: pw.Font.helvetica(),
                            fontSize: 10,
                            color: muted)),
                  pw.SizedBox(height: 16),
                  // -- item table -------------------------------------------
                  pw.Table(
                    columnWidths: const {
                      0: pw.FlexColumnWidth(5),
                      1: pw.FlexColumnWidth(1.4),
                      2: pw.FlexColumnWidth(2),
                      3: pw.FlexColumnWidth(2.2),
                    },
                    border: pw.TableBorder(
                      horizontalInside: pw.BorderSide(
                          color: PdfColors.grey300, width: 0.5),
                    ),
                    children: [
                      pw.TableRow(
                        decoration:
                            pw.BoxDecoration(color: accentSoft),
                        children: [
                          for (final h in ['ITEM', 'QTY', 'RATE', 'TOTAL'])
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              child: pw.Text(h,
                                  style: pw.TextStyle(
                                      font: pw.Font.helveticaBold(),
                                      fontSize: 9,
                                      color: accentColor)),
                            ),
                        ],
                      ),
                      for (final item in bill.items)
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 7),
                              child: pw.Text(item.name,
                                  style: pw.TextStyle(
                                      font: pw.Font.helvetica(),
                                      fontSize: 10,
                                      color: ink)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 7),
                              child: pw.Text(_qtyStr(item.qty),
                                  style: pw.TextStyle(
                                      font: pw.Font.helvetica(),
                                      fontSize: 10,
                                      color: ink)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 7),
                              child: pw.Text(_money(item.rate),
                                  style: pw.TextStyle(
                                      font: pw.Font.helvetica(),
                                      fontSize: 10,
                                      color: ink)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 7),
                              child: pw.Text(_money(item.total),
                                  style: pw.TextStyle(
                                      font: pw.Font.helveticaBold(),
                                      fontSize: 10,
                                      color: ink)),
                            ),
                          ],
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  // -- totals ------------------------------------------------
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.SizedBox(
                        width: 220,
                        child: pw.Column(
                          children: [
                            _totalRow('Subtotal', _money(bill.subtotal),
                                ink, muted),
                            _totalRow(
                                'Tax (${_pctStr(bill.taxPct)})',
                                _money(bill.subtotal * bill.taxPct / 100),
                                ink,
                                muted),
                            _totalRow('Discount', _money(bill.discount),
                                ink, muted),
                            pw.Divider(
                                color: PdfColors.grey300, thickness: 0.5),
                            _totalRow('Grand total',
                                _money(bill.grandTotal), accentColor, ink,
                                bold: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (bill.note.isNotEmpty) ...[
                    pw.SizedBox(height: 12),
                    label('Note'),
                    pw.SizedBox(height: 4),
                    pw.Text(bill.note,
                        style: pw.TextStyle(
                            font: pw.Font.helvetica(),
                            fontSize: 10,
                            color: ink)),
                  ],
                  pw.SizedBox(height: 18),
                  // -- payment info + terms ----------------------------------
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment:
                              pw.CrossAxisAlignment.start,
                          children: [
                            label('Payment info'),
                            pw.SizedBox(height: 4),
                            pw.Text(
                                'Pay by cash or bank transfer. Share this invoice on WhatsApp to confirm your payment.',
                                style: pw.TextStyle(
                                    font: pw.Font.helvetica(),
                                    fontSize: 9,
                                    color: muted)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 24),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment:
                              pw.CrossAxisAlignment.start,
                          children: [
                            label('Terms'),
                            pw.SizedBox(height: 4),
                            pw.Text(
                                'Sold goods cannot be returned. Payment is due within 7 days unless agreed otherwise.',
                                style: pw.TextStyle(
                                    font: pw.Font.helvetica(),
                                    fontSize: 9,
                                    color: muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 44),
                  // -- signature ---------------------------------------------
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment:
                            pw.CrossAxisAlignment.center,
                        children: [
                          pw.Container(
                              width: 160,
                              height: 1,
                              color: PdfColors.grey500),
                          pw.SizedBox(height: 4),
                          pw.Text('Authorised signature',
                              style: pw.TextStyle(
                                  font: pw.Font.helvetica(),
                                  fontSize: 9,
                                  color: muted)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.Spacer(),
            // -- footer ------------------------------------------------------
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 10),
              child: pw.Center(
                child: pw.Text('Made with Hisab Business',
                    style: pw.TextStyle(
                        font: pw.Font.helvetica(),
                        fontSize: 8,
                        color: PdfColors.grey400)),
              ),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  /// A4 PDF listing [bills] as a simple sales report.
  static Future<Uint8List> buildBillsReportPdf(List<Bill> bills) async {
    final doc = pw.Document();
    const ink = PdfColors.grey900;
    const muted = PdfColors.grey600;
    final total = bills.fold<double>(0, (s, b) => s + b.grandTotal);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text('Bills report',
                style: pw.TextStyle(
                    font: pw.Font.helveticaBold(),
                    fontSize: 20,
                    color: ink)),
            pw.SizedBox(height: 4),
            pw.Text(
                '${bills.length} bills  •  Total ${_money(total)}',
                style: pw.TextStyle(
                    font: pw.Font.helvetica(),
                    fontSize: 11,
                    color: muted)),
            pw.SizedBox(height: 16),
            pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(2.4),
                2: pw.FlexColumnWidth(3),
                3: pw.FlexColumnWidth(2.2),
              },
              border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(
                      color: PdfColors.grey300, width: 0.5)),
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    for (final h in ['BILL NO', 'DATE', 'STATUS', 'TOTAL'])
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: pw.Text(h,
                            style: pw.TextStyle(
                                font: pw.Font.helveticaBold(),
                                fontSize: 9,
                                color: muted)),
                      ),
                  ],
                ),
                for (final b in bills)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: pw.Text(b.billNo,
                              style: pw.TextStyle(
                                  font: pw.Font.helvetica(),
                                  fontSize: 10,
                                  color: ink))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: pw.Text(
                              '${b.date.day} ${_monthName(b.date.month)} ${b.date.year}',
                              style: pw.TextStyle(
                                  font: pw.Font.helvetica(),
                                  fontSize: 10,
                                  color: ink))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: pw.Text(b.status.toUpperCase(),
                              style: pw.TextStyle(
                                  font: pw.Font.helvetica(),
                                  fontSize: 10,
                                  color: ink))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: pw.Text(_money(b.grandTotal),
                              style: pw.TextStyle(
                                  font: pw.Font.helveticaBold(),
                                  fontSize: 10,
                                  color: ink))),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }
}

pw.Widget _totalRow(
    String label, String value, PdfColor valueColor, PdfColor labelColor,
    {bool bold = false}) {
  final style = pw.TextStyle(
      font: bold ? pw.Font.helveticaBold() : pw.Font.helvetica(),
      fontSize: bold ? 12 : 10,
      color: valueColor);
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                font: pw.Font.helvetica(), fontSize: 10, color: labelColor)),
        pw.Text(value, style: style),
      ],
    ),
  );
}

String _money(double amount) {
  // Keep PDF text ASCII-safe: round to whole rupees.
  final n = amount.round();
  final digits = n.abs().toString();
  final buf = StringBuffer();
  var count = 0;
  for (var i = digits.length - 1; i >= 0; i--) {
    buf.write(digits[i]);
    count++;
    // Pakistani grouping: first group of 3, then groups of 2.
    final remaining = i;
    if (remaining > 0 && (count == 3 || (count > 3 && (count - 3) % 2 == 0))) {
      buf.write(',');
    }
  }
  final grouped = buf.toString().split('').reversed.join();
  return 'Rs ${n < 0 ? '-' : ''}$grouped';
}

String _qtyStr(double qty) =>
    qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();

String _pctStr(double pct) =>
    pct == pct.roundToDouble() ? pct.toInt().toString() : pct.toString();

String _monthName(int month) => const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ][month - 1];
