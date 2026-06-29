import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/ui_kit.dart';

class LeavingScreen extends StatefulWidget {
  const LeavingScreen({super.key});

  @override
  State<LeavingScreen> createState() => _LeavingScreenState();
}

class _LeavingScreenState extends State<LeavingScreen> {
  String? leaveDate;
  final reasonCtrl = TextEditingController();

  @override
  void dispose() {
    reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final isLeaseholder = cu.role == 'leaseholder';
    final myNotice = state.notices.firstWhereOrNull((n) => n.userId == cu.id);
    final minLeave = DateTime.now().add(const Duration(days: 14));
    final minLeaveIso = minLeave.toIso8601String().substring(0, 10);

    leaveDate ??= minLeaveIso;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PageHead(title: 'Leaving the house', subtitle: "Give 2 weeks' notice. Bond returns after inspection."),
          if (myNotice == null)
            HomiesCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Give notice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text('Earliest leave date is 14 days from today: ${fmtDate(minLeaveIso)}.',
                    style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                const SizedBox(height: 8),
                const FieldLabel('Leaving date'),
                InkWell(
                  onTap: () async {
                    final d = await pickDate(context, initial: parseIso(leaveDate));
                    if (d != null) setState(() => leaveDate = toIso(d));
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(),
                    child: Text(fmtDate(leaveDate), style: const TextStyle(color: HomiesColors.text)),
                  ),
                ),
                const SizedBox(height: 8),
                const FieldLabel('Reason (optional)'),
                TextField(controller: reasonCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Moving cities, new job, etc.')),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: parseIso(leaveDate)?.isBefore(minLeave) == true
                      ? null
                      : () {
                          state.mutate(() => state.notices.add(Notice(
                                id: 'nt-${Random().nextInt(0xFFFF).toRadixString(36)}',
                                userId: cu.id,
                                givenAt: todayIso(),
                                leaveDate: leaveDate!,
                                reason: reasonCtrl.text.trim(),
                              )));
                        },
                  child: const Text('Give notice'),
                ),
              ]),
            ),
          if (myNotice != null) _NoticeCard(notice: myNotice),
          if (isLeaseholder && state.notices.any((n) => n.userId != cu.id))
            HomiesCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Housemates on notice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                for (final n in state.notices.where((n) => n.userId != cu.id)) _NoticeAdmin(notice: n),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Notice notice;
  const _NoticeCard({required this.notice});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text("You've given notice", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: HomiesChip('leaving ${fmtRelative(notice.leaveDate)}', tone: ChipTone.warn),
        ),
        Text('Final day: ${fmtDate(notice.leaveDate)}. Notice given on ${fmtDate(notice.givenAt)}.'),
        if (notice.reason.isNotEmpty)
          Text('Reason: "${notice.reason}"', style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
        const Divider(),
        const Text('Bond return', style: TextStyle(fontWeight: FontWeight.w600)),
        Text(
          notice.bondReturn == 'now'
              ? 'Leaseholder will release immediately.'
              : 'Leaseholder will release after agent inspection.',
          style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
        ),
        if (notice.deductions.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Proposed deductions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          for (final d in notice.deductions)
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(d.reason, style: const TextStyle(fontSize: 12))),
              Text(fmtAUD(d.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          if (notice.deductionExplanation.isNotEmpty)
            Text(notice.deductionExplanation, style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => state.mutate(() => state.notices.removeWhere((n) => n.id == notice.id)),
          style: TextButton.styleFrom(foregroundColor: HomiesColors.danger),
          child: const Text('Cancel notice'),
        ),
      ]),
    );
  }
}

class _NoticeAdmin extends StatefulWidget {
  final Notice notice;
  const _NoticeAdmin({required this.notice});

  @override
  State<_NoticeAdmin> createState() => _NoticeAdminState();
}

class _NoticeAdminState extends State<_NoticeAdmin> {
  bool _open = false;
  late String _bondMode;
  late List<MapEntry<TextEditingController, TextEditingController>> _deds;
  late TextEditingController _explCtrl;

  @override
  void initState() {
    super.initState();
    _bondMode = widget.notice.bondReturn;
    _deds = widget.notice.deductions
        .map((d) => MapEntry(TextEditingController(text: d.reason), TextEditingController(text: d.amount.toStringAsFixed(2))))
        .toList();
    _explCtrl = TextEditingController(text: widget.notice.deductionExplanation);
  }

  @override
  void dispose() {
    for (final e in _deds) {
      e.key.dispose();
      e.value.dispose();
    }
    _explCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final user = state.findUser(widget.notice.userId);
    final totalDed = _deds.fold<double>(0, (s, e) => s + (double.tryParse(e.value.text) ?? 0));
    final refund = (user?.bondAmount ?? 0) - totalDed;

    return HomiesCard(
      color: HomiesColors.surface2,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(user: user),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user?.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Leaves ${fmtDate(widget.notice.leaveDate)} (${fmtRelative(widget.notice.leaveDate)}) · bond ${fmtAUD(user?.bondAmount ?? 0)}',
                  style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
            ]),
          ),
          OutlinedButton(onPressed: () => setState(() => _open = !_open), child: Text(_open ? 'Close' : 'Manage bond')),
        ]),
        if (_open) ...[
          const Divider(),
          const FieldLabel('When to release bond'),
          Segment<String>(
            options: const ['now', 'after-agent'],
            value: _bondMode,
            labelFor: (v) => v == 'now' ? 'Release now' : 'After agent inspection',
            onChanged: (v) => setState(() => _bondMode = v),
          ),
          const SizedBox(height: 10),
          const FieldLabel('Deductions (if any)'),
          for (final e in _deds)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: TextField(controller: e.key, decoration: const InputDecoration(hintText: 'Reason'))),
                const SizedBox(width: 6),
                SizedBox(width: 100, child: TextField(controller: e.value, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: r'$'), onChanged: (_) => setState(() {}))),
              ]),
            ),
          OutlinedButton(
            onPressed: () => setState(() => _deds.add(MapEntry(TextEditingController(), TextEditingController()))),
            child: const Text('+ Add deduction'),
          ),
          if (_deds.isNotEmpty) ...[
            const SizedBox(height: 10),
            const FieldLabel('Explanation (required if cutting bond)'),
            TextField(controller: _explCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Why these deductions?')),
          ],
          const SizedBox(height: 10),
          HomiesCard(
            color: HomiesColors.surface,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Bond paid'),
                Text(fmtAUD(user?.bondAmount ?? 0), style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Deductions'),
                Text('−${fmtAUD(totalDed)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Refund', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(fmtAUD(refund), style: const TextStyle(fontWeight: FontWeight.w600, color: HomiesColors.accent)),
              ]),
            ]),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              state.mutate(() {
                widget.notice.bondReturn = _bondMode;
                widget.notice.deductions = [
                  for (final e in _deds)
                    if (e.key.text.trim().isNotEmpty && double.tryParse(e.value.text) != null)
                      Deduction(reason: e.key.text.trim(), amount: double.parse(e.value.text)),
                ];
                widget.notice.deductionExplanation = _explCtrl.text.trim();
              });
              setState(() => _open = false);
            },
            child: const Text('Save bond plan'),
          ),
        ],
      ]),
    );
  }
}
