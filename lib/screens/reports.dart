import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/hive_service.dart';
import '../l10n/bank_l10n.dart';
import '../l10n/strings.dart';
import '../routes.dart';
import '../services/report_service.dart';
import '../theme.dart';
import '../widgets/hb_cards.dart';
import '../widgets/hb_chrome.dart';

/// Reports hub: six report cards (Party Ledger, Cash Book, Expense, Stock,
/// Bank Statement, Profit & Loss). Each card expands into a config panel
/// with a date range (presets + pickers) and entity picker where needed;
/// Generate builds a PDF via [ReportService], saves it, and offers
/// View / Share (WhatsApp-compatible file share).
/// Optional route arguments: {'initial': 'party'|'cash'|'expense'|
/// 'stock'|'bank'|'pnl', 'partyId': ...}.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  static const routeName = Routes.reports;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum _ReportKind { party, cash, expense, stock, bank, pnl }

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportKind? _selected;
  bool _argsRead = false;

  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  int _preset = 2; // 0 today, 1 week, 2 month, -1 custom

  String? _partyId;
  String? _accountId;

  bool _generating = false;
  String? _lastPath;
  String? _lastTitle;

  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Brings the config/result panel into view after it appears.
  void _scrollToPanel() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _readArgs() {
    if (_argsRead) return;
    _argsRead = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;
    final initial = args['initial'] as String?;
    const map = {
      'party': _ReportKind.party,
      'cash': _ReportKind.cash,
      'expense': _ReportKind.expense,
      'stock': _ReportKind.stock,
      'bank': _ReportKind.bank,
      'pnl': _ReportKind.pnl,
    };
    if (initial != null && map.containsKey(initial)) {
      _selected = map[initial];
      _scrollToPanel();
    }
    final pid = args['partyId'] as String?;
    if (pid != null && HiveService.parties.containsKey(pid)) {
      _partyId = pid;
    }
  }

  void _applyPreset(int p) {
    final now = DateTime.now();
    setState(() {
      _preset = p;
      if (p == 0) {
        _from = DateTime(now.year, now.month, now.day);
        _to = _from;
      } else if (p == 1) {
        _from =
            DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        _to = DateTime(now.year, now.month, now.day);
      } else {
        _from = DateTime(now.year, now.month, 1);
        _to = DateTime(now.year, now.month, now.day);
      }
      _lastPath = null;
    });
  }

  Future<void> _pickBound(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _preset = -1;
      if (isFrom) {
        _from = picked;
        if (_from.isAfter(_to)) _to = _from;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = _to;
      }
      _lastPath = null;
    });
  }

  bool get _needsParty => _selected == _ReportKind.party;
  bool get _needsAccount => _selected == _ReportKind.bank;
  bool get _needsRange => _selected != _ReportKind.stock;

  bool get _canGenerate {
    if (_selected == null || _generating) return false;
    if (_needsParty && _partyId == null) return false;
    if (_needsAccount && _accountId == null) return false;
    return true;
  }

  String _titleOf(_ReportKind k) {
    switch (k) {
      case _ReportKind.party:
        return bankTr('reports.partyLedger');
      case _ReportKind.cash:
        return bankTr('reports.cashBook');
      case _ReportKind.expense:
        return bankTr('reports.expense');
      case _ReportKind.stock:
        return bankTr('reports.stock');
      case _ReportKind.bank:
        return bankTr('reports.bank');
      case _ReportKind.pnl:
        return bankTr('reports.pnl');
    }
  }

  String _subOf(_ReportKind k) {
    switch (k) {
      case _ReportKind.party:
        return bankTr('reports.partyLedgerSub');
      case _ReportKind.cash:
        return bankTr('reports.cashBookSub');
      case _ReportKind.expense:
        return bankTr('reports.expenseSub');
      case _ReportKind.stock:
        return bankTr('reports.stockSub');
      case _ReportKind.bank:
        return bankTr('reports.bankSub');
      case _ReportKind.pnl:
        return bankTr('reports.pnlSub');
    }
  }

  IconData _iconOf(_ReportKind k) {
    switch (k) {
      case _ReportKind.party:
        return Icons.people_outline;
      case _ReportKind.cash:
        return Icons.wallet_outlined;
      case _ReportKind.expense:
        return Icons.trending_down;
      case _ReportKind.stock:
        return Icons.inventory_2_outlined;
      case _ReportKind.bank:
        return Icons.account_balance_outlined;
      case _ReportKind.pnl:
        return Icons.bar_chart_outlined;
    }
  }

  Future<void> _generate() async {
    if (!_canGenerate) return;
    setState(() {
      _generating = true;
      _lastPath = null;
    });
    try {
      final kind = _selected!;
      late final Uint8List bytes;
      final slug = kind.name;
      switch (kind) {
        case _ReportKind.party:
          bytes = await ReportService.buildPartyLedgerPdf(
              _partyId!, _from, _to);
        case _ReportKind.cash:
          bytes = await ReportService.buildCashBookPdf(_from, _to);
        case _ReportKind.expense:
          bytes = await ReportService.buildExpensePdf(_from, _to);
        case _ReportKind.stock:
          bytes = await ReportService.buildStockPdf();
        case _ReportKind.bank:
          bytes = await ReportService.buildBankStatementPdf(
              _accountId!, _from, _to);
        case _ReportKind.pnl:
          bytes = await ReportService.buildPnlPdf(_from, _to);
      }
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final path =
          await ReportService.saveReport(bytes, '$slug-$stamp.pdf');
      if (!mounted) return;
      setState(() {
        _lastPath = path;
        _lastTitle = _titleOf(kind);
      });
      _scrollToPanel();
      HBToast.show(context,
          message: bankTr('reports.ready'), icon: Icons.check_circle);
    } catch (_) {
      if (!mounted) return;
      HBToast.show(context,
          message: bankTr('reports.failed'),
          icon: Icons.error_outline,
          tint: HBColors.moneyOutSoft);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _view() async {
    final path = _lastPath;
    if (path == null) return;
    try {
      final ok = await launchUrl(Uri.file(path),
          mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        HBToast.show(context,
            message: bankTr('reports.failed'), icon: Icons.error_outline);
      }
    } catch (_) {
      if (mounted) {
        HBToast.show(context,
            message: bankTr('reports.failed'), icon: Icons.error_outline);
      }
    }
  }

  Future<void> _share() async {
    final path = _lastPath;
    if (path == null) return;
    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(path)],
        text: _lastTitle ?? bankTr('reports.title'),
      ));
    } catch (_) {
      if (mounted) {
        HBToast.show(context,
            message: bankTr('reports.failed'), icon: Icons.error_outline);
      }
    }
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    _readArgs();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, _, _) {
        return Scaffold(
        appBar: HBAppBar(title: bankTr('reports.title')),
        body: ListView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(16),
          children: [
            Text(bankTr('reports.subtitle'),
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? HBColors.mutedDark : HBColors.muted)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
              children: [
                for (final k in _ReportKind.values) _reportCard(k, isDark),
              ],
            ),
            if (_selected != null) ...[
              const SizedBox(height: 16),
              _configCard(isDark),
            ],
            if (_lastPath != null) ...[
              const SizedBox(height: 12),
              _resultCard(isDark),
            ],
            const SizedBox(height: 24),
          ],
        ),
        );
      },
    );
  }

  Widget _reportCard(_ReportKind k, bool isDark) {
    final sel = _selected == k;
    return InkWell(
      onTap: () {
        setState(() {
        _selected = sel ? null : k;
        _lastPath = null;
        if (_needsParty && _partyId == null) {
          final ps = HiveService.activeParties();
          if (ps.isNotEmpty) _partyId = ps.first.id;
        }
        if (_needsAccount && _accountId == null) {
          final as = HiveService.bankAccounts.values.toList();
          if (as.isNotEmpty) _accountId = as.first.id;
        }
        });
        if (_selected != null) _scrollToPanel();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? HBColors.cardDark : HBColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: sel ? HBColors.primary : (isDark ? HBColors.hairlineDark : HBColors.hairline),
            width: sel ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: sel
                    ? HBColors.primary
                    : (isDark ? HBColors.primarySoftDark : HBColors.primarySoft),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconOf(k),
                  color: sel ? Colors.white : HBColors.primary, size: 22),
            ),
            const SizedBox(height: 8),
            Text(_titleOf(k),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(_subOf(k),
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? HBColors.mutedDark : HBColors.muted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _configCard(bool isDark) {
    final kind = _selected!;
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? HBColors.cardDark : HBColors.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HBSectionLabel(_titleOf(kind)),
            const SizedBox(height: 12),
            if (_needsParty) ...[
              _entityDropdown<String>(
                value: _partyId,
                hint: bankTr('reports.selectParty'),
                icon: Icons.person_outline,
                items: [
                  for (final p in HiveService.activeParties())
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) =>
                    setState(() => _partyId = v),
              ),
              const SizedBox(height: 12),
            ],
            if (_needsAccount) ...[
              _entityDropdown<String>(
                value: _accountId,
                hint: bankTr('reports.selectAccount'),
                icon: Icons.account_balance_outlined,
                items: [
                  for (final a in HiveService.bankAccounts.values)
                    DropdownMenuItem(
                        value: a.id,
                        child: Text('${a.bankName}'
                            '${a.title.isEmpty ? '' : ' - ${a.title}'}')),
                ],
                onChanged: (v) =>
                    setState(() => _accountId = v),
              ),
              const SizedBox(height: 12),
            ],
            if (_needsRange) ...[
              Wrap(
                spacing: 8,
                children: [
                  HBChip(
                      label: bankTr('reports.today'),
                      selected: _preset == 0,
                      onTap: () => _applyPreset(0)),
                  HBChip(
                      label: bankTr('reports.thisWeek'),
                      selected: _preset == 1,
                      onTap: () => _applyPreset(1)),
                  HBChip(
                      label: bankTr('reports.thisMonth'),
                      selected: _preset == 2,
                      onTap: () => _applyPreset(2)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _dateField(
                          bankTr('reports.from'), _from, () => _pickBound(true))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _dateField(
                          bankTr('reports.to'), _to, () => _pickBound(false))),
                ],
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _canGenerate ? _generate : null,
                icon: _generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_generating
                    ? bankTr('reports.generating')
                    : bankTr('reports.generate')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entityDropdown<T>({
    required T? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: items.any((i) => i.value == value) ? value : null,
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: Icon(icon),
      ),
      items: items,
      onChanged: onChanged,
      validator: (v) => v == null ? bankTr('bank.required') : null,
    );
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today, size: 20),
        ),
        child: Text(_fmt(value)),
      ),
    );
  }

  Widget _resultCard(bool isDark) {
    final fileName = _lastPath!.split('/').last;
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? HBColors.moneyInSoftDark : HBColors.moneyInSoft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: HBColors.moneyInDeep),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${bankTr('reports.ready')}: $fileName',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${bankTr('reports.savedAt')}: $_lastPath',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? HBColors.mutedDark : HBColors.muted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _view,
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(bankTr('reports.view')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.share),
                    label: Text(bankTr('reports.share')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
