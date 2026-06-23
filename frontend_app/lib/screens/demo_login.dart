import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../state/seed.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/ui_kit.dart';

/// Lets anyone explore the app instantly by signing in as a pre-seeded
/// housemate — no username or password required.
class DemoLoginScreen extends StatelessWidget {
  const DemoLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final currentUser = state.currentUser;
    final demoUsers = SeedData.users();
    final admins = demoUsers.where((u) => u.role == 'admin').toList();
    final leaseholders = demoUsers.where((u) => u.role == 'leaseholder').toList();
    final tenants = demoUsers.where((u) => u.role == 'tenant').toList();

    void enter(User u) {
      state.signInAs(u);
      context.go(u.role == 'admin' ? '/admin' : '/app');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Demo accounts')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const InfoBanner(
                    icon: Icons.bolt_rounded,
                    text: 'Pick a housemate to jump straight in — no username or password needed.',
                  ),
                  const SizedBox(height: 16),
                  if (admins.isNotEmpty && currentUser?.isAdmin == true) ...[
                    const _GroupLabel('ADMIN'),
                    const SizedBox(height: 8),
                    for (final u in admins) _DemoAccountTile(user: u, onTap: () => enter(u)),
                    const SizedBox(height: 18),
                  ],
                  const _GroupLabel('LEASEHOLDERS'),
                  const SizedBox(height: 8),
                  for (final u in leaseholders) _DemoAccountTile(user: u, onTap: () => enter(u)),
                  const SizedBox(height: 18),
                  const _GroupLabel('TENANTS'),
                  const SizedBox(height: 8),
                  for (final u in tenants) _DemoAccountTile(user: u, onTap: () => enter(u)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          color: HomiesColors.textFaint,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      );
}

class _DemoAccountTile extends StatelessWidget {
  final User user;
  final VoidCallback onTap;
  const _DemoAccountTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final roleLabel = switch (user.role) {
      'admin' => 'Admin',
      'leaseholder' => 'Leaseholder',
      _ => 'Tenant',
    };
    final roleTone = switch (user.role) {
      'admin' => ChipTone.neutral,
      'leaseholder' => ChipTone.accent,
      _ => ChipTone.info,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HomiesColors.surface,
              border: Border.all(color: HomiesColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Avatar.lg(user),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(user.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: HomiesColors.text)),
                          ),
                          const SizedBox(width: 8),
                          HomiesChip(roleLabel, tone: roleTone),
                          if (user.pending) ...[
                            const SizedBox(width: 6),
                            const HomiesChip('Onboarding', tone: ChipTone.warn),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: HomiesColors.textDim)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: HomiesColors.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
