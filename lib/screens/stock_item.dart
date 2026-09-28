import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../l10n/stock_l10n.dart';
import '../l10n/strings.dart';
import '../routes.dart';
import '../services/stock_service.dart';
import '../theme.dart';
import '../widgets/hb_actions.dart';
import '../widgets/hb_chrome.dart';

/// Stock item detail: header card (prices, qty, low-stock warning),
/// Stock IN / OUT buttons, and the movement ledger with running qty.
/// Route: [Routes.stockItem], arguments `{'itemId': id}`.
class StockItemScreen extends StatefulWidget {
  static const routeName = Routes.stockItem;

  final String? itemId;

  const StockItemScreen({super.key, this.itemId});

  @override
  State<StockItemScreen> createState() => _StockItemScreenState();
}

class _StockItemScreenState extends State<StockItemScreen> {
  String? _itemId;
  bool _loaded = false;

  void _loadArgs(BuildContext context) {
    if (_loaded) return;
    _loaded = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    _itemId =
        widget.itemId ?? (args is Map ? args['itemId'] as String? : null);
  }

  @override
  Widget build(BuildContext context) {
    _loadArgs(context);
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, lang, _) =>
          ValueListenableBuilder<Box<StockItem>>(
        valueListenable: HiveService.stockItems.listenable(),
        builder: (context, itemsBox, _) =>
            ValueListenableBuilder<Box<StockMovement>>(
          valueListenable: HiveService.stockMovements.listenable(),
          builder: (context, movBox, _) => _build(context),
        ),
      ),
    );
  }

  Widget _build(BuildContext context) {
    final item =
        _itemId == null ? null : HiveService.stockItems.get(_itemId);
    if (item == null) {
      return Scaffold(
        appBar: HBAppBar(title: stockTr('stock.title')),
        body: Center(child: Text(stockTr('stock.emptyTitle'))),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final qty = StockService.qtyOf(item.id);
    final low = item.lowStockAt != null && qty <= item.lowStockAt!;
    final movements = StockService.movementsForItem(item.id);

    return Scaffold(
      appBar: HBAppBar(
        title: item.name,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            tooltip: stockTr('stock.editItem'),
            onPressed: () => Navigator.of(context).pushNamed(
              Routes.stockItemAdd,
              arguments: {'itemId': item.id},
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: stockTr('stock.deleteItem'),
            onPressed: () => _confirmDelete(context, item),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _headerCard(context, item, qty, low, isDark),
                const SizedBox(height: 20),
                Text(stockTr('stock.movements'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (movements.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 40,
                            color: isDark
                                ? HBColors.mutedDark
                                : HBColors.muted),
                        const SizedBox(height: 8),
                        Text(stockTr('stock.noMovements'),
                            style: TextStyle(
                                color: isDark
                                    ? HBColors.mutedDark
                                    : HBColors.muted)),
                        const SizedBox(height: 4),
                        Text(stockTr('stock.noMovementsHint'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? HBColors.mutedDark
                                    : HBColors.muted)),
                      ],
                    ),
                  )
                else
                  _ledger(context, item, movements, isDark),
              ],
            ),
          ),
          HBStickyBottomBar(
            outLabel: stockTr('stock.stockOut'),
            inLabel: stockTr('stock.stockIn'),
            onOut: () => _movementSheet(context, item, 'out'),
            onIn: () => _movementSheet(context, item, 'in'),
          ),
        ],
      ),
    );
  }

  /// [INFERRED] Header card: big qty, buy/sell prices, low-stock chip.
  Widget _headerCard(BuildContext context, StockItem item, double qty,
      bool low, bool isDark) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? HBColors.cardDark : HBColors.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: low
                      ? Colors.amber.shade100
                      : HBColors.primarySoft,
                  foregroundColor: low
                      ? Colors.amber.shade900
                      : HBColors.primary,
                  child: Text(
                    StockService.initials(item.name),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(item.unit,
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? HBColors.mutedDark
                                  : HBColors.muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      StockService.formatQty(qty),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: HBColors.moneyIn,
                      ),
                    ),
                    Text(item.unit,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? HBColors.mutedDark
                                : HBColors.muted)),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                    child: _priceTile(context, stockTr('stock.buyPrice'),
                        item.buyPrice, isDark)),
                Expanded(
                    child: _priceTile(context, stockTr('stock.sellPrice'),
                        item.sellPrice, isDark)),
              ],
            ),
            if (low) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: Colors.amber.shade900),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        stockTr('stock.lowStockWarning'),
                        style: TextStyle(
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _priceTile(
      BuildContext context, String label, double amount, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: isDark ? HBColors.mutedDark : HBColors.muted)),
        const SizedBox(height: 2),
        Text(formatPKR(amount),
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  /// [INFERRED] Ledger: dated movement rows (green in / red out) with a
  /// running balance column, newest first.
  Widget _ledger(BuildContext context, StockItem item,
      List<StockMovement> movements, bool isDark) {
    double running = StockService.qtyOf(item.id);
    final rows = <Widget>[];
    for (final m in movements) {
      final isIn = m.direction == 'in';
      final after = running;
      rows.add(_movementRow(context, m, item.unit, after, isDark, isIn));
      running += isIn ? -m.qty : m.qty; // rewind to previous balance
      rows.add(const SizedBox(height: 8));
    }
    return Column(children: rows);
  }

  Widget _movementRow(BuildContext context, StockMovement m, String unit,
      double balanceAfter, bool isDark, bool isIn) {
    final color = isIn ? HBColors.moneyIn : HBColors.moneyOut;
    final partyName = m.partyId.isEmpty
        ? null
        : HiveService.parties.get(m.partyId)?.name;
    final subtitle = StringBuffer(StockService.formatDate(m.date));
    if (m.billNo.isNotEmpty) subtitle.write(' · ${m.billNo}');
    if (partyName != null) subtitle.write(' · $partyName');
    if (m.note.isNotEmpty) subtitle.write('\n${m.note}');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? HBColors.cardDark : HBColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? HBColors.hairlineDark : HBColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isIn
                  ? HBColors.moneyInSoft
                  : HBColors.moneyOutSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
                isIn ? Icons.arrow_downward : Icons.arrow_upward,
                color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isIn ? '+' : '−'}${StockService.formatQty(m.qty)} $unit',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
                const SizedBox(height: 2),
                Text(subtitle.toString(),
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? HBColors.mutedDark
                            : HBColors.muted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(stockTr('stock.runningQty'),
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? HBColors.mutedDark
                          : HBColors.muted)),
              Text(StockService.formatQty(balanceAfter),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  /// [INFERRED] Movement bottom sheet: qty, rate, party, bill no, date, note.
  void _movementSheet(
      BuildContext context, StockItem item, String direction) {
    final isIn = direction == 'in';
    final qtyCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    final billCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime date = DateTime.now();
    String partyId = '';
    final formKey = GlobalKey<FormState>();
    final parties = HiveService.activeParties();

    showHBSheet<void>(
      context,
      title:
          '${isIn ? stockTr('stock.stockIn') : stockTr('stock.stockOut')} — ${item.name}',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: qtyCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${stockTr('stock.qty')} (${item.unit})',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final q = double.tryParse(v?.trim() ?? '');
                  if (q == null) return stockTr('stock.qtyRequired');
                  if (q <= 0) return stockTr('stock.qtyInvalid');
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: rateCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: stockTr('stock.rate'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: stockTr('stock.party'),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: partyId,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                          value: '',
                          child: Text(stockTr('stock.noParty'))),
                      for (final p in parties)
                        DropdownMenuItem(
                            value: p.id, child: Text(p.name)),
                    ],
                    onChanged: (v) =>
                        setSheetState(() => partyId = v ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: billCtrl,
                      decoration: InputDecoration(
                        labelText: stockTr('stock.billNo'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setSheetState(() => date = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: stockTr('stock.date'),
                          border: const OutlineInputBorder(),
                        ),
                        child: Text(StockService.formatDate(date)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: stockTr('stock.note'),
                  hintText: stockTr('stock.noteHint'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await StockService.addMovement(
                      itemId: item.id,
                      direction: direction,
                      qty: double.parse(qtyCtrl.text.trim()),
                      rate:
                          double.tryParse(rateCtrl.text.trim()) ?? 0,
                      partyId: partyId,
                      billNo: billCtrl.text,
                      date: date,
                      note: noteCtrl.text,
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (context.mounted) {
                      HBToast.show(context,
                          message: stockTr('stock.movementSaved'),
                          icon: Icons.check);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isIn ? HBColors.moneyIn : HBColors.moneyOut,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                  ),
                  child: Text(stockTr('stock.save'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, StockItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(stockTr('stock.deleteConfirmTitle')),
        content: Text(stockTr('stock.deleteConfirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr(ctx, 'action.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: HBColors.moneyOut),
            child: Text(stockTr('stock.deleteItem')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await StockService.deleteItem(item.id);
      if (context.mounted) {
        HBToast.show(context,
            message: stockTr('stock.deleted'),
            icon: Icons.delete_outline);
        Navigator.of(context).pop();
      }
    }
  }
}
