import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'avatar.dart';

class NavSection {
  final String path;
  final String label;
  final IconData icon;
  final String group;
  const NavSection(this.path, this.label, this.icon, this.group);
}

const navSections = <NavSection>[
  NavSection('/app', 'Dashboard', Icons.home_outlined, 'primary'),
  NavSection('/app/property', 'Property & lease', Icons.description_outlined, 'primary'),
  NavSection('/app/housemates', 'Housemates', Icons.people_outline, 'primary'),
  NavSection('/app/bills', 'Bills', Icons.receipt_long_outlined, 'money'),
  NavSection('/app/subscriptions', 'Subscriptions', Icons.subscriptions_outlined, 'money'),
  NavSection('/app/groceries', 'Groceries', Icons.shopping_cart_outlined, 'money'),
  NavSection('/app/necessities', 'Necessities', Icons.cleaning_services_outlined, 'money'),
  NavSection('/app/cleaning', 'Cleaning', Icons.cleaning_services_outlined, 'living'),
  NavSection('/app/rules', 'House rules', Icons.gavel_outlined, 'living'),
  NavSection('/app/parties', 'Parties', Icons.celebration_outlined, 'living'),
  NavSection('/app/messages', 'Messages', Icons.chat_bubble_outline, 'living'),
  NavSection('/app/issues', 'House issues', Icons.build_outlined, 'living'),
  NavSection('/app/complaints', 'Complaints', Icons.flag_outlined, 'living'),
  NavSection('/app/leaving', 'Leaving', Icons.logout_outlined, 'exit'),
  NavSection('/app/termination', 'End of lease', Icons.event_busy_outlined, 'exit'),
];

const groupLabels = {
  'primary': '',
  'money': 'Money',
  'living': 'Living together',
  'exit': 'Wrap up',
};

const bottomNavPaths = ['/app', '/app/bills', '/app/cleaning', '/app/messages'];

class AppShell extends StatelessWidget {
  final Widget child;
  final String currentLocation;
  const AppShell({super.key, required this.child, required this.currentLocation});

  int get _bottomIndex {
    for (var i = 0; i < bottomNavPaths.length; i++) {
      if (currentLocation == bottomNavPaths[i]) return i;
    }
    if (currentLocation.startsWith('/app/bills')) return 1;
    if (currentLocation.startsWith('/app/cleaning')) return 2;
    if (currentLocation.startsWith('/app/messages')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final user = state.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/login'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final activeCount = state.activeHousemates.length;
    final pendingComplaints = state.complaints.where((c) => c.status == 'open').length;
    final pendingTasks = state.cleaningTasks.where((t) => !t.done && (t.excuse == null || t.excuse!.isEmpty)).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.property.address,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            Text(
              '${state.property.bedrooms}-bed · $activeCount living here',
              style: const TextStyle(fontSize: 11, color: HomiesColors.textDim),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 40),
              child: Padding(padding: const EdgeInsets.all(4), child: Avatar.sm(user)),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'profile',
                  child: ListTile(
                    leading: Avatar.sm(user),
                    title: Text(user.name.replaceAll(RegExp(r'^You \('), '').replaceAll(RegExp(r'\)$'), '')),
                    subtitle: Text(user.role),
                  ),
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
      drawer: Drawer(
        backgroundColor: HomiesColors.surface,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(children: [
                  Icon(Icons.circle, color: HomiesColors.accent, size: 12),
                  SizedBox(width: 8),
                  Text('homies', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                ]),
              ),
              for (final group in ['primary', 'money', 'living', 'exit']) ...[
                if (group != 'primary')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
                    child: Text(groupLabels[group]!.toUpperCase(),
                        style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint, letterSpacing: 0.7, fontWeight: FontWeight.w600)),
                  ),
                for (final s in navSections.where((n) =>
                    n.group == group && (user.role == 'leaseholder' || n.path != '/app/termination')))
                  _DrawerItem(
                    section: s,
                    active: currentLocation == s.path,
                    badge: s.label == 'Complaints' && pendingComplaints > 0
                        ? pendingComplaints
                        : s.label == 'Cleaning' && pendingTasks > 0
                            ? pendingTasks
                            : null,
                  ),
              ],
            ],
          ),
        ),
      ),
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: (i) => context.go(bottomNavPaths[i]),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Bills'),
          BottomNavigationBarItem(icon: Icon(Icons.cleaning_services_outlined), label: 'Cleaning'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final NavSection section;
  final bool active;
  final int? badge;
  const _DrawerItem({required this.section, required this.active, this.badge});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(section.icon, color: active ? HomiesColors.accent : HomiesColors.textDim, size: 22),
      title: Text(section.label,
          style: TextStyle(
              color: active ? HomiesColors.accentStrong : HomiesColors.text,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              fontSize: 14)),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: HomiesColors.accent, borderRadius: BorderRadius.circular(20)),
              child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            )
          : null,
      tileColor: active ? HomiesColors.accentSoft : null,
      onTap: () {
        Navigator.pop(context);
        context.go(section.path);
      },
    );
  }
}
