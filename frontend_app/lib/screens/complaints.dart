import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/ui_kit.dart';

const _threshold = 100;

class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final isLeaseholder = cu.role == 'leaseholder';
    final housemates = state.users.where((u) => !u.pending).toList();
    final totals = {
      for (final u in housemates)
        u.id: state.complaints.where((c) => c.against == u.id).fold<int>(0, (s, c) => s + c.severity),
    };

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'Complaints',
            subtitle: 'Threshold for serious action: $_threshold points.',
            action: ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: const _ComplaintModal(),
                ),
              ),
              child: const Text('+ New'),
            ),
          ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Complaint score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('Sum of severity points for each housemate.', style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
              const SizedBox(height: 8),
              for (final u in housemates)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Avatar.sm(u),
                    const SizedBox(width: 8),
                    SizedBox(width: 100, child: Text(u.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ((totals[u.id] ?? 0) / _threshold).clamp(0, 1),
                          minHeight: 8,
                          backgroundColor: HomiesColors.surface2,
                          valueColor: AlwaysStoppedAnimation(
                            (totals[u.id] ?? 0) >= _threshold ? HomiesColors.danger : (totals[u.id] ?? 0) >= _threshold * 0.5 ? HomiesColors.warn : HomiesColors.ok,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${totals[u.id] ?? 0} / $_threshold', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
          ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Open complaints', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              if (state.complaints.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('No complaints. Nice house.', style: TextStyle(color: HomiesColors.textDim))),
              for (final c in state.complaints)
                HomiesCard(
                  color: HomiesColors.surface2,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      Text('Against ${state.findUser(c.against)?.name ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      HomiesChip(c.status, tone: c.status == 'open' ? ChipTone.warn : ChipTone.ok),
                      HomiesChip('severity ${c.severity}'),
                    ]),
                    Text('From ${state.findUser(c.from)?.name ?? '—'} · ${fmtDate(c.date)}',
                        style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                    Padding(padding: const EdgeInsets.only(top: 6), child: Text(c.reason)),
                    if (c.status == 'open' && isLeaseholder)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(children: [
                          OutlinedButton(
                            onPressed: () => state.mutate(() => c.status = 'ignored'),
                            child: const Text('Ignore'),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: () => state.mutate(() => c.status = 'actioned'),
                            child: const Text('Action taken'),
                          ),
                        ]),
                      ),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ComplaintModal extends StatefulWidget {
  const _ComplaintModal();

  @override
  State<_ComplaintModal> createState() => _ComplaintModalState();
}

class _ComplaintModalState extends State<_ComplaintModal> {
  late HomiesState state;
  String? against;
  final reasonCtrl = TextEditingController();
  double severity = 5;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    state = HomiesScope.of(context);
    against ??= state.users.firstWhereOrNull((u) => !u.pending && u.id != state.currentUser?.id)?.id;
  }

  @override
  void dispose() {
    reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final others = state.users.where((u) => !u.pending && u.id != state.currentUser?.id).toList();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            const Text('Lodge a complaint', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const Text('Keep it factual. Severity 1 (minor) to 50 (major).', style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
            const SizedBox(height: 10),
            const FieldLabel('Against'),
            DropdownButtonFormField<String>(
              initialValue: against,
              items: [for (final u in others) DropdownMenuItem(value: u.id, child: Text(u.name))],
              onChanged: (v) => setState(() => against = v),
            ),
            const SizedBox(height: 10),
            const FieldLabel('What happened?'),
            TextField(controller: reasonCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Be specific — when, where, what.')),
            const SizedBox(height: 10),
            FieldLabel('Severity: ${severity.round()}'),
            Slider(value: severity, min: 1, max: 50, divisions: 49, onChanged: (v) => setState(() => severity = v)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: reasonCtrl.text.trim().isEmpty || against == null
                    ? null
                    : () {
                        final cu = state.currentUser!;
                        final accused = state.findUser(against!);
                        state.mutate(() => state.complaints.insert(0, Complaint(
                              id: 'co-${Random().nextInt(0xFFFF).toRadixString(36)}',
                              against: against!,
                              from: cu.id,
                              reason: reasonCtrl.text.trim(),
                              severity: severity.round(),
                              date: todayIso(),
                            )));
                        if (accused != null) {
                          state.addAppNotification(AppNotification(
                            id: 'complaint_${DateTime.now().millisecondsSinceEpoch}',
                            kind: 'complaint',
                            title: 'New complaint filed against you',
                            body: '${cu.name} filed a complaint: "${reasonCtrl.text.trim()}"',
                            at: DateTime.now().toIso8601String(),
                            forUserId: accused.id,
                          ));
                        }
                        Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(backgroundColor: HomiesColors.danger),
                child: const Text('Submit'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
