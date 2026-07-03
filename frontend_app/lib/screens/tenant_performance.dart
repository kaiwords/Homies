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

// 1 = improving, -1 = declining, 0 = stable
int _trend(TenantStats t) {
  if (t.overdueCount > 0 || t.lateUnpaid > 0) return -1;
  if (t.taskCount > 0 && t.doneCount == t.taskCount && t.billCount > 0 && t.paidCount == t.billCount) return 1;
  return 0;
}

String _tenure(String? moveInDate) {
  final d = parseIso(moveInDate);
  if (d == null) return '';
  final now = DateTime.now();
  final months = (now.year - d.year) * 12 + now.month - d.month;
  if (months < 1) return 'New arrival';
  if (months == 1) return '1 month';
  if (months < 12) return '$months months';
  final yrs = months ~/ 12;
  final rem = months % 12;
  if (rem == 0) return '$yrs year${yrs == 1 ? '' : 's'}';
  return '$yrs yr${yrs == 1 ? '' : 's'} $rem mo';
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
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PageHead(
            title: 'Tenant performance',
            subtitle: 'How each tenant is tracking on chores, bills, complaints and parties.',
          ),
          if (scored.isEmpty && newcomers.isEmpty)
            const EmptyState(title: 'No tenants yet', body: 'Once tenants join your house, their performance shows up here.'),
          if (scored.isNotEmpty) _HouseSummaryCard(tenants: scored),
          for (final t in scored) _TenantCard(t: t, state: state),
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

// ─── House summary ────────────────────────────────────────────────────────────

class _HouseSummaryCard extends StatelessWidget {
  final List<TenantStats> tenants;
  const _HouseSummaryCard({required this.tenants});

  @override
  Widget build(BuildContext context) {
    final avg = (tenants.fold<int>(0, (s, t) => s + t.standing) / tenants.length).round();
    final avgBand = bandStyle(avg);
    final goodCount = tenants.where((t) => t.standing >= 80).length;
    final fairCount = tenants.where((t) => t.standing >= 60 && t.standing < 80).length;
    final poorCount = tenants.where((t) => t.standing < 60).length;
    final totalOwed = tenants.fold<double>(0, (s, t) => s + t.owed);

    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.bar_chart_rounded, size: 18, color: HomiesColors.accent),
          const SizedBox(width: 8),
          const Expanded(child: Text('House overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          Text('${tenants.length} active tenant${tenants.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Avg. standing',
                  style: TextStyle(fontSize: 11, color: HomiesColors.textDim, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('$avg',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: avgBand.color, height: 1.1)),
                const Text(' / 100', style: TextStyle(fontSize: 11, color: HomiesColors.textFaint)),
              ]),
              const SizedBox(height: 4),
              HomiesChip(avgBand.label, tone: avgBand.tone),
            ]),
          ),
          Container(width: 1, height: 64, color: HomiesColors.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Distribution',
                  style: TextStyle(fontSize: 11, color: HomiesColors.textDim, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              if (goodCount > 0) _DistRow(Icons.check_circle_outline, '$goodCount Good', HomiesColors.ok),
              if (fairCount > 0) _DistRow(Icons.warning_amber_outlined, '$fairCount Fair', HomiesColors.warn),
              if (poorCount > 0) _DistRow(Icons.error_outline, '$poorCount Needs attention', HomiesColors.danger),
            ]),
          ),
        ]),
        if (totalOwed > 0) ...[
          const Divider(height: 20),
          Row(children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 14, color: HomiesColors.warn),
            const SizedBox(width: 6),
            Text('${fmtAUD(totalOwed)} outstanding across all tenants',
                style: const TextStyle(fontSize: 12, color: HomiesColors.warn, fontWeight: FontWeight.w500)),
          ]),
        ],
      ]),
    );
  }
}

class _DistRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _DistRow(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ]),
      );
}

// ─── Tenant card ─────────────────────────────────────────────────────────────

class _TenantCard extends StatefulWidget {
  final TenantStats t;
  final HomiesState state;
  const _TenantCard({required this.t, required this.state});

  @override
  State<_TenantCard> createState() => _TenantCardState();
}

class _TenantCardState extends State<_TenantCard> {
  bool _expanded = false;

  bool get _hasExtras =>
      widget.t.subCount > 0 || widget.t.groceriesCount > 0 || widget.t.necessitiesCount > 0;

  // Surface a warning on the collapsed toggle so delinquency in a hidden
  // category (unpaid subscriptions/groceries/necessities) isn't missed at a
  // glance — the collapsed row otherwise gives no hint anything's overdue.
  bool get _hasUnpaidExtras =>
      widget.t.subPaidCount < widget.t.subCount ||
      widget.t.groceriesPaidCount < widget.t.groceriesCount ||
      widget.t.necessitiesPaidCount < widget.t.necessitiesCount;

  int _extraCount() {
    var n = 0;
    if (widget.t.subCount > 0) n++;
    if (widget.t.groceriesCount > 0) n++;
    if (widget.t.necessitiesCount > 0) n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final band = bandStyle(t.standing);
    final trend = _trend(t);
    final tenure = _tenure(t.user.moveInDate);
    final refCount = widget.state.postMessages
        .where((m) =>
            m.kind == 'perf-share' &&
            (m.perf?.subjectId != null
                ? m.perf?.subjectId == t.user.id
                // Fall back to name matching only for references shared
                // before subjectId existed.
                : m.perf?.subject == t.user.name))
        .length;

    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Header ──
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(user: t.user),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Text('Tenant', style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
              if (tenure.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.calendar_today_outlined, size: 11, color: HomiesColors.textFaint),
                    const SizedBox(width: 3),
                    Text(tenure, style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint)),
                  ]),
                ),
              if (refCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.workspace_premium_outlined, size: 11, color: HomiesColors.accent),
                    const SizedBox(width: 3),
                    Text('$refCount ref${refCount == 1 ? '' : 's'} shared',
                        style: const TextStyle(fontSize: 11, color: HomiesColors.accent)),
                  ]),
                ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (trend != 0) ...[
                Icon(
                  trend > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 18,
                  color: trend > 0 ? HomiesColors.ok : HomiesColors.danger,
                ),
                const SizedBox(width: 4),
              ],
              Text('${t.standing}',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: band.color)),
            ]),
            HomiesChip(band.label, tone: band.tone),
          ]),
        ]),

        const SizedBox(height: 14),

        // ── Core metrics ──
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
            if (t.owed > 0)
              HomiesChip('${fmtAUD(t.owed)} outstanding', tone: ChipTone.warn)
            else
              const HomiesChip('All settled', tone: ChipTone.ok),
            if (t.lateUnpaid > 0) HomiesChip('${t.lateUnpaid} overdue', tone: ChipTone.danger),
          ],
        ),

        // ── Extra categories (expandable) ──
        if (_hasExtras) ...[
          if (!_expanded)
            GestureDetector(
              onTap: () => setState(() => _expanded = true),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  const Expanded(child: Divider(height: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_hasUnpaidExtras) ...[
                        const Icon(Icons.error_outline, size: 12, color: HomiesColors.danger),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        '${_extraCount()} more categor${_extraCount() == 1 ? 'y' : 'ies'}'
                        '${_hasUnpaidExtras ? ' · unpaid' : ''} ▾',
                        style: TextStyle(
                          fontSize: 11,
                          color: _hasUnpaidExtras ? HomiesColors.danger : HomiesColors.accent,
                          fontWeight: _hasUnpaidExtras ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ]),
                  ),
                  const Expanded(child: Divider(height: 1)),
                ]),
              ),
            )
          else ...[
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
            GestureDetector(
              onTap: () => setState(() => _expanded = false),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  const Expanded(child: Divider(height: 1)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('show less ▴', style: TextStyle(fontSize: 11, color: HomiesColors.accent)),
                  ),
                  const Expanded(child: Divider(height: 1)),
                ]),
              ),
            ),
          ],
        ],

        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: HomiesColors.border)),

        // ── Conduct section ──
        _ConductSection(t: t),
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

// ─── Conduct section ─────────────────────────────────────────────────────────

class _ConductSection extends StatelessWidget {
  final TenantStats t;
  const _ConductSection({required this.t});

  @override
  Widget build(BuildContext context) {
    final severityColor = t.complaintSeverity == 0
        ? HomiesColors.ok
        : t.complaintSeverity < 30
            ? HomiesColors.warn
            : HomiesColors.danger;
    final severityFrac = (t.complaintSeverity / 100).clamp(0.0, 1.0);
    final severityLabel = t.complaintSeverity == 0 ? 'No complaints' : '${t.complaintSeverity} pts';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Conduct', style: TextStyle(fontSize: 12, color: HomiesColors.textDim, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('🚩 Complaint severity', style: TextStyle(fontSize: 12, color: HomiesColors.textDim)),
        Text(severityLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: severityColor)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: severityFrac,
          minHeight: 6,
          backgroundColor: HomiesColors.surface2,
          valueColor: AlwaysStoppedAnimation(severityColor),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 16, runSpacing: 6, children: [
        _stat('🎉', 'Parties', '${t.partiesHosted}'),
        _stat('🔧', 'Issues raised', '${t.issuesRaised}'),
        if (t.groupMessageCount > 0) _stat('💬', 'Group msgs', '${t.groupMessageCount}'),
      ]),
    ]);
  }

  Widget _stat(String emoji, String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 3),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );
}
