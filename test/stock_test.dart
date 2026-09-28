import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:hisab_business/data/hive_service.dart';
import 'package:hisab_business/data/models.dart';
import 'package:hisab_business/l10n/stock_l10n.dart';
import 'package:hisab_business/l10n/strings.dart';
import 'package:hisab_business/screens/stock.dart';
import 'package:hisab_business/screens/stock_item.dart';
import 'package:hisab_business/screens/stock_item_add.dart';
import 'package:hisab_business/services/stock_service.dart';
import 'package:hisab_business/theme.dart';

/// Stock Book crew tests: temp-Hive boot (same pattern as boot_test.dart),
/// service logic (add item, in/out movements, qty, valuation, low stock),
/// and widget smoke tests for all three screens. Run with: flutter test
Future<void> initStockTestHive() async {
  final dir = await Directory.systemTemp.createTemp('hb_stock_test');
  Hive.init(dir.path);
  HiveService.registerAdapters();
  HiveService.stockItems =
      await Hive.openBox<StockItem>(HiveService.stockItemsBox);
  HiveService.stockMovements =
      await Hive.openBox<StockMovement>(HiveService.stockMovementsBox);
  HiveService.parties =
      await Hive.openBox<Party>(HiveService.partiesBox);
  HiveService.settings = await Hive.openBox(HiveService.settingsBox);
}

Widget _wrap(Widget child) => MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(body: child),
    );

void main() {
  setUpAll(() async {
    await initStockTestHive();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  setUp(() async {
    await HiveService.stockItems.clear();
    await HiveService.stockMovements.clear();
    AppLocale.current.value = 'en';
  });

  test('addItem creates a StockItem with the given fields', () async {
    final item = await StockService.addItem(
      name: 'Sugar 1kg',
      unit: 'kg',
      buyPrice: 150,
      sellPrice: 180,
      lowStockAt: 5,
    );
    expect(item.name, 'Sugar 1kg');
    expect(item.unit, 'kg');
    expect(HiveService.stockItems.get(item.id), isNotNull);
  });

  test('in/out movements drive stockQty', () async {
    final item = await StockService.addItem(name: 'Rice', unit: 'kg');
    await StockService.addMovement(
        itemId: item.id, direction: 'in', qty: 50);
    await StockService.addMovement(
        itemId: item.id, direction: 'out', qty: 12.5);
    expect(HiveService.stockQty(item.id), 37.5);
    expect(StockService.qtyOf(item.id), 37.5);
  });

  test('stockValuation sums qty x buyPrice', () async {
    final a = await StockService.addItem(
        name: 'A', unit: 'pcs', buyPrice: 100);
    final b = await StockService.addItem(
        name: 'B', unit: 'pcs', buyPrice: 250);
    await StockService.addMovement(
        itemId: a.id, direction: 'in', qty: 10);
    await StockService.addMovement(
        itemId: b.id, direction: 'in', qty: 4);
    await StockService.addMovement(
        itemId: b.id, direction: 'out', qty: 1);
    // 10*100 + 3*250 = 1750
    expect(StockService.stockValuation(), 1750);
  });

  test('lowStockItems returns items at/below their alert level', () async {
    final low = await StockService.addItem(
        name: 'Low one', lowStockAt: 10);
    final ok = await StockService.addItem(
        name: 'Fine one', lowStockAt: 10);
    final noAlert = await StockService.addItem(name: 'No alert');
    await StockService.addMovement(
        itemId: low.id, direction: 'in', qty: 10); // exactly at level
    await StockService.addMovement(
        itemId: ok.id, direction: 'in', qty: 11);
    await StockService.addMovement(
        itemId: noAlert.id, direction: 'in', qty: 1);
    final lows = StockService.lowStockItems();
    expect(lows.map((i) => i.id), contains(low.id));
    expect(lows.map((i) => i.id), isNot(contains(ok.id)));
    expect(lows.map((i) => i.id), isNot(contains(noAlert.id)));
  });

  test('movementsForItem returns newest first', () async {
    final item = await StockService.addItem(name: 'Dated');
    await StockService.addMovement(
        itemId: item.id,
        direction: 'in',
        qty: 1,
        date: DateTime(2026, 1, 1));
    await StockService.addMovement(
        itemId: item.id,
        direction: 'in',
        qty: 2,
        date: DateTime(2026, 3, 1));
    final list = StockService.movementsForItem(item.id);
    expect(list.length, 2);
    expect(list.first.qty, 2);
    expect(list.last.qty, 1);
  });

  test('updateItem persists edits; deleteItem removes item + movements',
      () async {
    final item = await StockService.addItem(name: 'Old name');
    await StockService.addMovement(
        itemId: item.id, direction: 'in', qty: 5);
    item.name = 'New name';
    await StockService.updateItem(item);
    expect(HiveService.stockItems.get(item.id)!.name, 'New name');
    await StockService.deleteItem(item.id);
    expect(HiveService.stockItems.get(item.id), isNull);
    expect(StockService.movementsForItem(item.id), isEmpty);
  });

  test('stockTr translates en and ur, falls back to key', () {
    AppLocale.current.value = 'en';
    expect(stockTr('stock.title'), 'Stock Book');
    AppLocale.current.value = 'ur';
    expect(stockTr('stock.title'), 'اسٹاک بک');
    expect(stockTr('stock.no.such.key'), 'stock.no.such.key');
    AppLocale.current.value = 'en';
  });

  test('formatQty trims trailing zeros', () {
    expect(StockService.formatQty(10), '10');
    expect(StockService.formatQty(2.5), '2.5');
    expect(StockService.formatQty(0), '0');
  });

  testWidgets('StockScreen shows empty state, then the added item',
      (tester) async {
    await tester.pumpWidget(_wrap(const StockScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(stockTr('stock.emptyTitle')), findsOneWidget);

    // Hive writes use real async I/O: run them outside the fake-async zone.
    final item = await tester.runAsync(() async {
      final it = await StockService.addItem(
          name: 'Test Flour', unit: 'kg', lowStockAt: 5);
      await StockService.addMovement(
          itemId: it.id, direction: 'in', qty: 20);
      return it;
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Test Flour'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(item, isNotNull);
  });

  testWidgets('StockItemAddScreen renders the form', (tester) async {
    await tester.pumpWidget(_wrap(const StockItemAddScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(stockTr('stock.itemName')), findsOneWidget);
    expect(find.text(stockTr('stock.buyPrice')), findsOneWidget);
    expect(find.text(stockTr('stock.sellPrice')), findsOneWidget);
    expect(find.text(stockTr('stock.save')), findsOneWidget);
  });

  testWidgets('StockItemAddScreen requires a name', (tester) async {
    await tester.pumpWidget(_wrap(const StockItemAddScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(stockTr('stock.save')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(stockTr('stock.nameRequired')), findsOneWidget);
  });

  testWidgets('StockItemScreen shows header, warning and ledger',
      (tester) async {
    final item = (await tester.runAsync(() async {
      final it = await StockService.addItem(
          name: 'Low Sugar',
          unit: 'kg',
          buyPrice: 150,
          sellPrice: 180,
          lowStockAt: 10);
      await StockService.addMovement(
          itemId: it.id,
          direction: 'in',
          qty: 10,
          billNo: 'B-1',
          note: 'opening');
      await StockService.addMovement(
          itemId: it.id, direction: 'out', qty: 4);
      return it;
    }))!;

    await tester.pumpWidget(_wrap(StockItemScreen(itemId: item.id)));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Low Sugar'), findsWidgets);
    expect(find.text(stockTr('stock.lowStockWarning')), findsOneWidget);
    expect(find.text(stockTr('stock.movements')), findsOneWidget);
    // running balance of newest (out 4) = 6
    expect(find.text('6'), findsWidgets);
    expect(find.textContaining('B-1'), findsOneWidget);
  });

  testWidgets('StockScreen low-stock tab filters correctly',
      (tester) async {
    await tester.runAsync(() async {
      final low = await StockService.addItem(
          name: 'Almost Gone', lowStockAt: 5);
      final fine =
          await StockService.addItem(name: 'Plenty', lowStockAt: 5);
      await StockService.addMovement(
          itemId: low.id, direction: 'in', qty: 2);
      await StockService.addMovement(
          itemId: fine.id, direction: 'in', qty: 50);
    });

    await tester.pumpWidget(_wrap(const StockScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Almost Gone'), findsOneWidget);
    expect(find.text('Plenty'), findsOneWidget);

    await tester.tap(find.textContaining(stockTr('stock.lowStock')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Almost Gone'), findsOneWidget);
    expect(find.text('Plenty'), findsNothing);
  });
}
