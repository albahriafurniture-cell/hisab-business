import 'package:uuid/uuid.dart';

import '../data/hive_service.dart';
import '../data/models.dart';

/// Stock Book data layer. Thin helpers over the Hive boxes owned by
/// [HiveService]; UI never touches the boxes directly.
abstract final class StockService {
  static final _uuid = Uuid();

  /// Create a new [StockItem] and persist it.
  static Future<StockItem> addItem({
    required String name,
    String unit = 'pcs',
    double buyPrice = 0,
    double sellPrice = 0,
    String barcode = '',
    String photoPath = '',
    double? lowStockAt,
  }) async {
    final now = DateTime.now();
    final item = StockItem(
      id: _uuid.v4(),
      name: name.trim(),
      unit: unit,
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      barcode: barcode.trim(),
      photoPath: photoPath,
      lowStockAt: lowStockAt,
      createdAt: now,
      updatedAt: now,
    );
    await HiveService.stockItems.put(item.id, item);
    return item;
  }

  /// Persist changes to an existing item (bumps [StockItem.updatedAt]).
  static Future<void> updateItem(StockItem item) async {
    item.updatedAt = DateTime.now();
    await HiveService.stockItems.put(item.id, item);
  }

  /// Delete an item and all of its movements.
  static Future<void> deleteItem(String itemId) async {
    for (final m in movementsForItem(itemId)) {
      await HiveService.stockMovements.delete(m.id);
    }
    await HiveService.stockItems.delete(itemId);
  }

  /// Record a stock movement ('in' | 'out').
  static Future<StockMovement> addMovement({
    required String itemId,
    required String direction,
    required double qty,
    double rate = 0,
    String partyId = '',
    String billNo = '',
    DateTime? date,
    String note = '',
  }) async {
    assert(direction == 'in' || direction == 'out');
    final now = DateTime.now();
    final m = StockMovement(
      id: _uuid.v4(),
      itemId: itemId,
      direction: direction,
      qty: qty,
      rate: rate,
      partyId: partyId,
      billNo: billNo.trim(),
      date: date ?? now,
      note: note.trim(),
      createdAt: now,
    );
    await HiveService.stockMovements.put(m.id, m);
    return m;
  }

  /// All movements of one item, newest first.
  static List<StockMovement> movementsForItem(String itemId) {
    final list = HiveService.stockMovements.values
        .where((m) => m.itemId == itemId)
        .toList()
      ..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
      });
    return list;
  }

  /// Current quantity of one item: Σ in − Σ out.
  static double qtyOf(String itemId) => HiveService.stockQty(itemId);

  /// Total stock value at buy price: Σ qty × buyPrice over all items.
  static double stockValuation() {
    double total = 0;
    for (final item in HiveService.stockItems.values) {
      total += HiveService.stockQty(item.id) * item.buyPrice;
    }
    return total;
  }

  /// Items whose quantity is at or below their alert level.
  static List<StockItem> lowStockItems() {
    final list = HiveService.stockItems.values
        .where((i) =>
            i.lowStockAt != null &&
            HiveService.stockQty(i.id) <= i.lowStockAt!)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// Last movement date of an item, or null when there is none.
  static DateTime? lastMovementDate(String itemId) {
    final list = movementsForItem(itemId);
    return list.isEmpty ? null : list.first.date;
  }

  /// Compact quantity text: drops trailing zeros ("10", "2.5").
  static String formatQty(double qty) {
    var s = qty.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s.isEmpty ? '0' : s;
  }

  /// Short date like "28 Sep 2026".
  static String formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// Initials for the avatar circle ("Sugar 1kg" → "S1").
  static String initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String first(String s) => String.fromCharCode(s.runes.first);
    if (parts.length == 1) {
      final runes = parts.first.runes.take(2).toList();
      return String.fromCharCodes(runes).toUpperCase();
    }
    return (first(parts[0]) + first(parts[1])).toUpperCase();
  }
}
