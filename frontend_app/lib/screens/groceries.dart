import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/file_picker_button.dart';
import '../widgets/ui_kit.dart';

class GroceriesScreen extends StatelessWidget {
  const GroceriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'Groceries',
            subtitle: "Upload the receipt and we'll do the splits.",
            action: ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: const _GroceryModal(),
                ),
              ),
              child: const Text('+ Log shop'),
            ),
          ),
          if (state.groceries.isEmpty) const EmptyState(title: 'No shops logged yet'),
          for (final g in state.groceries)
            HomiesCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(g.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text('${fmtDate(g.date)} · paid by ${state.findUser(g.payer)?.name ?? '—'} · ${g.mode}',
                          style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                    ]),
                  ),
                  Text(fmtAUD(g.total), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ]),
                if (g.receipt != null) AttachmentTile(value: g.receipt!, compact: true),
                if (g.mode == 'shared') ...[
                  const Divider(),
                  for (final entry in g.shares.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Avatar.sm(state.findUser(entry.key)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(state.findUser(entry.key)?.name ?? '—', style: const TextStyle(fontSize: 12))),
                        Text(fmtAUD(entry.value), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      ]),
                    ),
                ],
              ]),
            ),
        ]),
      ),
    );
  }
}

class _GroceryModal extends StatefulWidget {
  const _GroceryModal();

  @override
  State<_GroceryModal> createState() => _GroceryModalState();
}

class _GroceryModalState extends State<_GroceryModal> {
  late HomiesState state;
  final titleCtrl = TextEditingController();
  final totalCtrl = TextEditingController();
  String mode = 'shared';
  String? payer;
  late List<String> participants;
  Attachment? receipt;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    state = HomiesScope.of(context);
    payer ??= state.currentUser?.id;
    participants = state.activeHousemates.map((u) => u.id).toList();
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    totalCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final total = double.tryParse(totalCtrl.text) ?? 0;
    if (mode == 'individual') {
      final uid = state.currentUser!.id;
      state.mutate(() {
        state.personalExpenses.add(PersonalExpense(
          id: 'pe-${DateTime.now().millisecondsSinceEpoch}',
          userId: uid,
          category: 'grocery',
          title: titleCtrl.text.trim(),
          amount: total,
          date: todayIso(),
        ));
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to your personal spending')),
      );
      return;
    }
    final arr = equalSplit(total, participants.length);
    final shares = {for (var i = 0; i < participants.length; i++) participants[i]: arr[i]};
    state.mutate(() {
      state.groceries.insert(0, Grocery(
        id: 'g-${Random().nextInt(0xFFFF).toRadixString(36)}',
        title: titleCtrl.text.trim(),
        total: total,
        payer: payer ?? state.currentUser!.id,
        mode: 'shared',
        shares: shares,
        date: todayIso(),
        receipt: receipt,
      ));
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hms = state.activeHousemates;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            const Text('Log a grocery shop', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const FieldLabel('What was it?'),
            TextField(controller: titleCtrl, decoration: const InputDecoration(hintText: 'Coles weekly shop')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const FieldLabel('Total'),
                TextField(controller: totalCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
              ])),
              if (mode == 'shared') ...[
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FieldLabel('Paid by'),
                  DropdownButtonFormField<String>(
                    initialValue: payer,
                    items: [for (final u in hms) DropdownMenuItem(value: u.id, child: Text(u.name))],
                    onChanged: (v) => setState(() => payer = v),
                  ),
                ])),
              ],
            ]),
            const SizedBox(height: 10),
            const FieldLabel('Who is this for?'),
            Segment<String>(
              options: const ['shared', 'individual'],
              value: mode,
              labelFor: (v) => v == 'shared' ? 'Shared with housemates' : 'Just me',
              onChanged: (v) => setState(() => mode = v),
            ),
            if (mode == 'individual') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: HomiesColors.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.person_outlined, size: 15, color: HomiesColors.accentStrong),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will be saved directly to your personal spending — not visible to housemates.',
                      style: TextStyle(fontSize: 12, color: HomiesColors.accentStrong),
                    ),
                  ),
                ]),
              ),
            ],
            if (mode == 'shared') ...[
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
            ],
            const SizedBox(height: 10),
            const FieldLabel('Receipt (optional)'),
            FilePickerButton(value: receipt, onChanged: (v) => setState(() => receipt = v)),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: titleCtrl.text.trim().isEmpty || totalCtrl.text.trim().isEmpty ? null : _save,
                child: const Text('Save'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
