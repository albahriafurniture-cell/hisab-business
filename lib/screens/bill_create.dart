import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

/// Editable line item while a bill is being drafted.
class _DraftItem {
  String itemId; // '' for manual entries
  String name;
  String unit;
  double qty;
  double rate;

  _DraftItem({
    required this.itemId,
    required this.name,
    this.unit = 'pcs',
    this.qty = 1,
    this.rate = 0,
  });

  double get total => qty * rate;
}

/// Create a new bill: auto bill number, date, optional party, line items
/// (from stock or manual), tax %, discount, note. Saves as `due` and opens
/// the invoice preview.
class BillCreateScreen extends StatefulWidget {
  const BillCreateScreen({super.key});

  @override
  State<BillCreateScreen> createState() => _BillCreateScreenState();
}

class _BillCreateScreenState extends State<BillCreateScreen> {
  late String _billNo;
  DateTime _date = DateTime.now();
  String _partyId = '';
  final List<_DraftItem> _items = [];
  final _taxCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  double _taxPct = 0;
  double _discount = 0;

  @override
  void initState() {
    super.initState();
    _billNo = BillingService.nextBillNo();
    _taxCtrl.addListener(_parseTaxDiscount);
    _discountCtrl.addListener(_parseTaxDiscount);
  }

  @override
  void dispose() {
    _taxCtrl.dispose();
    _discountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _parseTaxDiscount() {
    setState(() {
      _taxPct = double.tryParse(_taxCtrl.text.trim()) ?? 0;
      _discount = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    });
  }

  double get _subtotal =>
      _items.fold<double>(0, (sum, i) => sum + i.total);
  double get _taxAmount => _subtotal * (_taxPct < 0 ? 0 : _taxPct) / 100;
  double get _grandTotal {
    final g = _subtotal + _taxAmount - (_discount < 0 ? 0 : _discount);
    return g < 0 ? 0 : g;
  }

  Party? get _party =>
      _partyId.isEmpty ? null : HiveService.parties.get(_partyId);

  // ------------------------------------------------------------------ party
  Future<void> _pickParty() async {
    final picked = await showHBSheet<String>(
      context,
      title: billingTr('billing.pickParty'),
      child: _PartyPickerSheet(selectedId: _partyId),
    );
    if (picked != null && mounted) {
      setState(() => _partyId = picked == '__none__' ? '' : picked);
    }
  }

  // ------------------------------------------------------------------ items
  Future<void> _addItemSheet() async {
    await showHBSheet<void>(
      context,
      title: billingTr('billing.addItem'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined,
                color: HBColors.primary),
            title: Text(billingTr('billing.fromStock')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(context);
              _addFromStockSheet();
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined,
                color: HBColors.primary),
            title: Text(billingTr('billing.manual')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(context);
              _manualItemSheet();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addFromStockSheet() async {
    final picked = await showHBSheet<StockItem>(
      context,
      title: billingTr('billing.fromStock'),
      child: ValueListenableBuilder<Box<StockItem>>(
        valueListenable: HiveService.stockItems.listenable(),
        builder: (context, box, _) {
          final items = box.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          if (items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(billingTr('billing.noStockItems'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: HBColors.muted)),
            );
          }
          return SizedBox(
            height: 320,
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text(
                      '${item.unit} • ${formatPKR(item.sellPrice)}'),
                  trailing: const Icon(Icons.add_circle_outline,
                      color: HBColors.primary),
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
          );
        },
      ),
    );
    if (picked != null && mounted) {
      setState(() => _items.add(_DraftItem(
            itemId: picked.id,
            name: picked.name,
            unit: picked.unit,
            qty: 1,
            rate: picked.sellPrice,
          )));
    }
  }

  Future<void> _manualItemSheet() async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final rateCtrl = TextEditingController();
    final added = await showHBSheet<_DraftItem>(
      context,
      title: billingTr('billing.manual'),
      child: StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: billingTr('billing.itemName'),
                hintText: billingTr('billing.itemNameHint'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setSheetState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]'))
                    ],
                    decoration: InputDecoration(
                      labelText: billingTr('billing.qty'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]'))
                    ],
                    decoration: InputDecoration(
                      labelText: billingTr('billing.rate'),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            HBPillButton(
              label: billingTr('billing.addItem'),
              icon: Icons.add,
              onPressed: nameCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(
                      context,
                      _DraftItem(
                        itemId: '',
                        name: nameCtrl.text.trim(),
                        qty: double.tryParse(qtyCtrl.text.trim()) ?? 1,
                        rate:
                            double.tryParse(rateCtrl.text.trim()) ?? 0,
                      )),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    qtyCtrl.dispose();
    rateCtrl.dispose();
    if (added != null && mounted) {
      setState(() => _items.add(added));
    }
  }

  /// Tap a qty/rate value to type an exact number.
  Future<void> _editValue(
      String title, double current, ValueChanged<double> onSet) async {
    final ctrl = TextEditingController(
        text: current == current.roundToDouble()
            ? current.toInt().toString()
            : current.toString());
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
          ],
          decoration: const InputDecoration(
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(billingTr('billing.clear')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
                context, double.tryParse(ctrl.text.trim())),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && result >= 0 && mounted) {
      setState(() => onSet(result));
    }
  }

  // -------------------------------------------------------------------- save
  Future<void> _save() async {
    if (_items.isEmpty) {
      HBToast.show(context,
          message: billingTr('billing.needItem'),
          icon: Icons.info_outline,
          tint: HBColors.primarySoft);
      return;
    }
    final items = _items
        .map((d) => BillItem(
              itemId: d.itemId,
              name: d.name,
              qty: d.qty,
              rate: d.rate,
              total: d.total,
            ))
        .toList();
    final bill = await BillingService.createBill(
      items: items,
      partyId: _partyId,
      date: _date,
      taxPct: _taxPct,
      discount: _discount,
      note: _noteCtrl.text.trim(),
    );
    if (!mounted) return;
    HBToast.show(context,
        message: billingTr('billing.saved'), icon: Icons.check_circle);
    Navigator.pushReplacementNamed(context, Routes.billPreview,
        arguments: {'billId': bill.id});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  // ------------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, lang, _) {
        final isDark =
            Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          appBar: HBAppBar(title: billingTr('billing.createNew')),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // -- bill no + date -----------------------------------
                    Row(
                      children: [
                        Expanded(
                          child: _InfoTile(
                            label: billingTr('billing.billNo'),
                            value: _billNo,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _pickDate,
                            child: _InfoTile(
                              label: billingTr('billing.date'),
                              value: BillingService.formatDate(_date),
                              trailing:
                                  const Icon(Icons.calendar_month_outlined,
                                      size: 18,
                                      color: HBColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // -- party --------------------------------------------
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _pickParty,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: isDark
                                  ? Colors.white24
                                  : Colors.black12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline,
                                color: HBColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      billingTr(
                                          'billing.partyOptional'),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: HBColors.muted)),
                                  Text(
                                    _party?.name ??
                                        billingTr('billing.noParty'),
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            if (_partyId.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () =>
                                    setState(() => _partyId = ''),
                              ),
                            const Icon(Icons.chevron_right,
                                color: HBColors.muted),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // -- items --------------------------------------------
                    HBSectionLabel(
                      billingTr('billing.addItem'),
                      trailing: Text(
                        billingItemsLabel(_items.length),
                        style: const TextStyle(
                            fontSize: 12, color: HBColors.muted),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _items.length; i++)
                      Dismissible(
                        key: ValueKey('draft_$i'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding:
                              const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: HBColors.moneyOutDeep,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete_outline,
                              color: Colors.white),
                        ),
                        onDismissed: (_) =>
                            setState(() => _items.removeAt(i)),
                        child: _ItemRow(
                          item: _items[i],
                          onChanged: () => setState(() {}),
                          onEditQty: () => _editValue(
                              billingTr('billing.qty'),
                              _items[i].qty,
                              (v) => _items[i].qty =
                                  v < 0.01 ? 0.01 : v),
                          onEditRate: () => _editValue(
                              billingTr('billing.rate'),
                              _items[i].rate,
                              (v) => _items[i].rate = v),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: _addItemSheet,
                      icon: const Icon(Icons.add),
                      label: Text(billingTr('billing.addItem')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HBColors.primary,
                        side: const BorderSide(
                            color: HBColors.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 13),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // -- totals -------------------------------------------
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14)),
                      color:
                          isDark ? HBColors.cardDark : HBColors.card,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            _TotalLine(
                              label: billingTr('billing.subtotal'),
                              value: formatPKR(_subtotal),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                    child: Text(
                                        billingTr(
                                            'billing.taxPct'),
                                        style: const TextStyle(
                                            fontSize: 14))),
                                SizedBox(
                                  width: 90,
                                  child: TextField(
                                    controller: _taxCtrl,
                                    keyboardType:
                                        const TextInputType
                                            .numberWithOptions(
                                                decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter
                                          .allow(RegExp(r'[0-9.]'))
                                    ],
                                    textAlign: TextAlign.end,
                                    decoration:
                                        const InputDecoration(
                                      isDense: true,
                                      border:
                                          OutlineInputBorder(),
                                      contentPadding:
                                          EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                    child: Text(
                                        billingTr(
                                            'billing.discount'),
                                        style: const TextStyle(
                                            fontSize: 14))),
                                SizedBox(
                                  width: 120,
                                  child: TextField(
                                    controller: _discountCtrl,
                                    keyboardType:
                                        const TextInputType
                                            .numberWithOptions(
                                                decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter
                                          .allow(RegExp(r'[0-9.]'))
                                    ],
                                    textAlign: TextAlign.end,
                                    decoration:
                                        const InputDecoration(
                                      isDense: true,
                                      border:
                                          OutlineInputBorder(),
                                      contentPadding:
                                          EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            _TotalLine(
                              label:
                                  billingTr('billing.grandTotal'),
                              value: formatPKR(_grandTotal),
                              big: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteCtrl,
                      maxLines: 2,
                      textCapitalization:
                          TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: billingTr('billing.note'),
                        hintText: billingTr('billing.noteHint'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
          bottomSheet: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: HBPillButton(
                label: billingTr('billing.saveBill'),
                icon: Icons.check,
                onPressed: _save,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoTile(
      {required this.label, required this.value, this.trailing});

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: HBColors.muted)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  final String label;
  final String value;
  final bool big;

  const _TotalLine(
      {required this.label, required this.value, this.big = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: big ? 16 : 14,
                fontWeight:
                    big ? FontWeight.bold : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                fontSize: big ? 20 : 14,
                fontWeight: FontWeight.bold,
                color: big ? HBColors.primaryDeep : null)),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final _DraftItem item;
  final VoidCallback onChanged;
  final VoidCallback onEditQty;
  final VoidCallback onEditRate;

  const _ItemRow({
    required this.item,
    required this.onChanged,
    required this.onEditQty,
    required this.onEditRate,
  });

  String _num(double v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toString();

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? HBColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
              Text(formatPKR(item.total),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: HBColors.primaryDeep)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Stepper(
                label: billingTr('billing.qty'),
                value: _num(item.qty),
                onMinus: item.qty <= 1
                    ? null
                    : () {
                        item.qty -= 1;
                        onChanged();
                      },
                onPlus: () {
                  item.qty += 1;
                  onChanged();
                },
                onTapValue: onEditQty,
              ),
              const SizedBox(width: 10),
              _Stepper(
                label: billingTr('billing.rate'),
                value: _num(item.rate),
                onMinus: item.rate <= 0
                    ? null
                    : () {
                        item.rate =
                            (item.rate - 10).clamp(0, double.infinity);
                        onChanged();
                      },
                onPlus: () {
                  item.rate += 10;
                  onChanged();
                },
                onTapValue: onEditRate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;
  final VoidCallback onTapValue;

  const _Stepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.onTapValue,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: HBColors.muted)),
          const SizedBox(height: 2),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _StepBtn(
                    icon: Icons.remove,
                    onTap: onMinus),
                Expanded(
                  child: InkWell(
                    onTap: onTapValue,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8),
                      child: Text(value,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                _StepBtn(icon: Icons.add, onTap: onPlus),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon,
            size: 16,
            color: onTap == null
                ? HBColors.muted.withValues(alpha: 0.4)
                : HBColors.primary),
      ),
    );
  }
}

/// Party picker bottom-sheet content with search.
class _PartyPickerSheet extends StatefulWidget {
  final String selectedId;

  const _PartyPickerSheet({required this.selectedId});

  @override
  State<_PartyPickerSheet> createState() => _PartyPickerSheetState();
}

class _PartyPickerSheetState extends State<_PartyPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          autofocus: false,
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            hintText: billingTr('billing.searchParty'),
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: ValueListenableBuilder<Box<Party>>(
            valueListenable: HiveService.parties.listenable(),
            builder: (context, box, _) {
              final q = _q.trim().toLowerCase();
              final parties = HiveService.activeParties()
                  .where((p) =>
                      q.isEmpty ||
                      p.name.toLowerCase().contains(q) ||
                      p.phone.contains(q))
                  .toList();
              return ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_off_outlined,
                        color: HBColors.muted),
                    title: Text(billingTr('billing.noParty')),
                    onTap: () =>
                        Navigator.pop(context, '__none__'),
                  ),
                  const Divider(height: 8),
                  for (final p in parties)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: HBColors.primarySoft,
                        child: Text(
                          p.name.isEmpty
                              ? '?'
                              : p.name.characters.first.toUpperCase(),
                          style: const TextStyle(
                              color: HBColors.primaryDeep,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(p.name),
                      subtitle: p.phone.isEmpty
                          ? null
                          : Text(p.phone),
                      trailing: p.id == widget.selectedId
                          ? const Icon(Icons.check_circle,
                              color: HBColors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, p.id),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
