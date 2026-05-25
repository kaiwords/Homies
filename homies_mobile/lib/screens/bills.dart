import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/file_picker_button.dart';
import '../widgets/ui_kit.dart';

const _categories = [
  ['utility', '💡 Utility'],
  ['internet', '🌐 NBN / internet'],
  ['water', '💧 Water'],
  ['maintenance', '🛠️ Maintenance'],
  ['cleaning', '🧹 Cleaning service'],
  ['pest', '🐜 Pest control'],
  ['other', '📌 Other'],
];

const _cadences = ['weekly', 'fortnightly', 'monthly', 'quarterly', 'half-yearly', 'yearly', 'custom'];

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  String _tab = 'bills';

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final isLeaseholder = state.currentUser?.role == 'leaseholder';
    final schedules = state.billSchedules;
    final dueSoon = schedules
        .where((s) => s.active && (parseIso(s.nextDueDate)?.difference(DateTime.now()).inDays ?? 999) <= 7)
        .toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'Bills',
            subtitle: 'Split equal, percentage, custom, or prorated.',
            action: _tab == 'bills'
                ? ElevatedButton(onPressed: () => _openBillModal(context, state, null), child: const Text('+ New'))
                : isLeaseholder
                    ? ElevatedButton(onPressed: () => _openScheduleModal(context, state, null), child: const Text('+ Schedule'))
                    : null,
          ),
          Segment<String>(
            options: const ['bills', 'schedules'],
            value: _tab,
            labelFor: (v) => v == 'bills' ? 'Bills' : 'Schedules${schedules.isNotEmpty ? ' · ${schedules.length}' : ''}',
            onChanged: (v) => setState(() => _tab = v),
          ),
          const SizedBox(height: 12),
          if (_tab == 'bills' && dueSoon.isNotEmpty)
            HomiesCard(
              color: HomiesColors.surface2,
              borderColor: HomiesColors.accentSoft,
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('🔔 ${dueSoon.length} scheduled bill${dueSoon.length == 1 ? '' : 's'} due soon',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(dueSoon.take(3).map((s) => s.title).join(' · '),
                        style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                  ]),
                ),
                OutlinedButton(onPressed: () => setState(() => _tab = 'schedules'), child: const Text('Open')),
              ]),
            ),
          if (_tab == 'bills') ...[
            if (state.bills.isEmpty)
              const EmptyState(title: 'No bills yet', body: 'Add one when the next invoice arrives.'),
            for (final b in state.bills) _BillCard(bill: b, canManage: isLeaseholder, onEdit: () => _openBillModal(context, state, b)),
          ] else ...[
            if (schedules.isEmpty)
              const EmptyState(
                  title: 'No bill schedules yet',
                  body: "Add electricity, NBN, water, pest control, steam cleaning — anything that arrives on a cycle."),
            for (final sch in schedules)
              _ScheduleCard(
                schedule: sch,
                canManage: isLeaseholder,
                onEdit: () => _openScheduleModal(context, state, sch),
                onRecord: () => _openRecordModal(context, state, sch),
              ),
          ],
        ]),
      ),
    );
  }

  void _openBillModal(BuildContext context, HomiesState state, Bill? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _BillModal(existing: existing),
      ),
    );
  }

  void _openScheduleModal(BuildContext context, HomiesState state, BillSchedule? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ScheduleModal(existing: existing),
      ),
    );
  }

  void _openRecordModal(BuildContext context, HomiesState state, BillSchedule schedule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _RecordBillModal(schedule: schedule),
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final Bill bill;
  final bool canManage;
  final VoidCallback onEdit;
  const _BillCard({required this.bill, required this.canManage, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final b = bill;
    final overdue = (parseIso(b.dueDate)?.isBefore(DateTime.now()) ?? false) && b.status != 'settled';
    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 4, children: [
                Text(b.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                HomiesChip(b.status == 'settled' ? 'settled' : fmtRelative(b.dueDate),
                    tone: b.status == 'settled' ? ChipTone.ok : overdue ? ChipTone.danger : ChipTone.warn),
                HomiesChip(b.split),
                if (b.scheduleId != null) const HomiesChip('🔁 scheduled'),
              ]),
              const SizedBox(height: 2),
              Text(
                'Due ${fmtDate(b.dueDate)}'
                '${b.periodStart != null ? ' · period ${fmtDate(b.periodStart)} → ${fmtDate(b.periodEnd)} (${daysBetween(b.periodStart, b.periodEnd)} d)' : ''}',
                style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
              ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmtAUD(b.amount), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            if (canManage)
              Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        content: Text('Delete bill "${b.title}"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true) state.mutate(() => state.bills.removeWhere((x) => x.id == b.id));
                  },
                  child: const Text('Delete', style: TextStyle(color: HomiesColors.danger)),
                ),
                OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
              ]),
          ]),
        ]),
        if (b.proof != null) ...[
          const SizedBox(height: 8),
          const Text('Proof of bill', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: HomiesColors.textDim)),
          AttachmentTile(value: b.proof!, compact: true),
        ],
        const Divider(),
        for (final entry in b.shares.entries)
          _ShareRow(billId: b.id, userId: entry.key, amount: entry.value, bill: b, cu: cu),
      ]),
    );
  }
}

class _ShareRow extends StatelessWidget {
  final String billId;
  final String userId;
  final double amount;
  final Bill bill;
  final User cu;
  const _ShareRow({required this.billId, required this.userId, required this.amount, required this.bill, required this.cu});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final user = state.findUser(userId);
    if (user == null) return const SizedBox.shrink();
    final paid = bill.paidBy[userId] == true;
    final isYou = userId == cu.id;
    final days = bill.periodStart != null && bill.periodEnd != null ? residentDays(user, bill.periodStart!, bill.periodEnd!) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Avatar.sm(user),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${user.name}${isYou ? ' (you)' : ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            Text(
              '${fmtAUD(amount)}${bill.split == 'prorated' && days != null ? ' · resident $days day${days == 1 ? '' : 's'}' : ''}',
              style: const TextStyle(color: HomiesColors.textDim, fontSize: 11),
            ),
          ]),
        ),
        OutlinedButton(
          onPressed: !isYou && cu.role != 'leaseholder'
              ? null
              : () {
                  state.mutate(() {
                    bill.paidBy[userId] = !paid;
                    final everyone = bill.shares.keys.every((uid) => bill.paidBy[uid] == true);
                    bill.status = everyone ? 'settled' : 'pending';
                  });
                },
          style: paid
              ? OutlinedButton.styleFrom(foregroundColor: HomiesColors.ok)
              : null,
          child: Text(paid ? '✓ Paid' : 'Mark paid', style: const TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final BillSchedule schedule;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onRecord;
  const _ScheduleCard({required this.schedule, required this.canManage, required this.onEdit, required this.onRecord});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final sch = schedule;
    final days = parseIso(sch.nextDueDate)?.difference(DateTime.now()).inDays ?? 0;
    ChipTone tone;
    String label;
    if (!sch.active) {
      tone = ChipTone.neutral;
      label = 'paused';
    } else if (days < 0) {
      tone = ChipTone.danger;
      label = 'overdue · ${days.abs()} d';
    } else if (days <= 7) {
      tone = ChipTone.warn;
      label = 'due ${fmtRelative(sch.nextDueDate)}';
    } else {
      tone = ChipTone.neutral;
      label = 'due ${fmtRelative(sch.nextDueDate)}';
    }
    final cat = _categories.firstWhere((c) => c[0] == sch.category, orElse: () => ['other', '📌']);

    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 4, children: [
                Text(sch.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                HomiesChip(cat[1]),
                HomiesChip(cadenceLabelFull(sch.cadence, sch.customDays)),
                HomiesChip(label, tone: tone),
              ]),
              Text('Next: ${fmtDate(sch.nextDueDate)} · period ${fmtDate(sch.cycleStart)} → ${fmtDate(sch.nextDueDate)}',
                  style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
              if (sch.estimatedAmount > 0)
                Text('Estimate: ${fmtAUD(sch.estimatedAmount)}', style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
            ]),
          ),
          Text(fmtAUD(sch.estimatedAmount), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Text('Splits between:', style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
          const SizedBox(width: 6),
          AvatarStack(users: sch.participants.map((id) => state.findUser(id)).whereType<User>().toList()),
          const SizedBox(width: 6),
          Text('· ${sch.splitMethod}', style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
        ]),
        if (canManage) ...[
          const Divider(),
          Wrap(spacing: 6, alignment: WrapAlignment.end, children: [
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    content: Text('Delete schedule "${sch.title}"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) state.mutate(() => state.billSchedules.removeWhere((x) => x.id == sch.id));
              },
              child: const Text('Delete', style: TextStyle(color: HomiesColors.danger)),
            ),
            OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
            OutlinedButton(
              onPressed: () => state.mutate(() => sch.active = !sch.active),
              child: Text(sch.active ? 'Pause' : 'Resume'),
            ),
            ElevatedButton.icon(
              onPressed: sch.active ? onRecord : null,
              icon: const Icon(Icons.photo_camera_outlined, size: 16),
              label: const Text('Record bill'),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _BillModal extends StatefulWidget {
  final Bill? existing;
  const _BillModal({this.existing});

  @override
  State<_BillModal> createState() => _BillModalState();
}

class _BillModalState extends State<_BillModal> {
  late HomiesState state;
  final titleCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  String category = 'utility';
  String? dueDate;
  String? periodStart;
  String? periodEnd;
  String split = 'equal';
  late List<String> participants;
  final Map<String, TextEditingController> customCtrls = {};

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      titleCtrl.text = e.title;
      amountCtrl.text = e.amount.toStringAsFixed(2);
      category = e.category;
      dueDate = e.dueDate;
      periodStart = e.periodStart;
      periodEnd = e.periodEnd;
      split = e.split;
      participants = e.shares.keys.toList();
      for (final entry in e.shares.entries) {
        customCtrls[entry.key] = TextEditingController(
          text: split == 'percentage' && e.amount > 0
              ? ((entry.value / e.amount) * 100).toStringAsFixed(0)
              : entry.value.toStringAsFixed(2),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    state = HomiesScope.of(context);
    if (widget.existing == null && customCtrls.isEmpty) {
      final hms = state.activeHousemates;
      final hasMixed = hms.any((u) => u.moveInDate != hms.first.moveInDate);
      participants = hms.map((u) => u.id).toList();
      if (split == 'equal' && hasMixed) split = 'prorated';
    }
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    amountCtrl.dispose();
    for (final c in customCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, double> _shares() {
    final total = double.tryParse(amountCtrl.text) ?? 0;
    if (split == 'equal') {
      final arr = equalSplit(total, participants.length);
      return {for (var i = 0; i < participants.length; i++) participants[i]: arr[i]};
    }
    if (split == 'prorated') {
      if (periodStart == null || periodEnd == null) return {};
      return prorateShares(total, participants, state.users, periodStart, periodEnd);
    }
    if (split == 'percentage') {
      return {
        for (final id in participants)
          id: ((total * (double.tryParse(customCtrls[id]?.text ?? '0') ?? 0) / 100) * 100).round() / 100,
      };
    }
    return {for (final id in participants) id: double.tryParse(customCtrls[id]?.text ?? '0') ?? 0};
  }

  void _save() {
    final shares = _shares();
    final isEdit = widget.existing != null;
    state.mutate(() {
      if (isEdit) {
        final b = widget.existing!;
        b.title = titleCtrl.text.trim();
        b.category = category;
        b.amount = double.tryParse(amountCtrl.text) ?? 0;
        b.periodStart = periodStart;
        b.periodEnd = periodEnd;
        b.dueDate = dueDate ?? '';
        b.split = split;
        b.shares = shares;
        b.paidBy = {for (final entry in b.paidBy.entries) if (shares.containsKey(entry.key)) entry.key: entry.value};
        b.status = shares.keys.isNotEmpty && shares.keys.every((uid) => b.paidBy[uid] == true) ? 'settled' : 'pending';
      } else {
        state.bills.add(Bill(
          id: 'b-${Random().nextInt(0xFFFF).toRadixString(36)}',
          title: titleCtrl.text.trim(),
          category: category,
          amount: double.tryParse(amountCtrl.text) ?? 0,
          periodStart: periodStart,
          periodEnd: periodEnd,
          dueDate: dueDate ?? '',
          issuedBy: state.currentUser?.id ?? 'u1',
          split: split,
          shares: shares,
        ));
      }
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hms = state.activeHousemates;
    final shares = _shares();
    final total = shares.values.fold<double>(0, (a, b) => a + b);
    final input = double.tryParse(amountCtrl.text) ?? 0;
    final isEdit = widget.existing != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Text(isEdit ? 'Edit bill' : 'New bill', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const FieldLabel('Title'),
              TextField(controller: titleCtrl, decoration: const InputDecoration(hintText: 'Electricity — AGL (Dec–Feb)')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const FieldLabel('Category'),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      items: [for (final c in _categories) DropdownMenuItem(value: c[0], child: Text(c[1]))],
                      onChanged: (v) => setState(() => category = v ?? 'utility'),
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 120,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const FieldLabel('Amount'),
                    TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              const FieldLabel('Due date'),
              _dateField(dueDate, (v) => setState(() => dueDate = v)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FieldLabel('Period start (optional)'),
                  _dateField(periodStart, (v) => setState(() => periodStart = v)),
                ])),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FieldLabel('Period end (optional)'),
                  _dateField(periodEnd, (v) => setState(() => periodEnd = v)),
                ])),
              ]),
              const Hint('Required if splitting prorated.'),
              const SizedBox(height: 10),
              const FieldLabel('Who pays'),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (final u in hms)
                  FilterChip(
                    label: Text(u.name),
                    selected: participants.contains(u.id),
                    onSelected: (v) => setState(() {
                      if (v) {
                        participants.add(u.id);
                      } else {
                        participants.remove(u.id);
                      }
                    }),
                  ),
              ]),
              const SizedBox(height: 10),
              const FieldLabel('Split method'),
              Segment<String>(
                options: const ['equal', 'prorated', 'percentage', 'custom'],
                value: split,
                labelFor: (v) => v[0].toUpperCase() + v.substring(1),
                onChanged: (v) {
                  setState(() {
                    split = v;
                    if (split == 'percentage' || split == 'custom') {
                      for (final id in participants) {
                        customCtrls.putIfAbsent(id, () => TextEditingController());
                      }
                    }
                  });
                },
              ),
              if (split == 'percentage' || split == 'custom') ...[
                const SizedBox(height: 10),
                FieldLabel('Per-person ${split == 'percentage' ? '%' : 'amount'}'),
                for (final id in participants)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Avatar.sm(state.findUser(id)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(state.findUser(id)?.name ?? '—', style: const TextStyle(fontSize: 13))),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: customCtrls.putIfAbsent(id, () => TextEditingController()),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(isDense: true),
                        ),
                      ),
                    ]),
                  ),
              ],
              const SizedBox(height: 10),
              HomiesCard(
                color: HomiesColors.surface2,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Preview', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: HomiesColors.textDim)),
                  if (split == 'prorated' && (periodStart == null || periodEnd == null))
                    const HomiesChip('Set a period above to compute the prorated split.', tone: ChipTone.warn)
                  else ...[
                    for (final entry in shares.entries)
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(state.findUser(entry.key)?.name ?? '—'),
                        Text(fmtAUD(entry.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ]),
                    const Divider(),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Split total', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(fmtAUD(total), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                    if ((total - input).abs() > 0.05) HomiesChip("Split doesn't add up to ${fmtAUD(input)}", tone: ChipTone.warn),
                  ]
                ]),
              ),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: titleCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty || dueDate == null
                      ? null
                      : _save,
                  child: Text(isEdit ? 'Save changes' : 'Create bill'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _dateField(String? value, ValueChanged<String?> onChanged) {
    return InkWell(
      onTap: () async {
        final d = await pickDate(context, initial: parseIso(value));
        if (d != null) onChanged(toIso(d));
      },
      child: InputDecorator(
        decoration: const InputDecoration(),
        child: Text(value != null ? fmtDate(value) : 'Pick a date',
            style: TextStyle(color: value != null ? HomiesColors.text : HomiesColors.textFaint)),
      ),
    );
  }
}

class _ScheduleModal extends StatefulWidget {
  final BillSchedule? existing;
  const _ScheduleModal({this.existing});

  @override
  State<_ScheduleModal> createState() => _ScheduleModalState();
}

class _ScheduleModalState extends State<_ScheduleModal> {
  late HomiesState state;
  final titleCtrl = TextEditingController();
  String category = 'utility';
  String cadence = 'quarterly';
  final customDaysCtrl = TextEditingController();
  String? nextDueDate;
  final estimateCtrl = TextEditingController();
  String splitMethod = 'prorated';
  late List<String> participants;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      titleCtrl.text = e.title;
      category = e.category;
      cadence = e.cadence;
      customDaysCtrl.text = e.customDays?.toString() ?? '';
      nextDueDate = e.nextDueDate;
      estimateCtrl.text = e.estimatedAmount > 0 ? e.estimatedAmount.toStringAsFixed(2) : '';
      splitMethod = e.splitMethod;
      participants = e.participants;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    state = HomiesScope.of(context);
    if (widget.existing == null) {
      participants = state.activeHousemates.map((u) => u.id).toList();
    }
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    customDaysCtrl.dispose();
    estimateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hms = state.activeHousemates;
    final cycleStart = nextDueDate != null
        ? subtractCadence(nextDueDate, cadence, int.tryParse(customDaysCtrl.text))
        : null;
    final canSave = titleCtrl.text.trim().isNotEmpty &&
        nextDueDate != null &&
        participants.isNotEmpty &&
        (cadence != 'custom' || (int.tryParse(customDaysCtrl.text) ?? 0) > 0);
    final isEdit = widget.existing != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Text(isEdit ? 'Edit bill schedule' : 'New bill schedule',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text("Set up a recurring bill. We'll surface it when due and let you record the actual amount + proof.",
                  style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
              const SizedBox(height: 12),
              const FieldLabel('Title'),
              TextField(controller: titleCtrl, decoration: const InputDecoration(hintText: 'Electricity — AGL'), onChanged: (_) => setState(() {})),
              const SizedBox(height: 10),
              const FieldLabel('Category'),
              DropdownButtonFormField<String>(
                initialValue: category,
                items: [for (final c in _categories) DropdownMenuItem(value: c[0], child: Text(c[1]))],
                onChanged: (v) => setState(() => category = v ?? 'utility'),
              ),
              const SizedBox(height: 10),
              const FieldLabel('Cadence'),
              DropdownButtonFormField<String>(
                initialValue: cadence,
                items: [for (final c in _cadences) DropdownMenuItem(value: c, child: Text(cadenceLabelFull(c, null)))],
                onChanged: (v) => setState(() => cadence = v ?? 'monthly'),
              ),
              if (cadence == 'custom') ...[
                const SizedBox(height: 10),
                const FieldLabel('Every N days'),
                TextField(controller: customDaysCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
              ],
              const SizedBox(height: 10),
              const FieldLabel('Next due date'),
              _dateField(nextDueDate, (v) => setState(() => nextDueDate = v)),
              const SizedBox(height: 10),
              const FieldLabel('Estimated amount (optional)'),
              TextField(controller: estimateCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: '420.00')),
              if (cycleStart != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Period for the first invoice: ${fmtDate(cycleStart)} → ${fmtDate(nextDueDate)}',
                      style: const TextStyle(color: HomiesColors.textFaint, fontSize: 12)),
                ),
              const SizedBox(height: 10),
              const FieldLabel('Default split'),
              Segment<String>(
                options: const ['equal', 'prorated'],
                value: splitMethod,
                labelFor: (v) => v[0].toUpperCase() + v.substring(1),
                onChanged: (v) => setState(() => splitMethod = v),
              ),
              const Hint('You can still change the split when you record each bill.'),
              const SizedBox(height: 10),
              const FieldLabel('Splits between'),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (final u in hms)
                  FilterChip(
                    label: Text(u.name),
                    selected: participants.contains(u.id),
                    onSelected: (v) => setState(() {
                      if (v) {
                        participants.add(u.id);
                      } else {
                        participants.remove(u.id);
                      }
                    }),
                  ),
              ]),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: canSave
                      ? () {
                          final cs = cycleStart ?? nextDueDate!;
                          state.mutate(() {
                            if (isEdit) {
                              final s = widget.existing!;
                              s.title = titleCtrl.text.trim();
                              s.category = category;
                              s.cadence = cadence;
                              s.customDays = cadence == 'custom' ? int.tryParse(customDaysCtrl.text) : null;
                              s.cycleStart = cs;
                              s.nextDueDate = nextDueDate!;
                              s.estimatedAmount = double.tryParse(estimateCtrl.text) ?? 0;
                              s.splitMethod = splitMethod;
                              s.participants = participants;
                            } else {
                              state.billSchedules.add(BillSchedule(
                                id: 'sch-${Random().nextInt(0xFFFF).toRadixString(36)}',
                                title: titleCtrl.text.trim(),
                                category: category,
                                cadence: cadence,
                                customDays: cadence == 'custom' ? int.tryParse(customDaysCtrl.text) : null,
                                cycleStart: cs,
                                nextDueDate: nextDueDate!,
                                estimatedAmount: double.tryParse(estimateCtrl.text) ?? 0,
                                splitMethod: splitMethod,
                                participants: participants,
                                createdBy: state.currentUser?.id ?? 'u1',
                              ));
                            }
                          });
                          Navigator.pop(context);
                        }
                      : null,
                  child: Text(isEdit ? 'Save changes' : 'Create schedule'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _dateField(String? value, ValueChanged<String?> onChanged) {
    return InkWell(
      onTap: () async {
        final d = await pickDate(context, initial: parseIso(value));
        if (d != null) onChanged(toIso(d));
      },
      child: InputDecorator(
        decoration: const InputDecoration(),
        child: Text(value != null ? fmtDate(value) : 'Pick a date',
            style: TextStyle(color: value != null ? HomiesColors.text : HomiesColors.textFaint)),
      ),
    );
  }
}

class _RecordBillModal extends StatefulWidget {
  final BillSchedule schedule;
  const _RecordBillModal({required this.schedule});

  @override
  State<_RecordBillModal> createState() => _RecordBillModalState();
}

class _RecordBillModalState extends State<_RecordBillModal> {
  late HomiesState state;
  late TextEditingController amountCtrl;
  late String dueDate;
  late String periodStart;
  late String periodEnd;
  late String split;
  late List<String> participants;
  Attachment? proof;
  bool advanceCycle = true;

  @override
  void initState() {
    super.initState();
    final sch = widget.schedule;
    amountCtrl = TextEditingController(text: sch.estimatedAmount > 0 ? sch.estimatedAmount.toStringAsFixed(2) : '');
    dueDate = todayIso();
    periodStart = sch.cycleStart;
    periodEnd = sch.nextDueDate;
    split = sch.splitMethod;
    participants = List.of(sch.participants);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    state = HomiesScope.of(context);
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    super.dispose();
  }

  Map<String, double> _shares() {
    final total = double.tryParse(amountCtrl.text) ?? 0;
    if (split == 'equal') {
      final arr = equalSplit(total, participants.length);
      return {for (var i = 0; i < participants.length; i++) participants[i]: arr[i]};
    }
    if (split == 'prorated') {
      return prorateShares(total, participants, state.users, periodStart, periodEnd);
    }
    return {for (final id in participants) id: 0};
  }

  void _save() {
    final sch = widget.schedule;
    final shares = _shares();
    final newNextDue = addCadence(sch.nextDueDate, sch.cadence, sch.customDays) ?? sch.nextDueDate;
    state.mutate(() {
      state.bills.add(Bill(
        id: 'b-${Random().nextInt(0xFFFF).toRadixString(36)}',
        title: '${sch.title} — ${fmtDate(periodStart)} → ${fmtDate(periodEnd)}',
        category: sch.category,
        amount: double.tryParse(amountCtrl.text) ?? 0,
        periodStart: periodStart,
        periodEnd: periodEnd,
        dueDate: dueDate,
        issuedBy: state.currentUser?.id ?? 'u1',
        split: split,
        shares: shares,
        scheduleId: sch.id,
        proof: proof,
      ));
      if (advanceCycle) {
        sch.cycleStart = sch.nextDueDate;
        sch.nextDueDate = newNextDue;
      }
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sch = widget.schedule;
    final shares = _shares();
    final input = double.tryParse(amountCtrl.text) ?? 0;
    final total = shares.values.fold<double>(0, (a, b) => a + b);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Text('Record ${sch.title}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('Enter the actual amount, attach proof, and the per-person share is created automatically.',
                  style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
              const SizedBox(height: 12),
              const FieldLabel('Actual amount'),
              TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
              const SizedBox(height: 10),
              const FieldLabel('Due date'),
              _dateField(dueDate, (v) => setState(() => dueDate = v ?? dueDate)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FieldLabel('Period start'),
                  _dateField(periodStart, (v) => setState(() => periodStart = v ?? periodStart)),
                ])),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FieldLabel('Period end'),
                  _dateField(periodEnd, (v) => setState(() => periodEnd = v ?? periodEnd)),
                ])),
              ]),
              const SizedBox(height: 10),
              const FieldLabel('Proof of bill'),
              FilePickerButton(value: proof, onChanged: (v) => setState(() => proof = v), label: 'Choose image or PDF'),
              const Hint('Optional but recommended — housemates can tap to view.'),
              const SizedBox(height: 10),
              const FieldLabel('Splits between'),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (final u in state.activeHousemates)
                  FilterChip(
                    label: Text(u.name),
                    selected: participants.contains(u.id),
                    onSelected: (v) => setState(() {
                      if (v) {
                        participants.add(u.id);
                      } else {
                        participants.remove(u.id);
                      }
                    }),
                  ),
              ]),
              const SizedBox(height: 10),
              const FieldLabel('Split method'),
              Segment<String>(
                options: const ['equal', 'prorated'],
                value: split,
                labelFor: (v) => v[0].toUpperCase() + v.substring(1),
                onChanged: (v) => setState(() => split = v),
              ),
              const SizedBox(height: 10),
              HomiesCard(
                color: HomiesColors.surface2,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Preview', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: HomiesColors.textDim)),
                  for (final entry in shares.entries)
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(state.findUser(entry.key)?.name ?? '—'),
                      Text(fmtAUD(entry.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(fmtAUD(total), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                  if ((total - input).abs() > 0.05) HomiesChip("Doesn't match ${fmtAUD(input)}", tone: ChipTone.warn),
                ]),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                value: advanceCycle,
                onChanged: (v) => setState(() => advanceCycle = v ?? true),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('Advance schedule (next due: ${fmtDate(addCadence(sch.nextDueDate, sch.cadence, sch.customDays))})',
                    style: const TextStyle(fontSize: 12)),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: amountCtrl.text.trim().isEmpty || participants.isEmpty ? null : _save,
                  child: const Text('Record bill & split'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _dateField(String? value, ValueChanged<String?> onChanged) {
    return InkWell(
      onTap: () async {
        final d = await pickDate(context, initial: parseIso(value));
        if (d != null) onChanged(toIso(d));
      },
      child: InputDecorator(
        decoration: const InputDecoration(),
        child: Text(value != null && value.isNotEmpty ? fmtDate(value) : 'Pick a date',
            style: TextStyle(color: value != null && value.isNotEmpty ? HomiesColors.text : HomiesColors.textFaint)),
      ),
    );
  }
}
