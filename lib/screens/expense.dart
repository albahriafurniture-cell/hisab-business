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

/// Maps an expense [ExpenseCategory.iconKey] to a Material icon.
/// [INFERRED] — the seeded iconKeys come from the foundation seed list.
const Map<String, IconData> kExpenseIcons = {
  'rent': Icons.home,
  'salaries': Icons.payments,
  'utilities': Icons.electrical_services,
  'fuel': Icons.local_gas_station,
  'repairs': Icons.build,
  'marketing': Icons.campaign,
  'supplies': Icons.inventory_2,
  'transport': Icons.local_shipping,
  'taxes': Icons.receipt_long,
  'shopping': Icons.shopping_bag,
  'phone': Icons.phone_android,
  'health': Icons.local_hospital,
  'education': Icons.school,
  'other': Icons.category,
};

IconData expenseIconFor(String iconKey) =>
    kExpenseIcons[iconKey] ?? Icons.category;

/// Preset colors offered when creating a category. [INFERRED]
const List<int> kCategoryColors = [
  0xFFF59E0B,
  0xFF8B5CF6,
  0xFF38BDF8,
  0xFFEF4444,
  0xFFF97316,
  0xFFEC4899,
  0xFF22D3EE,
  0xFF2DD4BF,
  0xFF64748B,
  0xFF94A3B8,
  0xFF1E9E50,
  0xFFEB5E1C,
];

/// Expense book: category grid with per-category totals, per-category
/// ledgers, expense entry sheet, and category creation.
class ExpenseScreen extends StatelessWidget {
  const ExpenseScreen({super.key});

  Future<void> _openExpenseSheet(BuildContext context) async {
    final saved = await showHBSheet<bool>(
      context,
      title: cashTr(context, 'cash.addExpense'),
      child: const _ExpenseForm(),
    );
    if (saved == true && context.mounted) {
      HBToast.show(context,
          message: cashTr(context, 'cash.saved'), icon: Icons.check);
    }
  }

  Future<void> _openCategorySheet(BuildContext context) async {
    final saved = await showHBSheet<bool>(
      context,
      title: cashTr(context, 'cash.addCategory'),
      child: const _CategoryForm(),
    );
    if (saved == true && context.mounted) {
      HBToast.show(context,
          message: cashTr(context, 'cash.categorySaved'),
          icon: Icons.check);
    }
  }

  void _openLedger(BuildContext context, ExpenseCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CategoryLedgerScreen(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild all copy when the app language changes.
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, _, _) {
        // Rebuild when expenses, categories, or hide-balances change.
        return ListenableBuilder(
          listenable: Listenable.merge([
            HiveService.expenseEntries.listenable(),
            HiveService.expenseCategories.listenable(),
            HiveService.settings.listenable(),
          ]),
          builder: (context, _) {
            final hide = HiveService.hideBalances;
            final categories =
                HiveService.expenseCategories.values.toList()
                  ..sort((a, b) => a.name.compareTo(b.name));
            final totals = CashService.categoryTotals();
            final grandTotal = CashService.totalExpenses();
            final isDark =
                Theme.of(context).brightness == Brightness.dark;

            return Scaffold(
              appBar: HBAppBar(
                title: cashTr(context, 'cash.expenseTitle'),
                showBack: true,
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: HBSummaryCard(
                      stats: [
                        HBStat(
                            cashTr(context, 'cash.totalExpenses'),
                            hide
                                ? '••••••'
                                : formatPKR(grandTotal),
                            false), // expenses are money OUT -> red
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: HBSectionLabel(
                        cashTr(context, 'cash.categories')),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          16, 0, 16, 96),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: categories.length + 1,
                      itemBuilder: (context, i) {
                        if (i == categories.length) {
                          return _AddCategoryTile(
                            isDark: isDark,
                            onTap: () =>
                                _openCategorySheet(context),
                          );
                        }
                        final cat = categories[i];
                        return _CategoryTile(
                          category: cat,
                          total: totals[cat.id] ?? 0,
                          isDark: isDark,
                          hide: hide,
                          onTap: () => _openLedger(context, cat),
                        );
                      },
                    ),
                  ),
                ],
              ),
              floatingActionButton: HBFab(
                label: cashTr(context, 'cash.addExpense'),
                icon: Icons.add,
                onPressed: () => _openExpenseSheet(context),
              ),
            );
          },
        );
      },
    );
  }
}

/// Grid tile: category icon on a tinted disc, name, lifetime total.
class _CategoryTile extends StatelessWidget {
  final ExpenseCategory category;
  final double total;
  final bool isDark;
  final bool hide;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.total,
    required this.isDark,
    required this.hide,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(category.color);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? HBColors.cardDark : HBColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  isDark ? HBColors.hairlineDark : HBColors.hairline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(expenseIconFor(category.iconKey),
                  color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              expenseCategoryLabel(context, category),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            HBAmountText(total,
                isIn: false, size: 12, hide: hide),
          ],
        ),
      ),
    );
  }
}

/// Last grid tile: dashed-style "new category" entry point. [INFERRED]
class _AddCategoryTile extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _AddCategoryTile({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? HBColors.hairlineDark : HBColors.hairline,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline,
                color: HBColors.primary, size: 32),
            const SizedBox(height: 8),
            Text(
              cashTr(context, 'cash.addCategory'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: HBColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-category ledger: total + entries grouped by day. [INFERRED]
class _CategoryLedgerScreen extends StatelessWidget {
  final ExpenseCategory category;

  const _CategoryLedgerScreen({required this.category});

  Map<DateTime, List<ExpenseEntry>> _groupByDay(
      List<ExpenseEntry> entries) {
    final map = <DateTime, List<ExpenseEntry>>{};
    for (final e in entries) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      map.putIfAbsent(d, () => []).add(e);
    }
    final ordered = map.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return Map.fromEntries(ordered);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, _, _) {
        return ListenableBuilder(
          listenable: Listenable.merge([
            HiveService.expenseEntries.listenable(),
            HiveService.settings.listenable(),
          ]),
          builder: (context, _) {
            final hide = HiveService.hideBalances;
            final entries =
                CashService.expensesForCategory(category.id);
            final total =
                entries.fold<double>(0, (s, e) => s + e.amount);
            final groups = _groupByDay(entries);

            return Scaffold(
              appBar: HBAppBar(
                title:
                    expenseCategoryLabel(context, category),
                showBack: true,
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: HBSummaryCard(
                      stats: [
                        HBStat(
                            cashTr(context, 'cash.totalExpenses'),
                            hide
                                ? '••••••'
                                : formatPKR(total),
                            false),
                        HBStat(
                            cashTr(context, 'cash.entries'),
                            hide
                                ? '••••••'
                                : entries.length.toString(),
                            false),
                      ],
                    ),
                  ),
                  Expanded(
                    child: entries.isEmpty
                        ? HBEmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: cashTr(
                                context, 'cash.noExpenses'),
                            subtitle: cashTr(context,
                                'cash.noExpensesHint'),
                          )
                        : ListView(
                            children: [
                              for (final day
                                  in groups.keys) ...[
                                _LedgerDayHeader(
                                    day: day,
                                    entries: groups[day]!,
                                    hide: hide),
                                for (final e
                                    in groups[day]!)
                                  _ExpenseEntryRow(
                                      entry: e, hide: hide),
                                const Divider(
                                    height: 1, indent: 16),
                              ],
                              const SizedBox(height: 24),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Day divider inside the ledger: weekday date + that day's total.
class _LedgerDayHeader extends StatelessWidget {
  final DateTime day;
  final List<ExpenseEntry> entries;
  final bool hide;

  const _LedgerDayHeader(
      {required this.day, required this.entries, required this.hide});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = entries.fold<double>(0, (s, e) => s + e.amount);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      color: isDark ? HBColors.pageDark : HBColors.page,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('EEE, d MMM yyyy')
                .format(day)
                .toUpperCase(),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold),
          ),
          HBAmountText(total, isIn: false, size: 13, hide: hide),
        ],
      ),
    );
  }
}

/// One expense row: time left, detail middle, amount right (red).
class _ExpenseEntryRow extends StatelessWidget {
  final ExpenseEntry entry;
  final bool hide;

  const _ExpenseEntryRow({required this.entry, required this.hide});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? HBColors.mutedDark : HBColors.muted;
    final title = entry.detail.isNotEmpty
        ? entry.detail
        : cashTr(context, 'cash.addExpense');
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
            child: Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          if (entry.photoPath.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Icon(Icons.receipt_long, size: 18, color: muted),
            ),
          HBAmountText(entry.amount,
              isIn: false, size: 16, hide: hide),
        ],
      ),
    );
  }
}

/// Bottom-sheet form for a new expense entry. [INFERRED] layout.
class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm();

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _amountCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();
  String? _categoryId;
  DateTime _date = DateTime.now();
  String _photoPath = '';
  String? _amountError;

  @override
  void dispose() {
    _amountCtrl.dispose();
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
    if (amount == null || amount <= 0) {
      setState(() => _amountError =
          cashTr(context, 'cash.invalidAmount'));
      return;
    }
    if (_categoryId == null) return;
    await CashService.addExpense(
      categoryId: _categoryId!,
      amount: amount,
      date: _date,
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
    final categories = HiveService.expenseCategories.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    _categoryId ??= categories.isNotEmpty ? categories.first.id : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _categoryId,
          decoration: InputDecoration(
            labelText: cashTr(context, 'cash.selectCategory'),
            prefixIcon: const Icon(Icons.category_outlined),
          ),
          items: [
            for (final c in categories)
              DropdownMenuItem(
                value: c.id,
                child: Row(
                  children: [
                    Icon(expenseIconFor(c.iconKey),
                        size: 20, color: Color(c.color)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        expenseCategoryLabel(context, c),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (v) => setState(() => _categoryId = v),
        ),
        const SizedBox(height: 12),
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
          color: HBColors.moneyOut,
          onPressed:
              _categoryId == null ? null : _save,
        ),
      ],
    );
  }
}

/// Bottom-sheet form for creating a new expense category. [INFERRED]
class _CategoryForm extends StatefulWidget {
  const _CategoryForm();

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final _nameCtrl = TextEditingController();
  String _iconKey = 'other';
  int _color = kCategoryColors[9];
  String? _nameError;

  static const List<String> _iconChoices = [
    'rent',
    'salaries',
    'utilities',
    'fuel',
    'repairs',
    'marketing',
    'supplies',
    'transport',
    'taxes',
    'shopping',
    'phone',
    'health',
    'education',
    'other',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() =>
          _nameError = cashTr(context, 'cash.nameRequired'));
      return;
    }
    await CashService.addExpenseCategory(
      name: name,
      iconKey: _iconKey,
      color: _color,
    );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? HBColors.mutedDark : HBColors.muted;
    final color = Color(_color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: cashTr(context, 'cash.categoryName'),
            errorText: _nameError,
          ),
          onChanged: (_) {
            if (_nameError != null) {
              setState(() => _nameError = null);
            }
          },
        ),
        const SizedBox(height: 16),
        Text(cashTr(context, 'cash.icon'),
            style: TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final key in _iconChoices)
              InkWell(
                onTap: () => setState(() => _iconKey = key),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: key == _iconKey
                        ? color.withValues(alpha: 0.18)
                        : (isDark
                            ? HBColors.cardDark
                            : HBColors.page),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: key == _iconKey
                          ? color
                          : (isDark
                              ? HBColors.hairlineDark
                              : HBColors.hairline),
                      width: key == _iconKey ? 2 : 1,
                    ),
                  ),
                  child: Icon(expenseIconFor(key),
                      color:
                          key == _iconKey ? color : muted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(cashTr(context, 'cash.color'),
            style: TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in kCategoryColors)
              GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c == _color
                          ? (isDark ? Colors.white : HBColors.ink)
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: c == _color
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 20)
                      : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        HBPillButton(
          label: cashTr(context, 'cash.save'),
          icon: Icons.check,
          onPressed: _save,
        ),
      ],
    );
  }
}
