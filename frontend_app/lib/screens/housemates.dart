import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/lifestyle_fields.dart';
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
    final cu = HomiesScope.of(context).currentUser;
    final canSeeFull = cu?.id == user.id || (cu?.isAdmin ?? false) || (cu?.isLeaseholder ?? false);
    final showEmail = canSeeFull || user.shareEmail;
    final showPhone = canSeeFull || user.sharePhone;
    final contactParts = <String>[
      if (showEmail && user.email.isNotEmpty) user.email,
      if (showPhone && user.phone.isNotEmpty) user.phone,
    ];
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
            if (contactParts.isNotEmpty)
              Text(contactParts.join(' · '), style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
            Text(
              '${user.moveInDate != null ? 'Moved in ${fmtDate(user.moveInDate)}' : 'Not moved in yet'}'
              '${user.bondPaid ? ' · bond ${fmtAUD(user.bondAmount)}' : ''}',
              style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
            ),
          ]),
        ),
        _UserMenu(user: user),
      ]),
    );
  }
}

/// Overflow ("⋮") menu on each housemate — view their details, report them, or
/// (leaseholder only) remove them from the house.
class _UserMenu extends StatelessWidget {
  final User user;
  const _UserMenu({required this.user});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser;
    final isSelf = user.id == cu?.id;
    final isLeaseholder = cu?.role == 'leaseholder';
    final firstName = user.name.split(' ').first;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: HomiesColors.textDim),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'view', child: ListTile(leading: Icon(Icons.badge_outlined), title: Text('View details'), dense: true)),
        if (!isSelf)
          PopupMenuItem(
            value: 'report',
            child: ListTile(
              leading: const Icon(Icons.flag_outlined, color: HomiesColors.danger),
              title: Text('Report $firstName', style: const TextStyle(color: HomiesColors.danger)),
              dense: true,
            ),
          ),
        if (isLeaseholder && !isSelf)
          PopupMenuItem(
            value: 'remove',
            child: ListTile(
              leading: const Icon(Icons.person_remove_outlined, color: HomiesColors.danger),
              title: Text('Remove $firstName', style: const TextStyle(color: HomiesColors.danger)),
              dense: true,
            ),
          ),
      ],
      onSelected: (v) async {
        switch (v) {
          case 'view':
            _viewDetails(context, user);
            break;
          case 'report':
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: _ReportModal(against: user),
              ),
            );
            break;
          case 'remove':
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
            break;
        }
      },
    );
  }

  void _viewDetails(BuildContext context, User user) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser;
    final canSeeFull = user.id == cu?.id || (cu?.isAdmin ?? false) || (cu?.isLeaseholder ?? false);
    final canSeeEmail = canSeeFull || user.shareEmail;
    final canSeePhone = canSeeFull || user.sharePhone;
    final canSeeLifestyle = canSeeFull || user.shareLifestyle;
    final canSeeEmergency = canSeeFull || user.shareEmergency;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Avatar.lg(user),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(user.role, style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                  ]),
                ),
              ]),
              const SizedBox(height: 4),
              Wrap(spacing: 8, runSpacing: 2, children: [
                if (canSeeEmail)
                  Text(user.email, style: const TextStyle(color: HomiesColors.textDim, fontSize: 12))
                else
                  _privateLabel('Email'),
                if (user.phone.isNotEmpty)
                  if (canSeePhone)
                    Text(user.phone, style: const TextStyle(color: HomiesColors.textDim, fontSize: 12))
                  else
                    _privateLabel('Phone'),
              ]),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: HomiesColors.border)),
              if (user.profileComplete) ...[
                if (canSeeLifestyle)
                  LifestyleSummary(
                    lifestyle: user.lifestyle,
                    emergency: canSeeEmergency ? user.emergency : null,
                    emergencyPrivate: !canSeeEmergency && (user.emergency?.isComplete ?? false),
                  )
                else ...[
                  _privateLabel('Lifestyle profile'),
                  const SizedBox(height: 8),
                  LifestyleSummary(
                    lifestyle: null,
                    emergency: canSeeEmergency ? user.emergency : null,
                    emergencyPrivate: !canSeeEmergency && (user.emergency?.isComplete ?? false),
                  ),
                ],
              ] else
                const Text("This housemate hasn't completed their lifestyle profile yet.",
                    style: TextStyle(color: HomiesColors.textDim, fontSize: 13)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Compact report form, pre-targeted at a specific housemate. Recorded as a
/// complaint so it feeds the same complaint-score / leaseholder review flow.
class _ReportModal extends StatefulWidget {
  final User against;
  const _ReportModal({required this.against});

  @override
  State<_ReportModal> createState() => _ReportModalState();
}

class _ReportModalState extends State<_ReportModal> {
  final reasonCtrl = TextEditingController();
  double severity = 5;

  @override
  void dispose() {
    reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text('Report ${widget.against.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const Text('Keep it factual. The leaseholder reviews reports. Severity 1 (minor) to 50 (major).',
                style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
            const SizedBox(height: 12),
            const FieldLabel('What happened?'),
            TextField(controller: reasonCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Be specific — when, where, what.'), onChanged: (_) => setState(() {})),
            const SizedBox(height: 10),
            FieldLabel('Severity: ${severity.round()}'),
            Slider(value: severity, min: 1, max: 50, divisions: 49, onChanged: (v) => setState(() => severity = v)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: reasonCtrl.text.trim().isEmpty
                    ? null
                    : () {
                        state.mutate(() => state.complaints.insert(0, Complaint(
                              id: 'co-${Random().nextInt(0xFFFF).toRadixString(36)}',
                              against: widget.against.id,
                              from: state.currentUser!.id,
                              reason: reasonCtrl.text.trim(),
                              severity: severity.round(),
                              date: todayIso(),
                            )));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted')));
                      },
                style: ElevatedButton.styleFrom(backgroundColor: HomiesColors.danger),
                child: const Text('Submit report'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

Widget _privateLabel(String label) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    const Icon(Icons.lock_outline, size: 12, color: HomiesColors.textFaint),
    const SizedBox(width: 3),
    Text('$label private', style: const TextStyle(color: HomiesColors.textFaint, fontSize: 12, fontStyle: FontStyle.italic)),
  ],
);

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
