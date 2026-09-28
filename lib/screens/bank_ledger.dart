import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../l10n/bank_l10n.dart';
import '../l10n/strings.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/hb_actions.dart';
import '../widgets/hb_chrome.dart';
import '../widgets/hb_rows.dart';

/// Single bank account ledger: header with balance, Deposit/Withdraw
/// buttons opening a bottom sheet, and a dated transaction list with a
/// running balance. Reads {'bankAccountId': id} from route arguments.
class BankLedgerScreen extends StatefulWidget {
  const BankLedgerScreen({super.key});

  static const routeName = Routes.bankLedger;

  @override
  State<BankLedgerScreen> createState() => _BankLedgerScreenState();
}

class _BankLedgerScreenState extends State<BankLedgerScreen> {
  String? get _accountId {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) return args['bankAccountId'] as String?;
    return null;
  }

  Future<void> _openTxnSheet(bool isDeposit) async {
    final accountId = _accountId;
    if (accountId == null) return;
    final amountCtrl = TextEditingController();
    final detailCtrl = TextEditingController();
    DateTime date = DateTime.now();
    final formKey = GlobalKey<FormState>();

    await showHBSheet<void>(
      context,
      title: isDeposit ? bankTr('bank.deposit') : bankTr('bank.withdraw'),
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: bankTr('bank.amount'),
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
                validator: (v) {
                  final n =
                      double.tryParse((v ?? '').trim().replaceAll(',', ''));
                  if (n == null || n <= 0) return bankTr('bank.invalidAmount');
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: detailCtrl,
                decoration: InputDecoration(
                  labelText: bankTr('bank.detail'),
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetCtx,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setSheetState(() => date = picked);
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: bankTr('bank.date'),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text('${date.day}/${date.month}/${date.year}'),
                ),
              ),
              const SizedBox(height: 20),
              HBPillButton(
                label: isDeposit
                    ? bankTr('bank.deposit')
                    : bankTr('bank.withdraw'),
                icon: isDeposit ? Icons.add : Icons.remove,
                color: isDeposit ? HBColors.moneyIn : HBColors.moneyOut,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final amount = double.parse(
                      amountCtrl.text.trim().replaceAll(',', ''));
                  const uuid = Uuid();
                  final id = uuid.v4();
                  final now = DateTime.now();
                  await HiveService.bankTxns.put(
                    id,
                    BankTxn(
                      id: id,
                      bankAccountId: accountId,
                      direction: isDeposit ? 'deposit' : 'withdraw',
                      amount: amount,
                      date: date,
                      detail: detailCtrl.text.trim(),
                      createdAt: now,
                    ),
                  );
                  if (!mounted) return;
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                  HBToast.show(context,
                      message: bankTr('bank.txnSaved'),
                      icon: Icons.check_circle);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    amountCtrl.dispose();
    detailCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, _, _) {
        final accountId = _accountId;
        final account =
            accountId == null ? null : HiveService.bankAccounts.get(accountId);
        if (account == null) {
          return Scaffold(
            appBar: HBAppBar(title: bankTr('bank.statement')),
            body: HBEmptyState(
              icon: Icons.account_balance,
              title: bankTr('bank.noBanks'),
              subtitle: bankTr('bank.noBanksSub'),
            ),
          );
        }
        return Scaffold(
          appBar: HBAppBar(title: account.bankName),
          bottomNavigationBar: HBStickyBottomBar(
            outLabel: bankTr('bank.withdraw'),
            inLabel: bankTr('bank.deposit'),
            onOut: () => _openTxnSheet(false),
            onIn: () => _openTxnSheet(true),
          ),
          body: ValueListenableBuilder<Box<BankTxn>>(
            valueListenable: HiveService.bankTxns.listenable(),
            builder: (context, txnsBox, _) {
              final txns = txnsBox.values
                  .where((t) => t.bankAccountId == account.id)
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date));
              final closing = HiveService.bankBalance(account.id);
              final hide = HiveService.hideBalances;
              final isDark =
                  Theme.of(context).brightness == Brightness.dark;

              // Running balance per row (newest first): walk back from closing.
              final runningAt = <String, double>{};
              var cursor = closing;
              for (final t in txns) {
                runningAt[t.id] = cursor;
                cursor += t.direction == 'deposit' ? -t.amount : t.amount;
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Card(
                      elevation: 2,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      color: isDark ? HBColors.cardDark : HBColors.card,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: isDark
                                  ? HBColors.primarySoftDark
                                  : HBColors.primarySoft,
                              child: const Icon(Icons.account_balance,
                                  color: HBColors.primary, size: 26),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(account.title,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis),
                                  if (account.accountNo.isNotEmpty)
                                    Text(account.accountNo,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? HBColors.mutedDark
                                                : HBColors.muted)),
                                  const SizedBox(height: 4),
                                  Text(bankTr('bank.balance'),
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? HBColors.mutedDark
                                              : HBColors.muted)),
                                  HBAmountText(closing,
                                      isIn: closing >= 0,
                                      size: 20,
                                      hide: hide),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: txns.isEmpty
                        ? HBEmptyState(
                            icon: Icons.receipt_long,
                            title: bankTr('bank.noTxns'),
                            subtitle: bankTr('bank.noTxnsSub'),
                          )
                        : ListView.separated(
                            padding:
                                const EdgeInsets.only(top: 4, bottom: 16),
                            itemCount: txns.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, indent: 72),
                            itemBuilder: (context, i) {
                              final t = txns[i];
                              final isDep = t.direction == 'deposit';
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: moneySoft(isDep,
                                            isDark: isDark),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        isDep
                                            ? Icons.arrow_downward
                                            : Icons.arrow_upward,
                                        color: moneyColor(isDep),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.detail.isEmpty
                                                ? (isDep
                                                    ? bankTr('bank.deposit')
                                                    : bankTr(
                                                        'bank.withdraw'))
                                                : t.detail,
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${t.date.day}/${t.date.month}/${t.date.year}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? HBColors.mutedDark
                                                    : HBColors.muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        HBAmountText(t.amount,
                                            isIn: isDep, size: 15),
                                        const SizedBox(height: 2),
                                        Text(
                                          hide
                                              ? '••••••'
                                              : formatPKR(
                                                  runningAt[t.id] ?? 0),
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
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
