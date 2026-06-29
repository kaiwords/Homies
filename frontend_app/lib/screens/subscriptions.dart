import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/file_picker_button.dart';
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
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
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
                      Text(
                        '${fmtAUD(s.amount)} / ${s.cadence} · paid by ${state.findUser(s.payer)?.name ?? '—'}',
                        style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
                      ),
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
                  _SubShareRow(sub: s, userId: id, cu: cu),
                const SizedBox(height: 8),
                if (s.receipt != null) ...[
                  const Text('Receipt', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: HomiesColors.textDim)),
                  AttachmentTile(value: s.receipt!, compact: true),
                  const SizedBox(height: 4),
                ],
                OutlinedButton.icon(
                  onPressed: () => _openReceiptSheet(context, state, s),
                  icon: const Icon(Icons.receipt_outlined, size: 14),
                  label: Text(
                    s.receipt == null ? 'Attach receipt' : 'Replace receipt',
                    style: const TextStyle(fontSize: 12),
                  ),
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

  void _openReceiptSheet(BuildContext context, HomiesState state, Subscription s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Attach receipt', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 10),
          FilePickerButton(
            value: s.receipt,
            onChanged: (f) {
              state.mutate(() => s.receipt = f);
              Navigator.pop(context);
            },
            label: 'Choose image or PDF',
          ),
          if (s.receipt != null)
            TextButton(
              onPressed: () {
                state.mutate(() => s.receipt = null);
                Navigator.pop(context);
              },
              child: const Text('Remove receipt', style: TextStyle(color: HomiesColors.danger)),
            ),
        ]),
      ),
    );
  }
}

class _SubShareRow extends StatelessWidget {
  final Subscription sub;
  final String userId;
  final User cu;

  const _SubShareRow({required this.sub, required this.userId, required this.cu});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final user = state.findUser(userId);
    if (user == null) return const SizedBox.shrink();

    final isPayer = userId == sub.payer;
    final paid = isPayer || sub.paidBy[userId] == true;
    final pay = sub.payments[userId];
    final isYou = userId == cu.id;
    final canMark = cu.id == sub.payer || cu.role == 'leaseholder' || isYou;

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
            Text(
              '${user.name}${isYou ? ' (you)' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            Text(
              fmtAUD(sub.shares[userId] ?? 0),
              style: const TextStyle(color: HomiesColors.textDim, fontSize: 11),
            ),
            if (isPayer)
              const Text(
                'Subscription payer',
                style: TextStyle(color: HomiesColors.ok, fontSize: 10.5, fontWeight: FontWeight.w500),
              )
            else if (paid && pay != null)
              Row(children: [
                const Icon(Icons.lock_outline, size: 11, color: HomiesColors.ok),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    'Paid ${fmtDateShort(pay.at)}${pay.confirmedBy != null ? ' · confirmed by ${pay.confirmedBy}' : ''}',
                    style: const TextStyle(color: HomiesColors.ok, fontSize: 10.5, fontWeight: FontWeight.w500),
                    maxLines: 2,
                  ),
                ),
              ]),
          ]),
        ),
        if (isPayer)
          const HomiesChip('Payer', tone: ChipTone.accent)
        else if (paid)
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
    final isYou = userId == cu.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save payment record'),
        content: Text(
          'Mark ${isYou ? 'your' : "${user.name}'s"} share of ${fmtAUD(sub.shares[userId] ?? 0)} as paid?\n\n'
          'This will be saved under ${user.name}\'s name with today\'s date'
          '${isYou ? '' : ', confirmed by ${cu.name}'} — so there\'s a clear record later.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm & save')),
        ],
      ),
    );
    if (ok != true) return;
    state.mutate(() {
      sub.paidBy[userId] = true;
      sub.payments[userId] = Payment(
        payerId: userId,
        payerName: user.name,
        confirmedBy: cu.id == userId ? null : cu.name,
        at: DateTime.now().toIso8601String(),
        amount: sub.shares[userId] ?? 0,
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
      sub.paidBy[userId] = false;
      sub.payments.remove(userId);
    });
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
  String _mode = 'shared'; // 'shared' | 'individual' — only for new subscriptions

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
    if (_mode == 'individual' && widget.existing == null) {
      final uid = state.currentUser!.id;
      state.mutate(() {
        state.personalExpenses.add(PersonalExpense(
          id: 'pe-${DateTime.now().millisecondsSinceEpoch}',
          userId: uid,
          category: 'subscription',
          title: nameCtrl.text.trim(),
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
                const FieldLabel('Frequency'),
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
            if (!isEdit) ...[
              const SizedBox(height: 10),
              const FieldLabel('Who is this for?'),
              Segment<String>(
                options: const ['shared', 'individual'],
                value: _mode,
                labelFor: (v) => v == 'shared' ? 'Shared with housemates' : 'Just me',
                onChanged: (v) => setState(() => _mode = v),
              ),
              if (_mode == 'individual') ...[
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
            ],
            if (_mode == 'shared' || isEdit) ...[
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
            ],
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: nameCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty ||
                           (_mode == 'shared' && participants.isEmpty) ? null : _save,
                child: Text(isEdit ? 'Save changes' : 'Add'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
