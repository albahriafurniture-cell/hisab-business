import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:hisab_business/data/hive_service.dart';
import 'package:hisab_business/data/models.dart';
import 'package:hisab_business/l10n/bank_l10n.dart';
import 'package:hisab_business/l10n/strings.dart';
import 'package:hisab_business/routes.dart';
import 'package:hisab_business/screens/bank.dart';
import 'package:hisab_business/screens/bank_add.dart';
import 'package:hisab_business/screens/bank_ledger.dart';
import 'package:hisab_business/screens/reports.dart';
import 'package:hisab_business/services/report_service.dart';

import 'boot_test.dart' show initTestHive;

/// Bank + Reports crew tests: temp-Hive data round-trip, PDF generation,
/// l10n map, and widget smoke tests for all four screens.
/// Run with: flutter test test/bank_reports_test.dart
void main() {
  const uuid = Uuid();
  late String accountId;
  late String partyId;

  setUpAll(() async {
    await initTestHive();
    final now = DateTime.now();

    await HiveService.business.put(
      'b1',
      BusinessProfile(
        id: 'b1',
        name: 'Test Traders',
        phone: '03001234567',
        createdAt: now,
      ),
    );

    accountId = uuid.v4();
    await HiveService.bankAccounts.put(
      accountId,
      BankAccount(
        id: accountId,
        bankName: 'Meezan Bank',
        title: 'Test Traders',
        accountNo: '01230123456789',
        createdAt: now,
      ),
    );
    for (final (dir, amt, detail) in [
      ('deposit', 5000.0, 'Opening balance'),
      ('deposit', 2500.0, 'Sale cash deposited'),
      ('withdraw', 2000.0, 'Supplier payment'),
    ]) {
      final id = uuid.v4();
      await HiveService.bankTxns.put(
        id,
        BankTxn(
          id: id,
          bankAccountId: accountId,
          direction: dir,
          amount: amt,
          date: now,
          detail: detail,
          createdAt: now,
        ),
      );
    }

    partyId = uuid.v4();
    await HiveService.parties.put(
      partyId,
      Party(
        id: partyId,
        name: 'Test Customer',
        phone: '03007654321',
        kind: 'customer',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final ke = uuid.v4();
    await HiveService.khataEntries.put(
      ke,
      KhataEntry(
        id: ke,
        partyId: partyId,
        direction: 'gave',
        amount: 10000,
        date: now,
        detail: 'Goods on credit',
        createdAt: now,
      ),
    );
    final ce = uuid.v4();
    await HiveService.cashEntries.put(
      ce,
      CashEntry(
        id: ce,
        direction: 'in',
        amount: 3000,
        date: now,
        category: 'Sales',
        detail: 'Counter sale',
        createdAt: now,
      ),
    );
    final ex = uuid.v4();
    final cat = HiveService.expenseCategories.values.first;
    await HiveService.expenseEntries.put(
      ex,
      ExpenseEntry(
        id: ex,
        categoryId: cat.id,
        amount: 500,
        date: now,
        detail: 'Tea',
        createdAt: now,
      ),
    );
    final si = uuid.v4();
    await HiveService.stockItems.put(
      si,
      StockItem(
        id: si,
        name: 'Sugar 1kg',
        unit: 'pcs',
        buyPrice: 150,
        sellPrice: 170,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final sm = uuid.v4();
    await HiveService.stockMovements.put(
      sm,
      StockMovement(
        id: sm,
        itemId: si,
        direction: 'in',
        qty: 20,
        rate: 150,
        date: now,
        createdAt: now,
      ),
    );
  });

  tearDownAll(() async {
    // boot_test.dart owns Hive.close() in its own run; nothing to do here.
  });

  group('bank balance math', () {
    test('bankBalance sums deposits minus withdrawals', () {
      // 5000 + 2500 - 2000 = 5500
      expect(HiveService.bankBalance(accountId), 5500);
    });

    test('opening-balance deposit is counted', () async {
      final id = uuid.v4();
      await HiveService.bankAccounts.put(
        id,
        BankAccount(
            id: id,
            bankName: 'UBL',
            title: 'Second',
            accountNo: '1111',
            createdAt: DateTime.now()),
      );
      final tx = uuid.v4();
      await HiveService.bankTxns.put(
        tx,
        BankTxn(
          id: tx,
          bankAccountId: id,
          direction: 'deposit',
          amount: 12000,
          date: DateTime.now(),
          detail: 'Opening balance',
          createdAt: DateTime.now(),
        ),
      );
      expect(HiveService.bankBalance(id), 12000);
    });

    test('unknown account balances to zero', () {
      expect(HiveService.bankBalance('no-such-id'), 0);
    });
  });

  group('report PDFs', () {
    final from = DateTime.now().subtract(const Duration(days: 30));
    final to = DateTime.now().add(const Duration(days: 1));

    test('bank statement bytes are non-empty', () async {
      final bytes =
          await ReportService.buildBankStatementPdf(accountId, from, to);
      expect(bytes.lengthInBytes, greaterThan(500));
    });

    test('party ledger bytes are non-empty', () async {
      final bytes =
          await ReportService.buildPartyLedgerPdf(partyId, from, to);
      expect(bytes.lengthInBytes, greaterThan(500));
    });

    test('cash book bytes are non-empty', () async {
      final bytes = await ReportService.buildCashBookPdf(from, to);
      expect(bytes.lengthInBytes, greaterThan(500));
    });

    test('expense report bytes are non-empty', () async {
      final bytes = await ReportService.buildExpensePdf(from, to);
      expect(bytes.lengthInBytes, greaterThan(500));
    });

    test('stock report bytes are non-empty', () async {
      final bytes = await ReportService.buildStockPdf();
      expect(bytes.lengthInBytes, greaterThan(500));
    });

    test('pnl report bytes are non-empty', () async {
      final bytes = await ReportService.buildPnlPdf(from, to);
      expect(bytes.lengthInBytes, greaterThan(500));
    });
  });

  group('bank l10n', () {
    test('en and ur maps cover the same keys', () {
      expect(bankStrings['en']!.keys.toSet(),
          bankStrings['ur']!.keys.toSet());
    });

    test('bankTr follows AppLocale with en fallback', () {
      AppLocale.current.value = 'en';
      expect(bankTr('bank.title'), 'Bank Book');
      AppLocale.current.value = 'ur';
      expect(bankTr('bank.title'), 'بینک بک');
      expect(bankTr('no.such.key'), 'no.such.key');
      AppLocale.current.value = 'en';
    });
  });

  group('screen smoke tests', () {
    Widget wrap(Widget w) => MaterialApp(
          routes: {
            Routes.bank: (_) => const BankScreen(),
            Routes.bankAdd: (_) => const BankAddScreen(),
            Routes.bankLedger: (_) => const BankLedgerScreen(),
            Routes.reports: (_) => const ReportsScreen(),
          },
          home: Directionality(
              textDirection: TextDirection.ltr, child: w),
        );

    testWidgets('BankScreen lists accounts and total', (tester) async {
      await tester.pumpWidget(wrap(const BankScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Meezan Bank'), findsOneWidget);
      expect(find.text(bankTr('bank.addBank')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('BankScreen reacts to locale change', (tester) async {
      AppLocale.current.value = 'ur';
      await tester.pumpWidget(wrap(const BankScreen()));
      await tester.pumpAndSettle();
      expect(find.text('بینک بک'), findsOneWidget);
      AppLocale.current.value = 'en';
      await tester.pumpAndSettle();
      expect(find.text('Bank Book'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('BankAddScreen shows the form', (tester) async {
      await tester.pumpWidget(wrap(const BankAddScreen()));
      await tester.pumpAndSettle();
      expect(find.text(bankTr('bank.saveAccount')), findsOneWidget);
      expect(find.text(bankTr('bank.bankName')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('BankLedgerScreen shows txns and running balance',
        (tester) async {
      await tester.pumpWidget(wrap(const Scaffold(body: Text('seed'))));
      final ctx = tester.element(find.text('seed'));
      Navigator.of(ctx).pushNamed(Routes.bankLedger,
          arguments: {'bankAccountId': accountId});
      await tester.pumpAndSettle();
      expect(find.byType(BankLedgerScreen), findsOneWidget);
      expect(find.text('Meezan Bank'), findsOneWidget);
      expect(find.text(bankTr('bank.deposit')), findsWidgets);
      expect(find.text(bankTr('bank.withdraw')), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('BankLedgerScreen without args shows empty state',
        (tester) async {
      await tester.pumpWidget(wrap(const BankLedgerScreen()));
      await tester.pumpAndSettle();
      expect(find.text(bankTr('bank.noBanks')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ReportsScreen shows six report cards', (tester) async {
      await tester.pumpWidget(wrap(const ReportsScreen()));
      await tester.pumpAndSettle();
      for (final label in [
        bankTr('reports.partyLedger'),
        bankTr('reports.cashBook'),
        bankTr('reports.expense'),
        bankTr('reports.stock'),
        bankTr('reports.bank'),
        bankTr('reports.pnl'),
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('ReportsScreen initial arg preselects a report',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        routes: {
          Routes.reports: (_) => const ReportsScreen(),
        },
        home: const Scaffold(body: Text('seed')),
      ));
      final ctx = tester.element(find.text('seed'));
      Navigator.of(ctx).pushNamed(Routes.reports,
          arguments: {'initial': 'cash'});
      await tester.pumpAndSettle();
      expect(find.text(bankTr('reports.generate')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ReportsScreen generates a cash-book PDF end to end',
        (tester) async {
      await tester.pumpWidget(wrap(const ReportsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(bankTr('reports.cashBook')));
      await tester.pumpAndSettle();
      expect(find.text(bankTr('reports.generate')), findsOneWidget);
      // Real file I/O (system-font probing + PDF write) cannot complete
      // inside the widget test's fake-async zone, so drive the generate tap
      // with real async via runAsync.
      await tester.runAsync(() async {
        await tester.tap(find.text(bankTr('reports.generate')));
        await Future<void>.delayed(const Duration(seconds: 5));
      });
      await tester.pumpAndSettle();
      expect(find.text(bankTr('reports.share')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
