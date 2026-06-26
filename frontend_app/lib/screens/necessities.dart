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
  String split = 'equal';
  late List<String> participants = [];
  final Map<String, TextEditingController> pctCtrls = {};
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    participants = HomiesScope.of(context).activeHousemates.map((u) => u.id).toList();
  }

  @override
  void dispose() {
    itemCtrl.dispose();
    amountCtrl.dispose();
    for (final c in pctCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _amount => double.tryParse(amountCtrl.text) ?? 0;

  /// Per-person owed amounts for the purchase being composed.
  Map<String, double> _previewShares() {
    final total = _amount;
    if (mode == 'individual') {
      final cu = HomiesScope.of(context).currentUser!;
      return {cu.id: total};
    }
    if (participants.isEmpty) return {};
    if (split == 'percentage') {
      return {
        for (final id in participants)
          id: ((total * (double.tryParse(pctCtrls[id]?.text ?? '0') ?? 0) / 100) * 100).round() / 100,
      };
    }
    final arr = equalSplit(total, participants.length);
    return {for (var i = 0; i < participants.length; i++) participants[i]: arr[i]};
  }

  void _add(HomiesState state) {
    final cu = state.currentUser!;
    if (mode == 'individual') {
      state.mutate(() {
        state.personalExpenses.add(PersonalExpense(
          id: 'pe-${DateTime.now().millisecondsSinceEpoch}',
          userId: cu.id,
          category: 'necessity',
          title: itemCtrl.text.trim(),
          amount: _amount,
          date: todayIso(),
        ));
      });
      itemCtrl.clear();
      amountCtrl.clear();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to your personal spending')),
      );
      return;
    }
    final shares = _previewShares();
    // The buyer fronted the money, so their own share is recorded as paid.
    final paidBy = <String, bool>{};
    final payments = <String, Payment>{};
    if (shares.containsKey(cu.id)) {
      paidBy[cu.id] = true;
      payments[cu.id] = Payment(
        payerId: cu.id,
        payerName: cu.name,
        at: DateTime.now().toIso8601String(),
        amount: shares[cu.id] ?? 0,
      );
    }
    state.mutate(() {
      state.necessities.insert(
        0,
        Necessity(
          id: 'n-${Random().nextInt(0xFFFF).toRadixString(36)}',
          item: itemCtrl.text.trim(),
          amount: _amount,
          mode: 'shared',
          payer: cu.id,
          date: todayIso(),
          split: split,
          participants: shares.keys.toList(),
          shares: shares,
          paidBy: paidBy,
          payments: payments,
        ),
      );
    });
    itemCtrl.clear();
    amountCtrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final hms = state.activeHousemates;
    final shared = state.necessities.where((n) => n.mode == 'shared');
    final loggedTotal = state.necessities.fold<double>(0, (s, n) => s + n.amount);
    // What's still owed back to whoever bought shared goods.
    final outstanding = shared.fold<double>(0, (sum, n) {
      return sum +
          n.shares.entries.where((e) => e.key != n.payer && n.paidBy[e.key] != true).fold<double>(0, (a, e) => a + e.value);
    });

    final preview = _previewShares();
    final previewTotal = preview.values.fold<double>(0, (a, b) => a + b);
    final pctSum = participants.fold<double>(0, (a, id) => a + (double.tryParse(pctCtrls[id]?.text ?? '0') ?? 0));
    final canAdd = itemCtrl.text.trim().isNotEmpty &&
        amountCtrl.text.trim().isNotEmpty &&
        (mode == 'individual' || participants.isNotEmpty);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PageHead(
            title: 'Necessities',
            subtitle: 'TP, hand soap, bin liners. The buyer picks how it splits and tracks who’s paid them back.',
          ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Log a purchase', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const FieldLabel('Item'),
              TextField(
                controller: itemCtrl,
                decoration: const InputDecoration(hintText: 'Toilet paper (24-pack)'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const FieldLabel('Amount you paid'),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const FieldLabel('Who is this for?'),
                    Segment<String>(
                      options: const ['shared', 'individual'],
                      value: mode,
                      labelFor: (v) => v == 'shared' ? 'Shared' : 'Just me',
                      onChanged: (v) => setState(() => mode = v),
                    ),
                  ]),
                ),
              ]),
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
                        'Saved to your personal spending only — not shared with housemates.',
                        style: TextStyle(fontSize: 12, color: HomiesColors.accentStrong),
                      ),
                    ),
                  ]),
                ),
              ],
              if (mode == 'shared') ...[
                const SizedBox(height: 10),
                const FieldLabel('Divide between'),
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
                const FieldLabel('Split'),
                Segment<String>(
                  options: const ['equal', 'percentage'],
                  value: split,
                  labelFor: (v) => v == 'equal' ? 'Equally' : 'By percentage',
                  onChanged: (v) => setState(() {
                    split = v;
                    if (v == 'percentage') {
                      for (final id in participants) {
                        pctCtrls.putIfAbsent(id, () => TextEditingController());
                      }
                    }
                  }),
                ),
                if (split == 'percentage') ...[
                  const SizedBox(height: 10),
                  const FieldLabel('Per-person %'),
                  for (final id in participants)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Avatar.sm(state.findUser(id)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(state.findUser(id)?.name ?? '—', style: const TextStyle(fontSize: 13))),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: pctCtrls.putIfAbsent(id, () => TextEditingController()),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(isDense: true, suffixText: '%'),
                          ),
                        ),
                      ]),
                    ),
                  if ((pctSum - 100).abs() > 0.5)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: HomiesChip('Percentages add up to ${pctSum.toStringAsFixed(0)}% (should be 100%)', tone: ChipTone.warn),
                    ),
                ],
                if (preview.isNotEmpty && _amount > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: HomiesColors.surface2, borderRadius: BorderRadius.circular(10)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Text('PREVIEW',
                          style: TextStyle(fontSize: 11, color: HomiesColors.textDim, letterSpacing: 0.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      for (final entry in preview.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(state.findUser(entry.key)?.name ?? '—', style: const TextStyle(fontSize: 12)),
                            Text(fmtAUD(entry.value), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      if ((previewTotal - _amount).abs() > 0.05)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: HomiesChip("Split (${fmtAUD(previewTotal)}) doesn't match ${fmtAUD(_amount)}", tone: ChipTone.warn),
                        ),
                    ]),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              ElevatedButton(onPressed: canAdd ? () => _add(state) : null, child: const Text('Add purchase')),
            ]),
          ),
          HomiesCard(
            child: StatRow(tiles: [
              StatTile(label: 'Logged total', value: fmtAUD(loggedTotal)),
              StatTile(label: 'Owed to buyers', value: fmtAUD(outstanding)),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 4),
            child: Text('Recent', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          if (state.necessities.isEmpty)
            const EmptyState(title: 'Nothing logged yet', body: 'Add a shared purchase and pick how it splits.'),
          for (final n in state.necessities) _NecessityCard(necessity: n),
        ]),
      ),
    );
  }
}

class _NecessityCard extends StatelessWidget {
  final Necessity necessity;
  const _NecessityCard({required this.necessity});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final n = necessity;
    final buyer = state.findUser(n.payer);
    final isShared = n.mode == 'shared';
    final owers = n.shares.entries.where((e) => e.key != n.payer).toList();
    final settled = owers.every((e) => n.paidBy[e.key] == true);

    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar.sm(buyer),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(n.item, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                HomiesChip(isShared ? (n.split == 'percentage' ? 'By %' : 'Equal') : 'Just me',
                    tone: isShared ? ChipTone.accent : ChipTone.neutral),
                if (isShared && owers.isNotEmpty) HomiesChip(settled ? 'All settled' : 'Owing', tone: settled ? ChipTone.ok : ChipTone.warn),
              ]),
              const SizedBox(height: 2),
              Text('${buyer?.name ?? '—'} bought · ${fmtDate(n.date)}',
                  style: const TextStyle(color: HomiesColors.textDim, fontSize: 11)),
            ]),
          ),
          Text(fmtAUD(n.amount), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        if (isShared && owers.isNotEmpty) ...[
          const Divider(),
          for (final e in owers) _OwerRow(necessity: n, userId: e.key, amount: e.value, cu: cu),
        ],
      ]),
    );
  }
}

class _OwerRow extends StatelessWidget {
  final Necessity necessity;
  final String userId;
  final double amount;
  final User cu;
  const _OwerRow({required this.necessity, required this.userId, required this.amount, required this.cu});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final user = state.findUser(userId);
    if (user == null) return const SizedBox.shrink();
    final n = necessity;
    final paid = n.paidBy[userId] == true;
    final pay = n.payments[userId];
    // Whoever posted (the buyer) marks reimbursements; the person themselves
    // or a leaseholder can too.
    final canMark = cu.id == n.payer || cu.id == userId || cu.role == 'leaseholder';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: paid ? HomiesColors.okSoft : HomiesColors.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Avatar.sm(user),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${user.name}${userId == cu.id ? ' (you)' : ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            Text('owes ${fmtAUD(amount)}', style: const TextStyle(color: HomiesColors.textDim, fontSize: 11)),
            if (paid && pay != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  const Icon(Icons.lock_outline, size: 11, color: HomiesColors.ok),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      'Paid back by ${pay.payerName} · ${fmtDateShort(pay.at)}'
                      '${pay.confirmedBy != null ? ' · marked by ${pay.confirmedBy}' : ''}',
                      style: const TextStyle(color: HomiesColors.ok, fontSize: 10.5, fontWeight: FontWeight.w500),
                      maxLines: 2,
                    ),
                  ),
                ]),
              ),
          ]),
        ),
        if (paid)
          Row(mainAxisSize: MainAxisSize.min, children: [
            const HomiesChip('✓ Paid', tone: ChipTone.ok),
            if (canMark)
              IconButton(
                tooltip: 'Undo payment record',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.undo, size: 16, color: HomiesColors.textDim),
                onPressed: () => _undo(context, state),
              ),
          ])
        else
          OutlinedButton(
            onPressed: canMark ? () => _markPaid(context, state, user) : null,
            child: const Text('Mark paid', style: TextStyle(fontSize: 12)),
          ),
      ]),
    );
  }

  Future<void> _markPaid(BuildContext context, HomiesState state, User user) async {
    final n = necessity;
    final byPoster = cu.id == n.payer && cu.id != userId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save payment record'),
        content: Text(
          'Mark ${user.name == cu.name ? 'your' : "${user.name}'s"} ${fmtAUD(amount)} for "${n.item}" as paid back?\n\n'
          'It\'s saved under ${user.name}\'s name with today\'s date'
          '${byPoster ? ', marked by ${cu.name}' : ''} — so the history is clear.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm & save')),
        ],
      ),
    );
    if (ok != true) return;
    state.mutate(() {
      n.paidBy[userId] = true;
      n.payments[userId] = Payment(
        payerId: userId,
        payerName: user.name,
        confirmedBy: cu.id == userId ? null : cu.name,
        at: DateTime.now().toIso8601String(),
        amount: amount,
      );
    });
  }

  Future<void> _undo(BuildContext context, HomiesState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: const Text('Undo this payment? The saved record will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Undo', style: TextStyle(color: HomiesColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    state.mutate(() {
      necessity.paidBy[userId] = false;
      necessity.payments.remove(userId);
    });
  }
}
