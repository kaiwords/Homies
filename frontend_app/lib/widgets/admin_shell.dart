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

