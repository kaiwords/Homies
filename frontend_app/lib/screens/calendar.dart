import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/ui_kit.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

enum _Type { rent, bill, subscription, chore, party, lease, task }

class _Event {
  final _Type type;
  final String title;
  final String subtitle;
  final DateTime date;
  final String? id; // set for task events — used for deletion

  const _Event({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.date,
    this.id,
  });

  Color get color => switch (type) {
        _Type.rent => HomiesColors.accent,
        _Type.bill => const Color(0xFF3182CE),
        _Type.subscription => const Color(0xFF7C3AED),
        _Type.chore => HomiesColors.ok,
        _Type.party => const Color(0xFFDB2777),
        _Type.lease => HomiesColors.warn,
        _Type.task => const Color(0xFFD97706),
      };

  IconData get icon => switch (type) {
        _Type.rent => Icons.home_outlined,
        _Type.bill => Icons.receipt_long_outlined,
        _Type.subscription => Icons.subscriptions_outlined,
        _Type.chore => Icons.cleaning_services_outlined,
        _Type.party => Icons.celebration_outlined,
        _Type.lease => Icons.description_outlined,
        _Type.task => Icons.task_alt_outlined,
      };

  String get typeLabel => switch (type) {
        _Type.rent => 'Rent',
        _Type.bill => 'Bill',
        _Type.subscription => 'Subscription',
        _Type.chore => 'Chore',
        _Type.party => 'Party',
        _Type.lease => 'Lease',
        _Type.task => 'My task',
      };
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _viewMonth = () {
    final n = DateTime.now();
    return DateTime(n.year, n.month);
  }();
  DateTime? _selectedDay;
  _Type? _filter; // null = all

  List<_Event> _buildEvents(HomiesState state) {
    final events = <_Event>[];
    final cu = state.currentUser;

    // Lease events
    final leaseStart = parseIso(state.property.leaseStart);
    if (leaseStart != null) {
      events.add(_Event(
        type: _Type.lease,
        title: 'Lease started',
        subtitle: state.property.address,
        date: leaseStart,
      ));
    }
    final leaseEnd = parseIso(state.property.leaseEnd);
    if (leaseEnd != null) {
      events.add(_Event(
        type: _Type.lease,
        title: 'Lease ends',
        subtitle: state.property.address,
        date: leaseEnd,
      ));
    }

    // Rent due dates — next 52 periods
    final rentStartStr = state.property.rentStartDate;
    if (rentStartStr != null && rentStartStr.isNotEmpty) {
      var current = rentStartStr;
      for (var i = 0; i < 52; i++) {
        final date = parseIso(current);
        if (date == null) break;
        final paid = state.rentPayments.where((p) => p.periodStart == current).length;
        final total = state.activeHousemates.length;
        final myPaid = cu != null && state.rentPayments.any((p) => p.userId == cu.id && p.periodStart == current);
        events.add(_Event(
          type: _Type.rent,
          title: 'Rent due',
          subtitle: '$paid/$total paid${myPaid ? ' · You paid' : ''}',
          date: date,
        ));
        final next = addCadence(current, state.property.rentCadence, null);
        if (next == null || next == current) break;
        current = next;
      }
    }

    // Bills
    for (final bill in state.bills) {
      final date = parseIso(bill.dueDate);
      if (date == null) continue;
      final myPaid = cu != null && (bill.paidBy[cu.id] ?? false);
      events.add(_Event(
        type: _Type.bill,
        title: bill.title,
        subtitle: '\$${bill.amount.toStringAsFixed(2)}${myPaid ? ' · You paid' : ''}',
        date: date,
      ));
    }

    // Subscriptions — project upcoming payment dates from today (up to 2 years)
    final horizon = DateTime.now().add(const Duration(days: 730));
    for (final sub in state.subscriptions) {
      var dateStr = todayIso();
      for (var i = 0; i < 30; i++) {
        final date = parseIso(dateStr);
        if (date == null || date.isAfter(horizon)) break;
        events.add(_Event(
          type: _Type.subscription,
          title: sub.name,
          subtitle: '\$${sub.amount.toStringAsFixed(2)} · ${sub.cadence}',
          date: date,
        ));
        final next = addCadence(dateStr, sub.cadence, null);
        if (next == null || next == dateStr) break;
        dateStr = next;
      }
    }

    // Chores
    for (final task in state.cleaningTasks) {
      final date = parseIso(task.dueDate);
      if (date == null) continue;
      final assignee = state.findUser(task.assignee);
      events.add(_Event(
        type: _Type.chore,
        title: task.task,
        subtitle: '${assignee?.name ?? task.assignee}${task.done ? ' · Done' : ''}',
        date: date,
      ));
    }

    // Parties
    for (final party in state.parties) {
      final date = parseIso(party.date);
      if (date == null) continue;
      events.add(_Event(
        type: _Type.party,
        title: party.title,
        subtitle: party.time.isNotEmpty ? party.time : 'Time TBC',
        date: date,
      ));
    }

    // Personal tasks (CalendarNotes) — only current user's own notes
    for (final note in state.calendarNotes) {
      if (note.userId != cu?.id) continue;
      final date = parseIso(note.date);
      if (date == null) continue;
      events.add(_Event(
        type: _Type.task,
        title: note.title,
        subtitle: note.note ?? '',
        date: date,
        id: note.id,
      ));
    }

    return events;
  }

  void _showAddTask(BuildContext context, HomiesState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _AddTaskModal(
          initialDate: _selectedDay ?? DateTime.now(),
          state: state,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final allEvents = _buildEvents(state);

    // Apply type filter
    final typeFiltered = _filter == null ? allEvents : allEvents.where((e) => e.type == _filter).toList();

    // Events in the viewed month (or selected day)
    final visibleEvents = _selectedDay != null
        ? typeFiltered.where((e) => _sameDay(e.date, _selectedDay!)).toList()
        : typeFiltered.where((e) => e.date.year == _viewMonth.year && e.date.month == _viewMonth.month).toList();
    visibleEvents.sort((a, b) => a.date.compareTo(b.date));

    // Dates that have events (for the mini calendar dots)
    final eventDays = typeFiltered
        .where((e) => e.date.year == _viewMonth.year && e.date.month == _viewMonth.month)
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet();

    // Group visible events by day
    final groups = <DateTime, List<_Event>>{};
    for (final e in visibleEvents) {
      final key = DateTime(e.date.year, e.date.month, e.date.day);
      (groups[key] ??= []).add(e);
    }
    final days = groups.keys.toList()..sort();

    return SafeArea(
      child: Column(
        children: [
          // ── Mini calendar ────────────────────────────────────────────────
          _MiniCalendar(
            viewMonth: _viewMonth,
            selectedDay: _selectedDay,
            eventDays: eventDays,
            onMonthChanged: (m) => setState(() { _viewMonth = m; _selectedDay = null; }),
            onDayTapped: (d) => setState(() {
              _selectedDay = (_selectedDay != null && _sameDay(_selectedDay!, d)) ? null : d;
            }),
          ),

          // ── Filter chips ─────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                _FilterChip(label: 'All', selected: _filter == null, onTap: () => setState(() => _filter = null)),
                const SizedBox(width: 6),
                for (final t in _Type.values) ...[
                  _FilterChip(
                    label: _Event(type: t, title: '', subtitle: '', date: DateTime.now()).typeLabel,
                    color: _Event(type: t, title: '', subtitle: '', date: DateTime.now()).color,
                    selected: _filter == t,
                    onTap: () => setState(() => _filter = _filter == t ? null : t),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),

          // ── Info row: selected day + add task ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(children: [
              if (_selectedDay != null) ...[
                Icon(Icons.filter_alt_outlined, size: 14, color: HomiesColors.textDim),
                const SizedBox(width: 4),
                Text(
                  'Showing ${DateFormat('d MMM').format(_selectedDay!)}',
                  style: const TextStyle(fontSize: 12, color: HomiesColors.textDim),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _selectedDay = null),
                  child: const Text('Clear', style: TextStyle(fontSize: 12, color: HomiesColors.accent, fontWeight: FontWeight.w600)),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => _showAddTask(context, state),
                child: const Row(children: [
                  Icon(Icons.add_task, size: 14, color: HomiesColors.accent),
                  SizedBox(width: 4),
                  Text('Add task', style: TextStyle(fontSize: 12, color: HomiesColors.accent, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),

          // ── Event list ───────────────────────────────────────────────────
          Expanded(
            child: days.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 44, color: HomiesColors.textFaint),
                        const SizedBox(height: 12),
                        Text(
                          _selectedDay != null ? 'Nothing on this day' : 'Nothing this month',
                          style: const TextStyle(fontSize: 14, color: HomiesColors.textDim, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _showAddTask(context, state),
                          icon: const Icon(Icons.add_task, size: 16),
                          label: const Text('Add a task'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: days.length,
                    itemBuilder: (ctx, i) {
                      final day = days[i];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DayHeader(date: day),
                          ...groups[day]!.map((e) => _EventTile(
                                event: e,
                                onDelete: e.type == _Type.task && e.id != null
                                    ? () => state.mutate(() {
                                          state.calendarNotes.removeWhere((n) => n.id == e.id);
                                        })
                                    : null,
                              )),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

// ─── Mini calendar ────────────────────────────────────────────────────────────

class _MiniCalendar extends StatelessWidget {
  final DateTime viewMonth;
  final DateTime? selectedDay;
  final Set<DateTime> eventDays;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDayTapped;

  const _MiniCalendar({
    required this.viewMonth,
    required this.selectedDay,
    required this.eventDays,
    required this.onMonthChanged,
    required this.onDayTapped,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = viewMonth; // already (year, month, 1)
    final startOffset = (firstDay.weekday - 1) % 7; // 0=Mon offset
    final daysInMonth = DateTime(viewMonth.year, viewMonth.month + 1, 0).day;
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    final totalCells = startOffset + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Container(
      color: HomiesColors.surface,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              visualDensity: VisualDensity.compact,
              color: HomiesColors.textDim,
              onPressed: () => onMonthChanged(DateTime(viewMonth.year, viewMonth.month - 1)),
            ),
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy').format(viewMonth),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomiesColors.text),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              visualDensity: VisualDensity.compact,
              color: HomiesColors.textDim,
              onPressed: () => onMonthChanged(DateTime(viewMonth.year, viewMonth.month + 1)),
            ),
          ]),

          Row(
            children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d, style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint, fontWeight: FontWeight.w500)),
                      ),
                    ))
                .toList(),
          ),

          const SizedBox(height: 2),

          for (var row = 0; row < rowCount; row++)
            Row(
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final dayNum = cellIndex - startOffset + 1;

                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 36));
                }

                final date = DateTime(viewMonth.year, viewMonth.month, dayNum);
                final hasEvent = eventDays.contains(date);
                final isSelected = selectedDay != null && _sameDay(date, selectedDay!);
                final isToday = _sameDay(date, todayDay);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onDayTapped(date),
                    child: SizedBox(
                      height: 36,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? HomiesColors.accent
                                  : isToday
                                      ? HomiesColors.accentSoft
                                      : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$dayNum',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                                color: isSelected
                                    ? Colors.white
                                    : isToday
                                        ? HomiesColors.accent
                                        : HomiesColors.text,
                              ),
                            ),
                          ),
                          if (hasEvent)
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? Colors.white70 : HomiesColors.accent,
                              ),
                            )
                          else
                            const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

// ─── Filter chips ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? HomiesColors.textDim;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.12) : HomiesColors.surface,
          border: Border.all(color: selected ? c : HomiesColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? c : HomiesColors.textDim,
          ),
        ),
      ),
    );
  }
}

// ─── Day header ───────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  final DateTime date;
  const _DayHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final isToday = _sameDay(date, todayDay);
    final label = isToday ? 'Today · ${DateFormat('EEE d MMM').format(date)}' : DateFormat('EEE d MMM').format(date);

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Row(children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isToday ? HomiesColors.accent : HomiesColors.textFaint,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: HomiesColors.border, height: 1)),
      ]),
    );
  }
}

// ─── Event tile ───────────────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  final _Event event;
  final VoidCallback? onDelete;
  const _EventTile({required this.event, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isPast = event.date.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));

    return Opacity(
      opacity: isPast ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: HomiesColors.surface,
          border: Border.all(color: HomiesColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: event.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(event.icon, size: 18, color: event.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                event.title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HomiesColors.text),
              ),
              if (event.subtitle.isNotEmpty)
                Text(
                  event.subtitle,
                  style: const TextStyle(fontSize: 11, color: HomiesColors.textDim),
                ),
            ]),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: HomiesColors.textFaint),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: onDelete,
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: event.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                event.typeLabel,
                style: TextStyle(fontSize: 10, color: event.color, fontWeight: FontWeight.w600),
              ),
            ),
        ]),
      ),
    );
  }
}

// ─── Add task modal ───────────────────────────────────────────────────────────

class _AddTaskModal extends StatefulWidget {
  final DateTime initialDate;
  final HomiesState state;
  const _AddTaskModal({required this.initialDate, required this.state});

  @override
  State<_AddTaskModal> createState() => _AddTaskModalState();
}

class _AddTaskModalState extends State<_AddTaskModal> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final state = widget.state;
    final uid = state.currentUser!.id;
    state.mutate(() {
      state.calendarNotes.add(CalendarNote(
        id: 'cn-${DateTime.now().millisecondsSinceEpoch}',
        userId: uid,
        title: _titleCtrl.text.trim(),
        date: _date.toIso8601String().substring(0, 10),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      ));
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          const Text('Add task', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          const FieldLabel("What's the task?"),
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'e.g. Pay bond, call landlord...'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          const FieldLabel('Date'),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: HomiesColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: HomiesColors.textDim),
                const SizedBox(width: 8),
                Text(DateFormat('EEE, d MMMM yyyy').format(_date), style: const TextStyle(fontSize: 14)),
                const Spacer(),
                const Icon(Icons.edit_outlined, size: 14, color: HomiesColors.textDim),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          const FieldLabel('Note (optional)'),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(hintText: 'Any extra details...'),
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _titleCtrl.text.trim().isEmpty ? null : _save,
              child: const Text('Add task'),
            ),
          ]),
        ]),
      ),
    );
  }
}
