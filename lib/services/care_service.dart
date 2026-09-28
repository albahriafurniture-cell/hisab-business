import 'dart:io';

import 'package:uuid/uuid.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../utils/app_paths.dart';

/// Care-crew service: collection reminders, backup file discovery, and
/// small shared helpers. All Hive access goes through [HiveService].
class CareService {
  CareService._();

  // ------------------------------------------------------------ reminders
  /// Open (not done) reminders, oldest due date first.
  static List<Reminder> dueReminders() {
    final list =
        HiveService.reminders.values.where((r) => !r.done).toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  /// All reminders for one party, newest first.
  static List<Reminder> remindersForParty(String partyId) {
    final list = HiveService.reminders.values
        .where((r) => r.partyId == partyId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Open reminders whose due date is still in the future (after today).
  static List<Reminder> upcomingReminders() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dueReminders()
        .where((r) => r.dueDate.isAfter(
            today.add(const Duration(days: 1)).subtract(const Duration(seconds: 1))))
        .toList();
  }

  /// Open reminders due today or earlier.
  static List<Reminder> pendingReminders() {
    final now = DateTime.now();
    final endOfToday =
        DateTime(now.year, now.month, now.day, 23, 59, 59);
    return dueReminders()
        .where((r) => !r.dueDate.isAfter(endOfToday))
        .toList();
  }

  /// Sent or completed reminders, most recently touched first.
  static List<Reminder> historyReminders() {
    final list = HiveService.reminders.values
        .where((r) => r.done || r.sentCount > 0)
        .toList()
      ..sort((a, b) {
        final at = a.lastSentAt ?? a.createdAt;
        final bt = b.lastSentAt ?? b.createdAt;
        return bt.compareTo(at);
      });
    return list;
  }

  /// Creates or updates the open promise-date reminder for [partyId].
  /// If [amount] is omitted, the party's current receivable balance is used.
  static Future<Reminder> setPromiseDate({
    required String partyId,
    required DateTime date,
    double? amount,
    String note = '',
  }) async {
    final open = HiveService.reminders.values.where(
        (r) => r.partyId == partyId && !r.done);
    final resolvedAmount = amount ?? HiveService.partyBalance(partyId);
    if (open.isNotEmpty) {
      final r = open.first;
      r.dueDate = date;
      r.amount = resolvedAmount;
      if (note.isNotEmpty) r.note = note;
      await HiveService.reminders.put(r.id, r);
      return r;
    }
    final r = Reminder(
      id: const Uuid().v4(),
      partyId: partyId,
      dueDate: date,
      amount: resolvedAmount,
      note: note,
      createdAt: DateTime.now(),
    );
    await HiveService.reminders.put(r.id, r);
    return r;
  }

  /// Records that a reminder was sent. [channel] is 'sms' or 'whatsapp'
  /// (kept for future analytics; the count is what the UI shows today).
  static Future<void> markReminderSent(String id, String channel) async {
    final r = HiveService.reminders.get(id);
    if (r == null) return;
    assert(channel == 'sms' || channel == 'whatsapp');
    r.sentCount += 1;
    r.lastSentAt = DateTime.now();
    await HiveService.reminders.put(r.id, r);
  }

  /// Marks a reminder done (moves it to history).
  static Future<void> markDone(String id) async {
    final r = HiveService.reminders.get(id);
    if (r == null) return;
    r.done = true;
    await HiveService.reminders.put(r.id, r);
  }

  /// Ensures a trackable reminder exists for [partyId] and records a send.
  /// Used when the user sends an SMS/WhatsApp from a row that has no
  /// reminder yet.
  static Future<Reminder> ensureAndMarkSent(
      String partyId, double amount, String channel) async {
    final open = HiveService.reminders.values
        .where((r) => r.partyId == partyId && !r.done);
    final r = open.isNotEmpty
        ? open.first
        : await setPromiseDate(
            partyId: partyId, date: DateTime.now(), amount: amount);
    await markReminderSent(r.id, channel);
    return r;
  }

  // --------------------------------------------------------------- backup
  /// Backup *.json files created by [HiveService.exportBackupToFile],
  /// newest first. Never throws — returns [] when storage is unreachable.
  static Future<List<File>> backupFiles() async {
    try {
      final files = <File>[];
      for (final dir in [
        await AppPaths.externalOrDocuments('backups'),
        await AppPaths.documentsDir(),
      ]) {
        if (!await dir.exists()) continue;
        await for (final e in dir.list()) {
          if (e is File &&
              e.path.toLowerCase().endsWith('.json') &&
              e.path.contains('hisab_business')) {
            files.add(e);
          }
        }
      }
      // De-dupe (same file reachable via both dirs) and sort newest first.
      final seen = <String>{};
      final unique =
          files.where((f) => seen.add(f.path)).toList()
            ..sort((a, b) => b.path.compareTo(a.path));
      return unique;
    } catch (_) {
      return [];
    }
  }

  /// When "Backup Now" last ran (stored in the settings box by the UI).
  /// [INFERRED] key — the settings box is untyped, so no foundation change.
  static DateTime? get lastBackupAt {
    final raw = HiveService.settings.get('lastBackupAt') as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static Future<void> recordBackupNow() =>
      HiveService.settings.put('lastBackupAt', DateTime.now().toIso8601String());
}

/// Short human date, e.g. 3 Sep 2026. Hand-rolled (no locale surprises).
String careDateShort(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// Relative day label used on reminder chips.
String careDayLabel(DateTime due) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(due.year, due.month, due.day);
  final diff = day.difference(today).inDays;
  if (diff < 0) return 'overdue';
  if (diff == 0) return 'today';
  if (diff == 1) return 'tomorrow';
  return 'future';
}
