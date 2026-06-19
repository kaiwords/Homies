import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/ui_kit.dart';

const _dayOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  /// Next rent date on/after today, stepping from the rent start by cadence.
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
    final owed = state.bills
        .where((b) => b.status == 'pending' && b.shares[user.id] != null && b.paidBy[user.id] != true)
        .fold<double>(0, (s, b) => s + (b.shares[user.id] ?? 0));
    final myUnpaidBills = state.bills
        .where((b) => b.status == 'pending' && b.shares[user.id] != null && b.paidBy[user.id] != true)
        .toList();
    final myTasks = state.cleaningTasks.where((t) => t.assignee == user.id && !t.done).toList();
    final myRoster = state.cleaningRoster.where((r) => r.assignee == user.id).toList()
      ..sort((a, b) => _dayOrder.indexOf(a.day).compareTo(_dayOrder.indexOf(b.day)));
    final upcomingParties = state.parties.where((p) {
      final d = parseIso(p.date);
      return d != null && !d.isBefore(DateTime.now());
    }).toList()
      ..sort((a, b) => (a.date).compareTo(b.date));
    final openComplaints = state.complaints.where((c) => c.status == 'open').toList();

    final cadence = cadenceLabel(state.property.cleaningCadence).toLowerCase();
    final nextRent = _nextRent(state);
    final perPersonRent = active.isEmpty ? 0.0 : state.property.rentAmount / active.length;
    final firstName = user.name.replaceAll(RegExp(r'^You \('), '').replaceAll(RegExp(r'\)$'), '').split(' ').first;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'Good day, $firstName 👋',
            subtitle: "Here's what's up at home.",
            action: AvatarStack(users: active),
          ),
          if (!user.profileComplete)
            HomiesCard(
              borderColor: HomiesColors.warnSoft,
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
          HomiesCard(
            child: StatRow(tiles: [
              StatTile(label: 'You owe', value: fmtAUD(owed), sub: '${myUnpaidBills.length} bill(s) to pay'),
              StatTile(label: 'Your chores', value: '${myTasks.length}', sub: 'still to do'),
              StatTile(label: 'Housemates', value: '${active.length} / ${state.property.maxOccupants}', sub: '${state.invites.length} invite(s) sent'),
              StatTile(label: 'Lease ends', valueFontSize: 16, value: fmtDate(state.property.leaseEnd), sub: fmtRelative(state.property.leaseEnd)),
            ]),
          ),

          // Rent period
          HomiesCard(
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: HomiesColors.accentSoft, borderRadius: BorderRadius.circular(12)),
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
              OutlinedButton(onPressed: () => context.go('/app/property'), child: const Text('Lease')),
            ]),
          ),

          // Your cleaning
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Expanded(child: Text('Your cleaning', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                HomiesChip('Repeats $cadence', tone: ChipTone.accent),
              ]),
              const SizedBox(height: 4),
              if (myRoster.isEmpty && myTasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text("You're all clear — nothing assigned to you right now. 🎉",
                      style: TextStyle(color: HomiesColors.textDim, fontSize: 13)),
                ),
              for (final r in myRoster)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: HomiesColors.accentSoft, borderRadius: BorderRadius.circular(8)),
                      child: Text(r.day, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: HomiesColors.accentStrong)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(r.area.isNotEmpty ? r.area : 'General clean',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ]),
                ),
              for (final t in myTasks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    const Text('🧹', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.task, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('Due ${fmtRelative(t.dueDate)}', style: const TextStyle(color: HomiesColors.textDim, fontSize: 11)),
                      ]),
                    ),
                  ]),
                ),
              if (myRoster.isNotEmpty || myTasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(onPressed: () => context.go('/app/cleaning'), child: const Text('Open cleaning')),
                  ),
                ),
            ]),
          ),

          // Coming up
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Coming up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              if (myUnpaidBills.isEmpty && upcomingParties.isEmpty && myTasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Nothing on the horizon — enjoy the calm.', style: TextStyle(color: HomiesColors.textDim, fontSize: 13)),
                ),
              for (final b in myUnpaidBills.take(3))
                _row(context, '💡', b.title, 'Due ${fmtRelative(b.dueDate)} · your share ${fmtAUD(b.shares[user.id] ?? 0)}', '/app/bills'),
              for (final p in upcomingParties.take(2))
                _row(context, '🎉', p.title,
                    '${fmtDate(p.date)} ${p.time} · ${p.responses.values.where((r) => r == 'accept').length} going',
                    '/app/parties'),
            ]),
          ),

          if (openComplaints.isNotEmpty)
            HomiesCard(
              borderColor: HomiesColors.dangerSoft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('🚩 Open complaints', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text('There ${openComplaints.length == 1 ? 'is' : 'are'} ${openComplaints.length} unresolved.',
                    style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                const SizedBox(height: 6),
                OutlinedButton(onPressed: () => context.go('/app/complaints'), child: const Text('Review')),
              ]),
            ),
        ]),
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
}
