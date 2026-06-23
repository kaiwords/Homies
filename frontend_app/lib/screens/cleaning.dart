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
        padding: const EdgeInsets.all(16),
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
                final cols = c.maxWidth < 400 ? 2 : c.maxWidth < 640 ? 3 : 4;
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
                child: Row(children: [
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
                  const SizedBox(width: 6),
                  OutlinedButton(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('Upload photo proof', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
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
                      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Attach photo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 10),
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
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(isEdit ? 'Edit cleaning task' : 'Add cleaning task', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            const FieldLabel('Task'),
            TextField(controller: taskCtrl, decoration: const InputDecoration(hintText: 'Scrub the oven')),
            const SizedBox(height: 10),
            const FieldLabel('Assignee'),
            DropdownButtonFormField<String>(
              initialValue: assignee,
              items: [for (final u in hms) DropdownMenuItem(value: u.id, child: Text(u.name))],
              onChanged: (v) => setState(() => assignee = v),
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 14),
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
