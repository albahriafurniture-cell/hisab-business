import 'package:uuid/uuid.dart';

import '../data/hive_service.dart';
import '../data/models.dart';

/// Domain logic for the khata (party ledger) module.
///
/// Money semantics (per PROJECT_STATUS — mandatory app-wide):
/// - `gave` = you gave money → you will GET it back → RED (receivable).
/// - `got`  = you got money  → you must GIVE it back → GREEN (payable).
/// - balance > 0  → they owe you (receivable); balance < 0 → you owe them.
class KhataService {
  KhataService._();

  static final Uuid _uuid = Uuid();

  /// Net balance for [partyId]: receivable = gave − got.
  /// Positive = they owe you, negative = you owe them.
  static double balanceForParty(String partyId) =>
      HiveService.partyBalance(partyId);

  /// Global totals across all active parties:
  /// `payables` = sum of |negative balances| (you owe, green),
  /// `receivables` = sum of positive balances (they owe you, red).
  static Map<String, double> totals() {
    double payables = 0;
    double receivables = 0;
    for (final p in HiveService.activeParties()) {
      final bal = HiveService.partyBalance(p.id);
      if (bal > 0) {
        receivables += bal;
      } else if (bal < 0) {
        payables += -bal;
      }
    }
    return {'payables': payables, 'receivables': receivables};
  }

  /// Global {gave, got} entry-amount totals across all parties.
  /// [INFERRED] helper for the home dashboard summary card.
  static Map<String, double> gaveGot() {
    double gave = 0;
    double got = 0;
    for (final e in HiveService.khataEntries.values) {
      if (e.direction == 'gave') {
        gave += e.amount;
      } else {
        got += e.amount;
      }
    }
    return {'gave': gave, 'got': got};
  }

  /// All entries for [partyId], newest first.
  static List<KhataEntry> entriesForParty(String partyId) =>
      HiveService.entriesForParty(partyId);

  /// Date of the newest entry for [partyId], or null when there are none.
  /// [INFERRED] helper for party-list subtitles.
  static DateTime? lastEntryDate(String partyId) {
    final entries = HiveService.entriesForParty(partyId);
    return entries.isEmpty ? null : entries.first.date;
  }

  /// Case-insensitive name/phone search over active parties,
  /// optionally restricted to a [kind] (`customer` | `supplier`).
  /// [INFERRED] helper for the party-list search row.
  static List<Party> searchParties(String query, {String? kind}) {
    final q = query.trim().toLowerCase();
    return HiveService.activeParties(kind: kind).where((p) {
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.phone.toLowerCase().contains(q);
    }).toList();
  }

  /// Records a khata entry and bumps the party's `updatedAt`.
  /// Throws [ArgumentError] when the direction or amount is invalid.
  static Future<KhataEntry> addEntry({
    required String partyId,
    required String direction, // 'gave' | 'got'
    required double amount,
    required DateTime date,
    String detail = '',
    String photoPath = '',
  }) async {
    if (direction != 'gave' && direction != 'got') {
      throw ArgumentError.value(
          direction, 'direction', "must be 'gave' or 'got'");
    }
    if (amount <= 0) {
      throw ArgumentError.value(
          amount, 'amount', 'must be greater than zero');
    }
    final now = DateTime.now();
    final entry = KhataEntry(
      id: _uuid.v4(),
      partyId: partyId,
      direction: direction,
      amount: amount,
      date: date,
      detail: detail,
      photoPath: photoPath,
      createdAt: now,
    );
    await HiveService.khataEntries.put(entry.id, entry);
    final party = HiveService.parties.get(partyId);
    if (party != null) {
      party.updatedAt = now;
      await HiveService.parties.put(party.id, party);
    }
    return entry;
  }

  /// Deletes one khata entry by id. [INFERRED]
  static Future<void> deleteEntry(String id) =>
      HiveService.khataEntries.delete(id);
}
