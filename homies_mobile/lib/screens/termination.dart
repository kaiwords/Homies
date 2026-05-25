import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/ui_kit.dart';

class TerminationScreen extends StatefulWidget {
  const TerminationScreen({super.key});

  @override
  State<TerminationScreen> createState() => _TerminationScreenState();
}

class _TerminationScreenState extends State<TerminationScreen> {
  late HomiesState state;
  late TerminationPlan draft;
  final Map<String, TextEditingController> _expenseReasonCtrls = {};
  final Map<String, TextEditingController> _expenseAmountCtrls = {};
  final Map<String, TextEditingController> _customCtrls = {};
  late TextEditingController _notesCtrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    state = HomiesScope.of(context);
    final existing = state.termination ?? TerminationPlan();
    draft = TerminationPlan(
      expenses: List.of(existing.expenses),
      splitMode: existing.splitMode,
      customShares: Map.of(existing.customShares),
      notes: existing.notes,
    );
    for (final e in draft.expenses) {
      _expenseReasonCtrls.putIfAbsent(e.id, () => TextEditingController(text: e.reason));
      _expenseAmountCtrls.putIfAbsent(e.id, () => TextEditingController(text: e.amount > 0 ? e.amount.toStringAsFixed(2) : ''));
    }
    _notesCtrl = TextEditingController(text: draft.notes);
  }

  @override
  void dispose() {
    for (final c in _expenseReasonCtrls.values) {
      c.dispose();
    }
    for (final c in _expenseAmountCtrls.values) {
      c.dispose();
    }
    for (final c in _customCtrls.values) {
      c.dispose();
    }
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    state.mutate(() {
      state.termination = TerminationPlan(
        expenses: [
          for (final e in draft.expenses)
            TerminationExpense(
              id: e.id,
              reason: _expenseReasonCtrls[e.id]?.text.trim() ?? '',
              amount: double.tryParse(_expenseAmountCtrls[e.id]?.text ?? '') ?? 0,
            ),
        ],
        splitMode: draft.splitMode,
        customShares: {for (final entry in _customCtrls.entries) entry.key: double.tryParse(entry.value.text) ?? 0},
        notes: _notesCtrl.text.trim(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cu = state.currentUser!;
    final isLeaseholder = cu.role == 'leaseholder';
    if (!isLeaseholder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/app');
      });
      return const SizedBox.shrink();
    }
    final housemates = state.activeHousemates;
    final totalBond = housemates.fold<double>(0, (s, u) => s + u.bondAmount);
    final totalExpenses =
        draft.expenses.fold<double>(0, (s, e) => s + (double.tryParse(_expenseAmountCtrls[e.id]?.text ?? '') ?? 0));
    final netRefund = totalBond - totalExpenses;
    final Map<String, double> shares;
    if (draft.splitMode == 'equal') {
      final arr = equalSplit(netRefund, housemates.length);
      shares = {for (var i = 0; i < housemates.length; i++) housemates[i].id: arr[i]};
    } else {
      shares = {for (final u in housemates) u.id: double.tryParse(_customCtrls[u.id]?.text ?? '') ?? 0};
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'End of lease',
            subtitle: 'Final cleanup, fix-up expenses, bond split.',
            action: isLeaseholder ? ElevatedButton(onPressed: _save, child: const Text('Save')) : null,
          ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Lease wrap-up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              StatRow(tiles: [
                StatTile(label: 'Lease end', value: fmtDate(state.property.leaseEnd), valueFontSize: 16, sub: fmtRelative(state.property.leaseEnd)),
                StatTile(label: 'Housemates', value: '${housemates.length}'),
                StatTile(label: 'Combined bond', value: fmtAUD(totalBond)),
              ]),
            ]),
          ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Property expenses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Text('Cleaning, repairs, damage — anything from the bond.',
                  style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
              const SizedBox(height: 8),
              for (final e in draft.expenses)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _expenseReasonCtrls[e.id],
                        enabled: isLeaseholder,
                        decoration: const InputDecoration(hintText: 'Carpet steam clean, oven repair…'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _expenseAmountCtrls[e.id],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        enabled: isLeaseholder,
                        decoration: const InputDecoration(hintText: r'$'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (isLeaseholder)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _expenseReasonCtrls.remove(e.id)?.dispose();
                          _expenseAmountCtrls.remove(e.id)?.dispose();
                          draft.expenses.removeWhere((x) => x.id == e.id);
                        }),
                      ),
                  ]),
                ),
              if (isLeaseholder)
                OutlinedButton(
                  onPressed: () {
                    final id = 'e-${Random().nextInt(0xFFFF).toRadixString(36)}';
                    setState(() {
                      draft.expenses.add(TerminationExpense(id: id, reason: '', amount: 0));
                      _expenseReasonCtrls[id] = TextEditingController();
                      _expenseAmountCtrls[id] = TextEditingController();
                    });
                  },
                  child: const Text('+ Add expense'),
                ),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Combined bond'),
                Text(fmtAUD(totalBond), style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Less expenses'),
                Text('−${fmtAUD(totalExpenses)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Net refund to split', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(fmtAUD(netRefund), style: const TextStyle(fontWeight: FontWeight.w600, color: HomiesColors.accent)),
              ]),
            ]),
          ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Refund split', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              if (isLeaseholder)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Segment<String>(
                    options: const ['equal', 'custom'],
                    value: draft.splitMode,
                    labelFor: (v) => v[0].toUpperCase() + v.substring(1),
                    onChanged: (v) => setState(() => draft.splitMode = v),
                  ),
                ),
              const SizedBox(height: 8),
              for (final u in housemates)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Avatar.sm(u),
                    const SizedBox(width: 8),
                    Expanded(child: Text(u.name, style: const TextStyle(fontSize: 13))),
                    if (draft.splitMode == 'custom' && isLeaseholder)
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _customCtrls.putIfAbsent(u.id, () => TextEditingController(text: draft.customShares[u.id]?.toStringAsFixed(2) ?? '')),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(isDense: true),
                        ),
                      )
                    else
                      Text(fmtAUD(shares[u.id] ?? 0), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                ),
            ]),
          ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _notesCtrl,
                maxLines: 4,
                enabled: isLeaseholder,
                decoration: const InputDecoration(hintText: 'Agent timeline, key handover, forwarding addresses.'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
