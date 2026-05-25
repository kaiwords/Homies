import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/ui_kit.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final user = state.currentUser!;
    final active = state.activeHousemates;
    final owed = state.bills
        .where((b) => b.status == 'pending' && b.shares[user.id] != null && b.paidBy[user.id] != true)
        .fold<double>(0, (s, b) => s + (b.shares[user.id] ?? 0));
    final myTasks = state.cleaningTasks.where((t) => t.assignee == user.id && !t.done).toList();
    final upcomingParties = state.parties.where((p) {
      final d = parseIso(p.date);
      return d != null && !d.isBefore(DateTime.now());
    }).toList();
    final openComplaints = state.complaints.where((c) => c.status == 'open').toList();
    final pendingBills = state.bills.where((b) => b.status == 'pending').toList();

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
          HomiesCard(
            child: StatRow(tiles: [
              StatTile(
                label: 'You owe',
                value: fmtAUD(owed),
                sub: '${pendingBills.length} bill(s) pending',
              ),
              StatTile(label: 'Cleaning', value: '${myTasks.length}', sub: 'assigned to you'),
              StatTile(label: 'Housemates', value: '${active.length} / ${state.property.maxOccupants}', sub: '${state.invites.length} invite(s) sent'),
              StatTile(
                label: 'Lease ends',
                valueFontSize: 16,
                value: fmtDate(state.property.leaseEnd),
                sub: fmtRelative(state.property.leaseEnd),
              ),
            ]),
          ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Coming up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              for (final b in pendingBills.take(2))
                _row(context, '💡', b.title, 'Due ${fmtRelative(b.dueDate)} · Your share ${fmtAUD(b.shares[user.id] ?? 0)}', '/app/bills'),
              for (final t in myTasks.take(2))
                _row(context, '🧹', t.task, 'Due ${fmtRelative(t.dueDate)}', '/app/cleaning'),
              for (final p in upcomingParties.take(1))
                _row(context, '🎉', p.title,
                    '${fmtDate(p.date)} ${p.time} · ${p.responses.values.where((r) => r == 'accept').length} accepted',
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
