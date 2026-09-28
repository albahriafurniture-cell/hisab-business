import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../l10n/bank_l10n.dart';
import '../l10n/strings.dart';
import '../routes.dart';
import '../widgets/hb_chrome.dart';

/// Add a new bank account: bank name, account title/number, opening
/// balance and date. A non-zero opening balance becomes the account's
/// first transaction (deposit, or withdrawal if negative).
class BankAddScreen extends StatefulWidget {
  const BankAddScreen({super.key});

  static const routeName = Routes.bankAdd;

  @override
  State<BankAddScreen> createState() => _BankAddScreenState();
}

class _BankAddScreenState extends State<BankAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _noCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();

  // Written fresh for Hisab Business; not copied from any source.
  static const _banks = [
    'Allied Bank',
    'Askari Bank',
    'Bank Alfalah',
    'Bank of Khyber',
    'Bank of Punjab',
    'BankIslami',
    'Dubai Islamic Bank',
    'Faysal Bank',
    'Habib Bank (HBL)',
    'Habib Metropolitan Bank',
    'JS Bank',
    'MCB Bank',
    'Meezan Bank',
    'National Bank of Pakistan',
    'Samba Bank',
    'Silk Bank',
    'Soneri Bank',
    'Standard Chartered Pakistan',
    'Summit Bank',
    'UBL',
    'Other',
  ];

  String? _bankName = _banks.first;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_bankName == null || _bankName!.isEmpty) return;
    setState(() => _saving = true);
    try {
      const uuid = Uuid();
      final id = uuid.v4();
      final now = DateTime.now();
      await HiveService.bankAccounts.put(
        id,
        BankAccount(
          id: id,
          bankName: _bankName!,
          title: _titleCtrl.text.trim(),
          accountNo: _noCtrl.text.trim(),
          createdAt: now,
        ),
      );
      final opening =
          double.tryParse(_balanceCtrl.text.trim().replaceAll(',', '')) ?? 0;
      if (opening != 0) {
        final txnId = uuid.v4();
        await HiveService.bankTxns.put(
          txnId,
          BankTxn(
            id: txnId,
            bankAccountId: id,
            direction: opening > 0 ? 'deposit' : 'withdraw',
            amount: opening.abs(),
            date: _date,
            detail: 'Opening balance',
            createdAt: now,
          ),
        );
      }
      if (!mounted) return;
      HBToast.show(context,
          message: bankTr('bank.saved'), icon: Icons.check_circle);
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, _, _) => Scaffold(
        appBar: HBAppBar(title: bankTr('bank.newAccount')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _bankName,
                decoration: InputDecoration(
                  labelText: bankTr('bank.bankName'),
                  prefixIcon: const Icon(Icons.account_balance),
                ),
                items: [
                  for (final b in _banks)
                    DropdownMenuItem(value: b, child: Text(b)),
                ],
                onChanged: (v) => setState(() => _bankName = v),
                validator: (v) =>
                    (v == null || v.isEmpty) ? bankTr('bank.required') : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: bankTr('bank.accountTitle'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _noCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: bankTr('bank.accountNo'),
                  prefixIcon: const Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _balanceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: bankTr('bank.openingBalance'),
                  prefixIcon: const Icon(Icons.savings_outlined),
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return null;
                  final n = double.tryParse(t.replaceAll(',', ''));
                  if (n == null) return bankTr('bank.invalidAmount');
                  return null;
                },
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: bankTr('bank.date'),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text('${_date.day}/${_date.month}/${_date.year}'),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(bankTr('bank.saveAccount')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
