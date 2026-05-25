import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final signedIn = state.currentUser != null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: HomiesCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: const [
                    Icon(Icons.circle, size: 14, color: HomiesColors.accent),
                    SizedBox(width: 8),
                    Text('homies', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 10),
                  const Text(
                    'Run a sharehouse without the spreadsheets. Bills, bond, chores, parties, complaints — one place, fair splits, less drama.',
                    style: TextStyle(color: HomiesColors.textDim, fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  Row(children: const [
                    Expanded(child: _Feature(icon: '💡', title: 'Bills & bond', body: 'Split utilities, track who paid, prorate by move-in date.')),
                    SizedBox(width: 10),
                    Expanded(child: _Feature(icon: '🧹', title: 'Chores', body: 'Roster, photo proof, excuses with a paper trail.')),
                  ]),
                  const SizedBox(height: 10),
                  const _Feature(icon: '🚪', title: 'Move out, cleanly', body: '2-week notice, bond release, deductions explained.'),
                  const SizedBox(height: 20),
                  if (signedIn) ...[
                    ElevatedButton(
                      onPressed: () => context.go('/app'),
                      child: Text('Continue as ${state.currentUser!.name}'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        await state.signOut();
                      },
                      child: const Text('Sign out'),
                    ),
                  ] else ...[
                    ElevatedButton(onPressed: () => context.push('/signup'), child: const Text('Create account')),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: () => context.push('/login'), child: const Text('Sign in')),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final String icon;
  final String title;
  final String body;
  const _Feature({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: HomiesColors.surface2, border: Border.all(color: HomiesColors.border), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        Text(body, style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
      ]),
    );
  }
}
