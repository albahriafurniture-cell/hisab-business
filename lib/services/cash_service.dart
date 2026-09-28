import 'package:uuid/uuid.dart';

import '../data/hive_service.dart';
import '../data/models.dart';

/// Service layer for the Cash book + Expense book feature.
///
/// All money math lives here; the screens only render. Cash semantics
/// (app-wide): 'in' = money IN (GREEN), 'out' = money OUT (RED).
/// [INFERRED] helper shapes below are crew-owned, not foundation.
typedef CashDayTotals = ({double inTotal, double outTotal});

class CashService {
  static final Uuid _uuid = Uuid();

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  // ------------------------------------------------------------------ cash

  /// Cash in hand right now: sum(in) − sum(out).
  static double cashInHand() => HiveService.cashInHand();

  /// All cash entries for the given calendar day, newest first.
  static List<CashEntry> entriesForDay(DateTime day) {
    final d = _dayOf(day);
    final list = HiveService.cashEntries.values
        .where((e) => _dayOf(e.date) == d)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// (inTotal, outTotal) for any calendar day.
  static CashDayTotals dayTotals(DateTime day) {
    double inTotal = 0, outTotal = 0;
    for (final e in entriesForDay(day)) {
      if (e.direction == 'in') {
        inTotal += e.amount;
      } else {
        outTotal += e.amount;
      }
    }
    return (inTotal: inTotal, outTotal: outTotal);
  }

  /// (inTotal, outTotal) for today.
  static CashDayTotals todayTotals() => dayTotals(DateTime.now());

  /// Net balance (in − out) for a calendar day.
  static double dayBalance(DateTime day) {
    final t = dayTotals(day);
    return t.inTotal - t.outTotal;
  }

  /// Distinct category names previously used in the cash book, for the
  /// entry-sheet suggestion list. [INFERRED]
  static List<String> categorySuggestions() {
    final seen = <String>[];
    for (final e in HiveService.cashEntries.values) {
      final c = e.category.trim();
      if (c.isNotEmpty && !seen.contains(c)) {
        seen.add(c);
      }
    }
    seen.sort();
    return seen;
  }

  /// Save a cash-book entry. Returns the new entry.
  static Future<CashEntry> addCashEntry({
    required String direction, // 'in' | 'out'
    required double amount,
    DateTime? date,
    String category = '',
    String partyId = '',
    String detail = '',
    String photoPath = '',
  }) async {
    if (direction != 'in' && direction != 'out') {
      throw ArgumentError('direction must be "in" or "out"');
    }
    if (amount <= 0) {
      throw ArgumentError('amount must be positive');
    }
    final now = DateTime.now();
    final entry = CashEntry(
      id: _uuid.v4(),
      direction: direction,
      amount: amount,
      date: date ?? now,
      category: category.trim(),
      partyId: partyId,
      detail: detail.trim(),
      photoPath: photoPath,
      createdAt: now,
    );
    await HiveService.cashEntries.put(entry.id, entry);
    return entry;
  }

  // --------------------------------------------------------------- expenses

  /// All expense entries for a category, newest first.
  static List<ExpenseEntry> expensesForCategory(String categoryId) {
    final list = HiveService.expenseEntries.values
        .where((e) => e.categoryId == categoryId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Total spent per category id.
  static Map<String, double> categoryTotals() {
    final totals = <String, double>{};
    for (final e in HiveService.expenseEntries.values) {
      totals.update(e.categoryId, (v) => v + e.amount,
          ifAbsent: () => e.amount);
    }
    return totals;
  }

  /// Total spent across all expense categories.
  static double totalExpenses() {
    double total = 0;
    for (final e in HiveService.expenseEntries.values) {
      total += e.amount;
    }
    return total;
  }

  /// Save an expense entry. Returns the new entry.
  static Future<ExpenseEntry> addExpense({
    required String categoryId,
    required double amount,
    DateTime? date,
    String detail = '',
    String photoPath = '',
  }) async {
    if (amount <= 0) {
      throw ArgumentError('amount must be positive');
    }
    final now = DateTime.now();
    final entry = ExpenseEntry(
      id: _uuid.v4(),
      categoryId: categoryId,
      amount: amount,
      date: date ?? now,
      detail: detail.trim(),
      photoPath: photoPath,
      createdAt: now,
    );
    await HiveService.expenseEntries.put(entry.id, entry);
    return entry;
  }

  /// Create a new expense category. [INFERRED]
  static Future<ExpenseCategory> addExpenseCategory({
    required String name,
    String iconKey = 'other',
    int color = 0xFF94A3B8,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('category name is required');
    }
    final category = ExpenseCategory(
      id: _uuid.v4(),
      name: trimmed,
      iconKey: iconKey,
      color: color,
    );
    await HiveService.expenseCategories.put(category.id, category);
    return category;
  }
}
