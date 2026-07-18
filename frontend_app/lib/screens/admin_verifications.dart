import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/ui_kit.dart';

/// Unified admin console — lease verifications + user management on one page.
/// Both sections read from [HomiesState.adminAllUsers], a live query over
/// every real account (not the house-scoped `state.users`, which for an
/// admin — who has no house — would only ever contain their own record).
class AdminVerificationsScreen extends StatefulWidget {
  const AdminVerificationsScreen({super.key});

  @override
  State<AdminVerificationsScreen> createState() => _AdminVerificationsScreenState();
}

class _AdminVerificationsScreenState extends State<AdminVerificationsScreen> {
  bool _syncStarted = false;
  // Captured while the widget is still in the tree — an inherited-widget lookup
  // in dispose() throws, so we save the reference here and reuse it.
  HomiesState? _state;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state = HomiesScope.of(context);
    if (_syncStarted) return;
    _syncStarted = true;
    _state!.startAdminUsersSync();
  }

  @override
  void dispose() {
    _state?.stopAdminUsersSync();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final leaseholders = state.adminAllUsers.where((u) => u.role == 'leaseholder').toList();
    final pending = leaseholders.where((u) => u.leaseStatus == 'pending').toList();
    final reviewed = leaseholders.where((u) => u.leaseStatus == 'verified' || u.leaseStatus == 'rejected').toList();
    final notSubmitted = leaseholders.where((u) => u.leaseStatus == 'none').toList();

    final admins = state.adminAllUsers.where((u) => u.role == 'admin').toList();
    final leaseholderUsers = leaseholders;
    final tenants = state.adminAllUsers.where((u) => u.role == 'tenant').toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Lease verifications ──────────────────────────────────────────
          const PageHead(
            title: 'Admin console',
            subtitle: 'Lease verifications and user management.',
          ),
          _StatRow(pending: pending.length, verified: leaseholders.where((u) => u.leaseStatus == 'verified').length),
          const SizedBox(height: 8),
          if (pending.isEmpty)
            const InfoBanner(icon: Icons.check_circle_outline, text: 'No lease verifications waiting.')
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

          // ── Users ────────────────────────────────────────────────────────
          const Padding(padding: EdgeInsets.only(top: 24), child: Divider()),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              const Expanded(child: _SectionLabel('Users')),
              ElevatedButton(
                onPressed: () => _addUser(context, state),
                child: const Text('+ Add'),
              ),
            ]),
          ),
          if (admins.isNotEmpty) ...[
            const _SectionLabel('Admins'),
            for (final u in admins) _AdminUserRow(user: u),
          ],
          const _SectionLabel('Leaseholders'),
          if (leaseholderUsers.isEmpty) const _Empty('No leaseholders yet.'),
          for (final u in leaseholderUsers) _AdminUserRow(user: u),
          const _SectionLabel('Tenants'),
          if (tenants.isEmpty) const _Empty('No tenants yet.'),
          for (final u in tenants) _AdminUserRow(user: u),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _addUser(BuildContext context, HomiesState state) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String role = 'tenant';
    String? error;
    bool submitting = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        Future<void> submit() async {
          final name = nameCtrl.text.trim();
          final email = emailCtrl.text.trim();
          final password = passwordCtrl.text;
          if (name.isEmpty || email.isEmpty) {
            setSheet(() => error = 'Name and email are required.');
            return;
          }
          if (password.length < 6) {
            setSheet(() => error = 'Password must be at least 6 characters.');
            return;
          }
          setSheet(() {
            submitting = true;
            error = null;
          });
          final result = await state.adminCreateUser(
            name: name,
            email: email,
            password: password,
            phone: phoneCtrl.text.trim(),
            role: role,
          );
          if (!result.ok) {
            setSheet(() {
              submitting = false;
              error = result.error;
            });
            return;
          }
          if (ctx.mounted) Navigator.pop(ctx);
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Add user', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const FieldLabel('Full name'),
              TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Jane Doe')),
              const SizedBox(height: 10),
              const FieldLabel('Email'),
              TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'jane@example.com')),
              const SizedBox(height: 10),
              const FieldLabel('Phone'),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '0400 000 000')),
              const SizedBox(height: 10),
              const FieldLabel('Password'),
              TextField(controller: passwordCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'At least 6 characters')),
              const Hint("This is a real login — share it with the person you're adding."),
              const SizedBox(height: 10),
              const FieldLabel('Role'),
              Segment<String>(
                options: const ['tenant', 'leaseholder', 'admin'],
                value: role,
                labelFor: (v) => v[0].toUpperCase() + v.substring(1),
                onChanged: (v) => setSheet(() => role = v),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: HomiesColors.danger, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: submitting ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: submitting ? null : submit,
                  child: submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add user'),
                ),
              ]),
            ]),
          ),
        );
      }),
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
      borderColor: status == 'pending' ? HomiesColors.warnBorder : null,
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
                onPressed: () async {
                  await state.reviewLeaseVerification(user.id, 'verified');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user.name} verified ✓')));
                  }
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
          const SizedBox(height: 14),
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
      await state.reviewLeaseVerification(user.id, 'rejected', note: ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
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

class _AdminUserRow extends StatelessWidget {
  final User user;
  const _AdminUserRow({required this.user});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final isSelf = user.id == state.currentUser?.id;
    return HomiesCard(
      child: Row(children: [
        Avatar.lg(user),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              HomiesChip(user.role, tone: switch (user.role) {
                'admin' => ChipTone.neutral,
                'leaseholder' => ChipTone.accent,
                _ => ChipTone.info,
              }),
              if (user.role == 'leaseholder' && user.leaseStatus != 'none')
                HomiesChip('lease ${user.leaseStatus}', tone: switch (user.leaseStatus) {
                  'verified' => ChipTone.ok,
                  'rejected' => ChipTone.danger,
                  _ => ChipTone.warn,
                }),
              if (user.pending) const HomiesChip('onboarding', tone: ChipTone.warn),
            ]),
            const SizedBox(height: 2),
            Text(user.email, style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
          ]),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: HomiesColors.textDim),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'role', child: ListTile(leading: Icon(Icons.swap_horiz), title: Text('Change role'), dense: true)),
            if (!isSelf)
              const PopupMenuItem(value: 'delete', child: ListTile(
                leading: Icon(Icons.delete_outline, color: HomiesColors.danger),
                title: Text('Delete', style: TextStyle(color: HomiesColors.danger)),
                dense: true,
              )),
          ],
          onSelected: (v) async {
            if (v == 'role' && context.mounted) await _changeRole(context, state);
            if (v == 'delete' && context.mounted) await _confirmDelete(context, state);
          },
        ),
      ]),
    );
  }

  Future<void> _changeRole(BuildContext context, HomiesState state) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(14), child: Text('Set role', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
          for (final r in const ['tenant', 'leaseholder', 'admin'])
            ListTile(
              leading: Icon(user.role == r ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: user.role == r ? HomiesColors.accent : HomiesColors.textFaint),
              title: Text(r[0].toUpperCase() + r.substring(1)),
              onTap: () => Navigator.pop(context, r),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked != null && picked != user.role) await state.adminSetRole(user.id, picked);
  }

  Future<void> _confirmDelete(BuildContext context, HomiesState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${user.name}?'),
        content: const Text(
          'Removes their profile from Homies. Their login stays active — if they sign back in '
          "they'll get a fresh, unverified account.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: HomiesColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final result = await state.adminDeleteUser(user.id);
      if (!result.ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to delete user.')),
        );
      }
    }
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(text, style: const TextStyle(color: HomiesColors.textFaint, fontSize: 13)),
      );
}
