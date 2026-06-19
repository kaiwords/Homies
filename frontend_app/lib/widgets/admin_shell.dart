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

  static const _tabs = ['/admin', '/admin/users'];

  int get _index {
    if (currentLocation.startsWith('/admin/users')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final user = state.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pending = state.pendingLeaseVerifications.length;

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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => context.go(_tabs[i]),
        items: [
          BottomNavigationBarItem(
            icon: _BadgeIcon(icon: Icons.verified_outlined, count: pending),
            activeIcon: _BadgeIcon(icon: Icons.verified, count: pending),
            label: 'Verifications',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.group_outlined), activeIcon: Icon(Icons.group), label: 'Users'),
        ],
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  const _BadgeIcon({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return Icon(icon);
    return Stack(clipBehavior: Clip.none, children: [
      Icon(icon),
      Positioned(
        right: -6,
        top: -4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: HomiesColors.accent, borderRadius: BorderRadius.circular(20)),
          child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }
}
