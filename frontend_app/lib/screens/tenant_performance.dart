import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/performance.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/ui_kit.dart';

String _pct(double? r) => r == null ? '—' : '${(r * 100).round()}%';

({String label, ChipTone tone, Color color}) bandStyle(int score) {
  final label = standingBand(score);
  if (score >= 80) return (label: label, tone: ChipTone.ok, color: HomiesColors.ok);
  if (score >= 60) return (label: label, tone: ChipTone.warn, color: HomiesColors.warn);
  return (label: label, tone: ChipTone.danger, color: HomiesColors.danger);
}

class TenantPerformanceScreen extends StatelessWidget {
  const TenantPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;

    if (cu.role != 'leaseholder') {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: EmptyState(title: 'Leaseholders only', body: 'Only the leaseholder can review tenant performance.'),
        ),
      );
    }

    final tenants = state.users.where((u) => u.role == 'tenant' && !u.pending).map((u) => computeTenantStats(u, state)).toList();
    final scored = tenants.where((t) => t.hasActivity).toList()..sort((a, b) => a.standing.compareTo(b.standing));
    final newcomers = tenants.where((t) => !t.hasActivity).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PageHead(
            title: 'Tenant performance',
            subtitle: 'How each tenant is tracking on chores, bills, complaints and parties.',
          ),
          if (scored.isEmpty && newcomers.isEmpty)
            const EmptyState(title: 'No tenants yet', body: 'Once tenants join your house, their performance shows up here.'),
          for (final t in scored) _TenantCard(t: t),
          if (newcomers.isNotEmpty)
            HomiesCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('New tenants', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Padding(
                  padding: EdgeInsets.only(top: 2, bottom: 6),
                  child: Text('Just joined — no activity to report yet.', style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                ),
                for (final t in newcomers)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Avatar.sm(t.user),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t.user.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                      const HomiesChip('New housemate'),
                    ]),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _TenantCard extends StatelessWidget {
  final TenantStats t;
  const _TenantCard({required this.t});

  @override
  Widget build(BuildContext context) {
    final band = bandStyle(t.standing);
    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(user: t.user),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Text('Tenant', style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${t.standing}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: band.color)),
            HomiesChip(band.label, tone: band.tone),
          ]),
        ]),
        const SizedBox(height: 14),
        _metric(
          label: '🧹 Chores',
          value: '${t.doneCount}/${t.taskCount} · ${_pct(t.choreRate)}',
          progress: t.choreRate,
          extras: [
            if (t.overdueCount > 0) HomiesChip('${t.overdueCount} overdue', tone: ChipTone.danger),
            if (t.excusedCount > 0) HomiesChip('${t.excusedCount} excused', tone: ChipTone.warn),
          ],
        ),
        const SizedBox(height: 12),
        _metric(
          label: '💡 Bills paid',
          value: '${t.paidCount}/${t.billCount} · ${_pct(t.billRate)}',
          progress: t.billRate,
          extras: [
            if (t.owed > 0) HomiesChip('${fmtAUD(t.owed)} outstanding', tone: ChipTone.warn)
            else const HomiesChip('All settled', tone: ChipTone.ok),
            if (t.lateUnpaid > 0) HomiesChip('${t.lateUnpaid} overdue', tone: ChipTone.danger),
          ],
        ),
        if (t.subCount > 0) ...[
          const SizedBox(height: 12),
          _metric(
            label: '📦 Subscriptions',
            value: '${t.subPaidCount}/${t.subCount} · ${_pct(t.subRate)}',
            progress: t.subRate,
            extras: [],
          ),
        ],
        if (t.groceriesCount > 0) ...[
          const SizedBox(height: 12),
          _metric(
            label: '🛒 Groceries',
            value: '${t.groceriesPaidCount}/${t.groceriesCount} · ${_pct(t.groceriesRate)}',
            progress: t.groceriesRate,
            extras: [],
          ),
        ],
        if (t.necessitiesCount > 0) ...[
          const SizedBox(height: 12),
          _metric(
            label: '🧴 Necessities',
            value: '${t.necessitiesPaidCount}/${t.necessitiesCount} · ${_pct(t.necessitiesRate)}',
            progress: t.necessitiesRate,
            extras: [],
          ),
        ],
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: HomiesColors.border)),
        Wrap(spacing: 12, runSpacing: 6, children: [
          Text('🚩 ${t.complaintSeverity} complaint pts', style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
          Text('🎉 ${t.partiesHosted} parties hosted', style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
          if (t.issuesRaised > 0)
            Text('🔧 ${t.issuesRaised} issue${t.issuesRaised == 1 ? '' : 's'} raised', style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
          if (t.groupMessageCount > 0)
            Text('💬 ${t.groupMessageCount} msg${t.groupMessageCount == 1 ? '' : 's'} sent', style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
        ]),
      ]),
    );
  }

  Widget _metric({required String label, required String value, double? progress, List<Widget> extras = const []}) {
    final pct = progress ?? 0;
    final color = pct >= 0.8 ? HomiesColors.ok : pct >= 0.5 ? HomiesColors.warn : HomiesColors.danger;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct.clamp(0.0, 1.0),
          minHeight: 8,
          backgroundColor: HomiesColors.surface2,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
      if (extras.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 6, runSpacing: 4, children: extras),
        ),
    ]);
  }
}
