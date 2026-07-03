import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/file_picker_button.dart';
import '../widgets/ui_kit.dart';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _cleaningCadences = ['weekly', 'fortnightly', 'monthly'];

class CleaningScreen extends StatefulWidget {
  const CleaningScreen({super.key});

  @override
  State<CleaningScreen> createState() => _CleaningScreenState();
}

class _CleaningScreenState extends State<CleaningScreen> {
  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final isLeaseholder = cu.role == 'leaseholder';

    void toggleDone(CleaningTask t) {
      state.mutate(() {
        if (t.done) {
          t.done = false;
          t.completedAt = null;
        } else {
          t.done = true;
          t.completedAt = todayIso();
        }
      });
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'Cleaning',
            subtitle: 'Weekly roster + tasks. Photo proof or excuses.',
            action: isLeaseholder
                ? ElevatedButton(onPressed: () => _openTaskModal(context, state, null), child: const Text('+ Task'))
                : null,
          ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Expanded(child: Text('Cleaning roster', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                if (isLeaseholder)
                  DropdownButton<String>(
                    value: state.property.cleaningCadence,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    style: const TextStyle(fontSize: 13, color: HomiesColors.accentStrong, fontWeight: FontWeight.w600),
                    items: [
                      for (final c in _cleaningCadences)
                        DropdownMenuItem(value: c, child: Text('Repeats ${cadenceLabel(c).toLowerCase()}')),
                    ],
                    onChanged: (v) => state.mutate(() => state.property.cleaningCadence = v ?? 'weekly'),
                  )
                else
                  HomiesChip('Repeats ${cadenceLabel(state.property.cleaningCadence).toLowerCase()}', tone: ChipTone.accent),
              ]),
              Text(isLeaseholder ? 'Set how often it repeats, then area + assignee per day.' : 'Leaseholder sets the schedule.',
                  style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth < 480 ? 2 : c.maxWidth < 640 ? 3 : 4;
                final present = _days.where((d) => state.cleaningRoster.any((r) => r.day == d)).toList();
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final d in present)
                    SizedBox(
                      width: (c.maxWidth - (cols - 1) * 8) / cols,
                      child: _RosterTile(day: d, isLeaseholder: isLeaseholder),
                    ),
                ]);
              }),
              if (isLeaseholder && _days.any((d) => !state.cleaningRoster.any((r) => r.day == d)))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(spacing: 4, children: [
                    const Text('Add a day:', style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                    for (final d in _days.where((d) => !state.cleaningRoster.any((r) => r.day == d)))
                      OutlinedButton(
                        onPressed: () => state.mutate(() => state.cleaningRoster.add(CleaningRosterEntry(day: d, area: '', assignee: ''))),
                        child: Text('+ $d', style: const TextStyle(fontSize: 12)),
                      ),
                  ]),
                ),
              if (isLeaseholder) ...[
                const SizedBox(height: 12),
                const Divider(),
                _AvailabilitySummary(),
              ],
            ]),
          ),
          if (!isLeaseholder) _TenantAvailabilityCard(userId: cu.id),
          const _SwapRequestsCard(),
          const _ApplianceBookingCard(),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Tasks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              if (state.cleaningTasks.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('No tasks yet.', style: TextStyle(color: HomiesColors.textDim, fontSize: 12))),
              for (final t in state.cleaningTasks) _TaskRow(
                task: t,
                isLeaseholder: isLeaseholder,
                isMine: t.assignee == cu.id,
                onToggle: () => toggleDone(t),
                onEdit: () => _openTaskModal(context, state, t),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _openTaskModal(BuildContext context, HomiesState state, CleaningTask? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _TaskModal(existing: existing),
      ),
    );
  }
}

class _RosterTile extends StatelessWidget {
  final String day;
  final bool isLeaseholder;
  const _RosterTile({required this.day, required this.isLeaseholder});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final row = state.cleaningRoster.firstWhereOrNull((r) => r.day == day);
    final assignee = row != null ? state.findUser(row.assignee) : null;

    final cu = state.currentUser;
    final isMine = !isLeaseholder && cu != null && row?.assignee == cu.id;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: HomiesColors.surface2, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(day, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: HomiesColors.textDim)),
          if (isLeaseholder)
            InkWell(
              onTap: () => state.mutate(() => state.cleaningRoster.removeWhere((r) => r.day == day)),
              child: const Icon(Icons.close, size: 14, color: HomiesColors.textFaint),
            ),
        ]),
        const SizedBox(height: 4),
        if (isLeaseholder)
          TextField(
            controller: TextEditingController(text: row?.area ?? ''),
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(isDense: true, hintText: 'Area', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
            onSubmitted: (v) => state.mutate(() {
              final r = state.cleaningRoster.firstWhereOrNull((r) => r.day == day);
              if (r != null) r.area = v;
            }),
          )
        else
          Text(row?.area ?? '—', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        if (isLeaseholder)
          DropdownButton<String>(
            value: () {
              final id = row?.assignee ?? '';
              if (id.isEmpty) return null;
              final exists = state.activeHousemates.any((u) => u.id == id);
              return exists ? id : null;
            }(),
            isExpanded: true,
            style: const TextStyle(fontSize: 12, color: HomiesColors.text),
            hint: const Text('— unassigned —', style: TextStyle(fontSize: 12)),
            items: [
              const DropdownMenuItem(value: '', child: Text('— unassigned —', style: TextStyle(fontSize: 12))),
              for (final u in state.activeHousemates)
                DropdownMenuItem(value: u.id, child: Text(u.name, style: const TextStyle(fontSize: 12))),
            ],
            onChanged: (v) => state.mutate(() {
              final r = state.cleaningRoster.firstWhereOrNull((r) => r.day == day);
              if (r != null) r.assignee = v ?? '';
            }),
          )
        else if (assignee != null)
          Row(children: [Avatar.sm(assignee), const SizedBox(width: 6), Text(assignee.name.split(' ').first, style: const TextStyle(fontSize: 12))])
        else
          const Text('unassigned', style: TextStyle(color: HomiesColors.textFaint, fontSize: 12)),
        if (isMine) ...[
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => _DaySwapSheet(day: day, area: row?.area ?? ''),
            ),
            icon: const Icon(Icons.swap_horiz_rounded, size: 13),
            label: const Text('Swap day', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ]),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final CleaningTask task;
  final bool isLeaseholder;
  final bool isMine;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  const _TaskRow({required this.task, required this.isLeaseholder, required this.isMine, required this.onToggle, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final assignee = state.findUser(task.assignee);
    final today = DateTime.now();
    final due = parseIso(task.dueDate);
    final overdue = !task.done && (task.excuse?.isEmpty ?? true) && due != null && due.isBefore(DateTime(today.year, today.month, today.day));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Checkbox(
          value: task.done,
          onChanged: !isMine && !isLeaseholder ? null : (_) => onToggle(),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(
                task.task,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: task.done ? TextDecoration.lineThrough : null,
                  color: task.done ? HomiesColors.textFaint : HomiesColors.text,
                ),
              ),
              if (overdue) const HomiesChip('overdue', tone: ChipTone.danger),
              if (task.done) HomiesChip('done ${fmtRelative(task.completedAt)}', tone: ChipTone.ok),
              if (task.excuse?.isNotEmpty == true) const HomiesChip('excused', tone: ChipTone.warn),
            ]),
            Text('${assignee?.name ?? '—'} · due ${fmtDate(task.dueDate)}',
                style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
            if (task.excuse?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('"${task.excuse}"', style: const TextStyle(fontStyle: FontStyle.italic, color: HomiesColors.textDim, fontSize: 12)),
              ),
            if (task.photo != null) AttachmentTile(value: task.photo!, compact: true),
            if (isMine && !task.done)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  OutlinedButton(
                    onPressed: () async {
                      final ctrl = TextEditingController();
                      final txt = await showDialog<String>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Can't do it"),
                          content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: "Why couldn't you?")),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Log excuse')),
                          ],
                        ),
                      );
                      if (txt != null && txt.isNotEmpty) {
                        state.mutate(() => task.excuse = txt);
                      }
                    },
                    child: const Text("Can't do it"),
                  ),
                  OutlinedButton(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => Padding(
                        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('Upload photo proof', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 14),
                          FilePickerButton(
                            value: null,
                            onChanged: (f) {
                              if (f != null) {
                                state.mutate(() {
                                  task.photo = f;
                                  task.done = true;
                                  task.completedAt = todayIso();
                                });
                              }
                              Navigator.pop(context);
                            },
                          ),
                        ]),
                      ),
                    ),
                    child: const Text('📷 Photo proof'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _SwapSheet(task: task),
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                    label: const Text('Swap'),
                  ),
                ]),
              ),
            if (isMine || isLeaseholder)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: OutlinedButton.icon(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Attach photo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 14),
                        FilePickerButton(
                          value: task.photo,
                          onChanged: (f) {
                            state.mutate(() => task.photo = f);
                            Navigator.pop(context);
                          },
                          allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
                          label: 'Choose a photo',
                        ),
                        if (task.photo != null)
                          TextButton(
                            onPressed: () {
                              state.mutate(() => task.photo = null);
                              Navigator.pop(context);
                            },
                            child: const Text('Remove photo', style: TextStyle(color: HomiesColors.danger)),
                          ),
                      ]),
                    ),
                  ),
                  icon: const Icon(Icons.photo_camera_outlined, size: 14),
                  label: Text(
                    task.photo == null ? 'Attach photo' : 'Replace photo',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Avatar.sm(assignee),
          if (isLeaseholder) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    content: const Text('Delete this task?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) state.mutate(() => state.cleaningTasks.removeWhere((t) => t.id == task.id));
              },
              child: const Text('Delete', style: TextStyle(color: HomiesColors.danger, fontSize: 12)),
            ),
            OutlinedButton(onPressed: onEdit, child: const Text('Edit', style: TextStyle(fontSize: 12))),
          ],
        ]),
      ]),
    );
  }
}

class _TaskModal extends StatefulWidget {
  final CleaningTask? existing;
  const _TaskModal({this.existing});

  @override
  State<_TaskModal> createState() => _TaskModalState();
}

class _TaskModalState extends State<_TaskModal> {
  late HomiesState state;
  final taskCtrl = TextEditingController();
  String? assignee;
  String? dueDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      taskCtrl.text = e.task;
      assignee = e.assignee;
      dueDate = e.dueDate;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    state = HomiesScope.of(context);
    assignee ??= state.activeHousemates.firstOrNull?.id;
  }

  @override
  void dispose() {
    taskCtrl.dispose();
    super.dispose();
  }

  void _save() {
    state.mutate(() {
      if (widget.existing != null) {
        widget.existing!.task = taskCtrl.text.trim();
        widget.existing!.assignee = assignee ?? '';
        widget.existing!.dueDate = dueDate ?? '';
      } else {
        state.cleaningTasks.add(CleaningTask(
          id: 'c-${Random().nextInt(0xFFFF).toRadixString(36)}',
          task: taskCtrl.text.trim(),
          assignee: assignee ?? '',
          dueDate: dueDate ?? '',
        ));
      }
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hms = state.activeHousemates;
    final isEdit = widget.existing != null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(isEdit ? 'Edit cleaning task' : 'Add cleaning task', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            const FieldLabel('Task'),
            TextField(controller: taskCtrl, decoration: const InputDecoration(hintText: 'Scrub the oven')),
            const SizedBox(height: 14),
            const FieldLabel('Assignee'),
            DropdownButtonFormField<String>(
              initialValue: assignee,
              items: [for (final u in hms) DropdownMenuItem(value: u.id, child: Text(u.name))],
              onChanged: (v) => setState(() => assignee = v),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Due date'),
            InkWell(
              onTap: () async {
                final d = await pickDate(context, initial: parseIso(dueDate));
                if (d != null) setState(() => dueDate = toIso(d));
              },
              child: InputDecorator(
                decoration: const InputDecoration(),
                child: Text(dueDate != null ? fmtDate(dueDate) : 'Pick a date',
                    style: TextStyle(color: dueDate != null ? HomiesColors.text : HomiesColors.textFaint)),
              ),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: taskCtrl.text.trim().isEmpty || dueDate == null ? null : _save,
                child: Text(isEdit ? 'Save changes' : 'Add task'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Leaseholder: availability summary + ask button ──────────────────────────

class _AvailabilitySummary extends StatelessWidget {
  const _AvailabilitySummary();

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final requested = state.property.cleaningAvailabilityRequested;
    final avail = state.cleaningAvailability;
    final tenants = state.activeHousemates.where((u) => u.role == 'tenant').toList();

    // Collect unique days that have at least one response
    final respondedDays = avail.map((a) => a.day).toSet();
    final allDays = {..._days.where((d) => respondedDays.contains(d))};

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Text(
            'Tenant availability',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        if (!requested)
          OutlinedButton.icon(
            onPressed: () => state.mutate(() => state.property.cleaningAvailabilityRequested = true),
            icon: const Icon(Icons.calendar_today_outlined, size: 14),
            label: const Text('Ask availability', style: TextStyle(fontSize: 12)),
          )
        else
          OutlinedButton(
            onPressed: () => state.mutate(() {
              state.property.cleaningAvailabilityRequested = false;
              state.cleaningAvailability.clear();
            }),
            child: const Text('Close round', style: TextStyle(fontSize: 12)),
          ),
      ]),
      if (requested) ...[
        const SizedBox(height: 6),
        if (avail.isEmpty)
          const Text('Waiting for tenants to respond…',
              style: TextStyle(color: HomiesColors.textDim, fontSize: 12))
        else
          for (final day in allDays) ...[
            const SizedBox(height: 6),
            Row(children: [
              SizedBox(
                width: 36,
                child: Text(day, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HomiesColors.textDim)),
              ),
              const SizedBox(width: 6),
              Wrap(spacing: 4, children: [
                for (final t in tenants)
                  if (avail.firstWhereOrNull((a) => a.userId == t.id && a.day == day) case final entry when entry != null)
                    HomiesChip(
                      t.name.split(' ').first,
                      tone: entry.status == 'available' ? ChipTone.ok : ChipTone.danger,
                    ),
              ]),
            ]),
          ],
        if (tenants.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${avail.map((a) => a.userId).toSet().length} of ${tenants.length} responded',
            style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint),
          ),
        ],
      ] else
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('Ask tenants which days work for them before assigning the roster.',
              style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
        ),
    ]);
  }
}

// ── Tenant: mark availability per day ───────────────────────────────────────

class _TenantAvailabilityCard extends StatelessWidget {
  final String userId;
  const _TenantAvailabilityCard({required this.userId});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    if (!state.property.cleaningAvailabilityRequested) return const SizedBox.shrink();

    final myResponses = {
      for (final a in state.cleaningAvailability.where((a) => a.userId == userId)) a.day: a.status,
    };

    void setDay(String day, String status) {
      state.mutate(() {
        state.cleaningAvailability.removeWhere((a) => a.userId == userId && a.day == day);
        state.cleaningAvailability.add(CleaningDayAvailability(userId: userId, day: day, status: status));
      });
    }

    void clearDay(String day) {
      state.mutate(() => state.cleaningAvailability.removeWhere((a) => a.userId == userId && a.day == day));
    }

    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 16, color: HomiesColors.accent),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Availability request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 2),
        const Text('Your leaseholder wants to know which days work for cleaning.',
            style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
        const SizedBox(height: 12),
        for (final day in _days) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(
                width: 40,
                child: Text(day, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              _DayToggle(
                label: 'Can do',
                selected: myResponses[day] == 'available',
                tone: ChipTone.ok,
                onTap: () => myResponses[day] == 'available' ? clearDay(day) : setDay(day, 'available'),
              ),
              const SizedBox(width: 6),
              _DayToggle(
                label: 'N/A',
                selected: myResponses[day] == 'na',
                tone: ChipTone.danger,
                onTap: () => myResponses[day] == 'na' ? clearDay(day) : setDay(day, 'na'),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _DayToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final ChipTone tone;
  final VoidCallback onTap;
  const _DayToggle({required this.label, required this.selected, required this.tone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      ChipTone.ok => (HomiesColors.ok.withValues(alpha: selected ? 0.18 : 0.06), selected ? HomiesColors.ok : HomiesColors.textDim),
      ChipTone.danger => (HomiesColors.danger.withValues(alpha: selected ? 0.18 : 0.06), selected ? HomiesColors.danger : HomiesColors.textDim),
      _ => (HomiesColors.surface2, HomiesColors.textDim),
    };
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: selected ? fg : HomiesColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }
}

// ── Chore swap request widgets ───────────────────────────────────────────────

class _SwapRequestsCard extends StatelessWidget {
  const _SwapRequestsCard();

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;

    final incoming = state.choreSwaps
        .where((r) =>
            r.status == 'pending' &&
            r.fromUserId != cu.id &&
            (r.toUserId == null || r.toUserId == cu.id))
        .toList();

    final mine = state.choreSwaps
        .where((r) => r.status == 'pending' && r.fromUserId == cu.id)
        .toList();

    if (incoming.isEmpty && mine.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HomiesCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Swap requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (incoming.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('NEEDS YOUR RESPONSE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: HomiesColors.textFaint, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            for (final r in incoming) _IncomingSwapTile(request: r),
          ],
          if (mine.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('YOUR REQUESTS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: HomiesColors.textFaint, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            for (final r in mine) _MySwapTile(request: r),
          ],
        ]),
      ),
    );
  }
}

class _IncomingSwapTile extends StatelessWidget {
  final ChoreSwapRequest request;
  const _IncomingSwapTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final isDaySwap = request.rosterDay != null;
    final isMutual = isDaySwap && request.wantedDay != null;
    final task = isDaySwap ? null : state.cleaningTasks.firstWhereOrNull((t) => t.id == request.taskId);
    final offeredEntry = isDaySwap ? state.cleaningRoster.firstWhereOrNull((r) => r.day == request.rosterDay) : null;
    final wantedEntry = isMutual ? state.cleaningRoster.firstWhereOrNull((r) => r.day == request.wantedDay) : null;
    final requester = state.activeHousemates.firstWhereOrNull((u) => u.id == request.fromUserId);

    String subtitle;
    if (isDaySwap) {
      final offeredLabel = offeredEntry?.area.isNotEmpty == true
          ? '${request.rosterDay} (${offeredEntry!.area})'
          : request.rosterDay!;
      if (isMutual) {
        final wantedLabel = wantedEntry?.area.isNotEmpty == true
            ? '${request.wantedDay} (${wantedEntry!.area})'
            : request.wantedDay!;
        subtitle = 'Proposing a swap: their $offeredLabel ↔ your $wantedLabel';
      } else {
        subtitle = 'Wants someone to cover their $offeredLabel cleaning';
      }
    } else {
      subtitle = 'Wants to swap: ${task?.task ?? 'Unknown task'}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.07),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (requester != null) Avatar.sm(requester),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(request.fromUserName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
              if (!isDaySwap && task != null)
                Text('Due ${fmtDate(task.dueDate)}',
                    style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint)),
            ]),
          ),
        ]),
        if (isMutual) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: HomiesColors.accentSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.swap_horiz_rounded, size: 14, color: HomiesColors.accentStrong),
              const SizedBox(width: 6),
              Text(
                'If you accept: you take ${request.rosterDay}, they take ${request.wantedDay}',
                style: const TextStyle(fontSize: 11, color: HomiesColors.accentStrong, fontWeight: FontWeight.w500),
              ),
            ]),
          ),
        ],
        if (request.note != null && request.note!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('"${request.note}"',
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: HomiesColors.textDim)),
        ],
        const SizedBox(height: 8),
        Row(children: [
          OutlinedButton(
            onPressed: () => state.mutate(() {
              request.status = 'declined';
              request.respondedAt = DateTime.now().toIso8601String();
              request.respondedBy = cu.id;
              request.respondedByName = cu.name;
            }),
            child: const Text('Decline'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              // The wanted day may have changed hands since this request was
              // made (e.g. another swap was accepted in the meantime) — don't
              // silently reassign it away from whoever holds it now.
              if (isMutual && wantedEntry != null && wantedEntry.assignee != cu.id) {
                state.mutate(() {
                  request.status = 'declined';
                  request.respondedAt = DateTime.now().toIso8601String();
                  request.respondedBy = cu.id;
                  request.respondedByName = cu.name;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('This swap is no longer valid — that day has already changed hands.')),
                );
                return;
              }
              state.mutate(() {
                request.status = 'accepted';
                request.respondedAt = DateTime.now().toIso8601String();
                request.respondedBy = cu.id;
                request.respondedByName = cu.name;
                if (isDaySwap) {
                  // Accepting user takes the offered day
                  if (offeredEntry != null) offeredEntry.assignee = cu.id;
                  // Mutual: requester gets the wanted day in return
                  if (isMutual && wantedEntry != null) {
                    wantedEntry.assignee = request.fromUserId;
                  }
                } else {
                  if (task != null) task.assignee = cu.id;
                }
                for (final other in state.choreSwaps) {
                  if (other.id != request.id && other.status == 'pending') {
                    final sameSlot = isDaySwap
                        ? (other.rosterDay == request.rosterDay ||
                            (isMutual && other.wantedDay == request.wantedDay))
                        : other.taskId == request.taskId;
                    if (sameSlot) other.status = 'cancelled';
                  }
                }
              });
            },
            child: const Text('Accept'),
          ),
        ]),
      ]),
    );
  }
}

class _MySwapTile extends StatelessWidget {
  final ChoreSwapRequest request;
  const _MySwapTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final isDaySwap = request.rosterDay != null;
    final isMutual = isDaySwap && request.wantedDay != null;
    final task = isDaySwap ? null : state.cleaningTasks.firstWhereOrNull((t) => t.id == request.taskId);
    final offeredEntry = isDaySwap ? state.cleaningRoster.firstWhereOrNull((r) => r.day == request.rosterDay) : null;

    final String label;
    if (isDaySwap) {
      final offeredLabel = offeredEntry?.area.isNotEmpty == true
          ? '${request.rosterDay} (${offeredEntry!.area})'
          : request.rosterDay!;
      label = isMutual ? '$offeredLabel ↔ ${request.wantedDay}' : '$offeredLabel cleaning';
    } else {
      label = task?.task ?? 'Unknown task';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: HomiesColors.surface2,
        border: Border.all(color: HomiesColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(
              request.toUserId == null
                  ? 'Open to anyone'
                  : isMutual
                      ? 'Proposed to ${request.toUserName ?? ''}'
                      : 'Directed at ${request.toUserName ?? ''}',
              style: const TextStyle(fontSize: 12, color: HomiesColors.textDim),
            ),
            if (request.note != null && request.note!.isNotEmpty)
              Text('"${request.note}"',
                  style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 11, color: HomiesColors.textFaint)),
          ]),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => state.mutate(() => request.status = 'cancelled'),
          child: const Text('Cancel', style: TextStyle(color: HomiesColors.danger)),
        ),
      ]),
    );
  }
}

class _DaySwapSheet extends StatefulWidget {
  final String day;
  final String area;
  const _DaySwapSheet({required this.day, required this.area});

  @override
  State<_DaySwapSheet> createState() => _DaySwapSheetState();
}

class _DaySwapSheetState extends State<_DaySwapSheet> {
  String? toUserId;
  String? toUserName;
  String? wantedDay;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final others = state.activeHousemates.where((u) => u.id != cu.id).toList();

    final alreadyPending = state.choreSwaps.any(
      (r) => r.rosterDay == widget.day && r.fromUserId == cu.id && r.status == 'pending',
    );

    final title = widget.area.isNotEmpty
        ? 'Swap ${widget.day} (${widget.area})'
        : 'Swap ${widget.day} cleaning';

    // Roster days assigned to the selected person (potential days to get in return)
    final theirDays = toUserId == null
        ? <CleaningRosterEntry>[]
        : state.cleaningRoster.where((r) => r.assignee == toUserId).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ]),
        const SizedBox(height: 4),
        const Text('Offer your day to another housemate in exchange for one of theirs.',
            style: TextStyle(fontSize: 12, color: HomiesColors.textDim)),
        const SizedBox(height: 20),
        if (alreadyPending)
          const Text('You already have a pending swap request for this day.',
              style: TextStyle(color: HomiesColors.textDim))
        else ...[
          const FieldLabel('Swap with'),
          DropdownButtonFormField<String?>(
            initialValue: toUserId,
            items: [
              const DropdownMenuItem(value: null, child: Text('Anyone (open — no return day)')),
              for (final u in others) DropdownMenuItem(value: u.id, child: Text(u.name)),
            ],
            onChanged: (v) => setState(() {
              toUserId = v;
              toUserName = v == null ? null : others.firstWhere((u) => u.id == v).name;
              wantedDay = null; // reset when target changes
            }),
          ),
          if (toUserId != null) ...[
            const SizedBox(height: 14),
            const FieldLabel('In exchange for their day'),
            const SizedBox(height: 8),
            if (theirDays.isEmpty)
              const Text('This person has no assigned days — they\'ll cover your shift without a return.',
                  style: TextStyle(fontSize: 12, color: HomiesColors.textDim))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final entry in theirDays)
                  GestureDetector(
                    onTap: () => setState(() => wantedDay = wantedDay == entry.day ? null : entry.day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: wantedDay == entry.day ? HomiesColors.accentSoft : HomiesColors.surface2,
                        border: Border.all(
                            color: wantedDay == entry.day ? HomiesColors.accentBorder : HomiesColors.border),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        entry.area.isNotEmpty ? '${entry.day} (${entry.area})' : entry.day,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: wantedDay == entry.day ? HomiesColors.accentStrong : HomiesColors.text,
                        ),
                      ),
                    ),
                  ),
              ]),
          ],
          const SizedBox(height: 14),
          const FieldLabel('Note (optional)'),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(hintText: "e.g. I'll be out of town"),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final swapId = 'sw-${Random().nextInt(0xFFFF).toRadixString(36)}';
              final now = DateTime.now().toIso8601String();
              final resolvedWantedDay = toUserId != null ? wantedDay : null;
              state.mutate(() {
                state.choreSwaps.add(ChoreSwapRequest(
                  id: swapId,
                  rosterDay: widget.day,
                  wantedDay: resolvedWantedDay,
                  fromUserId: cu.id,
                  fromUserName: cu.name,
                  toUserId: toUserId,
                  toUserName: toUserName,
                  note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
                  requestedAt: now,
                ));
              });
              final areaLabel = widget.area.isNotEmpty ? ' (${widget.area})' : '';
              final noteLabel = _noteCtrl.text.trim().isNotEmpty ? ' — "${_noteCtrl.text.trim()}"' : '';
              final targets = toUserId != null
                  ? [toUserId!]
                  : state.activeHousemates.where((u) => u.id != cu.id).map((u) => u.id).toList();
              for (final tid in targets) {
                final body = resolvedWantedDay != null
                    ? '${cu.name} wants to swap: their ${widget.day}$areaLabel ↔ your $resolvedWantedDay$noteLabel. Respond in Cleaning.'
                    : '${cu.name} is looking for someone to cover their ${widget.day}$areaLabel slot$noteLabel. Respond in Cleaning.';
                state.addAppNotification(AppNotification(
                  id: 'swap_${swapId}_$tid',
                  kind: 'swap_request',
                  title: resolvedWantedDay != null
                      ? '${cu.name} wants to swap ${widget.day} ↔ $resolvedWantedDay'
                      : '${cu.name} wants to swap their ${widget.day} clean',
                  body: body,
                  at: now,
                  forUserId: tid,
                ));
              }
              Navigator.pop(context);
            },
            child: const Text('Send swap request'),
          ),
        ],
      ]),
    );
  }
}

class _SwapSheet extends StatefulWidget {
  final CleaningTask task;
  const _SwapSheet({required this.task});

  @override
  State<_SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends State<_SwapSheet> {
  String? toUserId;
  String? toUserName;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final others = state.activeHousemates.where((u) => u.id != cu.id).toList();

    final alreadyPending = state.choreSwaps.any(
      (r) => r.taskId == widget.task.id && r.fromUserId == cu.id && r.status == 'pending',
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(
              'Request swap: ${widget.task.task}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ]),
        const SizedBox(height: 20),
        if (alreadyPending)
          const Text('You already have a pending swap request for this task.',
              style: TextStyle(color: HomiesColors.textDim))
        else ...[
          const FieldLabel('Ask who?'),
          DropdownButtonFormField<String?>(
            initialValue: toUserId,
            items: [
              const DropdownMenuItem(value: null, child: Text('Anyone (open request)')),
              for (final u in others) DropdownMenuItem(value: u.id, child: Text(u.name)),
            ],
            onChanged: (v) => setState(() {
              toUserId = v;
              toUserName = v == null ? null : others.firstWhere((u) => u.id == v).name;
            }),
          ),
          const SizedBox(height: 14),
          const FieldLabel('Note (optional)'),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(hintText: "e.g. I'll be out of town"),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final swapId = 'sw-${Random().nextInt(0xFFFF).toRadixString(36)}';
              final now = DateTime.now().toIso8601String();
              state.mutate(() {
                state.choreSwaps.add(ChoreSwapRequest(
                  id: swapId,
                  taskId: widget.task.id,
                  fromUserId: cu.id,
                  fromUserName: cu.name,
                  toUserId: toUserId,
                  toUserName: toUserName,
                  note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
                  requestedAt: now,
                ));
              });
              // Notify target(s)
              final targets = toUserId != null
                  ? [toUserId!]
                  : state.activeHousemates.where((u) => u.id != cu.id).map((u) => u.id).toList();
              for (final tid in targets) {
                state.addAppNotification(AppNotification(
                  id: 'swap_${swapId}_$tid',
                  kind: 'swap_request',
                  title: '${cu.name} wants to swap a chore',
                  body: 'They want to hand off "${widget.task.task}"${_noteCtrl.text.trim().isNotEmpty ? ' — "${_noteCtrl.text.trim()}"' : ''}. Respond in Cleaning.',
                  at: now,
                  forUserId: tid,
                ));
              }
              Navigator.pop(context);
            },
            child: const Text('Send request'),
          ),
        ],
      ]),
    );
  }
}

// ── Appliance booking ────────────────────────────────────────────────────────

const _appliances = ['Washing machine', 'Dryer', 'Dishwasher', 'BBQ', 'Oven'];

const _slots = [
  '6:00 AM – 8:00 AM',
  '8:00 AM – 10:00 AM',
  '10:00 AM – 12:00 PM',
  '12:00 PM – 2:00 PM',
  '2:00 PM – 4:00 PM',
  '4:00 PM – 6:00 PM',
  '6:00 PM – 8:00 PM',
  '8:00 PM – 10:00 PM',
];

class _ApplianceBookingCard extends StatelessWidget {
  const _ApplianceBookingCard();

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final isLeaseholder = cu.role == 'leaseholder';
    final todayIsoStr = toIso(DateTime.now())!;
    final cutoff = toIso(DateTime.now().add(const Duration(days: 6)))!;

    final upcoming = state.applianceBookings
        .where((b) => b.date.compareTo(todayIsoStr) >= 0 && b.date.compareTo(cutoff) <= 0)
        .toList()
      ..sort((a, b) {
        final d = a.date.compareTo(b.date);
        return d != 0 ? d : a.slot.compareTo(b.slot);
      });

    final byDate = <String, List<ApplianceBooking>>{};
    for (final b in upcoming) {
      (byDate[b.date] ??= []).add(b);
    }
    final dates = byDate.keys.toList()..sort();

    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
            child: Text('Appliance bookings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _BookSlotSheet(),
            ),
            child: const Text('Book slot'),
          ),
        ]),
        const Text(
          'Reserve the washing machine, dryer and other shared appliances.',
          style: TextStyle(color: HomiesColors.textDim, fontSize: 12),
        ),
        if (upcoming.isEmpty) ...[
          const SizedBox(height: 10),
          const Text('No bookings in the next 7 days.', style: TextStyle(color: HomiesColors.textFaint, fontSize: 12)),
        ] else ...[
          const SizedBox(height: 12),
          for (final date in dates) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                fmtDate(date),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: HomiesColors.textFaint, letterSpacing: 0.6),
              ),
            ),
            for (final b in byDate[date]!)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: b.userId == cu.id ? HomiesColors.accentSoft : HomiesColors.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: b.userId == cu.id ? HomiesColors.accentBorder : HomiesColors.border,
                  ),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b.appliance, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        '${b.slot} · ${b.userId == cu.id ? 'You' : b.userName}',
                        style: const TextStyle(fontSize: 12, color: HomiesColors.textDim),
                      ),
                      if (b.note?.isNotEmpty == true)
                        Text('"${b.note}"', style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint, fontStyle: FontStyle.italic)),
                    ]),
                  ),
                  if (b.userId == cu.id || isLeaseholder)
                    TextButton(
                      onPressed: () => state.mutate(() => state.applianceBookings.removeWhere((x) => x.id == b.id)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Cancel', style: TextStyle(color: HomiesColors.danger, fontSize: 12)),
                    ),
                ]),
              ),
            const SizedBox(height: 4),
          ],
        ],
      ]),
    );
  }
}

class _BookSlotSheet extends StatefulWidget {
  const _BookSlotSheet();

  @override
  State<_BookSlotSheet> createState() => _BookSlotSheetState();
}

class _BookSlotSheetState extends State<_BookSlotSheet> {
  String _appliance = _appliances.first;
  DateTime _date = DateTime.now();
  String? _slot;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final dateIso = toIso(_date)!;

    final takenSlots = state.applianceBookings
        .where((b) => b.appliance == _appliance && b.date == dateIso)
        .map((b) => b.slot)
        .toSet();

    final mySlots = state.applianceBookings
        .where((b) => b.userId == cu.id && b.appliance == _appliance && b.date == dateIso)
        .map((b) => b.slot)
        .toSet();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 28),
        child: ListView(controller: ctrl, children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: HomiesColors.textFaint, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text('Book an appliance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 20),
            child: Text('Pick the appliance, day and time slot.', style: TextStyle(color: HomiesColors.textDim, fontSize: 13)),
          ),

          const FieldLabel('Appliance'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in _appliances)
                GestureDetector(
                  onTap: () => setState(() { _appliance = a; _slot = null; }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _appliance == a ? HomiesColors.accentSoft : HomiesColors.surface2,
                      border: Border.all(color: _appliance == a ? HomiesColors.accentBorder : HomiesColors.border),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      a,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _appliance == a ? HomiesColors.accentStrong : HomiesColors.text,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          const FieldLabel('Date'),
          InkWell(
            onTap: () async {
              final d = await pickDate(context, initial: _date);
              if (d != null) setState(() { _date = d; _slot = null; });
            },
            child: InputDecorator(
              decoration: const InputDecoration(),
              child: Text(fmtDate(dateIso)),
            ),
          ),
          const SizedBox(height: 16),

          const FieldLabel('Time slot'),
          const SizedBox(height: 4),
          const Text(
            'Red = taken · Blue = yours · tap to select',
            style: TextStyle(fontSize: 11, color: HomiesColors.textFaint),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _slots)
                Builder(builder: (ctx) {
                  final isMine = mySlots.contains(s);
                  final isTaken = takenSlots.contains(s) && !isMine;
                  final isSelected = _slot == s;
                  return GestureDetector(
                    onTap: isTaken ? null : () => setState(() => _slot = isSelected ? null : s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? HomiesColors.accentSoft
                            : isTaken
                                ? HomiesColors.dangerSoft
                                : HomiesColors.surface2,
                        border: Border.all(
                          color: isSelected
                              ? HomiesColors.accentBorder
                              : isTaken
                                  ? HomiesColors.dangerBorder
                                  : HomiesColors.border,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? HomiesColors.accentStrong
                              : isTaken
                                  ? HomiesColors.danger
                                  : HomiesColors.text,
                          decoration: isTaken ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 16),

          const FieldLabel('Note (optional)'),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(hintText: 'e.g. big load, will be quick'),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _slot == null
                ? null
                : () {
                    state.mutate(() {
                      state.applianceBookings.add(ApplianceBooking(
                        id: 'ab-${Random().nextInt(0xFFFFFF).toRadixString(36)}',
                        appliance: _appliance,
                        userId: cu.id,
                        userName: cu.name,
                        date: dateIso,
                        slot: _slot!,
                        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
                        createdAt: DateTime.now().toIso8601String(),
                      ));
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$_appliance booked for $_slot')),
                    );
                  },
            child: const Text('Confirm booking'),
          ),
        ]),
      ),
    );
  }
}
