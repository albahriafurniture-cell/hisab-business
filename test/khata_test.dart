import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:hisab_business/data/hive_service.dart';
import 'package:hisab_business/data/models.dart';
import 'package:hisab_business/l10n/khata_l10n.dart';
import 'package:hisab_business/l10n/strings.dart';
import 'package:hisab_business/routes.dart';
import 'package:hisab_business/screens/khata_home_dashboard.dart';
import 'package:hisab_business/screens/ledger.dart';
import 'package:hisab_business/screens/parties.dart';
import 'package:hisab_business/screens/party_add.dart';
import 'package:hisab_business/screens/transaction_add.dart';
import 'package:hisab_business/services/khata_service.dart';

/// Khata crew tests: temp-Hive boot (same pattern as test/boot_test.dart),
/// KhataService balance math, and widget pumps of the khata screens with
/// no exceptions expected.
Future<void> initKhataTestHive() async {
  final dir = await Directory.systemTemp.createTemp('hb_khata');
  Hive.init(dir.path);
  HiveService.registerAdapters();
  HiveService.business =
      await Hive.openBox<BusinessProfile>(HiveService.businessBox);
  HiveService.parties =
      await Hive.openBox<Party>(HiveService.partiesBox);
  HiveService.khataEntries =
      await Hive.openBox<KhataEntry>(HiveService.khataEntriesBox);
  HiveService.cashEntries =
      await Hive.openBox<CashEntry>(HiveService.cashEntriesBox);
  HiveService.expenseCategories =
      await Hive.openBox<ExpenseCategory>(
          HiveService.expenseCategoriesBox);
  HiveService.expenseEntries =
      await Hive.openBox<ExpenseEntry>(HiveService.expenseEntriesBox);
  HiveService.stockItems =
      await Hive.openBox<StockItem>(HiveService.stockItemsBox);
  HiveService.stockMovements =
      await Hive.openBox<StockMovement>(HiveService.stockMovementsBox);
  HiveService.staff =
      await Hive.openBox<StaffMember>(HiveService.staffBox);
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
  AppLocale.current.value = 'en';
}

/// Test app with the real route wiring the khata screens use.
Widget khataTestApp(Widget home) => MaterialApp(
      routes: {
        Routes.parties: (_) => const PartiesScreen(),
        Routes.partyAdd: (_) => const PartyAddScreen(),
        Routes.ledger: (_) => const LedgerScreen(),
        Routes.transactionAdd: (_) => const TransactionAddScreen(),
        Routes.reminders: (_) =>
            const Scaffold(body: Text('reminders stub')),
        Routes.reports: (_) =>
            const Scaffold(body: Text('reports stub')),
        Routes.bank: (_) =>
            const Scaffold(body: Text('bank stub')),
        Routes.cash: (_) =>
            const Scaffold(body: Text('cash stub')),
        Routes.stock: (_) =>
            const Scaffold(body: Text('stock stub')),
        Routes.bills: (_) =>
            const Scaffold(body: Text('bills stub')),
        Routes.staff: (_) =>
            const Scaffold(body: Text('staff stub')),
        Routes.expense: (_) =>
            const Scaffold(body: Text('expense stub')),
      },
      home: home,
    );

/// Pushes [route] with [arguments] from a harness button and settles.
Future<void> openRoute(
    WidgetTester tester, String route, Object? arguments) async {
  await tester.pumpWidget(khataTestApp(
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context)
                .pushNamed(route, arguments: arguments),
            child: const Text('open route'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open route'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() async {
    await initKhataTestHive();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  test('khata strings have en + ur for every key', () {
    final en = khataStrings['en']!;
    final ur = khataStrings['ur']!;
    expect(en.keys.toSet(), ur.keys.toSet());
    for (final v in [...en.values, ...ur.values]) {
      expect(v.trim(), isNotEmpty);
    }
    // khataTr reads the live AppLocale.
    expect(AppLocale.current.value, 'en');
    expect(khataTr('khata.party'), 'Party');
    AppLocale.current.value = 'ur';
    expect(khataTr('khata.party'), 'پارٹی');
    expect(khataTr('khata.no.such.key'), 'khata.no.such.key');
    AppLocale.current.value = 'en';
  });

  test('balance math: gave - got, totals, search, delete, validation',
      () async {
    final now = DateTime.now();
    final a = Party(
        id: 'kh-p-a',
        name: 'Ali Traders',
        phone: '03001234567',
        createdAt: now,
        updatedAt: now);
    final b = Party(
        id: 'kh-p-b',
        name: 'Bilal Store',
        kind: 'supplier',
        createdAt: now,
        updatedAt: now);
    await HiveService.parties.put(a.id, a);
    await HiveService.parties.put(b.id, b);

    await KhataService.addEntry(
        partyId: a.id,
        direction: 'gave',
        amount: 1000,
        date: now,
        detail: 'goods on credit');
    await KhataService.addEntry(
        partyId: a.id,
        direction: 'got',
        amount: 400,
        date: now,
        detail: 'partial payment');
    await KhataService.addEntry(
        partyId: b.id, direction: 'got', amount: 200, date: now);

    // Receivable = gave - got.
    expect(KhataService.balanceForParty(a.id), 600);
    expect(KhataService.balanceForParty(b.id), -200);

    final totals = KhataService.totals();
    expect(totals['receivables'], 600);
    expect(totals['payables'], 200);

    final gaveGot = KhataService.gaveGot();
    expect(gaveGot['gave'], 1000);
    expect(gaveGot['got'], 600);

    final entries = KhataService.entriesForParty(a.id);
    expect(entries.length, 2);
    expect(KhataService.lastEntryDate(a.id), isNotNull);
    expect(KhataService.lastEntryDate('no-such-party'), isNull);

    expect(KhataService.searchParties('ali').map((p) => p.id),
        contains('kh-p-a'));
    expect(KhataService.searchParties('0300').map((p) => p.id),
        contains('kh-p-a'));
    expect(KhataService.searchParties('supplier-x'), isEmpty);
    expect(
        KhataService.searchParties('', kind: 'supplier')
            .map((p) => p.id),
        contains('kh-p-b'));

    // Delete removes one entry.
    await KhataService.deleteEntry(entries.first.id);
    expect(KhataService.entriesForParty(a.id).length, 1);

    // Validation guards.
    expect(
        () => KhataService.addEntry(
            partyId: a.id,
            direction: 'gave',
            amount: 0,
            date: now),
        throwsArgumentError);
    expect(
        () => KhataService.addEntry(
            partyId: a.id,
            direction: 'sideways',
            amount: 10,
            date: now),
        throwsArgumentError);
  });

  testWidgets('PartiesScreen lists parties without exceptions',
      (tester) async {
    await tester.pumpWidget(khataTestApp(const PartiesScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Ali Traders'), findsOneWidget);
    // 'Bilal Store' is a supplier: switch to the Suppliers tab.
    expect(find.text('Bilal Store'), findsNothing);
    await tester.tap(find.text(khataTr('khata.suppliers')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Bilal Store'), findsOneWidget);
    // Summary strip labels + search hint with count.
    expect(find.text('Payables'), findsOneWidget);
    expect(find.text('Receivables'), findsOneWidget);
    expect(find.text('COLLECTION'), findsOneWidget);
    expect(find.text('ADD'), findsOneWidget);
  });

  testWidgets('LedgerScreen shows entries, totals and entry actions',
      (tester) async {
    final now = DateTime.now();
    final p = Party(
        id: 'kh-p-ledger',
        name: 'Ledger Test Co',
        phone: '03009998888',
        createdAt: now,
        updatedAt: now);
    // Hive writes use real async I/O: run them outside the FakeAsync zone.
    await tester.runAsync(() async {
      await HiveService.parties.put(p.id, p);
      await KhataService.addEntry(
          partyId: p.id,
          direction: 'gave',
          amount: 5000,
          date: now,
          detail: 'stock supplied');
      await KhataService.addEntry(
          partyId: p.id,
          direction: 'got',
          amount: 1500,
          date: now,
          detail: 'cash received');
    });

    await openRoute(
        tester, Routes.ledger, {'partyId': 'kh-p-ledger'});
    expect(find.text('Ledger Test Co'), findsWidgets);
    expect(find.text('stock supplied'), findsOneWidget);
    expect(find.text('cash received'), findsOneWidget);
    // Entry amounts: 5000 red (gave), 1500 green (got).
    expect(find.text('Rs 5,000'), findsWidgets);
    expect(find.text('Rs 1,500'), findsWidgets);
    // Sticky bottom bar actions + report link.
    expect(find.text('You Gave'), findsOneWidget);
    expect(find.text('You Got'), findsOneWidget);
    expect(find.text('VIEW REPORT'), findsOneWidget);
    // Net balance 3500 = you will get (red side).
    expect(find.text('Rs 3,500'), findsWidgets);
  });

  testWidgets(
      'TransactionAddScreen form renders and saves an entry',
      (tester) async {
    final now = DateTime.now();
    final p = Party(
        id: 'kh-p-txn',
        name: 'Txn Test',
        createdAt: now,
        updatedAt: now);
    // Hive writes use real async I/O: outside the FakeAsync zone.
    await tester.runAsync(() async {
      await HiveService.parties.put(p.id, p);
    });

    await openRoute(tester, Routes.transactionAdd,
        {'partyId': 'kh-p-txn', 'direction': 'gave'});
    expect(find.text('Add Entry'), findsOneWidget);
    // Direction toggle defaults to the passed argument.
    expect(find.text('You Gave'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('khata_amount')), '2500');
    await tester.enterText(find.byKey(const Key('khata_detail')),
        'test entry via form');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Tap the real save button inside runAsync: the Hive write needs real
    // async I/O (FakeAsync never completes dart:io). The receipt sheet's
    // Done then closes sheet + screen.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('khata_save')));
      await tester.pump();
      // Let the save future finish and the receipt sheet appear.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await tester.pump();
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Entry persisted with the right math.
    expect(KhataService.balanceForParty('kh-p-txn'), 2500);

    // Done closes sheet + screen, back at the harness.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('open route'), findsOneWidget);
  });

  testWidgets('PartyAddScreen validates and saves a party',
      (tester) async {
    await tester.pumpWidget(khataTestApp(const PartyAddScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Empty name is rejected.
    await tester.tap(find.text('Save Party'));
    await tester.pump();
    expect(find.text('Please enter a name'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('party_name')), 'Widget Test Party');
    await tester.tap(find.text('Supplier'));
    // The save writes to Hive, which never completes inside testWidgets'
    // FakeAsync zone: tap in the real async zone and let the write finish.
    await tester.runAsync(() async {
      await tester.tap(find.text('Save Party'));
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final saved = HiveService.parties.values
        .where((p) => p.name == 'Widget Test Party');
    expect(saved, isNotEmpty);
    expect(saved.first.kind, 'supplier');
  });

  testWidgets('HomeDashboard renders hero, tiles and summary',
      (tester) async {
    // HomeDashboard is a body widget: it needs a Scaffold ancestor for
    // its InkWells, exactly as home_shell provides in the real app.
    await tester.pumpWidget(khataTestApp(const Scaffold(
      body: HomeDashboard(),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text("Your shop's money, in one khata"),
        findsOneWidget);
    expect(find.text('View Parties'), findsOneWidget);
    expect(find.text('KHATA'), findsOneWidget);
    for (final label in [
      'Party',
      'Cash',
      'Stock',
      'Bills',
      'Staff',
      'Expense'
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Total gave'), findsOneWidget);
    expect(find.text('Total got'), findsOneWidget);
  });
}
