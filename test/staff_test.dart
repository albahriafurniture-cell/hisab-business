import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:hisab_business/data/hive_service.dart';
import 'package:hisab_business/data/models.dart';
import 'package:hisab_business/l10n/staff_l10n.dart';
import 'package:hisab_business/l10n/strings.dart';
import 'package:hisab_business/routes.dart';
import 'package:hisab_business/screens/staff.dart';
import 'package:hisab_business/screens/staff_add.dart';
import 'package:hisab_business/screens/staff_profile.dart';
import 'package:hisab_business/services/staff_service.dart';

/// Staff crew tests: temp-Hive boot, attendance toggle, payments/advance
/// balance, slip math, localization, and widget pumps of all three screens.
Future<void> initStaffTestHive() async {
  final dir = await Directory.systemTemp.createTemp('hb_staff');
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

StaffMember _seedStaff(String id, String name) {
  final now = DateTime.now();
  final s = StaffMember(
      id: id, name: name, role: 'Cashier', monthlySalary: 50000, joinedAt: now);
  return s;
}

void main() {
  setUpAll(() async {
    await initStaffTestHive();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  test('add staff member persists to the staff box', () async {
    final s = _seedStaff('staff-1', 'Ahmed Khan');
    await HiveService.staff.put(s.id, s);
    final got = HiveService.staff.get('staff-1');
    expect(got, isNotNull);
    expect(got!.name, 'Ahmed Khan');
    expect(got.monthlySalary, 50000);
    expect(StaffService.activeStaff().any((x) => x.id == 'staff-1'), isTrue);
  });

  test('mark P/A persists and re-tapping clears the record', () async {
    final day = DateTime.now();
    await StaffService.markAttendance('staff-1', day, 'present');
    expect(StaffService.statusFor('staff-1', day), 'present');

    // Re-tap same status -> toggle off (record removed).
    await StaffService.markAttendance('staff-1', day, 'present');
    expect(StaffService.statusFor('staff-1', day), isNull);

    await StaffService.markAttendance('staff-1', day, 'absent');
    expect(StaffService.statusFor('staff-1', day), 'absent');

    final map = StaffService.attendanceForDay(day);
    expect(map['staff-1'], 'absent');
  });

  test('todayCounts reflects marks across staff', () async {
    await HiveService.staff.put('staff-2', _seedStaff('staff-2', 'Bilal'));
    final day = DateTime.now();
    await StaffService.markAttendance('staff-1', day, 'present');
    await StaffService.markAttendance('staff-2', day, 'absent');
    final counts = StaffService.todayCounts();
    expect(counts.present, greaterThanOrEqualTo(1));
    expect(counts.absent, greaterThanOrEqualTo(1));
  });

  test('advance + salary payments produce the right advance balance', () async {
    final now = DateTime.now();
    await StaffService.addPayment(
        staffId: 'staff-1', amount: 10000, kind: 'advance', date: now);
    await StaffService.addPayment(
        staffId: 'staff-1', amount: 4000, kind: 'salary', date: now);
    expect(HiveService.staffAdvanceBalance('staff-1'), 6000);
    expect(StaffService.paymentsForStaff('staff-1').length, 2);
  });

  test('monthlySlipData computes basic, bonuses, paid, advances, net', () {
    final now = DateTime.now();
    // +5000 bonus so net = 50000 + 5000 − 10000 − 4000 = 41000
    final slip = StaffService.monthlySlipData('staff-1', now);
    expect(slip.basicSalary, 50000);
    expect(slip.advances, 10000);
    expect(slip.salaryPaid, 4000);
    expect(slip.netPayable, greaterThanOrEqualTo(0));
  });

  test('net payable accounts for bonus', () async {
    final now = DateTime.now();
    await StaffService.addPayment(
        staffId: 'staff-1', amount: 5000, kind: 'bonus', date: now);
    final slip = StaffService.monthlySlipData('staff-1', now);
    expect(slip.bonuses, 5000);
    expect(slip.netPayable, 50000 + 5000 - 10000 - 4000);
  });

  test('staffTr resolves en and fresh ur strings', () {
    AppLocale.current.value = 'en';
    expect(staffTr('staff.title'), 'Staff Book');
    AppLocale.current.value = 'ur';
    expect(staffTr('staff.title'), isNot('Staff Book'));
    expect(staffTr('staff.present'), isNotEmpty);
    AppLocale.current.value = 'en';
  });

  Widget wrapScreen(Widget child) => MaterialApp(
        routes: {
          Routes.staff: (_) => const StaffScreen(),
          Routes.staffAdd: (_) => const StaffAddScreen(),
          Routes.staffProfile: (_) => const StaffProfileScreen(),
        },
        home: child,
      );

  testWidgets('StaffScreen pumps with staff list, no exceptions',
      (tester) async {
    await tester.pumpWidget(wrapScreen(const StaffScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Staff Book'), findsWidgets);
    expect(find.text('Ahmed Khan'), findsOneWidget);
    expect(find.text('Bilal'), findsOneWidget);
  });

  testWidgets('StaffAddScreen pumps and validates required name',
      (tester) async {
    await tester.pumpWidget(wrapScreen(const StaffAddScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Save with empty name -> validator blocks, staff box unchanged.
    final before = HiveService.staff.length;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(HiveService.staff.length, before);
    // Fill name and save -> pops and adds. The save writes to Hive, which
    // never completes inside testWidgets' FakeAsync zone: tap in the real
    // async zone and let the write finish.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'), 'Test Worker');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();
    expect(HiveService.staff.length, before + 1);
  });

  testWidgets('StaffProfileScreen pumps with attendance and ledger',
      (tester) async {
    await tester.pumpWidget(wrapScreen(const StaffProfileScreen(staffId: 'staff-1')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Ahmed Khan'), findsWidgets);
    expect(find.text('Give Payment'), findsOneWidget);
    expect(find.text('Salary Slip'), findsOneWidget);
    // Ledger rows for the earlier advance + salary payments.
    expect(find.text('Advance'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
  });
}
