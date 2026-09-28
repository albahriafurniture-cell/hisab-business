import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../l10n/khata_l10n.dart';
import '../l10n/strings.dart';
import '../services/khata_service.dart';
import '../theme.dart';
import '../widgets/hb_actions.dart';
import '../widgets/hb_chrome.dart';

/// Add-entry form (route [Routes.transactionAdd],
/// arguments `{'partyId': id, 'direction': 'gave'|'got'}`).
///
/// Direction toggle (You Gave / You Got), amount (> 0), date picker,
/// detail text, optional bill photo. Saving writes a [KhataEntry] via
/// [KhataService] and then offers a shareable receipt.
class TransactionAddScreen extends StatefulWidget {
  const TransactionAddScreen({super.key});

  @override
  State<TransactionAddScreen> createState() =>
      _TransactionAddScreenState();
}

class _TransactionAddScreenState extends State<TransactionAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _detail = TextEditingController();
  String _direction = 'gave';
  DateTime _date = DateTime.now();
  String _photoPath = '';
  bool _saving = false;
  bool _argsRead = false;

  @override
  void dispose() {
    _amount.dispose();
    _detail.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsRead) {
      _argsRead = true;
      final d = _arg('direction');
      if (d != null && (d == 'gave' || d == 'got')) _direction = d;
    }
  }

  String? _arg(String key) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) return args[key] as String?;
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickPhoto() async {
    try {
      final img = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (img != null) setState(() => _photoPath = img.path);
    } catch (_) {
      if (mounted) {
        HBToast.show(context,
            message: khataTr('khata.cantOpen'),
            icon: Icons.error_outline);
      }
    }
  }

  Future<void> _save(String? partyId) async {
    if (partyId == null) {
      HBToast.show(context,
          message: khataTr('khata.noParties'),
          icon: Icons.error_outline);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amt = double.tryParse(_amount.text.trim());
    if (amt == null || amt <= 0) return;
    setState(() => _saving = true);
    try {
      final entry = await KhataService.addEntry(
        partyId: partyId,
        direction: _direction,
        amount: amt,
        date: _date,
        detail: _detail.text.trim(),
        photoPath: _photoPath,
      );
      if (!mounted) return;
      HBToast.show(context,
          message: khataTr('khata.entrySaved'),
          icon: Icons.check);
      await _offerReceipt(partyId, entry);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // [INFERRED] receipt layout + share flow — not observed in research.
  String _receiptText(
      String partyName, KhataEntry entry, double balance) {
    final dirLine = entry.direction == 'gave'
        ? '${khataTr('khata.youGave')}: ${formatPKR(entry.amount)}'
        : '${khataTr('khata.youGot')}: ${formatPKR(entry.amount)}';
    final balWord = balance > 0
        ? khataTr('khata.youWillGet')
        : balance < 0
            ? khataTr('khata.youWillGive')
            : khataTr('khata.settled');
    final lines = [
      '${khataTr('khata.receipt')} — ${tr(context, 'app.name')}',
      '${tr(context, 'label.name')}: $partyName',
      '${khataTr('khata.date')}: ${DateFormat('MMM d, y').format(entry.date)}',
      dirLine,
      if (entry.detail.isNotEmpty)
        '${khataTr('khata.detail')}: ${entry.detail}',
      '${khataTr('khata.balanceAfter')}: '
          '${formatPKR(balance.abs())} ($balWord)',
    ];
    return lines.join('\n');
  }

  Future<void> _offerReceipt(
      String partyId, KhataEntry entry) async {
    final party = HiveService.parties.get(partyId);
    final balance = KhataService.balanceForParty(partyId);
    final text = _receiptText(party?.name ?? '', entry, balance);
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    await showHBSheet<void>(
      context,
      title: khataTr('khata.receipt'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? HBColors.pageDark
                  : HBColors.primarySofter,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(text,
                style: const TextStyle(fontSize: 14, height: 1.6)),
          ),
          const SizedBox(height: 12),
          HBPillButton(
            label: khataTr('khata.shareReceipt'),
            icon: Icons.share,
            onPressed: () =>
                SharePlus.instance.share(ShareParams(text: text)),
          ),
          const SizedBox(height: 8),
          HBPillButton(
            label: tr(context, 'action.done'),
            outlined: true,
            onPressed: () {
              Navigator.of(context).pop(); // sheet
              Navigator.of(context).pop(true); // screen
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
        final partyId = _arg('partyId');
        final party = partyId == null
            ? null
            : HiveService.parties.get(partyId);
        final isDark =
            Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: HBAppBar(title: khataTr('khata.addEntry')),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (party != null) _partyChip(party, isDark),
                if (party != null) const SizedBox(height: 16),
                _directionToggle(isDark),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('khata_amount'),
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: tr(context, 'label.amount'),
                    prefixText: 'Rs ',
                  ),
                  validator: (v) {
                    final amt =
                        double.tryParse((v ?? '').trim());
                    if (amt == null || amt <= 0) {
                      return khataTr('khata.amountRequired');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: khataTr('khata.date'),
                      suffixIcon:
                          const Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('EEE, MMM d, y')
                        .format(_date)),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('khata_detail'),
                  controller: _detail,
                  maxLines: 2,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: khataTr('khata.detail'),
                  ),
                ),
                const SizedBox(height: 16),
                _photoRow(isDark),
                const SizedBox(height: 24),
                HBPillButton(
                  key: const Key('khata_save'),
                  label: khataTr('khata.saveEntry'),
                  icon: Icons.check,
                  onPressed:
                      _saving ? null : () => _save(partyId),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _partyChip(Party party, bool isDark) {
    final balance = KhataService.balanceForParty(party.id);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? HBColors.cardDark : HBColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark
                ? HBColors.hairlineDark
                : HBColors.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline,
              color: HBColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(party.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          Text(
            formatPKR(balance.abs()),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: moneyColor(!isReceivable(balance))),
          ),
        ],
      ),
    );
  }

  // [INFERRED] red/green segmented toggle — research shows no entry form.
  Widget _directionToggle(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? HBColors.cardDark : HBColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark
                ? HBColors.hairlineDark
                : HBColors.hairline),
      ),
      child: Row(
        children: [
          _seg(khataTr('khata.youGave'), 'gave',
              HBColors.moneyOut),
          _seg(khataTr('khata.youGot'), 'got',
              HBColors.moneyIn),
        ],
      ),
    );
  }

  Widget _seg(String label, String value, Color color) {
    final sel = _direction == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _direction = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: sel ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: sel ? Colors.white : HBColors.muted,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoRow(bool isDark) {
    return InkWell(
      onTap: _pickPhoto,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark
                  ? HBColors.hairlineDark
                  : HBColors.hairline,
              style: BorderStyle.solid),
          color: isDark ? HBColors.cardDark : HBColors.card,
        ),
        child: _photoPath.isEmpty
            ? Row(
                children: [
                  const Icon(Icons.image_outlined,
                      color: HBColors.primary),
                  const SizedBox(width: 8),
                  Text(khataTr('khata.attachBill')),
                ],
              )
            : Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_photoPath),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _photoPath.split('/').last,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _photoPath = ''),
                    child: Text(tr(context, 'action.delete'),
                        style: const TextStyle(
                            color: HBColors.moneyOut)),
                  ),
                ],
              ),
      ),
    );
  }
}
