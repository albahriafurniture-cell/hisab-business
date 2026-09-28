import 'package:uuid/uuid.dart';

import '../data/hive_service.dart';
import '../data/models.dart';

/// Monthly salary-slip breakdown for one staff member.
///
/// All amounts are month-scoped (calendar year+month), so a slip never
/// mixes this month's salary with another month's payments:
///   netPayable = basicSalary + bonuses − advances − salaryPaid (≥ 0)
class StaffMonthSlip {
  final String staffId;
  final int year;
  final int month;
  final double basicSalary;
  final double bonuses;
  final double salaryPaid;
  final double advances;
  final double netPayable;

  const StaffMonthSlip({
    required this.staffId,
    required this.year,
    required this.month,
    required this.basicSalary,
    required this.bonuses,
    required this.salaryPaid,
    required this.advances,
    required this.netPayable,
  });
}

/// Staff-domain operations: attendance, payments and payroll slips.
/// // [INFERRED] helper layer designed for the Staff Book screens.
class StaffService {
  const StaffService._();

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static bool _sameDay(DateTime a, DateTime b) => _dayKey(a) == _dayKey(b);

  static String _nextKey() => const Uuid().v4();

  /// All ACTIVE staff, alphabetical.
  static List<StaffMember> activeStaff() {
    final list = HiveService.staff.values.where((s) => s.active).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Persist today's (or any day's) attendance for one staff member.
  /// Re-tapping the same status removes the record (acts as a toggle).
  static Future<void> markAttendance(
      String staffId, DateTime date, String status) async {
    final day = DateTime(date.year, date.month, date.day);
    AttendanceRecord? existing;
    for (final r in HiveService.attendance.values) {
      if (r.staffId == staffId && _sameDay(r.date, day)) {
        existing = r;
        break;
      }
    }
    if (existing != null) {
      if (existing.status == status) {
        // Re-tapping the same status un-marks the day (toggle off).
        await HiveService.attendance.delete(existing.id);
      } else {
        existing.status = status;
        await HiveService.attendance.put(existing.id, existing);
      }
    } else {
      final record = AttendanceRecord(
        id: _nextKey(),
        staffId: staffId,
        date: day,
        status: status,
      );
      await HiveService.attendance.put(record.id, record);
    }
  }

  /// staffId -> status ('present'|'absent'|'half') for one calendar day.
  static Map<String, String> attendanceForDay(DateTime date) {
    final map = <String, String>{};
    for (final r in HiveService.attendance.values) {
      if (_sameDay(r.date, date)) map[r.staffId] = r.status;
    }
    return map;
  }

  /// Status for one staff member on one day, or null if unmarked.
  static String? statusFor(String staffId, DateTime date) =>
      attendanceForDay(date)[staffId];

  /// Present/absent/half counts among active staff for a day.
  static ({int present, int absent, int half, int unmarked}) countsForDay(
      DateTime date) {
    final map = attendanceForDay(date);
    var present = 0, absent = 0, half = 0, unmarked = 0;
    for (final s in activeStaff()) {
      switch (map[s.id]) {
        case 'present':
          present++;
          break;
        case 'absent':
          absent++;
          break;
        case 'half':
          half++;
          break;
        default:
          unmarked++;
      }
    }
    return (present: present, absent: absent, half: half, unmarked: unmarked);
  }

  static ({int present, int absent, int half, int unmarked}) todayCounts() =>
      countsForDay(DateTime.now());

  /// Last [days] of attendance for one staff member, newest first.
  static List<AttendanceRecord> historyForStaff(String staffId, int days) {
    final list = HiveService.attendance.values
        .where((r) => r.staffId == staffId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list.take(days).toList();
  }

  /// Present/absent totals for the last [days] for one staff member.
  static ({int present, int absent}) monthAttendanceSummary(
      String staffId, int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days - 1));
    DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    var present = 0, absent = 0;
    for (final r in HiveService.attendance.values) {
      if (r.staffId != staffId) continue;
      if (dayOnly(r.date).isBefore(dayOnly(cutoff))) continue;
      if (r.status == 'present' || r.status == 'half') present++;
      if (r.status == 'absent') absent++;
    }
    return (present: present, absent: absent);
  }

  /// Record a salary/advance/bonus payment for a staff member.
  static Future<SalaryPayment> addPayment({
    required String staffId,
    required double amount,
    required String kind, // 'salary' | 'advance' | 'bonus'
    required DateTime date,
    String note = '',
  }) async {
    assert(kind == 'salary' || kind == 'advance' || kind == 'bonus');
    final p = SalaryPayment(
      id: _nextKey(),
      staffId: staffId,
      amount: amount,
      date: date,
      kind: kind,
      note: note,
    );
    await HiveService.salaryPayments.put(p.id, p);
    return p;
  }

  /// All payments for one staff member, newest first.
  static List<SalaryPayment> paymentsForStaff(String staffId) {
    final list = HiveService.salaryPayments.values
        .where((p) => p.staffId == staffId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Month-scoped payroll numbers for the slip.
  static StaffMonthSlip monthlySlipData(String staffId, DateTime month) {
    final staff = HiveService.staff.get(staffId);
    final basic = staff?.monthlySalary ?? 0;
    var bonuses = 0.0, salaryPaid = 0.0, advances = 0.0;
    for (final p in HiveService.salaryPayments.values) {
      if (p.staffId != staffId) continue;
      if (p.date.year != month.year || p.date.month != month.month) continue;
      switch (p.kind) {
        case 'bonus':
          bonuses += p.amount;
          break;
        case 'salary':
          salaryPaid += p.amount;
          break;
        case 'advance':
          advances += p.amount;
          break;
      }
    }
    var net = basic + bonuses - advances - salaryPaid;
    if (net < 0) net = 0;
    return StaffMonthSlip(
      staffId: staffId,
      year: month.year,
      month: month.month,
      basicSalary: basic,
      bonuses: bonuses,
      salaryPaid: salaryPaid,
      advances: advances,
      netPayable: net,
    );
  }
}
