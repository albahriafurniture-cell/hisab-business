import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../l10n/staff_l10n.dart';
import '../l10n/strings.dart';
import '../routes.dart';
import '../services/staff_service.dart';
import '../theme.dart';
import '../widgets/hb_actions.dart';
import '../widgets/hb_cards.dart';
import '../widgets/hb_chrome.dart';
import '../widgets/hb_rows.dart';

/// Reusable staff photo/initials avatar, shared by the staff screens.
class StaffAvatar extends StatelessWidget {
  final StaffMember staff;
  final double radius;

  const StaffAvatar({super.key, required this.staff, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = staff.photoPath.isNotEmpty &&
        !kIsWeb &&
        File(staff.photoPath).existsSync();
    if (hasPhoto) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(staff.photoPath)),
      );
    }
    final name = staff.name.trim();
    final initials = name.isEmpty
        ? '?'
        : name
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w[0])
            .join()
            .toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: HBColors.primarySoft,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: HBColors.primaryDeep,
        ),
      ),
    );
  }
}

/// Staff Book — daily attendance log + entry point to payroll & slips.
class StaffScreen extends StatefulWidget {
  static const routeName = Routes.staff;

  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  DateTime _day = DateTime.now();
  // null = all, 'present' = only marked present (incl. half), 'absent'
  String? _filter;

  DateTime get _dayOnly => DateTime(_day.year, _day.month, _day.day);

  void _changeDay(int delta) {
    setState(() => _day = _day.add(Duration(days: delta)));
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _toggle(String staffId, String status) async {
    await StaffService.markAttendance(staffId, _dayOnly, status);
    if (mounted) {
      HBToast.show(context,
          message: staffTr('staff.marked'), icon: Icons.check_circle);
    }
  }

  void _openPayrollPicker() {
    final list = StaffService.activeStaff();
    showHBSheet<void>(context,
        title: staffTr('staff.chooseStaff'),
        child: list.isEmpty
            ? HBEmptyState(
                icon: Icons.people_outline,
                title: staffTr('staff.empty'),
                subtitle: staffTr('staff.emptySub'),
                ctaLabel: staffTr('staff.add'),
                onCta: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed(Routes.staffAdd);
                },
              )
            : Column(
                children: [
                  for (final s in list)
                    ListTile(
                      leading: StaffAvatar(staff: s),
                      title: Text(s.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: s.role.isEmpty ? null : Text(s.role),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushNamed(Routes.staffProfile,
                            arguments: {'staffId': s.id});
                      },
                    ),
                ],
              ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, lang, child) {
        return ListenableBuilder(
          listenable: Listenable.merge([
            HiveService.staff.listenable(),
            HiveService.attendance.listenable(),
            HiveService.salaryPayments.listenable(),
          ]),
          builder: (context, _) {
            final counts = StaffService.countsForDay(_dayOnly);
            final all = StaffService.activeStaff();
            var list = all;
            if (_filter == 'present') {
              list = all
                  .where((s) => {
                        'present',
                        'half'
                      }.contains(StaffService.statusFor(s.id, _dayOnly)))
                  .toList();
            } else if (_filter == 'absent') {
              list = all
                  .where((s) =>
                      StaffService.statusFor(s.id, _dayOnly) == 'absent')
                  .toList();
            }
            return Scaffold(
              appBar: HBAppBar(title: staffTr('staff.title')),
              body: list.isEmpty && _filter == null
                  ? _buildEmptyBody()
                  : _buildList(context, isDark, counts, list),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: HBPillButton(
                    label: staffTr('staff.managePayroll'),
                    icon: Icons.receipt_long,
                    onPressed: _openPayrollPicker,
                    color: HBColors.ink,
                  ),
                ),
              ),
              floatingActionButton: HBFab(
                label: staffTr('staff.add'),
                icon: Icons.add,
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.staffAdd),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyBody() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _overviewCard(),
          const SizedBox(height: 24),
          HBEmptyState(
            icon: Icons.people_outline,
            title: staffTr('staff.empty'),
            subtitle: staffTr('staff.emptySub'),
            ctaLabel: staffTr('staff.add'),
            onCta: () => Navigator.of(context).pushNamed(Routes.staffAdd),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, bool isDark,
      ({int present, int absent, int half, int unmarked}) counts,
      List<StaffMember> list) {
    final dayFmt = DateFormat('EEE, d MMM yyyy');
    final isToday = DateUtils.isSameDay(_day, DateTime.now());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _overviewCard(),
        const SizedBox(height: 16),
        // ---- date selector ----
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeDay(-1),
            ),
            Expanded(
              child: GestureDetector(
                onTap: _pickDay,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? HBColors.cardDark : HBColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isDark
                            ? HBColors.hairlineDark
                            : HBColors.hairline),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: HBColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        isToday
                            ? '${dayFmt.format(_day)} • ${staffTr('staff.dailyLog')}'
                            : dayFmt.format(_day),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed:
                  isToday ? null : () => _changeDay(1), // never past today
            ),
          ],
        ),
        const SizedBox(height: 12),
        HBSectionLabel(staffTr('staff.dailyLog')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            HBChip(
              label: staffTr('staff.allStaff'),
              selected: _filter == null,
              onTap: () => setState(() => _filter = null),
            ),
            HBChip(
              label:
                  '${staffTr('staff.present')} (${counts.present + counts.half})',
              selected: _filter == 'present',
              onTap: () => setState(() =>
                  _filter = _filter == 'present' ? null : 'present'),
            ),
            HBChip(
              label: '${staffTr('staff.absent')} (${counts.absent})',
              selected: _filter == 'absent',
              onTap: () => setState(
                  () => _filter = _filter == 'absent' ? null : 'absent'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                _filter == 'present'
                    ? staffTr('staff.present')
                    : staffTr('staff.absent'),
                style: const TextStyle(color: HBColors.muted),
              ),
            ),
          )
        else
          for (final s in list) _staffRow(context, isDark, s),
      ],
    );
  }

  /// Gradient overview card with original copy about attendance + payroll.
  Widget _overviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [HBColors.gradientTop, HBColors.gradientBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_alt, color: Colors.white, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(staffTr('staff.overviewTitle'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(staffTr('staff.overviewSub'),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _staffRow(BuildContext context, bool isDark, StaffMember s) {
    final status = StaffService.statusFor(s.id, _dayOnly);
    final due = HiveService.staffAdvanceBalance(s.id);
    final hide = HiveService.hideBalances;
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? HBColors.cardDark : HBColors.card,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context)
            .pushNamed(Routes.staffProfile, arguments: {'staffId': s.id}),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              StaffAvatar(staff: s),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    if (s.role.isNotEmpty)
                      Text(s.role,
                          style: const TextStyle(
                              fontSize: 12, color: HBColors.muted)),
                    const SizedBox(height: 2),
                    if (due > 0)
                      Text(
                        '${staffTr('staff.advanceDue')} ${hide ? '••••••' : formatPKR(due)}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: HBColors.moneyOut,
                            fontWeight: FontWeight.w600),
                      )
                    else
                      Text(staffTr('staff.noDue'),
                          style: const TextStyle(
                              fontSize: 12, color: HBColors.muted)),
                  ],
                ),
              ),
              // P / A toggle buttons
              _markButton(
                label: 'P',
                active: status == 'present',
                activeColor: HBColors.moneyIn,
                onTap: () => _toggle(s.id, 'present'),
              ),
              const SizedBox(width: 6),
              _markButton(
                label: 'A',
                active: status == 'absent',
                activeColor: HBColors.moneyOut,
                onTap: () => _toggle(s.id, 'absent'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _markButton({
    required String label,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? activeColor
              : (isDark ? HBColors.cardDark : HBColors.page),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active
                  ? activeColor
                  : (isDark ? HBColors.hairlineDark : HBColors.hairline)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: active
                    ? Colors.white
                    : (isDark ? HBColors.mutedDark : HBColors.muted))),
      ),
    );
  }
}
