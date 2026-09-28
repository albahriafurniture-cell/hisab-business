import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:hisab_business/data/hive_service.dart';
import 'package:hisab_business/l10n/cash_l10n.dart';
import 'package:hisab_business/l10n/strings.dart';
import 'package:hisab_business/screens/cash.dart';
import 'package:hisab_business/screens/expense.dart';
import 'package:hisab_business/services/cash_service.dart';
import 'package:hisab_business/theme.dart';

import 'boot_test.dart'; // initTestHive: temp-Hive boot

void main() {
  setUpAll(() async {
    await initTestHive();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  group('CashService math', () {
    test('cashInHand = sum(in) - sum(out)', () async {
      await HiveService.cashEntries.clear();
      await CashService.addCashEntry(direction: 'in', amount: 10000);
      await CashService.addCashEntry(direction: 'in', amount: 5000);
      await CashService.addCashEntry(direction: 'out', amount: 3000);
      expect(CashService.cashInHand(), 12000);
      expect(HiveService.cashInHand(), 12000);
    });

    test('todayTotals splits in/out', () async {
      await HiveService.cashEntries.clear();
      await CashService.addCashEntry(direction: 'in', amount: 15000);
      await CashService.addCashEntry(direction: 'out', amount: 4000);
      final totals = CashService.todayTotals();
      expect(totals.inTotal, 15000);
      expect(totals.outTotal, 4000);
      expect(CashService.dayBalance(DateTime.now()), 11000);
    });

    test('entriesForDay filters by calendar day', () async {
      await HiveService.cashEntries.clear();
      final yesterday =
          DateTime.now().subtract(const Duration(days: 1));
      await CashService.addCashEntry(
          direction: 'in', amount: 100, date: yesterday);
      await CashService.addCashEntry(direction: 'out', amount: 50);
      expect(CashService.entriesForDay(DateTime.now()).length, 1);
      expect(CashService.entriesForDay(yesterday).length, 1);
    });

    test('entry stores category, party, detail', () async {
      await HiveService.cashEntries.clear();
      final entry = await CashService.addCashEntry(
        direction: 'in',
        amount: 2500,
        category: 'Shop sales',
        partyId: 'p-1',
        detail: 'Morning counter',
      );
      expect(entry.category, 'Shop sales');
      expect(entry.partyId, 'p-1');
      expect(entry.detail, 'Morning counter');
      expect(HiveService.cashEntries.get(entry.id), isNotNull);
    });

    test('rejects invalid direction and non-positive amount', () async {
      expect(
          () => CashService.addCashEntry(
              direction: 'sideways', amount: 10),
          throwsArgumentError);
      expect(
          () => CashService.addCashEntry(
              direction: 'in', amount: 0),
          throwsArgumentError);
    });
  });

  group('CashService expenses', () {
    test('categoryTotals and expensesForCategory', () async {
      await HiveService.expenseEntries.clear();
      final cats = HiveService.expenseCategories.values.toList();
      expect(cats.length, greaterThanOrEqualTo(2));
      final a = cats.first.id;
      final b = cats[1].id;
      await CashService.addExpense(categoryId: a, amount: 2000);
      await CashService.addExpense(categoryId: a, amount: 1000);
      await CashService.addExpense(categoryId: b, amount: 500);

      final totals = CashService.categoryTotals();
      expect(totals[a], 3000);
      expect(totals[b], 500);
      expect(CashService.totalExpenses(), 3500);

      final forA = CashService.expensesForCategory(a);
      expect(forA.length, 2);
      // newest first: first entry is not older than the last
      expect(forA.first.date.isBefore(forA.last.date), isFalse);
    });

    test('addExpenseCategory creates a usable category', () async {
      final before = HiveService.expenseCategories.length;
      final cat = await CashService.addExpenseCategory(
        name: 'Test Category',
        iconKey: 'shopping',
        color: 0xFF123456,
      );
      expect(HiveService.expenseCategories.length, before + 1);
      expect(cat.name, 'Test Category');
      await CashService.addExpense(categoryId: cat.id, amount: 250);
      expect(CashService.categoryTotals()[cat.id], 250);
    });

    test('category suggestions come from past entries', () async {
      await HiveService.cashEntries.clear();
      await CashService.addCashEntry(
          direction: 'in', amount: 10, category: 'Shop sales');
      await CashService.addCashEntry(
          direction: 'in', amount: 10, category: 'Shop sales');
      await CashService.addCashEntry(
          direction: 'out', amount: 5, category: 'Fuel');
      final suggestions = CashService.categorySuggestions();
      expect(suggestions, contains('Shop sales'));
      expect(suggestions, contains('Fuel'));
      expect(suggestions.length, 2); // deduplicated
    });
  });

  group('cash l10n', () {
    testWidgets('cashTr resolves en/ur and falls back to key',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ));
      expect(cashTr(ctx, 'cash.title'), 'Cash Book');
      expect(cashTr(ctx, 'cash.noSuchKey'), 'cash.noSuchKey');

      AppLocale.current.value = 'ur';
      addTearDown(() => AppLocale.current.value = 'en');
      expect(cashTr(ctx, 'cash.title'), 'کیش بک');
      expect(cashTr(ctx, 'cash.noSuchKey'), 'cash.noSuchKey');
    });
  });

  group('screens pump without exceptions', () {
    // Phone-size viewport: the default 800x600 test surface is shorter
    // than real phones and trips 13px RenderFlex overflows on screens
    // with a sticky bottom bar.
    void usePhoneViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
    }

    testWidgets('CashScreen pumps, shows summary + entries',
        (tester) async {
      usePhoneViewport(tester);
      // Hive I/O must run outside the FakeAsync zone (tester.runAsync),
      // otherwise dart:io awaits never complete and the test hangs.
      await tester.runAsync(() async {
        await HiveService.cashEntries.clear();
        await CashService.addCashEntry(
            direction: 'in', amount: 7000, detail: 'Counter sale');
        await CashService.addCashEntry(
            direction: 'out', amount: 2000, detail: 'Fuel');
      });

      await tester.pumpWidget(MaterialApp(
        theme: buildLightTheme(),
        home: const CashScreen(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Cash Book'), findsOneWidget);
      expect(find.text('Cash in Hand'), findsOneWidget);
      expect(find.text('Counter sale'), findsOneWidget);
      expect(find.text('Rs 7,000'), findsWidgets);
      // Sticky bottom bar CTAs ("Out"/"In" also label the day totals).
      expect(find.text('Out'), findsWidgets);
      expect(find.text('In'), findsWidgets);
    });

    testWidgets('CashScreen empty day shows empty state',
        (tester) async {
      usePhoneViewport(tester);
      await tester.runAsync(() async {
        await HiveService.cashEntries.clear();
      });
      await tester.pumpWidget(MaterialApp(
        theme: buildLightTheme(),
        home: const CashScreen(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('No transactions found'), findsOneWidget);
    });

    testWidgets('CashScreen renders Urdu copy', (tester) async {
      usePhoneViewport(tester);
      AppLocale.current.value = 'ur';
      addTearDown(() => AppLocale.current.value = 'en');
      await tester.pumpWidget(MaterialApp(
        theme: buildLightTheme(),
        home: const CashScreen(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('کیش بک'), findsOneWidget);
      expect(find.text('ہاتھ میں کیش'), findsOneWidget);
    });

    testWidgets('ExpenseScreen pumps, shows seeded categories',
        (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(MaterialApp(
        theme: buildLightTheme(),
        home: const ExpenseScreen(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Expense Book'), findsOneWidget);
      expect(find.text('Total Expenses'), findsOneWidget);
      expect(find.text('Shop Rent'), findsOneWidget);
      expect(find.text('Salaries'), findsOneWidget);
    });

    testWidgets('ExpenseScreen category tap opens ledger',
        (tester) async {
      usePhoneViewport(tester);
      // Deterministic category: box iteration order is not insertion
      // order, and tiles show the localized label, not the stored name.
      late String catId;
      await tester.runAsync(() async {
        await HiveService.expenseEntries.clear();
        final cat = HiveService.expenseCategories.values
            .firstWhere((c) => c.iconKey == 'rent');
        catId = cat.id;
        await CashService.addExpense(
            categoryId: cat.id, amount: 1500, detail: 'Test fuel');
      });

      await tester.pumpWidget(MaterialApp(
        theme: buildLightTheme(),
        home: const ExpenseScreen(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(find.text('Shop Rent'), 300);
      await tester.tap(find.text('Shop Rent'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Rs 1,500'), findsWidgets);
      expect(catId, isNotEmpty);
    });

    testWidgets('ExpenseScreen renders Urdu copy', (tester) async {
      usePhoneViewport(tester);
      AppLocale.current.value = 'ur';
      addTearDown(() => AppLocale.current.value = 'en');
      await tester.pumpWidget(MaterialApp(
        theme: buildLightTheme(),
        home: const ExpenseScreen(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('اخراجات کی کتاب'), findsOneWidget);
      expect(find.text('دکان کا کرایہ'), findsOneWidget);
    });
  });
}
