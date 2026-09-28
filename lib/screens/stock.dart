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
import '../widgets/hb_cards.dart';
import '../widgets/hb_chrome.dart';
import '../widgets/hb_rows.dart';

/// Stock Book: item list with All Items / Low Stock tabs, summary card,
/// IN/OUT report pills, search, and an add-item FAB.
/// Route: [Routes.stock].
class StockScreen extends StatefulWidget {
  static const routeName = Routes.stock;

  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  int _tab = 0; // 0 = all, 1 = low stock
  int _sort = 0; // 0 name, 1 qty desc, 2 qty asc, 3 recent
  String _query = '';

  @override
  Widget build(BuildContext context) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final all = HiveService.stockItems.values.toList();
    final lowCount = StockService.lowStockItems().length;

    var items = _tab == 1 ? StockService.lowStockItems() : all;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      items = items.where((i) => i.name.toLowerCase().contains(q)).toList();
    }
    items = _sortItems(items);

    return Scaffold(
      appBar: HBAppBar(title: stockTr('stock.title')),
      body: Column(
        children: [
          HBTabs(
            labels: [
              stockTr('stock.allItems'),
              '${stockTr('stock.lowStock')} ($lowCount)',
            ],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          Expanded(
            child: items.isEmpty
                ? HBEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: stockTr(_tab == 1
                        ? 'stock.emptyLowTitle'
                        : 'stock.emptyTitle'),
                    subtitle: stockTr(_tab == 1
                        ? 'stock.emptyLowSubtitle'
                        : 'stock.emptySubtitle'),
                    ctaLabel: _tab == 0 ? stockTr('stock.addItem') : null,
                    onCta: _tab == 0 ? _goAdd : null,
                  )
                : ListView(
                    padding: const EdgeInsets.only(
                        left: 16, right: 16, top: 12, bottom: 96),
                    children: [
                      HBSummaryCard(
                        stats: [
                          HBStat(stockTr('stock.totalItems'),
                              '${all.length}', true),
                        ],
                        actionLabel: stockTr('stock.report'),
                        onAction: () => Navigator.of(context)
                            .pushNamed(Routes.reports),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _reportPill(
                            context,
                            label: stockTr('stock.inReport'),
                            icon: Icons.arrow_downward,
                            tint: HBColors.moneyIn,
                            onTap: () => Navigator.of(context).pushNamed(
                              Routes.reports,
                              arguments: const {'stockDirection': 'in'},
                            ),
                          ),
                          const SizedBox(width: 12),
                          _reportPill(
                            context,
                            label: stockTr('stock.outReport'),
                            icon: Icons.arrow_upward,
                            tint: HBColors.moneyOut,
                            onTap: () => Navigator.of(context).pushNamed(
                              Routes.reports,
                              arguments: const {'stockDirection': 'out'},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      HBSearchRow(
                        hint: stockTr('stock.searchHint'),
                        onChanged: (v) =>
                            setState(() => _query = v.trim()),
                        onFilter: () => _showSortSheet(context),
                        onPdf: () => Navigator.of(context)
                            .pushNamed(Routes.reports),
                      ),
                      const SizedBox(height: 4),
                      for (final item in items) ...[
                        _itemRow(context, item, isDark),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: HBFab(
        label: stockTr('stock.addItem'),
        icon: Icons.add,
        onPressed: _goAdd,
      ),
    );
  }

  List<StockItem> _sortItems(List<StockItem> items) {
    final list = List<StockItem>.from(items);
    switch (_sort) {
      case 1:
        list.sort((a, b) => StockService.qtyOf(b.id)
            .compareTo(StockService.qtyOf(a.id)));
      case 2:
        list.sort((a, b) => StockService.qtyOf(a.id)
            .compareTo(StockService.qtyOf(b.id)));
      case 3:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      default:
        list.sort((a, b) => a.name.compareTo(b.name));
    }
    return list;
  }

  void _goAdd() => Navigator.of(context).pushNamed(Routes.stockItemAdd);

  /// [INFERRED] Tinted outlined pill button (green IN / red OUT).
  Widget _reportPill(BuildContext context,
      {required String label,
      required IconData icon,
      required Color tint,
      required VoidCallback onTap}) {
    return Expanded(
      child: Theme(
        data: Theme.of(context).copyWith(
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: tint,
              side: BorderSide(color: tint, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        child: HBPillButton(
          label: label,
          icon: icon,
          outlined: true,
          onPressed: onTap,
        ),
      ),
    );
  }

  /// [INFERRED] Item row: initials avatar · name + last-movement date ·
  /// right green qty + unit. Low-stock rows get an amber highlight.
  Widget _itemRow(BuildContext context, StockItem item, bool isDark) {
    final qty = StockService.qtyOf(item.id);
    final low = item.lowStockAt != null && qty <= item.lowStockAt!;
    final last = StockService.lastMovementDate(item.id);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context)
          .pushNamed(Routes.stockItem, arguments: {'itemId': item.id}),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: low
              ? (isDark
                  ? const Color(0xFF3A2C12)
                  : const Color(0xFFFFF6E5))
              : (isDark ? HBColors.cardDark : HBColors.card),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: low
                ? Colors.amber.shade700
                : (isDark ? HBColors.hairlineDark : HBColors.hairline),
            width: low ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  low ? Colors.amber.shade100 : HBColors.primarySoft,
              foregroundColor:
                  low ? Colors.amber.shade900 : HBColors.primary,
              child: Text(
                StockService.initials(item.name),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    last == null
                        ? '—'
                        : StockService.formatDate(last),
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? HBColors.mutedDark : HBColors.muted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  StockService.formatQty(qty),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: HBColors.moneyIn,
                  ),
                ),
                Text(item.unit,
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? HBColors.mutedDark : HBColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    final options = [
      stockTr('stock.sortName'),
      stockTr('stock.sortQtyHigh'),
      stockTr('stock.sortQtyLow'),
      stockTr('stock.sortRecent'),
    ];
    showHBSheet<void>(
      context,
      title: stockTr('stock.filterTitle'),
      child: RadioGroup<int>(
        groupValue: _sort,
        onChanged: (v) {
          setState(() => _sort = v ?? 0);
          Navigator.of(context).pop();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < options.length; i++)
              RadioListTile<int>(
                value: i,
                title: Text(options[i]),
                activeColor: HBColors.primary,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
