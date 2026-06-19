import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/ui_kit.dart';

/// Admin queue: review leaseholders' lease-agreement submissions.
class AdminVerificationsScreen extends StatelessWidget {
  const AdminVerificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final leaseholders = state.leaseholders;
    final pending = leaseholders.where((u) => u.leaseStatus == 'pending').toList();
    final reviewed = leaseholders.where((u) => u.leaseStatus == 'verified' || u.leaseStatus == 'rejected').toList();
    final notSubmitted = leaseholders.where((u) => u.leaseStatus == 'none').toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PageHead(
            title: 'Lease verifications',
            subtitle: 'Review the lease agreements leaseholders submit before they run a house.',
          ),
          _StatRow(pending: pending.length, verified: leaseholders.where((u) => u.leaseStatus == 'verified').length),
          const SizedBox(height: 8),
          if (pending.isEmpty)
            const InfoBanner(icon: Icons.check_circle_outline, text: 'Nothing waiting — all caught up.')
          else ...[
            const _SectionLabel('⏳ Awaiting review'),
            for (final u in pending) _VerificationCard(user: u),
          ],
          if (reviewed.isNotEmpty) ...[
            const SizedBox(height: 8),
            const _SectionLabel('Reviewed'),
            for (final u in reviewed) _VerificationCard(user: u),
          ],
          if (notSubmitted.isNotEmpty) ...[
            const SizedBox(height: 8),
            const _SectionLabel('Not submitted yet'),
            for (final u in notSubmitted)
              HomiesCard(
                child: Row(children: [
                  Avatar(user: u),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(u.email, style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                    ]),
                  ),
                  const HomiesChip('no submission', tone: ChipTone.neutral),
                ]),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final int pending;
  final int verified;
  const _StatRow({required this.pending, required this.verified});

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, int n, Color color) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: HomiesColors.surface,
              border: Border.all(color: HomiesColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Text('$n', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
              Text(label, style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        tile('Pending', pending, HomiesColors.warn),
        tile('Verified', verified, HomiesColors.ok),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 12, 2, 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      );
}

class _VerificationCard extends StatelessWidget {
  final User user;
  const _VerificationCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final v = user.leaseVerification!;
    final status = v.status;

    return HomiesCard(
      borderColor: status == 'pending' ? HomiesColors.warnSoft : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Avatar.lg(user),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text('Leaseholder', style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
            ]),
          ),
          _statusChip(status),
        ]),
        const Divider(),
        _row('Name on lease', v.fullName),
        _row('Phone', v.phone),
        _row('Email', v.email),
        _row('Submitted', v.submittedAt != null ? fmtDate(v.submittedAt) : '—'),
        if (v.reviewedAt != null) _row('Reviewed', fmtDate(v.reviewedAt)),
        const SizedBox(height: 8),
        if (v.agreement != null)
          AttachmentTile(value: v.agreement!)
        else
          const Text('⚠️ No agreement file attached.', style: TextStyle(color: HomiesColors.danger, fontSize: 12)),
        if (v.note != null && v.note!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Note: ${v.note}', style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
          ),
        if (status == 'pending') ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _reject(context, state),
                icon: const Icon(Icons.close, size: 18, color: HomiesColors.danger),
                label: const Text('Reject', style: TextStyle(color: HomiesColors.danger)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: HomiesColors.danger)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  state.reviewLeaseVerification(user.id, 'verified');
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user.name} verified ✓')));
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Verify'),
              ),
            ),
          ]),
        ] else if (status == 'rejected') ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => state.reviewLeaseVerification(user.id, 'verified'),
              child: const Text('Reverse — verify anyway'),
            ),
          ),
        ],
      ]),
    );
  }

  Future<void> _reject(BuildContext context, HomiesState state) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject submission'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Give the leaseholder a reason so they can fix it and resubmit.',
              style: TextStyle(fontSize: 13, color: HomiesColors.textDim)),
          const SizedBox(height: 10),
          TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(hintText: 'e.g. Lease document is unreadable / details don’t match.')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: HomiesColors.danger),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok == true) {
      state.reviewLeaseVerification(user.id, 'rejected', note: ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
    }
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: HomiesColors.textDim))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ]),
      );

  Widget _statusChip(String status) => switch (status) {
        'verified' => const HomiesChip('verified', tone: ChipTone.ok),
        'rejected' => const HomiesChip('rejected', tone: ChipTone.danger),
        _ => const HomiesChip('pending', tone: ChipTone.warn),
      };
}
