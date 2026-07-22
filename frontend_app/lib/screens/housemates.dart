import 'dart:math';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/lifestyle_fields.dart';
import '../widgets/ui_kit.dart';

String inviteShareText(Invite invite) =>
    "You're invited to join our house on Homies! If you already have the app, tap: "
    "homies://invite/${invite.code} — otherwise install Homies and enter code "
    "${invite.code} when you sign up.";

/// Opens the leaseholder's default mail app with the invite pre-filled
/// (to/subject/body) so they can review and hit send themselves — no backend
/// email-sending infrastructure required.
Future<void> _sendInviteEmail(Invite invite) async {
  final email = invite.email;
  if (email == null || email.isEmpty) return;
  final uri = Uri(
    scheme: 'mailto',
    path: email,
    queryParameters: {
      'subject': "You're invited to join our house on Homies",
      'body': inviteShareText(invite),
    },
  );
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

/// Opens the leaseholder's default texting app with the invite pre-filled as
/// an SMS body to the given number. The `sms:` URI's body param is joined
/// with `&` on iOS and `?` on Android/everywhere else — a longstanding
/// platform quirk, not a typo.
Future<void> _sendInviteSms(Invite invite) async {
  final phone = invite.phone;
  if (phone == null || phone.isEmpty) return;
  final separator = defaultTargetPlatform == TargetPlatform.iOS ? '&' : '?';
  final uri = Uri.parse('sms:$phone$separator' 'body=${Uri.encodeComponent(inviteShareText(invite))}');
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

/// Final step of the invite flow: show the generated code front-and-centre
/// (tap to copy) plus a single send action matching whichever contact method
/// the leaseholder chose up front — email, phone, or the OS share sheet for
/// social/anything else.
void _showInviteCode(BuildContext context, Invite invite) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Invite created', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text("Here's their code — it's good until they use it.",
              style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: invite.code));
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Code copied')));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: HomiesColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HomiesColors.border),
              ),
              child: Column(children: [
                Text(invite.code,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, fontFamily: 'monospace', letterSpacing: 1.5)),
                const SizedBox(height: 4),
                const Text('Tap to copy', style: TextStyle(fontSize: 11, color: HomiesColors.textDim)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          if (invite.method == 'email')
            ElevatedButton.icon(
              icon: const Icon(Icons.email_outlined),
              label: Text('Open in email app · ${invite.email}'),
              onPressed: () {
                Navigator.pop(ctx);
                _sendInviteEmail(invite);
              },
            )
          else if (invite.method == 'phone')
            ElevatedButton.icon(
              icon: const Icon(Icons.sms_outlined),
              label: Text('Text invite · ${invite.phone}'),
              onPressed: () {
                Navigator.pop(ctx);
                _sendInviteSms(invite);
              },
            )
          else
            ElevatedButton.icon(
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share via…'),
              onPressed: () {
                Navigator.pop(ctx);
                Share.share(inviteShareText(invite));
              },
            ),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ]),
      ),
    ),
  );
}

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
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'Housemates',
            subtitle: "Who's living here, who's awaiting approval.",
            action: isLeaseholder
                ? ElevatedButton(onPressed: () => _showInvite(context, state), child: const Text('+ Invite'))
                : null,
          ),
          if (isLeaseholder && awaiting.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.only(top: 12, bottom: 6), child: Text('⏳ Awaiting your approval', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
            for (final u in awaiting) _ApprovalCard(user: u),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
            const Text('Active housemates', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ],
          for (final u in shown) _UserCard(user: u),
          const _LhReviewsCard(),
          if (state.invites.isNotEmpty)
            HomiesCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Pending invites', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 8),
                for (final i in state.invites)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(i.email ?? i.phone ?? 'Invite code ${i.code}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            [i.role, 'code ${i.code}', 'sent ${fmtDate(i.sentAt)}'].join(' · '),
                            style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
                          ),
                        ]),
                      ),
                      if (i.status == 'sent') ...[
                        IconButton(
                          tooltip: 'View code',
                          icon: const Icon(Icons.pin_outlined, size: 18, color: HomiesColors.textDim),
                          onPressed: () => _showInviteCode(context, i),
                        ),
                        if (i.method == 'email')
                          IconButton(
                            tooltip: 'Open in email app',
                            icon: const Icon(Icons.email_outlined, size: 18, color: HomiesColors.textDim),
                            onPressed: () => _sendInviteEmail(i),
                          )
                        else if (i.method == 'phone')
                          IconButton(
                            tooltip: 'Text invite',
                            icon: const Icon(Icons.sms_outlined, size: 18, color: HomiesColors.textDim),
                            onPressed: () => _sendInviteSms(i),
                          )
                        else
                          IconButton(
                            tooltip: 'Share invite link',
                            icon: const Icon(Icons.share_outlined, size: 18, color: HomiesColors.textDim),
                            onPressed: () => Share.share(inviteShareText(i)),
                          ),
                      ],
                    ]),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }

  void _showInvite(BuildContext context, HomiesState state) {
    final contactCtrl = TextEditingController();
    String method = 'email';
    String role = 'tenant';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) {
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Invite a housemate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            const FieldLabel('How do you want to reach them?'),
            const SizedBox(height: 8),
            Segment<String>(
              options: const ['email', 'phone', 'social'],
              value: method,
              labelFor: (v) => switch (v) { 'email' => 'Email', 'phone' => 'Phone', _ => 'Social' },
              onChanged: (v) => setSheet(() {
                method = v;
                contactCtrl.clear();
              }),
            ),
            const SizedBox(height: 16),
            if (method == 'email') ...[
              const FieldLabel('Email'),
              TextField(
                controller: contactCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'housemate@example.com'),
              ),
            ] else if (method == 'phone') ...[
              const FieldLabel('Mobile number'),
              TextField(
                controller: contactCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: '+61 4XX XXX XXX'),
              ),
            ] else
              const Text(
                "You'll get a code and link to post wherever you like — WhatsApp, Instagram, anywhere.",
                style: TextStyle(color: HomiesColors.textDim, fontSize: 12),
              ),
            const SizedBox(height: 16),
            const FieldLabel('Role'),
            Segment<String>(
              options: const ['tenant', 'leaseholder'],
              value: role,
              labelFor: (v) => v == 'tenant' ? 'Tenant' : 'Co-leaseholder',
              onChanged: (v) => setSheet(() => role = v),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final contact = contactCtrl.text.trim();
                  if (method != 'social' && contact.isEmpty) return;
                  final invite = await state.createInvite(
                    email: method == 'email' ? contact : null,
                    phone: method == 'phone' ? contact : null,
                    method: method,
                    role: role,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) _showInviteCode(context, invite);
                },
                child: const Text('Create invite'),
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
            const SizedBox(height: 6),
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
              const SizedBox(height: 6),
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
      borderColor: HomiesColors.warnBorder,
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
          hasAttachment: subs?.idDoc?.dataUrl != null || subs?.idDoc?.url != null,
          approved: user.docVerified,
          onApprove: () => approve('docVerified'),
          onReject: () => reject('docVerified'),
        ),
        _ApprovalRow(
          title: 'Bond — ${fmtAUD(user.bondAmount)}',
          sub: subs?.bondProof != null ? 'paid via ${subs!.bondProof!.method}' : 'No submission',
          hasAttachment: subs?.bondProof?.dataUrl != null || subs?.bondProof?.url != null,
          approved: user.bondPaid,
          onApprove: () => approve('bondPaid'),
          onReject: () => reject('bondPaid'),
        ),
        _ApprovalRow(
          title: 'Advance rent',
          sub: subs?.advanceRentProof != null ? 'paid via ${subs!.advanceRentProof!.method}' : 'No submission',
          hasAttachment: subs?.advanceRentProof?.dataUrl != null || subs?.advanceRentProof?.url != null,
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

// ── Leaseholder reviews ──────────────────────────────────────────────────────

class _LhReviewsCard extends StatelessWidget {
  const _LhReviewsCard();

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final leaseholders = state.activeHousemates.where((u) => u.role == 'leaseholder').toList();
    if (leaseholders.isEmpty) return const SizedBox.shrink();

    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Leaseholder reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const Text(
          'Share honest feedback about your leaseholder.',
          style: TextStyle(color: HomiesColors.textDim, fontSize: 12),
        ),
        const SizedBox(height: 12),
        for (final lh in leaseholders) _LhReviewSection(leaseholder: lh, cu: cu),
      ]),
    );
  }
}

class _LhReviewSection extends StatelessWidget {
  final User leaseholder;
  final User cu;
  const _LhReviewSection({required this.leaseholder, required this.cu});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final reviews = state.lhReviews.where((r) => r.leaseholderId == leaseholder.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final myReview = reviews.firstWhereOrNull((r) => r.fromUserId == cu.id);
    final avg = reviews.isEmpty ? 0.0 : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    final isSelf = cu.id == leaseholder.id;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Avatar(user: leaseholder),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(leaseholder.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            if (reviews.isNotEmpty)
              Row(children: [
                for (int i = 1; i <= 5; i++)
                  Icon(i <= avg.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 14, color: const Color(0xFFF5A623)),
                const SizedBox(width: 4),
                Text('${avg.toStringAsFixed(1)} (${reviews.length})',
                    style: const TextStyle(fontSize: 11, color: HomiesColors.textDim)),
              ])
            else
              const Text('No reviews yet', style: TextStyle(fontSize: 11, color: HomiesColors.textFaint)),
          ]),
        ),
        if (!isSelf)
          TextButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => _WriteReviewSheet(leaseholder: leaseholder, existing: myReview),
            ),
            child: Text(myReview == null ? 'Review' : 'Edit review'),
          ),
      ]),
      if (reviews.isNotEmpty) ...[
        const SizedBox(height: 8),
        for (final r in reviews)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: r.fromUserId == cu.id ? HomiesColors.accentSoft : HomiesColors.surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: r.fromUserId == cu.id ? HomiesColors.accentBorder : HomiesColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                for (int i = 1; i <= 5; i++)
                  Icon(i <= r.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 13, color: const Color(0xFFF5A623)),
                const SizedBox(width: 6),
                Text(
                  r.anonymous ? 'Anonymous' : r.fromUserName,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HomiesColors.textDim),
                ),
                const Spacer(),
                Text(fmtDate(r.date), style: const TextStyle(fontSize: 10, color: HomiesColors.textFaint)),
              ]),
              if (r.body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(r.body, style: const TextStyle(fontSize: 12)),
              ],
            ]),
          ),
      ],
      const Divider(height: 20),
    ]);
  }
}

class _WriteReviewSheet extends StatefulWidget {
  final User leaseholder;
  final LeaseholderReview? existing;
  const _WriteReviewSheet({required this.leaseholder, this.existing});

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  int _rating = 3;
  bool _anon = false;
  late final TextEditingController _bodyCtrl;

  @override
  void initState() {
    super.initState();
    _rating = widget.existing?.rating ?? 3;
    _anon = widget.existing?.anonymous ?? false;
    _bodyCtrl = TextEditingController(text: widget.existing?.body ?? '');
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
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
          Text(
            widget.existing == null ? 'Review ${widget.leaseholder.name.split(' ').first}' : 'Edit your review',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Rating'),
          const SizedBox(height: 8),
          Row(children: [
            for (int i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () => setState(() => _rating = i),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 34,
                    color: const Color(0xFFF5A623),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          const FieldLabel('Your thoughts (optional)'),
          TextField(
            controller: _bodyCtrl,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'What went well? What could be better?'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Checkbox(
              value: _anon,
              onChanged: (v) => setState(() => _anon = v ?? false),
            ),
            const Text('Submit anonymously', style: TextStyle(fontSize: 13)),
          ]),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                state.mutate(() {
                  state.lhReviews.removeWhere((r) => r.fromUserId == cu.id && r.leaseholderId == widget.leaseholder.id);
                  state.lhReviews.add(LeaseholderReview(
                    id: 'lhr-${Random().nextInt(0xFFFFFF).toRadixString(36)}',
                    leaseholderId: widget.leaseholder.id,
                    fromUserId: cu.id,
                    fromUserName: cu.name,
                    anonymous: _anon,
                    rating: _rating,
                    body: _bodyCtrl.text.trim(),
                    date: todayIso(),
                  ));
                });
                Navigator.pop(context);
              },
              child: const Text('Submit review'),
            ),
          ]),
        ]),
      ),
    );
  }
}
