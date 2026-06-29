import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/file_picker_button.dart';
import '../widgets/ui_kit.dart';

IconData _billCategoryIcon(String category) {
  switch (category) {
    case 'utility':
      return Icons.bolt_outlined;
    case 'internet':
    case 'nbn':
      return Icons.wifi_outlined;
    case 'water':
      return Icons.water_drop_outlined;
    case 'gas':
      return Icons.local_fire_department_outlined;
    case 'maintenance':
      return Icons.build_outlined;
    default:
      return Icons.receipt_long_outlined;
  }
}

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;

    final pendingBills = state.bills.where((b) => b.status != 'settled').toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final sharedGroceries = state.groceries.where((g) => g.mode == 'shared').toList();
    final sharedNecessities = state.necessities.where((n) => n.mode == 'shared').toList();

    final isEmpty = pendingBills.isEmpty &&
        state.subscriptions.isEmpty &&
        sharedGroceries.isEmpty &&
        sharedNecessities.isEmpty;

    final active = state.activeHousemates;
    final perPersonRent = active.isEmpty ? 0.0 : state.property.rentAmount / active.length;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'Finance',
            subtitle: 'All shared expenses — rent, bills, subscriptions, groceries and necessities.',
            action: OutlinedButton.icon(
              onPressed: () => context.go('/app/my-spending'),
              icon: const Icon(Icons.bar_chart_outlined, size: 16),
              label: const Text('My spending'),
            ),
          ),

          _RentSummaryCard(perPersonRent: perPersonRent),

          if (isEmpty) const EmptyState(title: 'No other shared expenses yet'),

          if (pendingBills.isNotEmpty) ...[
            _SectionHeader('Bills', pendingBills.length),
            for (final b in pendingBills)
              _FinanceRow(
                icon: _billCategoryIcon(b.category),
                title: b.title,
                subtitle: 'Due ${fmtDate(b.dueDate)}',
                amount: b.amount,
                paidCount: b.paidBy.values.where((v) => v).length,
                totalCount: b.shares.length,
                onTap: () => _showSheet(
                  context,
                  title: b.title,
                  subtitle: '${fmtAUD(b.amount)} total',
                  dueDate: b.dueDate,
                  onUpdateDueDate: (d) => state.mutate(() => b.dueDate = d),
                  participants: b.shares.keys.toList(),
                  shares: b.shares,
                  paidBy: b.paidBy,
                  payments: b.payments,
                  payer: b.issuedBy,
                  cu: cu,
                  state: state,
                  onMarkPaid: (uid, user) => state.mutate(() {
                    b.paidBy[uid] = true;
                    b.payments[uid] = Payment(
                      payerId: uid,
                      payerName: user.name,
                      confirmedBy: cu.id == uid ? null : cu.name,
                      at: DateTime.now().toIso8601String(),
                      amount: b.shares[uid] ?? 0,
                    );
                    b.status = b.shares.keys.every((id) => b.paidBy[id] == true) ? 'settled' : 'pending';
                  }),
                  onUndo: (uid) => state.mutate(() {
                    b.paidBy[uid] = false;
                    b.payments.remove(uid);
                    b.status = 'pending';
                  }),
                ),
              ),
          ],

          if (state.subscriptions.isNotEmpty) ...[
            _SectionHeader('Subscriptions', state.subscriptions.length),
            for (final s in state.subscriptions)
              _FinanceRow(
                icon: Icons.subscriptions_outlined,
                title: s.name,
                subtitle: '${fmtAUD(s.amount)} / ${s.cadence}',
                amount: s.amount,
                paidCount: _subPaidCount(s),
                totalCount: s.participants.length,
                onTap: () => _showSheet(
                  context,
                  title: s.name,
                  subtitle: '${fmtAUD(s.amount)} / ${s.cadence}',
                  participants: s.participants,
                  shares: s.shares,
                  paidBy: s.paidBy,
                  payments: s.payments,
                  payer: s.payer,
                  cu: cu,
                  state: state,
                  onMarkPaid: (uid, user) => state.mutate(() {
                    s.paidBy[uid] = true;
                    s.payments[uid] = Payment(
                      payerId: uid,
                      payerName: user.name,
                      confirmedBy: cu.id == uid ? null : cu.name,
                      at: DateTime.now().toIso8601String(),
                      amount: s.shares[uid] ?? 0,
                    );
                  }),
                  onUndo: (uid) => state.mutate(() {
                    s.paidBy[uid] = false;
                    s.payments.remove(uid);
                  }),
                ),
              ),
          ],

          if (sharedGroceries.isNotEmpty) ...[
            _SectionHeader('Groceries', sharedGroceries.length),
            for (final g in sharedGroceries)
              _FinanceRow(
                icon: Icons.shopping_cart_outlined,
                title: g.title,
                subtitle: '${fmtDate(g.date)} · paid by ${state.findUser(g.payer)?.name ?? '—'}',
                amount: g.total,
                paidCount: g.paidBy.values.where((v) => v).length + 1,
                totalCount: g.shares.length,
                onTap: () => _showSheet(
                  context,
                  title: g.title,
                  subtitle: '${fmtDate(g.date)} · ${fmtAUD(g.total)} total',
                  participants: g.shares.keys.toList(),
                  shares: g.shares,
                  paidBy: g.paidBy,
                  payments: g.payments,
                  payer: g.payer,
                  cu: cu,
                  state: state,
                  onMarkPaid: (uid, user) => state.mutate(() {
                    g.paidBy[uid] = true;
                    g.payments[uid] = Payment(
                      payerId: uid,
                      payerName: user.name,
                      confirmedBy: cu.id == uid ? null : cu.name,
                      at: DateTime.now().toIso8601String(),
                      amount: g.shares[uid] ?? 0,
                    );
                  }),
                  onUndo: (uid) => state.mutate(() {
                    g.paidBy[uid] = false;
                    g.payments.remove(uid);
                  }),
                ),
              ),
          ],

          if (sharedNecessities.isNotEmpty) ...[
            _SectionHeader('Necessities', sharedNecessities.length),
            for (final n in sharedNecessities)
              _FinanceRow(
                icon: Icons.cleaning_services_outlined,
                title: n.item,
                subtitle: '${fmtDate(n.date)} · paid by ${state.findUser(n.payer)?.name ?? '—'}',
                amount: n.amount,
                paidCount: n.paidBy.values.where((v) => v).length + 1,
                totalCount: n.shares.length,
                onTap: () => _showSheet(
                  context,
                  title: n.item,
                  subtitle: '${fmtDate(n.date)} · ${fmtAUD(n.amount)} total',
                  participants: n.participants,
                  shares: n.shares,
                  paidBy: n.paidBy,
                  payments: n.payments,
                  payer: n.payer,
                  cu: cu,
                  state: state,
                  onMarkPaid: (uid, user) => state.mutate(() {
                    n.paidBy[uid] = true;
                    n.payments[uid] = Payment(
                      payerId: uid,
                      payerName: user.name,
                      confirmedBy: cu.id == uid ? null : cu.name,
                      at: DateTime.now().toIso8601String(),
                      amount: n.shares[uid] ?? 0,
                    );
                  }),
                  onUndo: (uid) => state.mutate(() {
                    n.paidBy[uid] = false;
                    n.payments.remove(uid);
                  }),
                ),
              ),
          ],
        ]),
      ),
    );
  }

  int _subPaidCount(Subscription s) {
    int count = 1; // payer always counts as paid
    for (final id in s.participants) {
      if (id != s.payer && s.paidBy[id] == true) count++;
    }
    return count;
  }

  void _showSheet(
    BuildContext context, {
    required String title,
    required String subtitle,
    String? dueDate,
    void Function(String)? onUpdateDueDate,
    required List<String> participants,
    required Map<String, double> shares,
    required Map<String, bool> paidBy,
    required Map<String, Payment> payments,
    required String payer,
    required User cu,
    required HomiesState state,
    required void Function(String uid, User user) onMarkPaid,
    required void Function(String uid) onUndo,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentSheet(
        title: title,
        subtitle: subtitle,
        dueDate: dueDate,
        onUpdateDueDate: onUpdateDueDate,
        participants: participants,
        shares: shares,
        paidBy: paidBy,
        payments: payments,
        payer: payer,
        cu: cu,
        state: state,
        onMarkPaid: onMarkPaid,
        onUndo: onUndo,
      ),
    );
  }
}

class _RentSummaryCard extends StatefulWidget {
  final double perPersonRent;
  const _RentSummaryCard({required this.perPersonRent});

  @override
  State<_RentSummaryCard> createState() => _RentSummaryCardState();
}

class _RentSummaryCardState extends State<_RentSummaryCard> {
  bool _expanded = false;

  String? _nextDue(HomiesState state) {
    var d = state.property.rentStartDate;
    if (d == null || d.isEmpty) return null;
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day);
    var guard = 0;
    while (guard++ < 2000) {
      final parsed = parseIso(d);
      if (parsed == null) return d;
      if (!parsed.isBefore(cutoff)) return d;
      final next = addCadence(d, state.property.rentCadence, null);
      if (next == null || next == d) return d;
      d = next;
    }
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final nextDue = _nextDue(state);
    final shares = state.rentShares;
    final active = state.activeHousemates;
    final isLeaseholder = cu.role == 'leaseholder';

    // Determine if split is equal (within 1 cent tolerance per person)
    final equalAmount = active.isEmpty ? 0.0 : state.property.rentAmount / active.length;
    final hasCustomShares = shares.isNotEmpty;
    final isEqualSplit = !hasCustomShares ||
        shares.every((s) => (s.amount - equalAmount).abs() < 0.01);

    final periodStart = _currentPeriodStart(state);
    final periodPayments = periodStart != null
        ? state.rentPayments.where((p) => p.periodStart == periodStart).toList()
        : <RentPayment>[];

    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: HomiesColors.accentSoft, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: const Icon(Icons.home_outlined, size: 22, color: HomiesColors.accentStrong),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(fmtAUD(state.property.rentAmount),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(width: 6),
                HomiesChip(cadenceLabel(state.property.rentCadence), tone: ChipTone.accent),
              ]),
              Text(
                'Rent${nextDue != null ? ' · next ${fmtRelative(nextDue)}' : ''}',
                style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
              ),
            ]),
          ),
          if (isLeaseholder) ...[
            IconButton(
              icon: const Icon(Icons.calendar_today_outlined, size: 18, color: HomiesColors.textDim),
              tooltip: 'Set rent schedule',
              onPressed: () => _openScheduleEditor(context, state),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: HomiesColors.textDim),
              tooltip: 'Edit rent shares',
              onPressed: () => _openShareEditor(context, state),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        const Divider(height: 1),

        // Tappable period row — always visible, toggles the housemate list
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              if (periodStart != null) ...[
                Expanded(
                  child: Text(
                    _periodLabel(periodStart, state.property.rentCadence),
                    style: const TextStyle(fontSize: 12, color: HomiesColors.textDim, fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '${periodPayments.length}/${active.length} paid',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: periodPayments.length >= active.length
                        ? HomiesColors.ok
                        : periodPayments.isNotEmpty
                            ? HomiesColors.warn
                            : HomiesColors.textFaint,
                  ),
                ),
                const SizedBox(width: 4),
              ] else ...[
                Expanded(child: Text('No rent period set', style: TextStyle(fontSize: 12, color: HomiesColors.textFaint))),
                if (isLeaseholder)
                  TextButton(
                    onPressed: () => _openScheduleEditor(context, state),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Set up', style: TextStyle(fontSize: 12)),
                  ),
              ],
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more, size: 18, color: HomiesColors.textDim),
              ),
            ]),
          ),
        ),

        // Collapsible: per-person rows + notes + history
        if (_expanded) ...[
          const SizedBox(height: 8),

          for (final u in active)
            _RentPayRow(
              user: u,
              amount: _amountFor(state, u, equalAmount),
              features: _featuresFor(state, u),
              reason: _reasonFor(state, u),
              payment: periodPayments.firstWhereOrNull((p) => p.userId == u.id),
              isYou: u.id == cu.id,
              canMark: isLeaseholder || u.id == cu.id,
              cu: cu,
              onMarkPaid: periodStart == null
                  ? null
                  : (proof) => state.mutate(() {
                        state.rentPayments.add(RentPayment(
                          id: 'rp_${DateTime.now().millisecondsSinceEpoch}',
                          userId: u.id,
                          userName: u.name,
                          amount: _amountFor(state, u, equalAmount),
                          paidAt: DateTime.now().toIso8601String(),
                          periodStart: periodStart,
                          confirmedBy: cu.id != u.id ? cu.name : null,
                          proof: proof,
                        ));
                      }),
              onUndo: periodStart == null
                  ? null
                  : () => state.mutate(() {
                        state.rentPayments.removeWhere(
                          (p) => p.userId == u.id && p.periodStart == periodStart,
                        );
                      }),
            ),

          if (!hasCustomShares) ...[
            const SizedBox(height: 4),
            const Text('Equal split — each person pays the same amount.',
                style: TextStyle(color: HomiesColors.textFaint, fontSize: 11)),
          ] else if (!isEqualSplit && state.property.rentShareExplanation?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: HomiesColors.surface2, borderRadius: BorderRadius.circular(8)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline, size: 14, color: HomiesColors.textDim),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    state.property.rentShareExplanation!,
                    style: const TextStyle(fontSize: 12, color: HomiesColors.textDim),
                  ),
                ),
              ]),
            ),
          ],

          if (state.rentPayments.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            TextButton.icon(
              icon: const Icon(Icons.history, size: 15),
              label: const Text('Payment history'),
              style: TextButton.styleFrom(
                foregroundColor: HomiesColors.textDim,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _showHistory(context, state),
            ),
          ],
        ],
      ]),
    );
  }

  // Returns the start date of the rent period that contains today.
  String? _currentPeriodStart(HomiesState state) {
    final startDate = state.property.rentStartDate;
    if (startDate == null || startDate.isEmpty) return null;
    final startParsed = parseIso(startDate);
    if (startParsed == null) return null;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    if (!startParsed.isBefore(todayDate)) return startDate;
    var current = startDate;
    var guard = 0;
    while (guard++ < 5000) {
      final next = addCadence(current, state.property.rentCadence, null);
      if (next == null) break;
      final nd = parseIso(next);
      if (nd == null) break;
      if (!DateTime(nd.year, nd.month, nd.day).isAfter(todayDate)) {
        current = next;
      } else {
        break;
      }
    }
    return current;
  }

  String _periodLabel(String periodStart, String cadence) {
    final d = parseIso(periodStart);
    if (d == null) return fmtDateShort(periodStart);
    switch (cadence) {
      case 'weekly':
      case 'fortnightly':
        final next = addCadence(periodStart, cadence, null);
        final end = next != null ? parseIso(next)?.subtract(const Duration(days: 1)) : null;
        return end != null
            ? '${fmtDateShort(periodStart)} – ${fmtDateShort(end.toIso8601String())}'
            : 'From ${fmtDateShort(periodStart)}';
      case 'monthly':
        const months = ['', 'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'];
        return '${months[d.month]} ${d.year}';
      default:
        return 'From ${fmtDateShort(periodStart)}';
    }
  }

  double _amountFor(HomiesState state, User u, double equalAmount) {
    final rs = state.rentShares.firstWhereOrNull((s) => s.userId == u.id);
    return rs?.amount ?? equalAmount;
  }

  String? _reasonFor(HomiesState state, User u) {
    final rs = state.rentShares.firstWhereOrNull((s) => s.userId == u.id);
    return rs?.reason?.isNotEmpty == true ? rs!.reason : null;
  }

  List<String> _featuresFor(HomiesState state, User u) {
    final rs = state.rentShares.firstWhereOrNull((s) => s.userId == u.id);
    if (rs == null) return [];
    return [
      if (rs.hasParking) 'Parking',
      if (rs.hasBalcony) 'Balcony',
      if (rs.hasPrivateWashroom) 'Washroom',
    ];
  }

  void _showHistory(BuildContext context, HomiesState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RentHistorySheet(state: state),
    );
  }

  void _openScheduleEditor(BuildContext context, HomiesState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RentScheduleSheet(state: state),
    );
  }

  void _openShareEditor(BuildContext context, HomiesState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RentShareEditorSheet(state: state),
    );
  }
}

// ─── Rent pay row ─────────────────────────────────────────────────────────────

class _RentPayRow extends StatelessWidget {
  final User user;
  final double amount;
  final List<String> features;
  final String? reason;
  final RentPayment? payment;
  final bool isYou;
  final bool canMark;
  final User cu;
  final void Function(Attachment? proof)? onMarkPaid;
  final VoidCallback? onUndo;

  const _RentPayRow({
    required this.user,
    required this.amount,
    required this.features,
    this.reason,
    this.payment,
    required this.isYou,
    required this.canMark,
    required this.cu,
    this.onMarkPaid,
    this.onUndo,
  });

  bool get _isPaid => payment != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _isPaid ? HomiesColors.okSoft : HomiesColors.surface2,
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
            if (features.isNotEmpty)
              Wrap(spacing: 4, children: [
                for (final f in features) HomiesChip(f, tone: ChipTone.accent),
              ]),
            if (reason != null)
              Text(reason!, style: const TextStyle(fontSize: 11, color: HomiesColors.textDim, height: 1.3)),
            if (_isPaid && payment != null) ...[
              Row(children: [
                const Icon(Icons.lock_outline, size: 11, color: HomiesColors.ok),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    '${fmtDateShort(payment!.paidAt)}${payment!.confirmedBy != null ? ' · ${payment!.confirmedBy}' : ''}',
                    style: const TextStyle(color: HomiesColors.ok, fontSize: 10.5),
                    maxLines: 1,
                  ),
                ),
              ]),
              if (payment!.proof != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: AttachmentTile(value: payment!.proof!, compact: true),
                ),
            ],
          ]),
        ),
        Text(fmtAUD(amount),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: _isPaid ? HomiesColors.ok : HomiesColors.text,
            )),
        const SizedBox(width: 6),
        if (_isPaid)
          Row(mainAxisSize: MainAxisSize.min, children: [
            const HomiesChip('✓ Paid', tone: ChipTone.ok),
            if (canMark && onUndo != null)
              IconButton(
                tooltip: 'Undo',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.undo, size: 16, color: HomiesColors.textDim),
                onPressed: () => _confirmUndo(context),
              ),
          ])
        else if (canMark && onMarkPaid != null)
          OutlinedButton(
            onPressed: () => _confirmMark(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Mark paid', style: TextStyle(fontSize: 11)),
          )
        else
          const SizedBox.shrink(),
      ]),
    );
  }

  Future<void> _confirmMark(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RentMarkPaidSheet(
        label: isYou ? 'your' : "${user.name}'s",
        amount: amount,
        onConfirm: (proof) => onMarkPaid?.call(proof),
      ),
    );
  }

  Future<void> _confirmUndo(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: const Text('Remove this rent payment record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: HomiesColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) onUndo?.call();
  }
}

// ─── Rent mark-paid sheet ─────────────────────────────────────────────────────

class _RentMarkPaidSheet extends StatefulWidget {
  final String label;
  final double amount;
  final void Function(Attachment? proof) onConfirm;
  const _RentMarkPaidSheet({required this.label, required this.amount, required this.onConfirm});

  @override
  State<_RentMarkPaidSheet> createState() => _RentMarkPaidSheetState();
}

class _RentMarkPaidSheetState extends State<_RentMarkPaidSheet> {
  Attachment? _proof;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          'Mark ${widget.label} rent paid',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          fmtAUD(widget.amount),
          style: const TextStyle(fontSize: 15, color: HomiesColors.textDim),
        ),
        const SizedBox(height: 20),
        const Text('Attach transfer proof (optional)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        FilePickerButton(
          value: _proof,
          onChanged: (f) => setState(() => _proof = f),
          allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
          label: _proof == null ? 'Upload screenshot or receipt' : 'Replace file',
        ),
        if (_proof != null) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => setState(() => _proof = null),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Remove proof', style: TextStyle(color: HomiesColors.danger, fontSize: 12)),
          ),
        ],
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onConfirm(_proof);
              },
              child: const Text('Confirm paid'),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─── Rent history sheet ───────────────────────────────────────────────────────

class _RentHistorySheet extends StatelessWidget {
  final HomiesState state;
  const _RentHistorySheet({required this.state});

  @override
  Widget build(BuildContext context) {
    // Group payments by periodStart, most recent first
    final byPeriod = <String, List<RentPayment>>{};
    for (final p in state.rentPayments) {
      (byPeriod[p.periodStart] ??= []).add(p);
    }
    final periods = byPeriod.keys.toList()..sort((a, b) => b.compareTo(a));

    final cadence = state.property.rentCadence;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: ListView(controller: ctrl, children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: HomiesColors.textFaint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text('Rent payment history',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('All recorded rent payments per period.',
              style: const TextStyle(color: HomiesColors.textDim, fontSize: 13)),
          const SizedBox(height: 12),
          for (final period in periods) ...[
            _PeriodGroup(
              period: period,
              cadence: cadence,
              payments: byPeriod[period]!,
              activeCount: state.activeHousemates.length,
            ),
            const SizedBox(height: 8),
          ],
        ]),
      ),
    );
  }
}

class _PeriodGroup extends StatelessWidget {
  final String period;
  final String cadence;
  final List<RentPayment> payments;
  final int activeCount;
  const _PeriodGroup({
    required this.period,
    required this.cadence,
    required this.payments,
    required this.activeCount,
  });

  String _label() {
    final d = parseIso(period);
    if (d == null) return fmtDateShort(period);
    switch (cadence) {
      case 'weekly':
      case 'fortnightly':
        final next = addCadence(period, cadence, null);
        final end = next != null ? parseIso(next)?.subtract(const Duration(days: 1)) : null;
        return end != null
            ? '${fmtDateShort(period)} – ${fmtDateShort(end.toIso8601String())}'
            : 'From ${fmtDateShort(period)}';
      case 'monthly':
        const months = ['', 'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'];
        return '${months[d.month]} ${d.year}';
      default:
        return 'From ${fmtDateShort(period)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPaid = payments.length >= activeCount;
    return Container(
      decoration: BoxDecoration(
        color: allPaid ? HomiesColors.okSoft : HomiesColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: allPaid
              ? HomiesColors.ok.withValues(alpha: 0.2)
              : HomiesColors.border,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(_label(),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          HomiesChip(
            '${payments.length}/$activeCount paid',
            tone: allPaid ? ChipTone.ok : ChipTone.warn,
          ),
        ]),
        const SizedBox(height: 6),
        for (final p in payments..sort((a, b) => a.paidAt.compareTo(b.paidAt)))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, size: 13, color: HomiesColors.ok),
              const SizedBox(width: 6),
              Expanded(
                child: Text(p.userName,
                    style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
              ),
              Text(fmtAUD(p.amount),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(fmtDateShort(p.paidAt),
                  style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint)),
            ]),
          ),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader(this.title, this.count);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text('$title · $count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      );
}

class _FinanceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double amount;
  final int paidCount;
  final int totalCount;
  final VoidCallback? onTap;

  const _FinanceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.paidCount,
    required this.totalCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final allPaid = paidCount >= totalCount;
    final somePaid = paidCount > 0 && !allPaid;

    return GestureDetector(
      onTap: onTap,
      child: HomiesCard(
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: allPaid ? HomiesColors.okSoft : HomiesColors.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: allPaid ? HomiesColors.ok : HomiesColors.textDim),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(subtitle, style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmtAUD(amount), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            if (totalCount > 1)
              Text(
                '$paidCount/$totalCount paid',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: allPaid ? HomiesColors.ok : somePaid ? HomiesColors.warn : HomiesColors.textDim,
                ),
              ),
          ]),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18, color: HomiesColors.textFaint),
          ],
        ]),
      ),
    );
  }
}

class _PaymentSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? dueDate;
  final void Function(String)? onUpdateDueDate;
  final List<String> participants;
  final Map<String, double> shares;
  final Map<String, bool> paidBy;
  final Map<String, Payment> payments;
  final String payer;
  final User cu;
  final HomiesState state;
  final void Function(String uid, User user) onMarkPaid;
  final void Function(String uid) onUndo;

  const _PaymentSheet({
    required this.title,
    required this.subtitle,
    this.dueDate,
    this.onUpdateDueDate,
    required this.participants,
    required this.shares,
    required this.paidBy,
    required this.payments,
    required this.payer,
    required this.cu,
    required this.state,
    required this.onMarkPaid,
    required this.onUndo,
  });

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late String? _dueDate;

  @override
  void initState() {
    super.initState();
    _dueDate = widget.dueDate;
  }

  Future<void> _pickDueDate() async {
    final picked = await pickDate(context, initial: parseIso(_dueDate));
    if (picked == null) return;
    final iso = toIso(picked)!;
    setState(() => _dueDate = iso);
    widget.onUpdateDueDate!(iso);
  }

  @override
  Widget build(BuildContext context) {
    final isPayer = widget.cu.id == widget.payer;
    final canEditDate = isPayer && widget.onUpdateDueDate != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: ListView(controller: ctrl, children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: HomiesColors.textFaint, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(widget.subtitle, style: const TextStyle(color: HomiesColors.textDim, fontSize: 13)),
          if (canEditDate) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDueDate,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: HomiesColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    _dueDate != null ? 'Due ${fmtDate(_dueDate)} · tap to change' : 'Set due date',
                    style: const TextStyle(color: HomiesColors.accent, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          for (final uid in widget.participants)
            _ShareRow(
              uid: uid,
              payer: widget.payer,
              billTitle: widget.title,
              shares: widget.shares,
              paidBy: widget.paidBy,
              payments: widget.payments,
              cu: widget.cu,
              state: widget.state,
              onMarkPaid: widget.onMarkPaid,
              onUndo: widget.onUndo,
            ),
        ]),
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  final String uid;
  final String payer;
  final String billTitle;
  final Map<String, double> shares;
  final Map<String, bool> paidBy;
  final Map<String, Payment> payments;
  final User cu;
  final HomiesState state;
  final void Function(String, User) onMarkPaid;
  final void Function(String) onUndo;

  const _ShareRow({
    required this.uid,
    required this.payer,
    required this.billTitle,
    required this.shares,
    required this.paidBy,
    required this.payments,
    required this.cu,
    required this.state,
    required this.onMarkPaid,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final user = state.findUser(uid);
    if (user == null) return const SizedBox.shrink();

    final isPayer = uid == payer;
    final paid = isPayer || paidBy[uid] == true;
    final pay = payments[uid];
    final isYou = uid == cu.id;
    final canMark = cu.id == payer || cu.role == 'leaseholder' || isYou;

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
              isPayer ? 'Paid upfront' : fmtAUD(shares[uid] ?? 0),
              style: const TextStyle(color: HomiesColors.textDim, fontSize: 11),
            ),
            if (!isPayer && paid && pay != null)
              Row(children: [
                const Icon(Icons.lock_outline, size: 11, color: HomiesColors.ok),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    '${fmtDateShort(pay.at)}${pay.confirmedBy != null ? ' · ${pay.confirmedBy}' : ''}',
                    style: const TextStyle(color: HomiesColors.ok, fontSize: 10.5),
                    maxLines: 1,
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
                tooltip: 'Undo',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.undo, size: 16, color: HomiesColors.textDim),
                onPressed: () => _undo(context),
              ),
          ])
        else
          Row(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton(
              onPressed: canMark ? () => _markPaid(context, user) : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Mark paid', style: TextStyle(fontSize: 11)),
            ),
            if (cu.id == payer || cu.role == 'leaseholder') ...[
              const SizedBox(width: 4),
              OutlinedButton(
                onPressed: () => _requestPayment(context, user),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Request', style: TextStyle(fontSize: 11)),
              ),
            ],
          ]),
      ]),
    );
  }

  Future<void> _markPaid(BuildContext context, User user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save payment record'),
        content: Text(
          'Mark ${uid == cu.id ? 'your' : "${user.name}'s"} share of ${fmtAUD(shares[uid] ?? 0)} as paid?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok == true) onMarkPaid(uid, user);
  }

  Future<void> _undo(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: const Text('Undo this payment? The saved record will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Undo', style: TextStyle(color: HomiesColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) onUndo(uid);
  }

  void _requestPayment(BuildContext context, User user) {
    final title = 'Payment request';
    final body = '${cu.name} is requesting your share of $billTitle — ${fmtAUD(shares[uid] ?? 0)}.';
    final notif = AppNotification(
      id: 'pr_${DateTime.now().millisecondsSinceEpoch}',
      kind: 'payment_request',
      title: title,
      body: body,
      at: DateTime.now().toIso8601String(),
      forUserId: uid,
    );
    state.addAppNotification(notif);
    NotificationService.showNow(5000 + state.appNotifications.length, title, body);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment reminder sent to ${user.name} ✓')),
    );
  }
}

class _RentShareEditorSheet extends StatefulWidget {
  final HomiesState state;
  const _RentShareEditorSheet({required this.state});

  @override
  State<_RentShareEditorSheet> createState() => _RentShareEditorSheetState();
}

class _RentShareEditorSheetState extends State<_RentShareEditorSheet> {
  late List<_ShareEntry> _entries;
  late TextEditingController _explanationCtrl;

  @override
  void initState() {
    super.initState();
    final active = widget.state.activeHousemates;
    final existingShares = widget.state.rentShares;
    final totalRent = widget.state.property.rentAmount;
    final equalAmount = active.isEmpty ? 0.0 : totalRent / active.length;

    _entries = active.map((u) {
      final s = existingShares.firstWhereOrNull((x) => x.userId == u.id);
      return _ShareEntry(
        user: u,
        amountCtrl: TextEditingController(
          text: (s?.amount ?? equalAmount).toStringAsFixed(0),
        ),
        reasonCtrl: TextEditingController(text: s?.reason ?? ''),
        hasParking: s?.hasParking ?? false,
        hasBalcony: s?.hasBalcony ?? false,
        hasPrivateWashroom: s?.hasPrivateWashroom ?? false,
      );
    }).toList();

    _explanationCtrl = TextEditingController(
      text: widget.state.property.rentShareExplanation ?? '',
    );
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.amountCtrl.dispose();
      e.reasonCtrl.dispose();
    }
    _explanationCtrl.dispose();
    super.dispose();
  }

  double get _total => widget.state.property.rentAmount;

  double get _allocated =>
      _entries.fold(0.0, (sum, e) => sum + (double.tryParse(e.amountCtrl.text.trim()) ?? 0));

  bool get _isEqual {
    if (_entries.isEmpty) return true;
    final equal = _total / _entries.length;
    return _entries.every((e) => ((double.tryParse(e.amountCtrl.text.trim()) ?? 0) - equal).abs() < 0.01);
  }

  bool get _allFeaturesJustify {
    // Every person paying more than equal share must have a feature or a reason
    if (_entries.isEmpty) return true;
    final equal = _total / _entries.length;
    for (final e in _entries) {
      final amt = double.tryParse(e.amountCtrl.text.trim()) ?? 0;
      if (amt > equal + 0.01 && !e.hasParking && !e.hasBalcony && !e.hasPrivateWashroom && e.reasonCtrl.text.trim().isEmpty) return false;
    }
    return true;
  }

  bool get _needsExplanation => !_isEqual && !_allFeaturesJustify;

  bool get _canSave {
    final diff = (_allocated - _total).abs();
    if (diff > 0.5) return false;
    if (_needsExplanation && _explanationCtrl.text.trim().isEmpty) return false;
    return true;
  }

  void _equalSplit() {
    if (_entries.isEmpty) return;
    final amount = (_total / _entries.length).toStringAsFixed(0);
    setState(() {
      for (final e in _entries) {
        e.amountCtrl.text = amount;
      }
    });
  }

  void _save() {
    final state = widget.state;
    state.mutate(() {
      state.rentShares = _entries.map((e) => RentShare(
        userId: e.user.id,
        amount: double.tryParse(e.amountCtrl.text.trim()) ?? 0,
        hasParking: e.hasParking,
        hasBalcony: e.hasBalcony,
        hasPrivateWashroom: e.hasPrivateWashroom,
        reason: e.reasonCtrl.text.trim().isEmpty ? null : e.reasonCtrl.text.trim(),
      )).toList();
      state.property.rentShareExplanation =
          _needsExplanation ? _explanationCtrl.text.trim() : null;
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rent breakdown saved ✓')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diff = (_allocated - _total).abs();
    final unbalanced = diff > 0.5;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 28),
        child: ListView(controller: ctrl, children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: HomiesColors.textFaint, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(children: [
            const Expanded(
              child: Text('Set rent breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            TextButton(onPressed: _equalSplit, child: const Text('Equal split')),
          ]),
          Text(
            'Total rent: ${fmtAUD(_total)} ${cadenceLabel(widget.state.property.rentCadence)}',
            style: const TextStyle(color: HomiesColors.textDim, fontSize: 13),
          ),
          if (unbalanced)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Allocated ${fmtAUD(_allocated)} — difference of ${fmtAUD(diff)} from total.',
                style: const TextStyle(color: HomiesColors.danger, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          for (final e in _entries) _EntryCard(entry: e, onChanged: () => setState(() {})),
          const SizedBox(height: 8),
          if (_needsExplanation) ...[
            const FieldLabel('Explanation (required for unequal split without room features)'),
            TextField(
              controller: _explanationCtrl,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'e.g. Room size difference — master bedroom is larger.',
              ),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton(
            onPressed: _canSave ? _save : null,
            child: const Text('Save breakdown'),
          ),
        ]),
      ),
    );
  }
}

class _ShareEntry {
  final User user;
  final TextEditingController amountCtrl;
  final TextEditingController reasonCtrl;
  bool hasParking;
  bool hasBalcony;
  bool hasPrivateWashroom;

  _ShareEntry({
    required this.user,
    required this.amountCtrl,
    required this.reasonCtrl,
    this.hasParking = false,
    this.hasBalcony = false,
    this.hasPrivateWashroom = false,
  });
}

class _EntryCard extends StatelessWidget {
  final _ShareEntry entry;
  final VoidCallback onChanged;
  const _EntryCard({required this.entry, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomiesColors.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar.sm(entry.user),
          const SizedBox(width: 8),
          Expanded(child: Text(entry.user.name, style: const TextStyle(fontWeight: FontWeight.w600))),
          SizedBox(
            width: 90,
            child: TextField(
              controller: entry.amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                prefixText: '\$ ',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        const Text('Room features:', style: TextStyle(fontSize: 12, color: HomiesColors.textDim)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, children: [
          _FeatureToggle(
            label: 'Parking',
            value: entry.hasParking,
            onChanged: (v) {
              entry.hasParking = v;
              onChanged();
            },
          ),
          _FeatureToggle(
            label: 'Balcony',
            value: entry.hasBalcony,
            onChanged: (v) {
              entry.hasBalcony = v;
              onChanged();
            },
          ),
          _FeatureToggle(
            label: 'Private washroom',
            value: entry.hasPrivateWashroom,
            onChanged: (v) {
              entry.hasPrivateWashroom = v;
              onChanged();
            },
          ),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: entry.reasonCtrl,
          onChanged: (_) => onChanged(),
          decoration: const InputDecoration(
            hintText: 'Reason, e.g. master bedroom, has garage…',
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ]),
    );
  }
}

class _FeatureToggle extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;
  const _FeatureToggle({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: value,
        onSelected: onChanged,
        selectedColor: HomiesColors.accentSoft,
        checkmarkColor: HomiesColors.accentStrong,
        side: BorderSide(
          color: value ? HomiesColors.accentStrong.withValues(alpha: 0.5) : HomiesColors.textFaint.withValues(alpha: 0.3),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
}

// ─── Rent schedule sheet ──────────────────────────────────────────────────────

class _RentScheduleSheet extends StatefulWidget {
  final HomiesState state;
  const _RentScheduleSheet({required this.state});

  @override
  State<_RentScheduleSheet> createState() => _RentScheduleSheetState();
}

class _RentScheduleSheetState extends State<_RentScheduleSheet> {
  late String _cadence;
  DateTime? _startDate;

  static const _cadenceOptions = [
    ('weekly', 'Weekly'),
    ('fortnightly', 'Fortnightly'),
    ('monthly', 'Monthly'),
  ];

  @override
  void initState() {
    super.initState();
    _cadence = widget.state.property.rentCadence;
    _startDate = parseIso(widget.state.property.rentStartDate);
  }

  void _save() {
    if (_startDate == null) return;
    widget.state.mutate(() {
      widget.state.property.rentCadence = _cadence;
      widget.state.property.rentStartDate = toIso(_startDate);
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rent schedule saved ✓')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.75,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 28),
        child: ListView(controller: ctrl, children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: HomiesColors.textFaint, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text('Rent schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 20),
            child: Text(
              'Set how often rent is due and the date of the first payment.',
              style: TextStyle(color: HomiesColors.textDim, fontSize: 13),
            ),
          ),
          const FieldLabel('Payment frequency'),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: HomiesColors.border, width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _cadenceOptions.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14),
                  InkWell(
                    borderRadius: BorderRadius.vertical(
                      top: i == 0 ? const Radius.circular(9) : Radius.zero,
                      bottom: i == _cadenceOptions.length - 1 ? const Radius.circular(9) : Radius.zero,
                    ),
                    onTap: () => setState(() => _cadence = _cadenceOptions[i].$1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      child: Row(children: [
                        Icon(
                          _cadence == _cadenceOptions[i].$1
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: _cadence == _cadenceOptions[i].$1
                              ? HomiesColors.accent
                              : HomiesColors.textFaint,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _cadenceOptions[i].$2,
                          style: TextStyle(
                            fontSize: 14,
                            color: _cadence == _cadenceOptions[i].$1
                                ? HomiesColors.accentStrong
                                : HomiesColors.text,
                            fontWeight: _cadence == _cadenceOptions[i].$1
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const FieldLabel('First payment date'),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final picked = await pickDate(context, initial: _startDate);
              if (picked != null) setState(() => _startDate = picked);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: HomiesColors.surface,
                border: Border.all(color: HomiesColors.border, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 18, color: HomiesColors.textDim),
                const SizedBox(width: 10),
                Text(
                  _startDate != null ? fmtDate(toIso(_startDate)) : 'Pick a date…',
                  style: TextStyle(
                    fontSize: 14,
                    color: _startDate != null ? HomiesColors.text : HomiesColors.textFaint,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _startDate != null ? _save : null,
            child: const Text('Save schedule'),
          ),
        ]),
      ),
    );
  }
}
