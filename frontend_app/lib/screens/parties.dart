import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/ui_kit.dart';

class PartiesScreen extends StatelessWidget {
  const PartiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'Parties',
            subtitle: 'Propose a home party — accept, suggest another date, or pass.',
            action: ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: const _PartyModal(),
                ),
              ),
              child: const Text('+ Propose'),
            ),
          ),
          if (state.parties.isEmpty)
            const EmptyState(title: 'No parties yet', body: 'Hosting something? Run it by the house first.'),
          for (final p in state.parties)
            HomiesCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text('${fmtDate(p.date)} at ${p.time} · host ${state.findUser(p.host)?.name ?? '—'}',
                    style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                if (p.notes.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text(p.notes, style: const TextStyle(fontSize: 13))),
                const Divider(),
                const Text('Housemate responses', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: HomiesColors.textDim)),
                for (final u in state.activeHousemates.where((u) => u.id != p.host))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Avatar.sm(u),
                      const SizedBox(width: 8),
                      Expanded(child: Text(u.name, style: const TextStyle(fontSize: 12))),
                      switch (p.responses[u.id]) {
                        'accept' => const HomiesChip("in", tone: ChipTone.ok),
                        'push' => const HomiesChip('suggest other date', tone: ChipTone.warn),
                        'decline' => const HomiesChip('pass', tone: ChipTone.danger),
                        _ => const HomiesChip('no reply'),
                      },
                    ]),
                  ),
                if (p.host != cu.id) ...[
                  const Divider(),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    const Text('Your reply:', style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                    for (final r in const ['accept', 'push', 'decline'])
                      OutlinedButton(
                        onPressed: () => state.mutate(() => p.responses[cu.id] = r),
                        style: p.responses[cu.id] == r
                            ? OutlinedButton.styleFrom(backgroundColor: HomiesColors.accentSoft, foregroundColor: HomiesColors.accentStrong)
                            : null,
                        child: Text(r == 'accept' ? "I'm in" : r == 'push' ? 'Push it' : 'Pass'),
                      ),
                  ]),
                ],
              ]),
            ),
        ]),
      ),
    );
  }
}

class _PartyModal extends StatefulWidget {
  const _PartyModal();

  @override
  State<_PartyModal> createState() => _PartyModalState();
}

class _PartyModalState extends State<_PartyModal> {
  final titleCtrl = TextEditingController();
  final timeCtrl = TextEditingController(text: '19:00');
  final notesCtrl = TextEditingController();
  String? date;

  @override
  void dispose() {
    titleCtrl.dispose();
    timeCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            const Text('Propose a party', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            const FieldLabel("What's the occasion?"),
            TextField(controller: titleCtrl, decoration: const InputDecoration(hintText: "Marco's 30th, housewarming, etc.")),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const FieldLabel('Date'),
                InkWell(
                  onTap: () async {
                    final d = await pickDate(context, initial: parseIso(date));
                    if (d != null) setState(() => date = toIso(d));
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(),
                    child: Text(date != null ? fmtDate(date) : 'Pick a date',
                        style: TextStyle(color: date != null ? HomiesColors.text : HomiesColors.textFaint)),
                  ),
                ),
              ])),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const FieldLabel('Start time'),
                TextField(controller: timeCtrl, decoration: const InputDecoration(hintText: '19:00')),
              ])),
            ]),
            const SizedBox(height: 10),
            const FieldLabel('Notes for housemates'),
            TextField(controller: notesCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'How many people, food & drinks, end time…')),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: titleCtrl.text.trim().isEmpty || date == null
                    ? null
                    : () {
                        state.mutate(() => state.parties.add(Party(
                              id: 'pa-${Random().nextInt(0xFFFF).toRadixString(36)}',
                              title: titleCtrl.text.trim(),
                              date: date!,
                              time: timeCtrl.text.trim(),
                              host: state.currentUser!.id,
                              notes: notesCtrl.text.trim(),
                            )));
                        Navigator.pop(context);
                      },
                child: const Text('Propose'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
