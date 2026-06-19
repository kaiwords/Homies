import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/ui_kit.dart';
import 'signup.dart' show InviteHandoff;

class AcceptInviteScreen extends StatelessWidget {
  final String code;
  const AcceptInviteScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final invite = state.invites.firstWhereOrNull((i) => i.code == code);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: HomiesCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text("You've been invited 🎉", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (invite != null) ...[
                    Text('You were invited to join ${state.property.address} as a ${invite.role}.',
                        style: const TextStyle(color: HomiesColors.textDim)),
                    const SizedBox(height: 12),
                    HomiesCard(
                      color: HomiesColors.surface2,
                      child: Column(children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('Invite code', style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                          Text(invite.code, style: const TextStyle(fontFamily: 'monospace')),
                        ]),
                        const SizedBox(height: 6),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('Sent to', style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                          Text(invite.email),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.push(
                        '/signup',
                        extra: InviteHandoff(code: invite.code, email: invite.email, role: invite.role),
                      ),
                      child: const Text('Accept & create account'),
                    ),
                  ] else
                    const Text("That invite code isn't recognised. Ask the leaseholder for a fresh link.",
                        style: TextStyle(color: HomiesColors.textDim)),
                  const SizedBox(height: 12),
                  TextButton(onPressed: () => context.go('/'), child: const Text('Back to home')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
