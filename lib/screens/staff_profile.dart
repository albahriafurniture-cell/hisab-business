import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../l10n/staff_l10n.dart';
import '../l10n/strings.dart';
import '../routes.dart';
import '../services/staff_service.dart';
import '../theme.dart';
import '../widgets/hb_actions.dart';
import '../widgets/hb_cards.dart';
import '../widgets/hb_chrome.dart';
import '../widgets/hb_rows.dart';
import 'staff.dart' show StaffAvatar;

/// Staff profile: attendance history, salary ledger, payments and pay slips.
class StaffProfileScreen extends StatefulWidget {
  static const routeName = Routes.staffProfile;

  /// Preferred over route arguments in tests; route arguments win at runtime.
  final String? staffId;

  const StaffProfileScreen({super.key, this.staffId});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  late DateTime _slipMonth = DateTime.now();

  String? _resolveStaffId(BuildContext context) {
    if (widget.staffId != null) return widget.staffId;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['staffId'] is String) {
      return args['staffId'] as String;
    }
    return null;
  }

  // ------------------------------------------------------------ give payment
  void _openPaymentSheet(StaffMember staff) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var kind = 'salary';
    var date = DateTime.now();
    final formKey = GlobalKey<FormState>();

    showHBSheet<void>(
      context,
      title: staffTr('staff.givePayment'),
      child: StatefulBuilder(
        builder: (sheetCtx, setSheet) => Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                    labelText: staffTr('staff.amount'),
                    prefixIcon: const Icon(Icons.payments_outlined)),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  return (n == null || n <= 0)
                      ? staffTr('staff.invalidAmount')
                      : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: InputDecoration(
                    labelText: staffTr('staff.kind'),
                    prefixIcon: const Icon(Icons.category_outlined)),
                items: [
                  DropdownMenuItem(
                      value: 'salary',
                      child: Text(staffTr('staff.kindSalary'))),
                  DropdownMenuItem(
                      value: 'advance',
                      child: Text(staffTr('staff.kindAdvance'))),
                  DropdownMenuItem(
                      value: 'bonus', child: Text(staffTr('staff.kindBonus'))),
                ],
                onChanged: (v) => setSheet(() => kind = v ?? 'salary'),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetCtx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setSheet(() => date = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: staffTr('staff.date'),
                    prefixIcon: const Icon(Icons.event_outlined),
                  ),
                  child: Text(DateFormat('dd MMM yyyy').format(date)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteCtrl,
                decoration: InputDecoration(
                    labelText: staffTr('staff.note'),
                    prefixIcon: const Icon(Icons.note_outlined)),
              ),
              const SizedBox(height: 16),
              HBPillButton(
                label: staffTr('staff.givePayment'),
                icon: Icons.check,
                onPressed: () async {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  await StaffService.addPayment(
                    staffId: staff.id,
                    amount: double.parse(amountCtrl.text.trim()),
                    kind: kind,
                    date: date,
                    note: noteCtrl.text.trim(),
                  );
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                  if (mounted) {
                    HBToast.show(context,
                        message: staffTr('staff.paid'),
                        icon: Icons.check_circle);
                    setState(() {});
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- salary slip
  void _openSlipSheet(StaffMember staff) {
    showHBSheet<void>(
      context,
      title: staffTr('staff.slip'),
      child: StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          final slip =
              StaffService.monthlySlipData(staff.id, _slipMonth);
          final biz = HiveService.currentBusiness;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setSheet(() {
                      _slipMonth =
                          DateTime(_slipMonth.year, _slipMonth.month - 1);
                    }),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_month,
                        size: 18, color: HBColors.primary),
                    label: Text(
                      DateFormat('MMMM yyyy').format(_slipMonth),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: sheetCtx,
                        initialDate: _slipMonth,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDatePickerMode: DatePickerMode.year,
                      );
                      if (picked != null) {
                        setSheet(() => _slipMonth =
                            DateTime(picked.year, picked.month));
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: DateUtils.isSameMonth(_slipMonth, DateTime.now())
                        ? null
                        : () => setSheet(() {
                              _slipMonth = DateTime(
                                  _slipMonth.year, _slipMonth.month + 1);
                            }),
                  ),
                ],
              ),
              // Original slip layout: business header, staff + month,
              // breakdown rows, net payable footer.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx).brightness == Brightness.dark
                      ? HBColors.cardDark
                      : HBColors.page,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (biz != null)
                      Text(biz.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                        '${staffTr('staff.slipFor')} ${staff.name} • ${DateFormat('MMMM yyyy').format(_slipMonth)}',
                        style: const TextStyle(
                            fontSize: 13, color: HBColors.muted)),
                    const Divider(height: 20),
                    _slipRow(staffTr('staff.basicSalary'),
                        slip.basicSalary, false),
                    _slipRow(staffTr('staff.bonuses'), slip.bonuses, true),
                    _slipRow(staffTr('staff.salaryPaid'),
                        -slip.salaryPaid, false),
                    _slipRow(staffTr('staff.advancesDeducted'),
                        -slip.advances, false),
                    const Divider(height: 20),
                    _slipRow(staffTr('staff.netPayable'),
                        slip.netPayable, true,
                        bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(staffTr('staff.generatedBy'),
                  style:
                      const TextStyle(fontSize: 11, color: HBColors.muted)),
              const SizedBox(height: 12),
              HBPillButton(
                label: staffTr('staff.share'),
                icon: Icons.share,
                onPressed: () => _shareSlip(staff, slip, biz?.name ?? ''),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _slipRow(String label, double amount, bool positive,
      {bool bold = false}) {
    final isIn = positive;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 16 : 14,
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal)),
          HBAmountText(amount.abs(),
              isIn: isIn, size: bold ? 18 : 15, hide: false),
        ],
      ),
    );
  }

  Future<void> _shareSlip(
      StaffMember staff, StaffMonthSlip slip, String bizName) async {
    final doc = pw.Document();
    final monthName = DateFormat('MMMM yyyy')
        .format(DateTime(slip.year, slip.month));
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(bizName.isEmpty ? 'Hisab Business' : bizName,
              style: pw.TextStyle(
                  fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('${staffTr('staff.slip')} • $monthName',
              style: const pw.TextStyle(fontSize: 14)),
          pw.Divider(),
          pw.Text('${staffTr('staff.slipFor')} ${staff.name}',
              style: const pw.TextStyle(fontSize: 12)),
          if (staff.role.isNotEmpty)
            pw.Text(staff.role,
                style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 16),
          _pdfRow(staffTr('staff.basicSalary'), slip.basicSalary),
          _pdfRow(staffTr('staff.bonuses'), slip.bonuses),
          _pdfRow(
              staffTr('staff.salaryPaid'), -slip.salaryPaid),
          _pdfRow(staffTr('staff.advancesDeducted'),
              -slip.advances),
          pw.Divider(),
          _pdfRow(staffTr('staff.netPayable'), slip.netPayable,
              bold: true),
          pw.Spacer(),
          pw.Text(staffTr('staff.generatedBy'),
              style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    ));
    final bytes = await doc.save();
    final dir = Directory.systemTemp;
    final file = File(
        '${dir.path}/salary-slip-${staff.id}-${slip.year}-${slip.month}.pdf');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: '${staffTr('staff.slip')} — ${staff.name}, $monthName'));
  }

  pw.Widget _pdfRow(String label, double amount, {bool bold = false}) {
    final style = pw.TextStyle(
        fontSize: bold ? 16 : 13,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(formatPKR(amount.abs()), style: style),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, lang, child) {
        final staffId = _resolveStaffId(context);
        final staff =
            staffId == null ? null : HiveService.staff.get(staffId);
        if (staff == null) {
          return Scaffold(
            appBar: HBAppBar(title: staffTr('staff.title')),
            body: const Center(child: Text('—')),
          );
        }
        return Scaffold(
          appBar: HBAppBar(title: staff.name),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _headerCard(staff),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: HBPillButton(
                      label: staffTr('staff.givePayment'),
                      icon: Icons.payments_outlined,
                      onPressed: () => _openPaymentSheet(staff),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: HBPillButton(
                      label: staffTr('staff.slip'),
                      icon: Icons.receipt_long_outlined,
                      outlined: true,
                      onPressed: () => _openSlipSheet(staff),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              HBSectionLabel(staffTr('staff.attendance')),
              const SizedBox(height: 4),
              _attendanceSection(staff),
              const SizedBox(height: 20),
              HBSectionLabel(staffTr('staff.ledger')),
              const SizedBox(height: 4),
              _ledgerSection(staff),
            ],
          ),
        );
      },
    );
  }

  Widget _headerCard(StaffMember staff) {
    final due = HiveService.staffAdvanceBalance(staff.id);
    final hide = HiveService.hideBalances;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            StaffAvatar(staff: staff, radius: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(staff.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  if (staff.role.isNotEmpty)
                    Text(staff.role,
                        style: const TextStyle(
                            fontSize: 13, color: HBColors.muted)),
                  if (staff.phone.isNotEmpty)
                    Text(staff.phone,
                        style: const TextStyle(
                            fontSize: 13, color: HBColors.muted)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: due > 0
                              ? HBColors.moneyOutSoft
                              : HBColors.moneyInSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          due > 0
                              ? '${staffTr('staff.advanceDue')}: ${hide ? '••••••' : formatPKR(due)}'
                              : staffTr('staff.noDue'),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: due > 0
                                  ? HBColors.moneyOutDeep
                                  : HBColors.moneyInDeep),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attendanceSection(StaffMember staff) {
    final summary = StaffService.monthAttendanceSummary(staff.id, 30);
    final now = DateTime.now();
    // Build last 30 days newest-first.
    final days = List.generate(
        30, (i) => DateTime(now.year, now.month, now.day - i));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${summary.present} ${staffTr('staff.daysPresent')} • ${summary.absent} ${staffTr('staff.daysAbsent')}',
          style: const TextStyle(fontSize: 13, color: HBColors.muted),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (sepCtx, sepIdx) => const SizedBox(width: 6),
            itemBuilder: (ctx, i) {
              final d = days[i];
              final status = StaffService.statusFor(staff.id, d);
              Color bg;
              Color fg;
              String mark;
              switch (status) {
                case 'present':
                  bg = HBColors.moneyInSoft;
                  fg = HBColors.moneyInDeep;
                  mark = 'P';
                  break;
                case 'absent':
                  bg = HBColors.moneyOutSoft;
                  fg = HBColors.moneyOutDeep;
                  mark = 'A';
                  break;
                case 'half':
                  bg = HBColors.primarySoft;
                  fg = HBColors.primaryDeep;
                  mark = 'H';
                  break;
                default:
                  bg = Theme.of(ctx).brightness == Brightness.dark
                      ? HBColors.cardDark
                      : HBColors.page;
                  fg = HBColors.muted;
                  mark = '–';
              }
              final isToday = i == 0;
              return Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                  border: isToday
                      ? Border.all(color: HBColors.primary, width: 1.5)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(DateFormat('d').format(d),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: fg)),
                    Text(DateFormat('EEE').format(d),
                        style: TextStyle(fontSize: 10, color: fg)),
                    Text(mark,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: fg)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _ledgerSection(StaffMember staff) {
    final payments = StaffService.paymentsForStaff(staff.id);
    if (payments.isEmpty) {
      return HBEmptyState(
        icon: Icons.receipt_long_outlined,
        title: staffTr('staff.ledger'),
        subtitle: staffTr('staff.emptySub'),
      );
    }
    // Running advance balance: advances increase it, salary/bonus reduce it.
    final asc = payments.reversed.toList();
    final running = <String, double>{};
    var bal = 0.0;
    for (final p in asc) {
      bal += p.kind == 'advance' ? p.amount : -p.amount;
      running[p.id] = bal;
    }
    return Column(
      children: [
        for (final p in payments)
          Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? HBColors.hairlineDark
                        : HBColors.hairline)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: p.kind == 'advance'
                          ? HBColors.moneyOutSoft
                          : HBColors.moneyInSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      p.kind == 'advance'
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 20,
                      color: p.kind == 'advance'
                          ? HBColors.moneyOutDeep
                          : HBColors.moneyInDeep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_kindLabel(p.kind),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        Text(
                          '${DateFormat('dd MMM yyyy').format(p.date)}${p.note.isNotEmpty ? ' • ${p.note}' : ''}',
                          style: const TextStyle(
                              fontSize: 12, color: HBColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // All staff payouts are cash OUT (red) per money rules.
                      HBAmountText(p.amount, isIn: false, size: 15),
                      Text(
                        '${staffTr('staff.advanceDue')}: ${formatPKR(running[p.id] ?? 0)}',
                        style: const TextStyle(
                            fontSize: 11, color: HBColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'advance':
        return staffTr('staff.kindAdvance');
      case 'bonus':
        return staffTr('staff.kindBonus');
      default:
        return staffTr('staff.kindSalary');
    }
  }
}
