import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:hisab_business/data/hive_service.dart';
import 'package:hisab_business/data/models.dart';
import 'package:hisab_business/main.dart';
import 'package:hisab_business/routes.dart';
import 'package:hisab_business/screens/onboarding.dart';
import 'package:hisab_business/screens/splash.dart';

/// Foundation boot test: boots the real app against a temp Hive store,
/// verifies splash -> onboarding routing on a fresh install, and checks
/// the PKR formatter. Run with: flutter test
Future<void> initTestHive() async {
  final dir = await Directory.systemTemp.createTemp('hb_boot');
  Hive.init(dir.path);
  HiveService.registerAdapters();
  HiveService.business =
      await Hive.openBox<BusinessProfile>(HiveService.businessBox);
  HiveService.parties = await Hive.openBox<Party>(HiveService.partiesBox);
  HiveService.khataEntries =
      await Hive.openBox<KhataEntry>(HiveService.khataEntriesBox);
  HiveService.cashEntries =
      await Hive.openBox<CashEntry>(HiveService.cashEntriesBox);
  HiveService.expenseCategories = await Hive.openBox<ExpenseCategory>(
      HiveService.expenseCategoriesBox);
  HiveService.expenseEntries =
      await Hive.openBox<ExpenseEntry>(HiveService.expenseEntriesBox);
  HiveService.stockItems =
      await Hive.openBox<StockItem>(HiveService.stockItemsBox);
  HiveService.stockMovements =
      await Hive.openBox<StockMovement>(HiveService.stockMovementsBox);
  HiveService.staff = await Hive.openBox<StaffMember>(HiveService.staffBox);
  HiveService.attendance =
      await Hive.openBox<AttendanceRecord>(HiveService.attendanceBox);
  HiveService.salaryPayments =
      await Hive.openBox<SalaryPayment>(HiveService.salaryPaymentsBox);
  HiveService.bills = await Hive.openBox<Bill>(HiveService.billsBox);
  HiveService.bankAccounts =
      await Hive.openBox<BankAccount>(HiveService.bankAccountsBox);
  HiveService.bankTxns =
      await Hive.openBox<BankTxn>(HiveService.bankTxnsBox);
  HiveService.reminders =
      await Hive.openBox<Reminder>(HiveService.remindersBox);
  HiveService.settings = await Hive.openBox(HiveService.settingsBox);
  await HiveService.seedDefaults();
}

void main() {
  setUpAll(() async {
    await initTestHive();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  test('PKR formatter uses lakh/crore grouping', () {
    expect(formatPKR(0), 'Rs 0');
    expect(formatPKR(500), 'Rs 500');
    expect(formatPKR(5000), 'Rs 5,000');
    expect(formatPKR(125000), 'Rs 1,25,000');
    expect(formatPKR(2500000), 'Rs 25,00,000');
    expect(formatPKR(10000000), 'Rs 1,00,00,000');
    expect(formatPKR(-750), 'Rs -750');
  });

  test('expense categories are seeded with defaults', () {
    expect(HiveService.expenseCategories.length, greaterThanOrEqualTo(8));
  });

  test('settings defaults are seeded', () {
    expect(HiveService.language, 'en');
    expect(HiveService.hideBalances, isFalse);
    expect(HiveService.firstRun, isTrue);
    expect(HiveService.hasPin, isFalse);
  });

  test('backup/restore round-trips party data', () async {
    final now = DateTime.now();
    final party = Party(
        id: 'p-test-1',
        name: 'Test Party',
        createdAt: now,
        updatedAt: now);
    await HiveService.parties.put(party.id, party);
    final json = await HiveService.backupToJson();
    expect(json.contains('hisab_business'), isTrue);

    await HiveService.resetAll();
    expect(HiveService.parties.isEmpty, isTrue);

    await HiveService.restoreFromJson(json);
    final restored = HiveService.parties.get('p-test-1');
    expect(restored, isNotNull);
    expect(restored!.name, 'Test Party');
  });

  testWidgets('app boots: splash shows, then routes to onboarding',
      (tester) async {
    await tester.pumpWidget(const HisabBusinessApp());
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.byType(SplashScreen), findsOneWidget);

    // Let the splash router fire (1600ms timer), then settle the transition.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Onboarding'), findsWidgets);
  });

  test('routing decision logic covers lock and home states', () async {
    // Pin set -> lock.
    await HiveService.setFirstRun(false);
    await HiveService.setPinHash('dummy-hash');
    expect(HisabBusinessApp.initialRoute(), Routes.lock);

    // No pin, not first run -> home.
    await HiveService.settings.delete('pinHash');
    expect(HisabBusinessApp.initialRoute(), Routes.home);

    // First run again -> onboarding (restores fixture state).
    await HiveService.setFirstRun(true);
    expect(HisabBusinessApp.initialRoute(), Routes.onboarding);
  });
}
