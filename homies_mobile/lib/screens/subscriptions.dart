import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/ui_kit.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final isLeaseholder = cu.role == 'leaseholder';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'Subscriptions',
            subtitle: 'Recurring services — Netflix, Spotify, gym.',
            action: ElevatedButton(onPressed: () => _openSubModal(context, null), child: const Text('+ Add')),
          ),
          if (state.subscriptions.isEmpty) const EmptyState(title: 'No subscriptions yet'),
          for (final s in state.subscriptions)
            HomiesCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text('${fmtAUD(s.amount)} / ${s.cadence} · paid by ${state.findUser(s.payer)?.name ?? '—'}',
                          style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                    ]),
                  ),
                  if (isLeaseholder || s.payer == cu.id) ...[
                    OutlinedButton(onPressed: () => _openSubModal(context, s), child: const Text('Edit')),
                    TextButton(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            content: const Text('Remove this subscription?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
                            ],
                          ),
                        );
                        if (ok == true) state.mutate(() => state.subscriptions.removeWhere((x) => x.id == s.id));
                      },
                      child: const Text('Remove', style: TextStyle(color: HomiesColors.danger)),
                    ),
                  ],
                ]),
                const Divider(),
                for (final id in s.participants)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Avatar.sm(state.findUser(id)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(state.findUser(id)?.name ?? '—', style: const TextStyle(fontSize: 12))),
                      Text(fmtAUD(s.shares[id] ?? 0), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    ]),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }

  void _openSubModal(BuildContext context, Subscription? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _SubModal(existing: existing),
      ),
    );
  }
}

class _SubModal extends StatefulWidget {
  final Subscription? existing;
  const _SubModal({this.existing});

  @override
  State<_SubModal> createState() => _SubModalState();
}

class _SubModalState extends State<_SubModal> {
  late HomiesState state;
  final nameCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  String cadence = 'monthly';
  String? payer;
  late List<String> participants;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      nameCtrl.text = e.name;
      amountCtrl.text = e.amount.toStringAsFixed(2);
      cadence = e.cadence;
      payer = e.payer;
      participants = List.of(e.participants);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    state = HomiesScope.of(context);
    if (widget.existing == null) {
      payer ??= state.currentUser?.id;
      participants = state.activeHousemates.map((u) => u.id).toList();
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final total = double.tryParse(amountCtrl.text) ?? 0;
    final arr = equalSplit(total, participants.length);
    final shares = {for (var i = 0; i < participants.length; i++) participants[i]: arr[i]};
    state.mutate(() {
      if (widget.existing != null) {
        final s = widget.existing!;
        s.name = nameCtrl.text.trim();
        s.amount = total;
        s.cadence = cadence;
        s.payer = payer ?? state.currentUser!.id;
        s.participants = participants;
        s.shares = shares;
      } else {
        state.subscriptions.add(Subscription(
          id: 's-${Random().nextInt(0xFFFF).toRadixString(36)}',
          name: nameCtrl.text.trim(),
          amount: total,
          cadence: cadence,
          payer: payer ?? state.currentUser!.id,
          participants: participants,
          shares: shares,
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
            Text(isEdit ? 'Edit subscription' : 'Add subscription', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const FieldLabel('Name'),
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Netflix Premium')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const FieldLabel('Amount'),
                TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              ])),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const FieldLabel('Cadence'),
                DropdownButtonFormField<String>(
                  initialValue: cadence,
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'fortnightly', child: Text('Fortnightly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                  ],
                  onChanged: (v) => setState(() => cadence = v ?? 'monthly'),
                ),
              ])),
            ]),
            const SizedBox(height: 10),
            const FieldLabel('Paid by'),
            DropdownButtonFormField<String>(
              initialValue: payer,
              items: [for (final u in hms) DropdownMenuItem(value: u.id, child: Text(u.name))],
              onChanged: (v) => setState(() => payer = v),
            ),
            const SizedBox(height: 10),
            const FieldLabel('Split between'),
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
            const Hint("Anyone not ticked is excluded — useful when a housemate doesn't use the service."),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: nameCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty || participants.isEmpty ? null : _save,
                child: Text(isEdit ? 'Save changes' : 'Add'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
