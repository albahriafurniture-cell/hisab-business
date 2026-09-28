import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:hisab_business/data/hive_service.dart';
import 'package:hisab_business/data/models.dart';
import 'package:hisab_business/l10n/billing_l10n.dart';
import 'package:hisab_business/screens/bill_create.dart';
import 'package:hisab_business/screens/bill_preview.dart';
import 'package:hisab_business/screens/bills.dart';
import 'package:hisab_business/services/billing_service.dart';

/// Billing feature tests: service math + persistence + PDF bytes,
/// and widget smoke tests for all three billing screens.
///
/// Boots the real app against a temp Hive store (same pattern as
/// test/boot_test.dart; each test file runs in its own isolate).
Future<void> initBillingTestHive() async {
  final dir = await Directory.systemTemp.createTemp('hb_billing');
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

String _seedBillId = '';

List<BillItem> _twoItems() => [
      BillItem(
          itemId: 's1', name: 'Sugar', qty: 2, rate: 100, total: 200),
      BillItem(itemId: '', name: 'Tea', qty: 3, rate: 50, total: 150),
    ];

void main() {
  setUpAll(() async {
    await initBillingTestHive();
    final now = DateTime.now();
    await HiveService.parties.put(
        'p1',
        Party(
            id: 'p1',
            name: 'Test Trader',
            phone: '03001234567',
            address: 'Main Bazaar',
            createdAt: now,
            updatedAt: now));
    await HiveService.stockItems.put(
        's1',
        StockItem(
            id: 's1',
            name: 'Sugar',
            unit: 'kg',
            sellPrice: 120,
            createdAt: now,
            updatedAt: now));
  });

  tearDownAll(() async {
    await Hive.close();
  });

  group('billing service', () {
    test('bill numbers follow the HB-0001 sequence', () async {
      await HiveService.bills.clear();
      expect(BillingService.nextBillNo(), 'HB-0001');
      await BillingService.createBill(items: _twoItems());
      expect(BillingService.nextBillNo(), 'HB-0002');
    });

    test('computeTotals does the math', () {
      final t = BillingService.computeTotals(_twoItems(), 10, 20);
      expect(t.subtotal, 350);
      expect(t.taxAmount, 35);
      expect(t.grandTotal, 365);
    });

    test('computeTotals clamps negatives and floors at zero', () {
      final t = BillingService.computeTotals(_twoItems(), -5, 99999);
      expect(t.taxAmount, 0);
      expect(t.grandTotal, 0);
    });

    test('createBill persists a 2-item bill with correct totals',
        () async {
      await HiveService.bills.clear();
      final bill = await BillingService.createBill(
        items: _twoItems(),
        partyId: 'p1',
        taxPct: 10,
        discount: 20,
        note: 'test note',
      );
      _seedBillId = bill.id;
      expect(bill.billNo, 'HB-0001');
      expect(bill.status, 'due');
      expect(bill.items.length, 2);
      expect(bill.subtotal, 350);
      expect(bill.grandTotal, 365);
      expect(bill.note, 'test note');
      final stored = HiveService.bills.get(bill.id);
      expect(stored, isNotNull);
      expect(stored!.grandTotal, 365);
    });

    test('billsForParty and monthSalesTotal', () {
      final forParty = BillingService.billsForParty('p1');
      expect(forParty.length, 1);
      expect(forParty.first.id, _seedBillId);
      expect(BillingService.billsForParty('nobody'), isEmpty);
      expect(BillingService.monthSalesTotal(), 365);
    });

    test('updateBillStatus flips paid/due', () async {
      await BillingService.updateBillStatus(_seedBillId, 'paid');
      expect(BillingService.getBill(_seedBillId)!.status, 'paid');
      await BillingService.updateBillStatus(_seedBillId, 'due');
      expect(BillingService.getBill(_seedBillId)!.status, 'due');
    });

    test('buildBillPdf produces non-empty bytes', () async {
      final bill = BillingService.getBill(_seedBillId)!;
      final bytes = await BillingService.buildBillPdf(bill);
      expect(bytes.isNotEmpty, isTrue);
      // PDF magic header
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('billingTr resolves en and falls back to the key', () {
      expect(billingTr('billing.book'), 'Bill Book');
      expect(billingTr('billing.grandTotal'), 'Grand total');
      expect(billingTr('billing.no.such.key'), 'billing.no.such.key');
      expect(billingItemsLabel(1), '1 item');
      expect(billingItemsLabel(3), '3 items');
    });

    test('date formatters are hand-rolled and deterministic', () {
      // 2026-09-18 is a Friday.
      final d = DateTime(2026, 9, 18, 14, 5);
      expect(BillingService.formatDateTime(d), 'Fri, 18 Sep 26 • 2:05 PM');
      expect(BillingService.formatDate(d), '18 Sep 2026');
      expect(BillingService.formatDateTime(DateTime(2026, 1, 1, 0, 0)),
          'Thu, 1 Jan 26 • 12:00 AM');
    });
  });

  group('billing screens', () {
    testWidgets('BillsScreen pumps with no exceptions', (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: BillsScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Bill Book'), findsOneWidget);
      // The seeded bill from the service tests shows up in the list.
      expect(find.textContaining('Bill #'), findsWidgets);
    });

    testWidgets('BillCreateScreen pumps with no exceptions',
        (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: BillCreateScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Add item'), findsOneWidget);
      expect(find.text('SAVE BILL'), findsOneWidget);
    });

    testWidgets('BillPreviewScreen pumps with no exceptions',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: (_) => MaterialPageRoute(
          settings:
              RouteSettings(arguments: {'billId': _seedBillId}),
          builder: (_) => const BillPreviewScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('INVOICE'), findsOneWidget);
      expect(find.text('Test Trader'), findsOneWidget);
    });
  });
}
