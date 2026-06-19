import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/ui_kit.dart';

/// Admin user management — add, delete, and change roles for every account.
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final admins = state.users.where((u) => u.role == 'admin').toList();
    final leaseholders = state.users.where((u) => u.role == 'leaseholder').toList();
    final tenants = state.users.where((u) => u.role == 'tenant').toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PageHead(
            title: 'Users',
            subtitle: '${state.users.length} accounts across the platform.',
            action: ElevatedButton(onPressed: () => _addUser(context, state), child: const Text('+ Add')),
          ),
          if (admins.isNotEmpty) ...[
            const _SectionLabel('Admins'),
            for (final u in admins) _UserRow(user: u),
          ],
          const _SectionLabel('Leaseholders'),
          if (leaseholders.isEmpty) const _Empty('No leaseholders yet.'),
          for (final u in leaseholders) _UserRow(user: u),
          const _SectionLabel('Tenants'),
          if (tenants.isEmpty) const _Empty('No tenants yet.'),
          for (final u in tenants) _UserRow(user: u),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _addUser(BuildContext context, HomiesState state) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String role = 'tenant';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
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
              const FieldLabel('Role'),
              Segment<String>(
                options: const ['tenant', 'leaseholder', 'admin'],
                value: role,
                labelFor: (v) => v[0].toUpperCase() + v.substring(1),
                onChanged: (v) => setSheet(() => role = v),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
                    final initials = parts.take(2).map((p) => p[0]).join().toUpperCase();
                    state.adminAddUser(User(
                      id: 'u-${Random().nextInt(0x7FFFFFFF).toRadixString(36)}',
                      name: name,
                      initials: initials.isEmpty ? '?' : initials,
                      role: role,
                      email: emailCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      member: role != 'admin',
                      pending: role == 'tenant',
                    ));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Add user'),
                ),
              ]),
            ]),
          ),
        );
      }),
    );
  }
}

class _UserRow extends StatelessWidget {
  final User user;
  const _UserRow({required this.user});

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
                HomiesChip('lease ${user.leaseStatus}',
                    tone: switch (user.leaseStatus) {
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
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: HomiesColors.danger),
                  title: Text('Delete', style: TextStyle(color: HomiesColors.danger)),
                  dense: true,
                ),
              ),
          ],
          onSelected: (v) async {
            if (v == 'role') {
              await _changeRole(context, state);
            } else if (v == 'delete') {
              await _confirmDelete(context, state);
            }
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
    if (picked != null && picked != user.role) {
      state.adminSetRole(user.id, picked);
    }
  }

  Future<void> _confirmDelete(BuildContext context, HomiesState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${user.name}?'),
        content: const Text('This permanently removes the account. This cannot be undone.'),
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
    if (ok == true) state.adminDeleteUser(user.id);
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(text, style: const TextStyle(color: HomiesColors.textFaint, fontSize: 13)));
}
