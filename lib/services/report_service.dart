import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/hive_service.dart';
import '../utils/app_paths.dart';

/// Builds PDF business reports from Hive data. All layout is original:
/// business-name header, plain data tables, totals, generated-at footer.
///
/// PDFs are rendered in English only: the built-in PDF fonts cannot render
/// Urdu script, so an embedded system font is used when one is available
/// (desktop/test hosts) and text falls back to ASCII-safe output otherwise.
// [INFERRED] layout: header band, tables, totals, footer.
class ReportService {
  ReportService._();

  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

  static pw.Font? _font;
  static bool _fontTried = false;

  /// Try to load a system TTF so non-Latin names (Urdu) print correctly.
  /// Silently falls back to the built-in font on devices without one.
  static Future<void> _ensureFont() async {
    if (_fontTried) return;
    _fontTried = true;
    const candidates = [
      '/usr/share/fonts/truetype/noto/NotoSansArabic-Regular.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
    ];
    for (final path in candidates) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          _font = pw.Font.ttf(ByteData.sublistView(bytes));
          return;
        }
      } catch (_) {
        // try next candidate
      }
    }
  }

  /// ASCII-safe fallback when no embeddable font is available.
  static String _t(String s) =>
      _font != null ? s : s.replaceAll(RegExp(r'[^\x20-\x7E]'), '?');

  static String _d(DateTime d) => _dateFmt.format(d);

  static bool _inRange(DateTime d, DateTime from, DateTime to) {
    final day = DateTime(d.year, d.month, d.day);
    final f = DateTime(from.year, from.month, from.day);
    final t = DateTime(to.year, to.month, to.day);
    return !day.isBefore(f) && !day.isAfter(t);
  }

  // ------------------------------------------------------------ scaffolding

  static pw.Widget _header(String title, String rangeLine) {
    final b = HiveService.currentBusiness;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          _t(b?.name.isNotEmpty == true ? b!.name : 'Hisab Business'),
          style: pw.TextStyle(
              font: _font, fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        if ((b?.phone ?? '').isNotEmpty)
          pw.Text(_t(b!.phone),
              style: pw.TextStyle(font: _font, fontSize: 10)),
        pw.SizedBox(height: 6),
        pw.Text(_t(title),
            style: pw.TextStyle(
                font: _font, fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Text(_t(rangeLine),
            style: pw.TextStyle(font: _font, fontSize: 11)),
        pw.Divider(thickness: 1.2),
      ],
    );
  }

  static pw.Widget _totals(List<pw.Widget> rows) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Divider(),
          ...rows,
        ],
      );

  static pw.Widget _totalLine(String label, String value,
      {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(_t(label),
              style: pw.TextStyle(
                  font: _font,
                  fontSize: 11,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(_t(value),
              style: pw.TextStyle(
                  font: _font,
                  fontSize: 11,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  static pw.Widget _table(List<String> headers, List<List<String>> data,
      {List<int>? flex}) {
    return pw.TableHelper.fromTextArray(
      headers: headers.map(_t).toList(),
      data: data.map((r) => r.map(_t).toList()).toList(),
      headerStyle:
          pw.TextStyle(font: _font, fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: pw.TextStyle(font: _font, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignments: {
        for (var i = 0; i < headers.length; i++)
          i: i == 0 ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
      },
      columnWidths: flex == null
          ? null
          : {for (var i = 0; i < flex.length; i++) i: pw.FlexColumnWidth(flex[i].toDouble())},
    );
  }

  static pw.PageTheme _pageTheme() => const pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(28),
      );

  static String _footerLine() =>
      'Generated on ${_dateTimeFmt.format(DateTime.now())} - Hisab Business';

  static Future<Uint8List> _finish(pw.Document doc) => doc.save();

  /// Writes [bytes] into the app's reports folder and returns the file path.
  /// On Android this is external storage (browsable + shareable); on other
  /// platforms (and as a fallback) the system temp dir is used.
  static Future<String> saveReport(Uint8List bytes, String fileName) async {
    Directory dir;
    try {
      dir = Platform.isAndroid
          ? await AppPaths.externalOrDocuments('reports')
          : await Directory.systemTemp.createTemp('hb_reports');
    } catch (_) {
      dir = await Directory.systemTemp.createTemp('hb_reports');
    }
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  // ------------------------------------------------------------------ party

  /// Party ledger: opening balance before [from], dated entries in range,
  /// totals and closing balance. Positive balance = they owe you.
  static Future<Uint8List> buildPartyLedgerPdf(
      String partyId, DateTime from, DateTime to) async {
    await _ensureFont();
    final party = HiveService.parties.get(partyId);
    final name = party?.name ?? 'Unknown party';

    final entries = HiveService.entriesForParty(partyId)
        .where((e) => _inRange(e.date, from, to))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    double opening = 0;
    for (final e in HiveService.entriesForParty(partyId)) {
      if (e.date.isBefore(DateTime(from.year, from.month, from.day))) {
        opening += e.direction == 'gave' ? e.amount : -e.amount;
      }
    }

    double gave = 0, got = 0;
    final rows = <List<String>>[];
    for (final e in entries) {
      if (e.direction == 'gave') {
        gave += e.amount;
      } else {
        got += e.amount;
      }
      rows.add([
        _d(e.date),
        e.detail.isEmpty ? '-' : e.detail,
        e.direction == 'gave' ? formatPKR(e.amount) : '',
        e.direction == 'got' ? formatPKR(e.amount) : '',
      ]);
    }
    final closing = opening + gave - got;

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageTheme: _pageTheme(),
      header: (_) => _header('Party Ledger - $name',
          '${_d(from)} to ${_d(to)}  |  Phone: ${party?.phone ?? '-'}'),
      footer: (_) => pw.Text(_footerLine(),
          style: pw.TextStyle(font: _font, fontSize: 9)),
      build: (_) => [
        _table(['Date', 'Detail', 'You Gave', 'You Got'], rows,
            flex: [2, 5, 2, 2]),
        pw.SizedBox(height: 8),
        _totals([
          _totalLine('Opening balance', formatPKR(opening)),
          _totalLine('Total you gave', formatPKR(gave)),
          _totalLine('Total you got', formatPKR(got)),
          _totalLine(
              'Closing balance (they owe you)',
              formatPKR(closing),
              bold: true,
              color: closing >= 0 ? PdfColors.red : PdfColors.green),
        ]),
      ],
    ));
    return _finish(doc);
  }

  // ------------------------------------------------------------------- cash

  /// Cash book: opening cash before [from], dated in/out entries, day totals.
  static Future<Uint8List> buildCashBookPdf(
      DateTime from, DateTime to) async {
    await _ensureFont();
    final f = DateTime(from.year, from.month, from.day);
    double opening = 0;
    final rows = <List<String>>[];
    double totalIn = 0, totalOut = 0;

    final entries = HiveService.cashEntries.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    for (final e in entries) {
      if (e.date.isBefore(f)) {
        opening += e.direction == 'in' ? e.amount : -e.amount;
      } else if (_inRange(e.date, from, to)) {
        if (e.direction == 'in') {
          totalIn += e.amount;
        } else {
          totalOut += e.amount;
        }
        rows.add([
          _d(e.date),
          e.detail.isEmpty ? (e.category.isEmpty ? '-' : e.category) : e.detail,
          e.direction == 'in' ? formatPKR(e.amount) : '',
          e.direction == 'out' ? formatPKR(e.amount) : '',
        ]);
      }
    }
    final closing = opening + totalIn - totalOut;

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageTheme: _pageTheme(),
      header: (_) =>
          _header('Cash Book', '${_d(from)} to ${_d(to)}'),
      footer: (_) => pw.Text(_footerLine(),
          style: pw.TextStyle(font: _font, fontSize: 9)),
      build: (_) => [
        _table(['Date', 'Detail', 'Cash In', 'Cash Out'], rows,
            flex: [2, 5, 2, 2]),
        pw.SizedBox(height: 8),
        _totals([
          _totalLine('Opening cash', formatPKR(opening)),
          _totalLine('Total cash in', formatPKR(totalIn)),
          _totalLine('Total cash out', formatPKR(totalOut)),
          _totalLine('Closing cash', formatPKR(closing),
              bold: true,
              color: closing >= 0 ? PdfColors.green : PdfColors.red),
        ]),
      ],
    ));
    return _finish(doc);
  }

  // ---------------------------------------------------------------- expense

  /// Expense report: entries in range grouped by category with grand total.
  static Future<Uint8List> buildExpensePdf(
      DateTime from, DateTime to) async {
    await _ensureFont();
    final catName = <String, String>{
      for (final c in HiveService.expenseCategories.values) c.id: c.name
    };
    final rows = <List<String>>[];
    final byCat = <String, double>{};
    double total = 0;

    final entries = HiveService.expenseEntries.values
        .where((e) => _inRange(e.date, from, to))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    for (final e in entries) {
      final cat = catName[e.categoryId] ?? 'Other';
      byCat[cat] = (byCat[cat] ?? 0) + e.amount;
      total += e.amount;
      rows.add([
        _d(e.date),
        cat,
        e.detail.isEmpty ? '-' : e.detail,
        formatPKR(e.amount),
      ]);
    }

    final summary = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageTheme: _pageTheme(),
      header: (_) =>
          _header('Expense Report', '${_d(from)} to ${_d(to)}'),
      footer: (_) => pw.Text(_footerLine(),
          style: pw.TextStyle(font: _font, fontSize: 9)),
      build: (_) => [
        _table(['Date', 'Category', 'Detail', 'Amount'], rows,
            flex: [2, 3, 5, 2]),
        pw.SizedBox(height: 10),
        pw.Text('By category',
            style: pw.TextStyle(
                font: _font, fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        _table(['Category', 'Amount'],
            summary.map((e) => [e.key, formatPKR(e.value)]).toList(),
            flex: [5, 2]),
        pw.SizedBox(height: 8),
        _totals([
          _totalLine('Total expenses', formatPKR(total),
              bold: true, color: PdfColors.red),
        ]),
      ],
    ));
    return _finish(doc);
  }

  // ------------------------------------------------------------------ stock

  /// Stock report: every item with in/out/balance qty and stock value.
  static Future<Uint8List> buildStockPdf() async {
    await _ensureFont();
    final rows = <List<String>>[];
    double totalValue = 0;

    final items = HiveService.stockItems.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final item in items) {
      final qty = HiveService.stockQty(item.id);
      final value = qty * item.buyPrice;
      totalValue += value;
      rows.add([
        item.name,
        item.unit,
        qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2),
        formatPKR(item.buyPrice),
        formatPKR(item.sellPrice),
        formatPKR(value),
      ]);
    }

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageTheme: _pageTheme(),
      header: (_) =>
          _header('Stock Report', 'As of ${_d(DateTime.now())}'),
      footer: (_) => pw.Text(_footerLine(),
          style: pw.TextStyle(font: _font, fontSize: 9)),
      build: (_) => [
        _table(['Item', 'Unit', 'Qty', 'Buy Price', 'Sell Price', 'Value'],
            rows,
            flex: [4, 2, 2, 2, 2, 2]),
        pw.SizedBox(height: 8),
        _totals([
          _totalLine('Items', '${items.length}'),
          _totalLine('Total stock value', formatPKR(totalValue), bold: true),
        ]),
      ],
    ));
    return _finish(doc);
  }

  // ------------------------------------------------------------------- bank

  /// Bank statement: opening balance before [from], dated transactions in
  /// range with running balance, totals and closing balance.
  static Future<Uint8List> buildBankStatementPdf(
      String accountId, DateTime from, DateTime to) async {
    await _ensureFont();
    final acct = HiveService.bankAccounts.get(accountId);
    final title =
        '${acct?.bankName ?? 'Bank'} - ${acct?.title ?? ''}'.trim();
    final f = DateTime(from.year, from.month, from.day);

    double opening = 0;
    final txns = HiveService.bankTxns.values
        .where((t) => t.bankAccountId == accountId)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final inRange = txns.where((t) => _inRange(t.date, from, to)).toList();
    for (final t in txns) {
      if (t.date.isBefore(f)) {
        opening += t.direction == 'deposit' ? t.amount : -t.amount;
      }
    }

    double running = opening, dep = 0, wd = 0;
    final rows = <List<String>>[];
    for (final t in inRange) {
      if (t.direction == 'deposit') {
        dep += t.amount;
        running += t.amount;
      } else {
        wd += t.amount;
        running -= t.amount;
      }
      rows.add([
        _d(t.date),
        t.detail.isEmpty ? '-' : t.detail,
        t.direction == 'deposit' ? formatPKR(t.amount) : '',
        t.direction == 'withdraw' ? formatPKR(t.amount) : '',
        formatPKR(running),
      ]);
    }

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageTheme: _pageTheme(),
      header: (_) => _header('Bank Statement - $title',
          '${_d(from)} to ${_d(to)}  |  A/C: ${acct?.accountNo ?? '-'}'),
      footer: (_) => pw.Text(_footerLine(),
          style: pw.TextStyle(font: _font, fontSize: 9)),
      build: (_) => [
        _table(
            ['Date', 'Detail', 'Deposit', 'Withdraw', 'Balance'], rows,
            flex: [2, 4, 2, 2, 2]),
        pw.SizedBox(height: 8),
        _totals([
          _totalLine('Opening balance', formatPKR(opening)),
          _totalLine('Total deposits', formatPKR(dep)),
          _totalLine('Total withdrawals', formatPKR(wd)),
          _totalLine('Closing balance', formatPKR(running),
              bold: true,
              color: running >= 0 ? PdfColors.green : PdfColors.red),
        ]),
      ],
    ));
    return _finish(doc);
  }

  // -------------------------------------------------------------------- pnl

  /// Profit & Loss (simple, [INFERRED]): total money-in minus total money-out
  /// over [from]..[to].
  ///   money-in  = cash in + khata got + bank deposits
  ///   money-out = cash out + khata gave + bank withdrawals + expenses
  static Future<Uint8List> buildPnlPdf(DateTime from, DateTime to) async {
    await _ensureFont();

    double cashIn = 0, cashOut = 0, khataGot = 0, khataGave = 0;
    double bankDep = 0, bankWd = 0, expenses = 0;

    for (final e in HiveService.cashEntries.values) {
      if (!_inRange(e.date, from, to)) continue;
      if (e.direction == 'in') {
        cashIn += e.amount;
      } else {
        cashOut += e.amount;
      }
    }
    for (final e in HiveService.khataEntries.values) {
      if (!_inRange(e.date, from, to)) continue;
      if (e.direction == 'got') {
        khataGot += e.amount;
      } else {
        khataGave += e.amount;
      }
    }
    for (final t in HiveService.bankTxns.values) {
      if (!_inRange(t.date, from, to)) continue;
      if (t.direction == 'deposit') {
        bankDep += t.amount;
      } else {
        bankWd += t.amount;
      }
    }
    for (final e in HiveService.expenseEntries.values) {
      if (!_inRange(e.date, from, to)) continue;
      expenses += e.amount;
    }

    final totalIn = cashIn + khataGot + bankDep;
    final totalOut = cashOut + khataGave + bankWd + expenses;
    final net = totalIn - totalOut;

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageTheme: _pageTheme(),
      header: (_) =>
          _header('Profit & Loss', '${_d(from)} to ${_d(to)}'),
      footer: (_) => pw.Text(_footerLine(),
          style: pw.TextStyle(font: _font, fontSize: 9)),
      build: (_) => [
        pw.Text('Money In',
            style: pw.TextStyle(
                font: _font, fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        _table(['Source', 'Amount'], [
          ['Cash in', formatPKR(cashIn)],
          ['Khata received', formatPKR(khataGot)],
          ['Bank deposits', formatPKR(bankDep)],
        ], flex: [5, 2]),
        pw.SizedBox(height: 10),
        pw.Text('Money Out',
            style: pw.TextStyle(
                font: _font, fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        _table(['Source', 'Amount'], [
          ['Cash out', formatPKR(cashOut)],
          ['Khata given', formatPKR(khataGave)],
          ['Bank withdrawals', formatPKR(bankWd)],
          ['Business expenses', formatPKR(expenses)],
        ], flex: [5, 2]),
        pw.SizedBox(height: 8),
        _totals([
          _totalLine('Total money in', formatPKR(totalIn),
              color: PdfColors.green),
          _totalLine('Total money out', formatPKR(totalOut),
              color: PdfColors.red),
          _totalLine(net >= 0 ? 'Net profit' : 'Net loss',
              formatPKR(net.abs()),
              bold: true,
              color: net >= 0 ? PdfColors.green : PdfColors.red),
        ]),
      ],
    ));
    return _finish(doc);
  }
}
