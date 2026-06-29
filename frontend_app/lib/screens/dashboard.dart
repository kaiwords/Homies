import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/ui_kit.dart';

const _dayOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const _weekdayIndex = {
  'Mon': DateTime.monday,
  'Tue': DateTime.tuesday,
  'Wed': DateTime.wednesday,
  'Thu': DateTime.thursday,
  'Fri': DateTime.friday,
  'Sat': DateTime.saturday,
  'Sun': DateTime.sunday,
};

DateTime _nextWeekday(String day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = _weekdayIndex[day] ?? DateTime.monday;
  var daysAhead = target - today.weekday;
  if (daysAhead <= 0) daysAhead += 7;
  return today.add(Duration(days: daysAhead));
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String? _nextRent(HomiesState state) {
    final cad = state.property.rentCadence;
    var d = state.property.rentStartDate;
    if (d == null || d.isEmpty) return null;
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day);
    var guard = 0;
    while (guard++ < 2000) {
      final parsed = parseIso(d);
      if (parsed == null) return d;
      if (!parsed.isBefore(cutoff)) return d;
      final next = addCadence(d, cad, null);
      if (next == null || next == d) return d;
      d = next;
    }
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final user = state.currentUser!;
    final active = state.activeHousemates;

    // Total owed across all finance categories
    final billsOwed = state.bills
        .where((b) => b.status == 'pending' && b.shares.containsKey(user.id) && b.paidBy[user.id] != true)
        .fold<double>(0, (s, b) => s + (b.shares[user.id] ?? 0));
    final subsOwed = state.subscriptions
        .where((sub) => sub.participants.contains(user.id) && sub.payer != user.id && sub.paidBy[user.id] != true)
        .fold<double>(0, (acc, sub) => acc + (sub.shares[user.id] ?? 0));
    final groceriesOwed = state.groceries
        .where((g) => g.mode == 'shared' && g.payer != user.id && g.paidBy[user.id] != true && g.shares.containsKey(user.id))
        .fold<double>(0, (s, g) => s + (g.shares[user.id] ?? 0));
    final necessitiesOwed = state.necessities
        .where((n) => n.mode == 'shared' && n.payer != user.id && n.paidBy[user.id] != true && n.shares.containsKey(user.id))
        .fold<double>(0, (s, n) => s + (n.shares[user.id] ?? 0));
    final totalOwed = billsOwed + subsOwed + groceriesOwed + necessitiesOwed;

    final myUnpaidBills = state.bills
        .where((b) => b.status == 'pending' && b.shares[user.id] != null && b.paidBy[user.id] != true)
        .toList();
    final myRoster = state.cleaningRoster.where((r) => r.assignee == user.id).toList()
      ..sort((a, b) => _dayOrder.indexOf(a.day).compareTo(_dayOrder.indexOf(b.day)));
    final myTasks = state.cleaningTasks.where((t) => t.assignee == user.id && !t.done).toList();
    final upcomingParties = state.parties.where((p) {
      final d = parseIso(p.date);
      return d != null && !d.isBefore(DateTime.now());
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final openComplaints = state.complaints.where((c) => c.status == 'open').toList();

    final cadence = state.property.cleaningCadence;
    final showNextDates = cadence == 'weekly' || cadence == 'fortnightly';
    final nextRent = _nextRent(state);
    final perPersonRent = active.isEmpty ? 0.0 : state.property.rentAmount / active.length;
    final firstName = user.name
        .replaceAll(RegExp(r'^You \('), '')
        .replaceAll(RegExp(r'\)$'), '')
        .split(' ')
        .first;

    // Lease expiry logic
    final leaseEndStr = state.property.leaseEnd;
    final leaseEnd = leaseEndStr?.isNotEmpty == true ? parseIso(leaseEndStr!) : null;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final daysLeft = leaseEnd?.difference(today).inDays;
    final notifSent = state.property.leaseNotificationSentAt;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
        child: FadeSlideIn(
         child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'Good day, $firstName 👋',
            subtitle: "Here's what's up at home.",
            action: AvatarStack(users: active),
          ),

          // Lease expiry banners
          if (daysLeft != null && daysLeft <= 14 && daysLeft >= 0)
            _LeaseExpiryBanner(
              daysLeft: daysLeft,
              isUrgent: true,
              notifSent: notifSent,
              isLeaseholder: user.role == 'leaseholder',
              onNotify: () => _notifyTenants(context, state),
            ),
          if (daysLeft != null && daysLeft > 14 && daysLeft <= 30)
            _LeaseExpiryBanner(
              daysLeft: daysLeft,
              isUrgent: false,
              notifSent: notifSent,
              isLeaseholder: user.role == 'leaseholder',
              onNotify: () => _notifyTenants(context, state),
            ),
          if (notifSent != null && user.role == 'tenant')
            HomiesCard(
              borderColor: HomiesColors.accentBorder,
              child: Row(children: [
                const Icon(Icons.notifications_outlined, size: 20, color: HomiesColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Lease update from your leaseholder',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(
                      'Your leaseholder notified all housemates on ${fmtDate(notifSent)}. '
                      'The lease${daysLeft != null ? ' ends in $daysLeft days' : ' is changing'}. '
                      'Speak to them if you have questions.',
                      style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
                    ),
                  ]),
                ),
              ]),
            ),

          // Profile completion banner
          if (!user.profileComplete)
            HomiesCard(
              borderColor: HomiesColors.warnBorder,
              child: Row(children: [
                const Text('📝', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Complete your profile', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('Add your lifestyle answers and an emergency contact.',
                        style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                  ]),
                ),
                OutlinedButton(onPressed: () => context.go('/app/profile'), child: const Text('Complete')),
              ]),
            ),

          // Finance summary — tappable → Finance screen
          GestureDetector(
            onTap: () => context.go('/app/finance'),
            child: HomiesCard(
              borderColor: totalOwed > 0 ? HomiesColors.warnBorder : HomiesColors.okBorder,
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: totalOwed > 0 ? HomiesColors.warnSoft : HomiesColors.okSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(totalOwed > 0 ? '💸' : '✅', style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      fmtAUD(totalOwed),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: totalOwed > 0 ? HomiesColors.warn : HomiesColors.ok,
                      ),
                    ),
                    Text(
                      totalOwed > 0 ? 'you owe — tap to view Finance' : 'All settled — nothing outstanding',
                      style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
                    ),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: HomiesColors.textFaint),
              ]),
            ),
          ),

          // Quick stats
          HomiesCard(
            child: StatRow(tiles: [
              StatTile(
                label: 'Housemates',
                value: '${active.length} / ${state.property.maxOccupants}',
                sub: '${state.invites.length} invite(s) sent',
              ),
              StatTile(
                label: 'Lease ends',
                valueFontSize: 16,
                value: fmtDate(state.property.leaseEnd),
                sub: fmtRelative(state.property.leaseEnd),
              ),
            ]),
          ),

          // Rent
          HomiesCard(
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: HomiesColors.accentBorder, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Text('🏠', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('${fmtAUD(state.property.rentAmount)} ',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    HomiesChip(cadenceLabel(state.property.rentCadence), tone: ChipTone.accent),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    'Rent · your share ≈ ${fmtAUD(perPersonRent)}'
                    '${nextRent != null ? ' · next ${fmtRelative(nextRent)}' : ''}',
                    style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
                  ),
                ]),
              ),
              if (user.role == 'leaseholder')
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: HomiesColors.textDim),
                  tooltip: 'Edit rent',
                  onPressed: () => _editRent(context, state),
                )
              else
                OutlinedButton(onPressed: () => context.go('/app/property'), child: const Text('Lease')),
            ]),
          ),

          // Upcoming parties
          if (upcomingParties.isNotEmpty)
            HomiesCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Expanded(
                    child: Text('Upcoming parties 🎉', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/app/parties'),
                    child: const Text('All'),
                  ),
                ]),
                const SizedBox(height: 10),
                for (final p in upcomingParties.take(3)) _PartyRow(party: p),
              ]),
            ),

          // Cleaning schedule
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Expanded(child: Text('Your cleaning', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                HomiesChip(cadenceLabel(cadence), tone: ChipTone.accent),
              ]),
              const SizedBox(height: 10),
              if (myRoster.isEmpty && myTasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text("You're all clear — nothing assigned to you right now. 🎉",
                      style: TextStyle(color: HomiesColors.textDim, fontSize: 13)),
                ),
              for (final r in myRoster)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: HomiesColors.accentBorder, borderRadius: BorderRadius.circular(8)),
                      child: Text(r.day,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12, color: HomiesColors.accentStrong)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.area.isNotEmpty ? r.area : 'General clean',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        if (showNextDates)
                          Text(
                            'Next: ${fmtDate(_nextWeekday(r.day).toIso8601String())}',
                            style: const TextStyle(color: HomiesColors.textDim, fontSize: 11),
                          ),
                      ]),
                    ),
                  ]),
                ),
              for (final t in myTasks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    const Text('🧹', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.task, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('Due ${fmtRelative(t.dueDate)}',
                            style: const TextStyle(color: HomiesColors.textDim, fontSize: 11)),
                      ]),
                    ),
                  ]),
                ),
              if (myRoster.isNotEmpty || myTasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                        onPressed: () => context.go('/app/cleaning'), child: const Text('Open cleaning')),
                  ),
                ),
            ]),
          ),

          // Bills due
          if (myUnpaidBills.isNotEmpty)
            HomiesCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Bills due', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                for (final b in myUnpaidBills.take(3))
                  _row(context, '💡', b.title,
                      'Due ${fmtRelative(b.dueDate)} · your share ${fmtAUD(b.shares[user.id] ?? 0)}',
                      '/app/bills'),
                if (myUnpaidBills.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '+${myUnpaidBills.length - 3} more — open Finance to view all',
                      style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
                    ),
                  ),
              ]),
            ),

          // Open complaints
          if (openComplaints.isNotEmpty)
            HomiesCard(
              borderColor: HomiesColors.dangerBorder,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('🚩 Open complaints', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  'There ${openComplaints.length == 1 ? 'is' : 'are'} ${openComplaints.length} unresolved.',
                  style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
                ),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => context.go('/app/complaints'), child: const Text('Review')),
              ]),
            ),
        ]),
        ),  // FadeSlideIn
      ),
    );
  }

  Widget _row(BuildContext context, String emoji, String title, String sub, String path) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(sub, style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
          ]),
        ),
        OutlinedButton(onPressed: () => context.go(path), child: const Text('Open')),
      ]),
    );
  }

  void _notifyTenants(BuildContext context, HomiesState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Notify housemates'),
        content: const Text(
          'This will send a lease update banner to all housemates. '
          'They will see a notification on their dashboard.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              state.mutate(() {
                state.property.leaseNotificationSentAt = DateTime.now().toIso8601String();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Housemates notified ✓')),
              );
            },
            child: const Text('Send notification'),
          ),
        ],
      ),
    );
  }

  void _editRent(BuildContext context, HomiesState state) {
    final amountCtrl = TextEditingController(
      text: state.property.rentAmount > 0 ? state.property.rentAmount.toStringAsFixed(0) : '',
    );
    String cadence = state.property.rentCadence;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Edit rent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            const FieldLabel('Amount (\$)'),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: '0.00', prefixText: '\$ '),
            ),
            const SizedBox(height: 12),
            const FieldLabel('Frequency'),
            Wrap(spacing: 8, children: [
              for (final c in ['weekly', 'fortnightly', 'monthly'])
                ChoiceChip(
                  label: Text(cadenceLabel(c)),
                  selected: cadence == c,
                  onSelected: (_) => setSt(() => cadence = c),
                ),
            ]),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                state.mutate(() {
                  state.property.rentAmount = amount;
                  state.property.rentCadence = cadence;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PartyRow extends StatelessWidget {
  final Party party;
  const _PartyRow({required this.party});

  @override
  Widget build(BuildContext context) {
    final d = parseIso(party.date);
    final goingCount = party.responses.values.where((r) => r == 'accept').length;
    final isProposed = party.status == 'proposed';
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: HomiesColors.accentBorder, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              d != null ? dayNames[d.weekday - 1] : '??',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: HomiesColors.accentStrong),
            ),
            Text(
              d != null ? '${d.day}' : '??',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: HomiesColors.accentStrong),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(party.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${party.time} · $goingCount going',
                style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
          ]),
        ),
        HomiesChip(
          isProposed ? 'Proposed' : 'Approved',
          tone: isProposed ? ChipTone.warn : ChipTone.ok,
        ),
      ]),
    );
  }
}

class _LeaseExpiryBanner extends StatelessWidget {
  final int daysLeft;
  final bool isUrgent;
  final String? notifSent;
  final bool isLeaseholder;
  final VoidCallback onNotify;

  const _LeaseExpiryBanner({
    required this.daysLeft,
    required this.isUrgent,
    required this.notifSent,
    required this.isLeaseholder,
    required this.onNotify,
  });

  @override
  Widget build(BuildContext context) {
    final color = isUrgent ? HomiesColors.danger : HomiesColors.warn;
    final icon = isUrgent ? Icons.warning_amber_rounded : Icons.schedule_outlined;
    final label = daysLeft == 0
        ? 'Lease expires today!'
        : 'Lease expires in $daysLeft day${daysLeft == 1 ? '' : 's'}';

    return HomiesCard(
      borderColor: color.withValues(alpha: 0.45),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
              if (isLeaseholder)
                Text(
                  notifSent != null
                      ? 'Housemates notified on ${fmtDate(notifSent)}.'
                      : 'Notify all housemates at least 2 weeks before the lease ends.',
                  style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
                )
              else
                const Text(
                  'Check with your leaseholder about renewal or move-out plans.',
                  style: TextStyle(color: HomiesColors.textDim, fontSize: 12),
                ),
            ]),
          ),
        ]),
        if (isLeaseholder && notifSent == null) ...[
          const SizedBox(height: 8),
          ElevatedButton(onPressed: onNotify, child: const Text('Notify housemates now')),
        ],
      ]),
    );
  }
}
