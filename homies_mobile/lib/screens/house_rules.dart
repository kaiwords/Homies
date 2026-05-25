import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/ui_kit.dart';

class HouseRulesScreen extends StatefulWidget {
  const HouseRulesScreen({super.key});

  @override
  State<HouseRulesScreen> createState() => _HouseRulesScreenState();
}

class _HouseRulesScreenState extends State<HouseRulesScreen> {
  final newRuleCtrl = TextEditingController();
  String? editingId;
  final editCtrl = TextEditingController();

  @override
  void dispose() {
    newRuleCtrl.dispose();
    editCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final isLeaseholder = cu.role == 'leaseholder';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PageHead(
            title: 'House rules',
            subtitle: 'Tenants accept these on join. Leaseholder can edit anytime.',
          ),
          if (!isLeaseholder)
            InfoBanner(text: "You accepted these on ${fmtDate(cu.acceptedRulesAt)}. Only the leaseholder can edit."),
          if (isLeaseholder)
            HomiesCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Add a rule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: newRuleCtrl,
                      decoration: const InputDecoration(hintText: 'E.g. No smoking inside, vaping on balcony only'),
                      onSubmitted: (_) => _add(state, cu),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: () => _add(state, cu), child: const Text('Add')),
                ]),
                const Hint('Topics: smoking, vaping, parties, guests, quiet hours, pets.'),
              ]),
            ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Current rules', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              if (state.houseRules.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('No rules yet.', style: TextStyle(color: HomiesColors.textDim, fontSize: 12))),
              for (var i = 0; i < state.houseRules.length; i++) _ruleRow(state, isLeaseholder, i),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _ruleRow(HomiesState state, bool isLeaseholder, int i) {
    final r = state.houseRules[i];
    final author = state.findUser(r.addedBy);
    final isEditing = editingId == r.id;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: HomiesColors.border))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 22, child: Text('${i + 1}.', style: const TextStyle(color: HomiesColors.textFaint))),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (isEditing)
              TextField(controller: editCtrl, autofocus: true)
            else
              Text(r.text),
            Text('Added by ${author?.name ?? '—'} · ${fmtDate(r.addedAt)}',
                style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
          ]),
        ),
        if (isLeaseholder)
          isEditing
              ? Row(children: [
                  TextButton(onPressed: () => setState(() => editingId = null), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: editCtrl.text.trim().isEmpty
                        ? null
                        : () {
                            state.mutate(() => r.text = editCtrl.text.trim());
                            setState(() => editingId = null);
                          },
                    child: const Text('Save'),
                  ),
                ])
              : Row(children: [
                  TextButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          content: const Text('Remove this rule?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
                          ],
                        ),
                      );
                      if (ok == true) state.mutate(() => state.houseRules.removeWhere((x) => x.id == r.id));
                    },
                    child: const Text('Remove', style: TextStyle(color: HomiesColors.danger, fontSize: 12)),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      editingId = r.id;
                      editCtrl.text = r.text;
                    }),
                    child: const Text('Edit', style: TextStyle(fontSize: 12)),
                  ),
                ]),
      ]),
    );
  }

  void _add(HomiesState state, dynamic cu) {
    final txt = newRuleCtrl.text.trim();
    if (txt.isEmpty) return;
    state.mutate(() {
      state.houseRules.add(HouseRule(
        id: 'r-${Random().nextInt(0xFFFF).toRadixString(36)}',
        text: txt,
        addedBy: cu.id,
        addedAt: todayIso(),
      ));
    });
    newRuleCtrl.clear();
    setState(() {});
  }
}
