import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../l10n/cash_l10n.dart';
import '../l10n/strings.dart';
import '../services/cash_service.dart';
import '../theme.dart';
import '../widgets/hb_actions.dart';
import '../widgets/hb_cards.dart';
import '../widgets/hb_chrome.dart';
import '../widgets/hb_rows.dart';

/// Cash book: daily cash in/out register.
/// Also used as the Cash bottom-tab body (wired by the coordinator);
/// as a pushed route it simply shows without a back chevron — [INFERRED].
class CashScreen extends StatefulWidget {
  const CashScreen({super.key});

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  DateTime _day = DateTime.now();

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year &&
        _day.month == now.month &&
        _day.day == now.day;
  }

  Future<void> _pickHistoryDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _day = picked);
    }
  }

  Future<void> _openEntrySheet(String direction) async {
    final saved = await showHBSheet<bool>(
      context,
      title: cashTr(
          context, direction == 'in' ? 'cash.entryIn' : 'cash.entryOut'),
      child: _CashEntryForm(
        direction: direction,
        initialDate: _day,
      ),
    );
    if (saved == true && mounted) {
      HBToast.show(context,
          message: cashTr(context, 'cash.saved'), icon: Icons.check);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild all copy when the app language changes.
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, _, _) {
        // Rebuild when cash entries or the hide-balances setting change.
        return ListenableBuilder(
          listenable: Listenable.merge([
            HiveService.cashEntries.listenable(),
            HiveService.settings.listenable(),
          ]),
          builder: (context, _) {
            final hide = HiveService.hideBalances;
            final inHand = CashService.cashInHand();
            final today = CashService.dayTotals(DateTime.now());
            final todayBalance = today.inTotal - today.outTotal;
            final dayTotals = CashService.dayTotals(_day);
            final entries = CashService.entriesForDay(_day);
            final dayLabel =
                DateFormat('EEE, d MMM yyyy').format(_day).toUpperCase();

            return Scaffold(
              appBar: HBAppBar(
                title: cashTr(context, 'cash.title'),
                showBack: false,
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: HBSummaryCard(
                      stats: [
                        HBStat(cashTr(context, 'cash.inHand'),
                            hide ? '••••••' : formatPKR(inHand), true),
                        HBStat(
                            cashTr(context, 'cash.todayBalance'),
                            hide
                                ? '••••••'
                                : formatPKR(todayBalance),
                            todayBalance >= 0),
                      ],
                      actionLabel: cashTr(context, 'cash.history'),
                      onAction: _pickHistoryDay,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(dayLabel,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        Text(
                          '${entries.length} ${cashTr(context, 'cash.entries')}',
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? HBColors.mutedDark
                                  : HBColors.muted),
                        ),
                      ],
                    ),
                  ),
                  if (!_isToday)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: TextButton.icon(
                          onPressed: () =>
                              setState(() => _day = DateTime.now()),
                          icon: const Icon(Icons.today, size: 16),
                          label: Text(
                              cashTr(context, 'cash.backToToday')),
                          style: TextButton.styleFrom(
                            foregroundColor: HBColors.primary,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(cashTr(context, 'cash.out'),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1,
                                      color: HBColors.moneyOut)),
                              const SizedBox(height: 2),
                              HBAmountText(dayTotals.outTotal,
                                  isIn: false, size: 17, hide: hide),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(cashTr(context, 'cash.in'),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1,
                                      color: HBColors.moneyIn)),
                              const SizedBox(height: 2),
                              HBAmountText(dayTotals.inTotal,
                                  isIn: true, size: 17, hide: hide),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: entries.isEmpty
                        ? HBEmptyState(
                            icon: Icons
                                .account_balance_wallet_outlined,
                            title: cashTr(
                                context, 'cash.noTransactions'),
                            subtitle: cashTr(context,
                                'cash.noTransactionsHint'),
                          )
                        : ListView.separated(
                            itemCount: entries.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, indent: 16),
                            itemBuilder: (context, i) =>
                                _CashEntryRow(
                                    entry: entries[i], hide: hide),
                          ),
                  ),
                ],
              ),
              bottomNavigationBar: HBStickyBottomBar(
                outLabel: cashTr(context, 'cash.out'),
                inLabel: cashTr(context, 'cash.in'),
                onOut: () => _openEntrySheet('out'),
                onIn: () => _openEntrySheet('in'),
              ),
            );
          },
        );
      },
    );
  }
}

/// One cash-book row: time left, detail middle, amount right (colored).
class _CashEntryRow extends StatelessWidget {
  final CashEntry entry;
  final bool hide;

  const _CashEntryRow({required this.entry, required this.hide});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? HBColors.mutedDark : HBColors.muted;
    final isIn = entry.direction == 'in';
    final title = entry.detail.isNotEmpty
        ? entry.detail
        : (entry.category.isNotEmpty
            ? entry.category
            : cashTr(context, isIn ? 'cash.entryIn' : 'cash.entryOut'));
    final party = entry.partyId.isEmpty
        ? null
        : HiveService.parties.get(entry.partyId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 66,
            child: Text(
              DateFormat('hh:mm a').format(entry.date),
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (party != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(party.name,
                        style:
                            TextStyle(fontSize: 12, color: muted)),
                  )
                else if (entry.detail.isNotEmpty &&
                    entry.category.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(entry.category,
                        style:
                            TextStyle(fontSize: 12, color: muted)),
                  ),
              ],
            ),
          ),
          if (entry.photoPath.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Icon(Icons.receipt_long, size: 18, color: muted),
            ),
          HBAmountText(entry.amount,
              isIn: isIn, size: 16, hide: hide),
        ],
      ),
    );
  }
}

/// Bottom-sheet form for a cash in/out entry. [INFERRED] layout.
class _CashEntryForm extends StatefulWidget {
  final String direction; // 'in' | 'out'
  final DateTime initialDate;

  const _CashEntryForm(
      {required this.direction, required this.initialDate});

  @override
  State<_CashEntryForm> createState() => _CashEntryFormState();
}

class _CashEntryFormState extends State<_CashEntryForm> {
  final _amountCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();
  late DateTime _date;
  String _partyId = '';
  String _photoPath = '';
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _categoryCtrl.dispose();
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // back-dating allowed, no future
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(cashTr(context, 'cash.takePhoto')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(cashTr(context, 'cash.chooseGallery')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _photoPath = picked.path);
      }
    } catch (_) {
      // Camera/gallery unavailable — the entry can still be saved.
    }
  }

  Future<void> _save() async {
    final raw = _amountCtrl.text.trim().replaceAll(',', '');
    final amount = double.tryParse(raw);
    if (amount == null) {
      setState(
          () => _amountError = cashTr(context, 'cash.invalidAmount'));
      return;
    }
    if (amount <= 0) {
      setState(
          () => _amountError = cashTr(context, 'cash.amountRequired'));
      return;
    }
    await CashService.addCashEntry(
      direction: widget.direction,
      amount: amount,
      date: _date,
      category: _categoryCtrl.text,
      partyId: _partyId,
      detail: _detailCtrl.text,
      photoPath: _photoPath,
    );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? HBColors.mutedDark : HBColors.muted;
    final parties = HiveService.activeParties();
    final suggestions = CashService.categorySuggestions()
        .where((s) =>
            _categoryCtrl.text.trim().isNotEmpty &&
            s.toLowerCase().contains(_categoryCtrl.text.trim().toLowerCase()))
        .take(6)
        .toList();
    final allSuggestions = _categoryCtrl.text.trim().isEmpty
        ? CashService.categorySuggestions().take(6).toList()
        : suggestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _amountCtrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: cashTr(context, 'cash.amount'),
            prefixText: 'Rs ',
            errorText: _amountError,
          ),
          onChanged: (_) {
            if (_amountError != null) {
              setState(() => _amountError = null);
            }
          },
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                  color: isDark
                      ? HBColors.hairlineDark
                      : HBColors.hairline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 20, color: HBColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('EEE, d MMM yyyy').format(_date),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                Text(cashTr(context, 'cash.date'),
                    style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _categoryCtrl,
          decoration: InputDecoration(
            labelText: cashTr(context, 'cash.category'),
            hintText: cashTr(context, 'cash.categoryHint'),
            prefixIcon: const Icon(Icons.label_outline),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (allSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in allSuggestions)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: HBChip(
                      label: s,
                      selected: false,
                      onTap: () =>
                          setState(() => _categoryCtrl.text = s),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _partyId.isEmpty ? null : _partyId,
          decoration: InputDecoration(
            labelText: cashTr(context, 'cash.party'),
            prefixIcon: const Icon(Icons.person_outline),
          ),
          hint: Text(cashTr(context, 'cash.noParty')),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(cashTr(context, 'cash.noParty')),
            ),
            for (final p in parties)
              DropdownMenuItem(
                value: p.id,
                child: Text(p.name,
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() => _partyId = v ?? ''),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _detailCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: cashTr(context, 'cash.detail'),
            hintText: cashTr(context, 'cash.detailHint'),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickPhoto,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark
                    ? HBColors.hairlineDark
                    : HBColors.hairline,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (_photoPath.isNotEmpty && !kIsWeb)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_photoPath),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image),
                    ),
                  )
                else
                  const Icon(Icons.receipt_long_outlined,
                      color: HBColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _photoPath.isEmpty
                        ? cashTr(context, 'cash.attachBill')
                        : cashTr(context, 'cash.changePhoto'),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const Icon(Icons.add_a_photo_outlined,
                    size: 20, color: HBColors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        HBPillButton(
          label: cashTr(context, 'cash.save'),
          icon: Icons.check,
          color: widget.direction == 'in'
              ? HBColors.moneyIn
              : HBColors.moneyOut,
          onPressed: _save,
        ),
      ],
    );
  }
}
