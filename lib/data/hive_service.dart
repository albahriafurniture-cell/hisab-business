import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import '../utils/app_paths.dart';

/// Central Hive access: boxes, seeding, queries, backup/restore.
///
/// Money-direction semantics (kept consistent app-wide for user familiarity):
/// - Khata ledger: 'gave' = you gave money (you will GET back → RED,
///   receivable); 'got' = you got money (you must GIVE → GREEN, payable).
/// - Cash book: 'in' = money IN (GREEN), 'out' = money OUT (RED).
/// - Party balance: positive = they owe YOU (receivable, red), negative =
///   you owe THEM (payable, green). See [partyBalance].
class HiveService {
  static const businessBox = 'business';
  static const partiesBox = 'parties';
  static const khataEntriesBox = 'khata_entries';
  static const cashEntriesBox = 'cash_entries';
  static const expenseCategoriesBox = 'expense_categories';
  static const expenseEntriesBox = 'expense_entries';
  static const stockItemsBox = 'stock_items';
  static const stockMovementsBox = 'stock_movements';
  static const staffBox = 'staff';
  static const attendanceBox = 'attendance';
  static const salaryPaymentsBox = 'salary_payments';
  static const billsBox = 'bills';
  static const bankAccountsBox = 'bank_accounts';
  static const bankTxnsBox = 'bank_txns';
  static const remindersBox = 'reminders';
  static const settingsBox = 'settings';

  static late Box<BusinessProfile> business;
  static late Box<Party> parties;
  static late Box<KhataEntry> khataEntries;
  static late Box<CashEntry> cashEntries;
  static late Box<ExpenseCategory> expenseCategories;
  static late Box<ExpenseEntry> expenseEntries;
  static late Box<StockItem> stockItems;
  static late Box<StockMovement> stockMovements;
  static late Box<StaffMember> staff;
  static late Box<AttendanceRecord> attendance;
  static late Box<SalaryPayment> salaryPayments;
  static late Box<Bill> bills;
  static late Box<BankAccount> bankAccounts;
  static late Box<BankTxn> bankTxns;
  static late Box<Reminder> reminders;
  static late Box settings;

  /// Diagnostic boot log. Diagnostic builds surface this on screen so a
  /// startup failure can be reported back exactly instead of guessing.
  static final List<String> bootLog = [];

  /// Which Hive path strategy ended up working: 'hand-rolled',
  /// 'initFlutter-fallback', 'initFlutter(web)'.
  static String initNote = 'not-started';

  static Future<void> init() async {
    bootLog.add('HiveService.init start');
    if (kIsWeb) {
      await Hive.initFlutter();
      initNote = 'initFlutter(web)';
      await _openBoxes();
      bootLog.add('init ok (web)');
      return;
    }
    // Strategy 1: hand-rolled dart:io path (no path_provider).
    try {
      final docsDir = await AppPaths.documentsDir();
      bootLog.add('hand-rolled dir=${docsDir.path}');
      Hive.init(docsDir.path);
      await _openBoxes();
      initNote = 'hand-rolled';
      bootLog.add('hand-rolled init ok');
      return;
    } catch (e, st) {
      bootLog.add('hand-rolled FAILED: $e');
      bootLog.add('$st');
    }
    // Strategy 2: Hive.initFlutter() via path_provider. The official Gradle
    // build bundles path_provider_android's JNI lib correctly (proven by the
    // working Hisab app), so this is a safe fallback on real devices.
    try {
      await Hive.close();
    } catch (_) {
      // nothing was open — fine
    }
    bootLog.add('trying Hive.initFlutter() fallback');
    await Hive.initFlutter();
    await _openBoxes();
    initNote = 'initFlutter-fallback';
    bootLog.add('fallback init ok');
  }

  /// Opens all boxes, registers adapters and seeds defaults.
  static Future<void> _openBoxes() async {
    _registerAdapters();
    business = await Hive.openBox<BusinessProfile>(businessBox);
    parties = await Hive.openBox<Party>(partiesBox);
    khataEntries = await Hive.openBox<KhataEntry>(khataEntriesBox);
    cashEntries = await Hive.openBox<CashEntry>(cashEntriesBox);
    expenseCategories =
        await Hive.openBox<ExpenseCategory>(expenseCategoriesBox);
    expenseEntries = await Hive.openBox<ExpenseEntry>(expenseEntriesBox);
    stockItems = await Hive.openBox<StockItem>(stockItemsBox);
    stockMovements = await Hive.openBox<StockMovement>(stockMovementsBox);
    staff = await Hive.openBox<StaffMember>(staffBox);
    attendance = await Hive.openBox<AttendanceRecord>(attendanceBox);
    salaryPayments = await Hive.openBox<SalaryPayment>(salaryPaymentsBox);
    bills = await Hive.openBox<Bill>(billsBox);
    bankAccounts = await Hive.openBox<BankAccount>(bankAccountsBox);
    bankTxns = await Hive.openBox<BankTxn>(bankTxnsBox);
    reminders = await Hive.openBox<Reminder>(remindersBox);
    settings = await Hive.openBox(settingsBox);
    await seedDefaults();
    bootLog.add('16 boxes open, defaults seeded');
  }

  static void registerAdapters() => _registerAdapters();

  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(BusinessProfileAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(PartyAdapter());
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(KhataEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(CashEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ExpenseCategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(ExpenseEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(StockItemAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(StockMovementAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(StaffMemberAdapter());
    }
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(AttendanceRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(SalaryPaymentAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(BillItemAdapter());
    }
    if (!Hive.isAdapterRegistered(12)) Hive.registerAdapter(BillAdapter());
    if (!Hive.isAdapterRegistered(13)) {
      Hive.registerAdapter(BankAccountAdapter());
    }
    if (!Hive.isAdapterRegistered(14)) {
      Hive.registerAdapter(BankTxnAdapter());
    }
    if (!Hive.isAdapterRegistered(15)) {
      Hive.registerAdapter(ReminderAdapter());
    }
  }

  // ---------------------------------------------------------------- seeding
  static Future<void> seedDefaults() async {
    if (expenseCategories.isEmpty) {
      for (final c in _defaultExpenseCategories()) {
        await expenseCategories.put(c.id, c);
      }
    }
    for (final e in [
      ('language', 'en'),
      ('hideBalances', false),
      ('biometricEnabled', false),
      ('themeMode', 'system'),
      ('firstRun', true),
    ]) {
      if (!settings.containsKey(e.$1)) {
        await settings.put(e.$1, e.$2);
      }
    }
  }

  static List<ExpenseCategory> _defaultExpenseCategories() {
    // [INFERRED] own category names — not copied from any competitor.
    const seed = [
      ('Shop Rent', 'rent', 0xFFF59E0B),
      ('Salaries', 'salaries', 0xFF8B5CF6),
      ('Utilities', 'utilities', 0xFF38BDF8),
      ('Fuel', 'fuel', 0xFFEF4444),
      ('Repairs', 'repairs', 0xFFF97316),
      ('Marketing', 'marketing', 0xFFEC4899),
      ('Supplies', 'supplies', 0xFF22D3EE),
      ('Transport', 'transport', 0xFF2DD4BF),
      ('Taxes', 'taxes', 0xFF64748B),
      ('Other', 'other', 0xFF94A3B8),
    ];
    final uuid = Uuid();
    return [
      for (final e in seed)
        ExpenseCategory(
            id: uuid.v4(), name: e.$1, iconKey: e.$2, color: e.$3),
    ];
  }

  /// Wipes everything and re-seeds (used by backup-restore and data reset).
  static Future<void> resetAll() async {
    await business.clear();
    await parties.clear();
    await khataEntries.clear();
    await cashEntries.clear();
    await expenseCategories.clear();
    await expenseEntries.clear();
    await stockItems.clear();
    await stockMovements.clear();
    await staff.clear();
    await attendance.clear();
    await salaryPayments.clear();
    await bills.clear();
    await bankAccounts.clear();
    await bankTxns.clear();
    await reminders.clear();
    await settings.clear();
    await seedDefaults();
  }

  // ----------------------------------------------------------------- queries
  /// Net balance for a party: positive = they owe you (receivable),
  /// negative = you owe them (payable).
  static double partyBalance(String partyId) {
    double bal = 0;
    for (final e in khataEntries.values) {
      if (e.partyId != partyId) continue;
      bal += e.direction == 'gave' ? e.amount : -e.amount;
    }
    return bal;
  }

  static List<KhataEntry> entriesForParty(String partyId) {
    final list =
        khataEntries.values.where((e) => e.partyId == partyId).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Cash in hand right now: sum(in) − sum(out).
  static double cashInHand() {
    double net = 0;
    for (final e in cashEntries.values) {
      net += e.direction == 'in' ? e.amount : -e.amount;
    }
    return net;
  }

  /// Current stock quantity of an item: sum(in qty) − sum(out qty).
  static double stockQty(String itemId) {
    double qty = 0;
    for (final m in stockMovements.values) {
      if (m.itemId != itemId) continue;
      qty += m.direction == 'in' ? m.qty : -m.qty;
    }
    return qty;
  }

  /// Bank account balance: sum(deposits) − sum(withdrawals).
  static double bankBalance(String bankAccountId) {
    double bal = 0;
    for (final t in bankTxns.values) {
      if (t.bankAccountId != bankAccountId) continue;
      bal += t.direction == 'deposit' ? t.amount : -t.amount;
    }
    return bal;
  }

  /// Net staff ledger: advances given − salary paid.
  static double staffAdvanceBalance(String staffId) {
    double bal = 0;
    for (final p in salaryPayments.values) {
      if (p.staffId != staffId) continue;
      bal += p.kind == 'advance' ? p.amount : -p.amount;
    }
    return bal;
  }

  static List<Party> activeParties({String? kind}) {
    final list = parties.values
        .where((p) => !p.archived && (kind == null || p.kind == kind))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  // ------------------------------------------------------------------ backup
  /// Serializes every box to a JSON string. The backup crew writes this to
  /// a file / shares it; [restoreFromJson] reads it back.
  static Future<String> backupToJson() async {
    final data = <String, dynamic>{
      'business': business.values.map((e) => e.toJson()).toList(),
      'parties': parties.values.map((e) => e.toJson()).toList(),
      'khataEntries': khataEntries.values.map((e) => e.toJson()).toList(),
      'cashEntries': cashEntries.values.map((e) => e.toJson()).toList(),
      'expenseCategories':
          expenseCategories.values.map((e) => e.toJson()).toList(),
      'expenseEntries':
          expenseEntries.values.map((e) => e.toJson()).toList(),
      'stockItems': stockItems.values.map((e) => e.toJson()).toList(),
      'stockMovements':
          stockMovements.values.map((e) => e.toJson()).toList(),
      'staff': staff.values.map((e) => e.toJson()).toList(),
      'attendance': attendance.values.map((e) => e.toJson()).toList(),
      'salaryPayments': salaryPayments.values.map((e) => e.toJson()).toList(),
      'bills': bills.values.map((e) => e.toJson()).toList(),
      'bankAccounts': bankAccounts.values.map((e) => e.toJson()).toList(),
      'bankTxns': bankTxns.values.map((e) => e.toJson()).toList(),
      'reminders': reminders.values.map((e) => e.toJson()).toList(),
    };
    return jsonEncode({
      'app': 'hisab_business',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': Map<String, dynamic>.from(
          settings.toMap().map((k, v) => MapEntry(k.toString(), v))),
      'data': data,
    });
  }

  /// Writes [backupToJson] to a timestamped file and returns its path.
  /// [INFERRED] helper shape — the backup crew owns the UI around it.
  static Future<String> exportBackupToFile() async {
    final json = await backupToJson();
    if (kIsWeb) {
      throw UnsupportedError('File export is not supported on web');
    }
    final dir = await AppPaths.externalOrDocuments('backups');
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/hisab_business_$stamp.json');
    await file.writeAsString(json);
    return file.path;
  }

  /// Restores a backup produced by [backupToJson]. Clears existing data first.
  static Future<void> restoreFromJson(String jsonStr) async {
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    if (decoded['app'] != 'hisab_business') {
      throw FormatException('Not a Hisab Business backup file');
    }
    final data = decoded['data'] as Map<String, dynamic>;
    final settingsMap =
        decoded['settings'] as Map<String, dynamic>? ?? {};

    List<Map<String, dynamic>> listOf(String key) =>
        ((data[key] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    await resetAll();

    Future<void> fill<T>(Box<T> box, List<T> items) async {
      for (final item in items) {
        final id = (item as dynamic).id as String;
        await box.put(id, item);
      }
    }

    await fill(business, listOf('business').map(BusinessProfile.fromJson).toList());
    await fill(parties, listOf('parties').map(Party.fromJson).toList());
    await fill(khataEntries, listOf('khataEntries').map(KhataEntry.fromJson).toList());
    await fill(cashEntries, listOf('cashEntries').map(CashEntry.fromJson).toList());
    await fill(expenseCategories,
        listOf('expenseCategories').map(ExpenseCategory.fromJson).toList());
    await fill(expenseEntries,
        listOf('expenseEntries').map(ExpenseEntry.fromJson).toList());
    await fill(stockItems, listOf('stockItems').map(StockItem.fromJson).toList());
    await fill(stockMovements,
        listOf('stockMovements').map(StockMovement.fromJson).toList());
    await fill(staff, listOf('staff').map(StaffMember.fromJson).toList());
    await fill(attendance,
        listOf('attendance').map(AttendanceRecord.fromJson).toList());
    await fill(salaryPayments,
        listOf('salaryPayments').map(SalaryPayment.fromJson).toList());
    await fill(bills, listOf('bills').map(Bill.fromJson).toList());
    await fill(bankAccounts,
        listOf('bankAccounts').map(BankAccount.fromJson).toList());
    await fill(bankTxns, listOf('bankTxns').map(BankTxn.fromJson).toList());
    await fill(reminders, listOf('reminders').map(Reminder.fromJson).toList());

    for (final entry in settingsMap.entries) {
      await settings.put(entry.key, entry.value);
    }
    await seedDefaults();
  }

  // ----------------------------------------------------------------- settings
  static String? get pinHash => settings.get('pinHash') as String?;
  static Future<void> setPinHash(String hash) => settings.put('pinHash', hash);
  static bool get hasPin => pinHash != null && pinHash!.isNotEmpty;

  static String get language => settings.get('language') as String? ?? 'en';
  static Future<void> setLanguage(String v) => settings.put('language', v);

  static bool get hideBalances => settings.get('hideBalances') as bool? ?? false;
  static Future<void> setHideBalances(bool v) =>
      settings.put('hideBalances', v);

  static bool get biometricEnabled =>
      settings.get('biometricEnabled') as bool? ?? false;
  static Future<void> setBiometricEnabled(bool v) =>
      settings.put('biometricEnabled', v);

  static String? get businessId => settings.get('businessId') as String?;
  static Future<void> setBusinessId(String v) => settings.put('businessId', v);

  static String get themeMode => settings.get('themeMode') as String? ?? 'system';
  static Future<void> setThemeMode(String v) => settings.put('themeMode', v);

  static bool get firstRun => settings.get('firstRun') as bool? ?? true;
  static Future<void> setFirstRun(bool v) => settings.put('firstRun', v);

  static BusinessProfile? get currentBusiness {
    final id = businessId;
    if (id == null) return business.values.isEmpty ? null : business.values.first;
    return business.get(id) ?? (business.values.isEmpty ? null : business.values.first);
  }
}

/// Formats an amount in Pakistani lakh/crore grouping with the "Rs" prefix,
/// e.g. 125000 → "Rs 1,25,000", 2500000 → "Rs 25,00,000".
/// Written by hand — no intl locale data needed, works offline everywhere.
String formatPKR(double amount) {
  final negative = amount < 0;
  final n = amount.abs().round();
  final digits = n.toString();
  String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final tail = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[tail];
    while (rest.length > 2) {
      parts.add(rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.add(rest);
    grouped = parts.reversed.join(',');
  }
  return 'Rs ${negative ? '-' : ''}$grouped';
}

/// True when [balance] (from [HiveService.partyBalance]) means they owe you.
bool isReceivable(double balance) => balance > 0;
