import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:hisab_business/data/hive_service.dart';
import 'package:hisab_business/data/models.dart';
import 'package:hisab_business/l10n/care_l10n.dart';
import 'package:hisab_business/screens/backup.dart';
import 'package:hisab_business/screens/business_card.dart';
import 'package:hisab_business/screens/more.dart';
import 'package:hisab_business/screens/reminders.dart';
import 'package:hisab_business/screens/settings.dart';
import 'package:hisab_business/services/care_service.dart';

import 'boot_test.dart' show initTestHive;

/// Care-crew tests: reminder lifecycle, backup/restore round trip, and a
/// smoke pump of all five owned screens. Run with: flutter test
void main() {
  setUpAll(() async {
    await initTestHive();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  test('careTr falls back to English and the key itself', () {
    expect(careTr('care.backupNow'), isNotEmpty);
    expect(careTr('care.noSuchKey'), 'care.noSuchKey');
  });

  test('create reminder, mark sent, mark done', () async {
    final now = DateTime.now();
    final party = Party(
        id: 'care-p1', name: 'Care Party', createdAt: now, updatedAt: now);
    await HiveService.parties.put(party.id, party);

    final due = now.add(const Duration(days: 2));
    final created = await CareService.setPromiseDate(
        partyId: party.id, date: due, amount: 5000);
    expect(created.partyId, party.id);
    expect(created.amount, 5000);

    // Setting again updates the same open reminder, no duplicate.
    await CareService.setPromiseDate(partyId: party.id, date: due);
    expect(
        HiveService.reminders.values
            .where((r) => r.partyId == party.id && !r.done)
            .length,
        1);

    expect(
        CareService.dueReminders().any((r) => r.partyId == party.id), isTrue);
    expect(
        CareService.remindersForParty(party.id).length, greaterThanOrEqualTo(1));

    await CareService.markReminderSent(created.id, 'sms');
    final sent = HiveService.reminders.get(created.id)!;
    expect(sent.sentCount, 1);
    expect(sent.lastSentAt, isNotNull);
    expect(CareService.historyReminders().any((r) => r.id == created.id),
        isTrue);

    await CareService.markDone(created.id);
    expect(HiveService.reminders.get(created.id)!.done, isTrue);
    expect(CareService.dueReminders().any((r) => r.id == created.id),
        isFalse);
  });

  test('backup/restore round trip keeps reminders', () async {
    final now = DateTime.now();
    await HiveService.parties.put(
        'care-p2',
        Party(
            id: 'care-p2',
            name: 'Backup Party',
            createdAt: now,
            updatedAt: now));
    await CareService.setPromiseDate(
        partyId: 'care-p2', date: now, amount: 2500, note: 'roundtrip');

    final json = await HiveService.backupToJson();
    expect(json.contains('hisab_business'), isTrue);

    await HiveService.resetAll();
    expect(HiveService.reminders.isEmpty, isTrue);
    expect(HiveService.parties.isEmpty, isTrue);

    await HiveService.restoreFromJson(json);
    expect(HiveService.parties.get('care-p2')?.name, 'Backup Party');
    final restored = HiveService.reminders.values
        .where((r) => r.partyId == 'care-p2')
        .toList();
    expect(restored, isNotEmpty);
    expect(restored.first.amount, 2500);
    expect(restored.first.note, 'roundtrip');
  });

  test('backupFiles never throws', () async {
    final files = await CareService.backupFiles();
    expect(files, isA<List>());
  });

  testWidgets('all five care screens pump without exceptions',
      (tester) async {
    final screens = [
      const RemindersScreen(),
      const BackupScreen(),
      const BusinessCardScreen(),
      const SettingsScreen(),
      const MoreScreen(),
    ];
    for (final screen in screens) {
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'pumping ${screen.runtimeType} threw');
    }
  });

  testWidgets('reminders tabs switch without exceptions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RemindersScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Tap the Upcoming and History tabs.
    await tester.tap(find.text(careTr('care.upcoming')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(careTr('care.history')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('more screen opens recycle bin and help', (tester) async {
    // The tile grid is itself a Scrollable (NeverScrollablePhysics), so
    // scrollUntilVisible's default finder is ambiguous and its drag never
    // lands; jump the outer list directly instead.
    Future<void> revealTile(Finder tile) async {
      final outerScroll = find.ancestor(
          of: find.byType(GridView), matching: find.byType(Scrollable));
      final state = tester.state<ScrollableState>(outerScroll);
      final dy = tester.getCenter(tile).dy;
      state.position.jumpTo((state.position.pixels + dy - 300)
          .clamp(0.0, state.position.maxScrollExtent));
      await tester.pump();
    }

    await tester.pumpWidget(const MaterialApp(home: MoreScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await revealTile(find.text(careTr('care.recycleBin')));
    await tester.tap(find.text(careTr('care.recycleBin')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(careTr('care.noArchived')), findsOneWidget);

    // Back to the More screen for the help flow (keeps the real nav stack;
    // HBAppBar's back chevron is a plain IconButton, not a BackButton).
    await tester
        .tap(find.widgetWithIcon(IconButton, Icons.arrow_back));
    await tester.pumpAndSettle();
    await revealTile(find.text(careTr('care.helpFaq')));
    await tester.tap(find.text(careTr('care.helpFaq')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(careTr('care.faq1q')), findsOneWidget);
  });
}
