import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../l10n/care_l10n.dart';
import '../services/care_service.dart';
import '../theme.dart';
import '../widgets/hb_chrome.dart';
import '../widgets/hb_rows.dart';

/// Collections hub: Pending (dues to collect), Upcoming (promise dates),
/// History (sent/done reminders). Route: [Routes.reminders].
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  int _tab = 0;
  int _refreshToken = 0;

  void _refresh() => setState(() => _refreshToken++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HBAppBar(
        title: careTr('care.collections'),
        actions: [
          if (_tab == 0)
            IconButton(
              tooltip: careTr('care.setDateForAll'),
              icon: const Icon(Icons.event_available, color: Colors.white),
              onPressed: _bulkPromiseDate,
            ),
        ],
      ),
      body: Column(
        children: [
          HBTabs(
            labels: [
              careTr('care.pending'),
              careTr('care.upcoming'),
              careTr('care.history'),
            ],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          Expanded(
            child: switch (_tab) {
              0 => _PendingTab(
                  key: ValueKey('pending-$_refreshToken'),
                  onChanged: _refresh,
                ),
              1 => _UpcomingList(
                  key: ValueKey('upcoming-$_refreshToken'),
                  onChanged: _refresh,
                ),
              _ => _HistoryList(key: ValueKey('history-$_refreshToken')),
            },
          ),
        ],
      ),
    );
  }

  /// [INFERRED] simple bulk flow: one date picker, applied to every pending party.
  Future<void> _bulkPromiseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: careTr('care.pickDate'),
    );
    if (date == null || !mounted) return;
    for (final row in _pendingRows()) {
      await CareService.setPromiseDate(partyId: row.party.id, date: date);
    }
    if (!mounted) return;
    HBToast.show(context,
        message: careTr('care.bulkDone'), icon: Icons.check_circle);
    _refresh();
  }
}

/// One row in the Pending tab: a party that owes money and/or has an open reminder.
class _PendingRowData {
  final Party party;
  final double balance;
  final Reminder? reminder;
  _PendingRowData(this.party, this.balance, this.reminder);
}

/// Builds pending rows: parties with receivable balance > 0, plus any party
/// with an open due reminder, sorted by due date (no-date rows last).
List<_PendingRowData> _pendingRows() {
  final byParty = <String, Reminder>{};
  for (final r in CareService.pendingReminders()) {
    byParty.putIfAbsent(r.partyId, () => r);
  }
  final rows = <_PendingRowData>[];
  final seen = <String>{};
  for (final p in HiveService.activeParties()) {
    final bal = HiveService.partyBalance(p.id);
    final rem = byParty[p.id];
    if (bal > 0 || rem != null) {
      rows.add(_PendingRowData(p, bal, rem));
      seen.add(p.id);
    }
  }
  for (final entry in byParty.entries) {
    if (seen.contains(entry.key)) continue;
    final p = HiveService.parties.get(entry.key);
    if (p == null || p.archived) continue;
    rows.add(_PendingRowData(p, HiveService.partyBalance(p.id), entry.value));
  }
  final farFuture = DateTime(2100);
  rows.sort((a, b) => (a.reminder?.dueDate ?? farFuture)
      .compareTo(b.reminder?.dueDate ?? farFuture));
  return rows;
}

class _PendingTab extends StatefulWidget {
  final VoidCallback onChanged;
  const _PendingTab({super.key, required this.onChanged});

  @override
  State<_PendingTab> createState() => _PendingTabState();
}

class _PendingTabState extends State<_PendingTab> {
  late List<_PendingRowData> _rows;

  @override
  void initState() {
    super.initState();
    _rows = _pendingRows();
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty) {
      return HBEmptyState(
        icon: Icons.mark_email_read_outlined,
        title: careTr('care.noPending'),
        subtitle: careTr('care.noPendingSub'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _rows.length,
      itemBuilder: (ctx, i) {
        final row = _rows[i];
        final amount = row.balance > 0 ? row.balance : row.reminder!.amount;
        return _ReminderCard(
          party: row.party,
          amount: amount,
          reminder: row.reminder,
          onChanged: widget.onChanged,
        );
      },
    );
  }
}

class _UpcomingList extends StatefulWidget {
  final VoidCallback onChanged;
  const _UpcomingList({super.key, required this.onChanged});

  @override
  State<_UpcomingList> createState() => _UpcomingListState();
}

class _UpcomingListState extends State<_UpcomingList> {
  late List<Reminder> _list;

  @override
  void initState() {
    super.initState();
    _list = CareService.upcomingReminders();
  }

  @override
  Widget build(BuildContext context) {
    if (_list.isEmpty) {
      return HBEmptyState(
        icon: Icons.schedule_outlined,
        title: careTr('care.noUpcoming'),
        subtitle: careTr('care.noUpcomingSub'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _list.length,
      itemBuilder: (ctx, i) {
        final r = _list[i];
        final party = HiveService.parties.get(r.partyId);
        if (party == null) return const SizedBox.shrink();
        return _ReminderCard(
          party: party,
          amount: r.amount,
          reminder: r,
          onChanged: widget.onChanged,
        );
      },
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    final list = CareService.historyReminders();
    if (list.isEmpty) {
      return HBEmptyState(
        icon: Icons.history_outlined,
        title: careTr('care.noHistory'),
        subtitle: careTr('care.noHistorySub'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final r = list[i];
        final party = HiveService.parties.get(r.partyId);
        final name = party?.name ?? '—';
        final stamp = r.lastSentAt ?? r.createdAt;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: HBColors.primarySoft,
              child: Icon(
                r.done ? Icons.check_circle : Icons.send,
                color: HBColors.primary,
              ),
            ),
            title: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${careTr('care.sentTimes').replaceFirst('{n}', '${r.sentCount}')} · ${careDateShort(stamp)}',
            ),
            trailing: HBAmountText(r.amount, isIn: false, size: 15),
          ),
        );
      },
    );
  }
}

/// Card with party, amount, due-date chip and the four actions:
/// SMS, WhatsApp, promise date, mark done.
class _ReminderCard extends StatelessWidget {
  final Party party;
  final double amount;
  final Reminder? reminder;
  final VoidCallback onChanged;

  const _ReminderCard({
    required this.party,
    required this.amount,
    required this.reminder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(party.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                // Receivable (they owe you) is RED per money semantics.
                HBAmountText(amount, isIn: false, size: 17),
              ],
            ),
            if (reminder != null) ...[
              const SizedBox(height: 6),
              _dueChip(context, reminder!.dueDate),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                _ActionBtn(
                  icon: Icons.sms_outlined,
                  label: careTr('care.sms'),
                  onTap: () => _send(context, 'sms'),
                ),
                _ActionBtn(
                  icon: Icons.chat_bubble_outline,
                  label: careTr('care.whatsapp'),
                  onTap: () => _send(context, 'whatsapp'),
                ),
                _ActionBtn(
                  icon: Icons.event_outlined,
                  label: careTr('care.promiseDate'),
                  onTap: () => _pickDate(context),
                ),
                const Spacer(),
                _ActionBtn(
                  icon: Icons.check_circle_outline,
                  label: careTr('care.markDone'),
                  onTap: () => _confirmDone(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _message() {
    final biz = HiveService.currentBusiness?.name ?? careTr('care.myBusiness');
    // [INFERRED] own reminder wording — never copied from any competitor.
    return 'Hello ${party.name}, this is a friendly payment reminder from $biz: '
        '${formatPKR(amount)} is still pending on your khata. '
        'Kindly clear it at your earliest. Thank you!';
  }

  String _digits() => party.phone.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _send(BuildContext context, String channel) async {
    final digits = _digits();
    if (digits.isEmpty) {
      if (context.mounted) {
        HBToast.show(context,
            message: careTr('care.noPhone'), icon: Icons.error_outline);
      }
      return;
    }
    final msg = _message();
    final uri = channel == 'sms'
        ? Uri(scheme: 'sms', path: digits, queryParameters: {'body': msg})
        : Uri.parse(
            'https://wa.me/$digits?text=${Uri.encodeComponent(msg)}');
    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched || !context.mounted) return;
    // Log the send against a reminder row so History stays accurate.
    if (reminder != null) {
      await CareService.markReminderSent(reminder!.id, channel);
    } else {
      await CareService.ensureAndMarkSent(party.id, amount, channel);
    }
    if (context.mounted) {
      HBToast.show(context,
          message: careTr('care.reminderOpened'), icon: Icons.send);
      onChanged();
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final initial = reminder?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    final date = await showDatePicker(
      context: context,
      initialDate:
          initial.isBefore(DateTime.now()) ? DateTime.now() : initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: careTr('care.pickDate'),
    );
    if (date == null || !context.mounted) return;
    await CareService.setPromiseDate(
        partyId: party.id, date: date, amount: amount);
    if (context.mounted) {
      HBToast.show(context,
          message: careTr('care.promiseSaved'), icon: Icons.event_available);
      onChanged();
    }
  }

  Future<void> _confirmDone(BuildContext context) async {
    if (reminder == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(careTr('care.confirmDoneTitle')),
        content: Text(careTr('care.confirmDoneBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(careTr('care.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(careTr('care.confirm')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await CareService.markDone(reminder!.id);
    if (context.mounted) {
      HBToast.show(context,
          message: careTr('care.markedDone'), icon: Icons.check_circle);
      onChanged();
    }
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: HBColors.primary),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

Widget _dueChip(BuildContext context, DateTime due) {
  final label = careDayLabel(due);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  late Color bg;
  late Color fg;
  late String text;
  switch (label) {
    case 'overdue':
      bg = moneySoft(false, isDark: isDark);
      fg = moneyColor(false, isDark: isDark);
      text = '${careTr('care.overdue')} · ${careDateShort(due)}';
    case 'today':
      bg = isDark ? HBColors.primarySoftDark : HBColors.primarySoft;
      fg = HBColors.primary;
      text = careTr('care.today');
    default:
      bg = isDark ? HBColors.hairlineDark : HBColors.page;
      fg = isDark ? HBColors.mutedDark : HBColors.muted;
      text = '${careTr('care.due')} · ${careDateShort(due)}';
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration:
        BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(text,
        style:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
  );
}
