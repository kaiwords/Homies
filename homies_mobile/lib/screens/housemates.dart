import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/ui_kit.dart';

class HousematesScreen extends StatefulWidget {
  const HousematesScreen({super.key});

  @override
  State<HousematesScreen> createState() => _HousematesScreenState();
}

class _HousematesScreenState extends State<HousematesScreen> {
  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final isLeaseholder = state.currentUser?.role == 'leaseholder';
    final awaiting = state.users.where((u) => u.pending && u.submissions != null).toList();
    final shown = state.users.where((u) => !u.pending || u.submissions == null).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'Housemates',
            subtitle: "Who's living here, who's awaiting approval.",
            action: isLeaseholder
                ? ElevatedButton(onPressed: () => _showInvite(context, state), child: const Text('+ Invite'))
                : null,
          ),
          if (isLeaseholder && awaiting.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.only(top: 8, bottom: 4), child: Text('⏳ Awaiting your approval', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
            for (final u in awaiting) _ApprovalCard(user: u),
            const Divider(),
            const Text('Active housemates', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ],
          for (final u in shown) _UserCard(user: u),
          if (state.invites.isNotEmpty)
            HomiesCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Pending invites', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                for (final i in state.invites)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(i.email, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${i.role} · code ${i.code} · sent ${fmtDate(i.sentAt)}',
                              style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }

  void _showInvite(BuildContext context, HomiesState state) {
    final emailCtrl = TextEditingController();
    String role = 'tenant';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) {
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Invite a housemate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            const FieldLabel('Email'),
            TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'housemate@example.com')),
            const SizedBox(height: 10),
            const FieldLabel('Role'),
            Segment<String>(
              options: const ['tenant', 'leaseholder'],
              value: role,
              labelFor: (v) => v == 'tenant' ? 'Tenant' : 'Co-leaseholder',
              onChanged: (v) => setSheet(() => role = v),
            ),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final email = emailCtrl.text.trim();
                  if (email.isEmpty) return;
                  state.mutate(() {
                    state.invites.add(Invite(
                      code: 'HMI-${Random().nextInt(0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0')}',
                      email: email,
                      role: role,
                      sentAt: todayIso(),
                    ));
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Send invite'),
              ),
            ]),
          ]),
        );
      }),
    );
  }
}

class _UserCard extends StatelessWidget {
  final User user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final isLeaseholder = state.currentUser?.role == 'leaseholder';
    return HomiesCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Avatar.lg(user),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              HomiesChip(user.role, tone: user.role == 'leaseholder' ? ChipTone.accent : ChipTone.info),
              if (user.pending && user.submissions == null) const HomiesChip('invited', tone: ChipTone.warn),
              if (user.moveOutDate != null && user.moveOutDate!.isNotEmpty)
                HomiesChip('moving out ${fmtDate(user.moveOutDate)}'),
              if (isApprovalComplete(user)) const HomiesChip('active', tone: ChipTone.ok),
            ]),
            const SizedBox(height: 4),
            Text('${user.email} · ${user.phone}', style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
            Text(
              '${user.moveInDate != null ? 'Moved in ${fmtDate(user.moveInDate)}' : 'Not moved in yet'}'
              '${user.bondPaid ? ' · bond ${fmtAUD(user.bondAmount)}' : ''}',
              style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
            ),
          ]),
        ),
        if (isLeaseholder && user.id != state.currentUser?.id)
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  content: const Text("Remove this housemate? They'll lose access immediately."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
                  ],
                ),
              );
              if (ok == true) {
                state.mutate(() => state.users.removeWhere((u) => u.id == user.id));
              }
            },
            style: TextButton.styleFrom(foregroundColor: HomiesColors.danger),
            child: const Text('Remove'),
          ),
      ]),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final User user;
  const _ApprovalCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final subs = user.submissions;

    void approve(String flag) {
      state.mutate(() {
        switch (flag) {
          case 'docVerified':
            user.docVerified = true;
            break;
          case 'bondPaid':
            user.bondPaid = true;
            break;
          case 'advanceRentPaid':
            user.advanceRentPaid = true;
            break;
        }
        if (user.docVerified && user.bondPaid && user.advanceRentPaid && (user.acceptedRulesAt?.isNotEmpty ?? false) && (user.moveInDate?.isNotEmpty ?? false)) {
          user.pending = false;
        }
      });
    }

    void reject(String flag) {
      state.mutate(() {
        switch (flag) {
          case 'docVerified':
            user.docVerified = false;
            break;
          case 'bondPaid':
            user.bondPaid = false;
            break;
          case 'advanceRentPaid':
            user.advanceRentPaid = false;
            break;
        }
      });
    }

    return HomiesCard(
      borderColor: HomiesColors.warnSoft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Avatar.lg(user),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                const HomiesChip('awaiting approval', tone: ChipTone.warn),
              ]),
              Text('${user.email} · ${user.phone}', style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
              Text('Planned move-in ${user.moveInDate != null ? fmtDate(user.moveInDate) : '—'}',
                  style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
            ]),
          ),
        ]),
        const Divider(),
        _ApprovalRow(
          title: 'ID document',
          sub: subs?.idDoc != null ? (subs!.idDoc!.kind ?? '').replaceAll('-', ' ') : 'No submission',
          hasAttachment: subs?.idDoc?.dataUrl != null,
          approved: user.docVerified,
          onApprove: () => approve('docVerified'),
          onReject: () => reject('docVerified'),
        ),
        _ApprovalRow(
          title: 'Bond — ${fmtAUD(user.bondAmount)}',
          sub: subs?.bondProof != null ? 'paid via ${subs!.bondProof!.method}' : 'No submission',
          hasAttachment: subs?.bondProof?.dataUrl != null,
          approved: user.bondPaid,
          onApprove: () => approve('bondPaid'),
          onReject: () => reject('bondPaid'),
        ),
        _ApprovalRow(
          title: 'Advance rent',
          sub: subs?.advanceRentProof != null ? 'paid via ${subs!.advanceRentProof!.method}' : 'No submission',
          hasAttachment: subs?.advanceRentProof?.dataUrl != null,
          approved: user.advanceRentPaid,
          onApprove: () => approve('advanceRentPaid'),
          onReject: () => reject('advanceRentPaid'),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Approving all three above will make ${user.name.split(' ').first} an active housemate.',
              style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
        ),
      ]),
    );
  }
}

class _ApprovalRow extends StatelessWidget {
  final String title;
  final String sub;
  final bool approved;
  final bool hasAttachment;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _ApprovalRow({
    required this.title,
    required this.sub,
    required this.approved,
    required this.hasAttachment,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(sub, style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
          ]),
        ),
        if (approved)
          Row(children: [
            const HomiesChip('approved', tone: ChipTone.ok),
            TextButton(onPressed: onReject, child: const Text('Revoke')),
          ])
        else
          ElevatedButton(onPressed: onApprove, child: const Text('Approve')),
      ]),
    );
  }
}
