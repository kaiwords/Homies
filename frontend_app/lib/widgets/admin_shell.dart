import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'avatar.dart';

/// Chrome for the platform admin — a slim shell with its own bottom nav for the
/// verification queue and user management. Completely separate from the
/// house-member [AppShell].
class AdminShell extends StatelessWidget {
  final Widget child;
  final String currentLocation;
  const AdminShell({super.key, required this.child, required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final user = state.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // The admin console is data-table/desktop-oriented and admin accounts
    // aren't house members, so there's no sensible mobile screen to fall
    // back to — show a plain message instead of the console on native apps.
    if (!kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Homies console')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.desktop_windows_outlined, size: 40, color: HomiesColors.textFaint),
              const SizedBox(height: 16),
              const Text('Desktop only', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: HomiesColors.text)),
              const SizedBox(height: 8),
              const Text(
                'The admin console is only available on the web. Please sign in from a desktop browser.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: HomiesColors.textDim),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () async {
                  await state.signOut();
                  if (context.mounted) context.go('/login');
                },
                child: const Text('Sign out'),
              ),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: HomiesColors.text, borderRadius: BorderRadius.circular(6)),
            child: const Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),
          const SizedBox(width: 8),
          const Text('Homies console', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 40),
              child: Padding(padding: const EdgeInsets.all(4), child: Avatar.sm(user)),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'me',
                  child: ListTile(leading: Avatar.sm(user), title: Text(user.name), subtitle: const Text('Administrator'), dense: true),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'signout', child: Text('Sign out')),
              ],
              onSelected: (v) async {
                if (v == 'signout') {
                  await state.signOut();
                  if (context.mounted) context.go('/login');
                }
              },
            ),
          ),
        ],
      ),
      body: child,
    );
  }
}

