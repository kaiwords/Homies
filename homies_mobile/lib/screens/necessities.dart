import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/ui_kit.dart';

class NecessitiesScreen extends StatefulWidget {
  const NecessitiesScreen({super.key});

  @override
  State<NecessitiesScreen> createState() => _NecessitiesScreenState();
}

class _NecessitiesScreenState extends State<NecessitiesScreen> {
  final itemCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  String mode = 'shared';

  @override
  void dispose() {
    itemCtrl.dispose();
    amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final totalShared = state.necessities.where((n) => n.mode == 'shared').fold<double>(0, (s, n) => s + n.amount);
    final hmCount = state.activeHousemates.length;
    final perPerson = hmCount == 0 ? 0.0 : totalShared / hmCount;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PageHead(
            title: 'Necessities',
            subtitle: 'TP, hand soap, bin liners. Default split equal across everyone.',
          ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Log a purchase', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const FieldLabel('Item'),
              TextField(controller: itemCtrl, decoration: const InputDecoration(hintText: 'Toilet paper (24-pack)'), onChanged: (_) => setState(() {})),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FieldLabel('Amount'),
                  TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
                ])),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FieldLabel('Mode'),
                  Segment<String>(
                    options: const ['shared', 'individual'],
                    value: mode,
                    labelFor: (v) => v == 'shared' ? 'Shared' : 'Just me',
                    onChanged: (v) => setState(() => mode = v),
                  ),
                ])),
              ]),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: itemCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty
                    ? null
                    : () {
                        state.mutate(() {
                          state.necessities.insert(0, Necessity(
                            id: 'n-${Random().nextInt(0xFFFF).toRadixString(36)}',
                            item: itemCtrl.text.trim(),
                            amount: double.tryParse(amountCtrl.text) ?? 0,
                            mode: mode,
                            payer: cu.id,
                            date: todayIso(),
                          ));
                        });
                        itemCtrl.clear();
                        amountCtrl.clear();
                        setState(() {});
                      },
                child: const Text('Add'),
              ),
            ]),
          ),
          HomiesCard(
            child: StatRow(tiles: [
              StatTile(label: 'Shared total', value: fmtAUD(totalShared)),
              StatTile(label: '≈ Per person', value: fmtAUD(perPerson)),
            ]),
          ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Recent', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              if (state.necessities.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Nothing logged yet.', style: TextStyle(color: HomiesColors.textDim, fontSize: 12))),
              for (final n in state.necessities)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Avatar.sm(state.findUser(n.payer)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n.item, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('${state.findUser(n.payer)?.name ?? '—'} · ${fmtDate(n.date)} · ${n.mode}',
                            style: const TextStyle(color: HomiesColors.textDim, fontSize: 11)),
                      ]),
                    ),
                    Text(fmtAUD(n.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
