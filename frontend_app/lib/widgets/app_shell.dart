import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import 'avatar.dart';

class NavSection {
  final String path;
  final String label;
  final IconData icon;
  final String group;
  final bool leaseholderOnly;
  const NavSection(this.path, this.label, this.icon, this.group, {this.leaseholderOnly = false});
}

// Priority order: highest-use features first within each group.
const navSections = <NavSection>[
  // ── Core — daily essentials, no group label ─────────────────────────────────
  NavSection('/app',            'Dashboard',   Icons.home_outlined,                   'core'),
  NavSection('/app/finance',    'Finance',     Icons.account_balance_wallet_outlined,  'core'),
  NavSection('/app/bills',      'Bills',       Icons.receipt_long_outlined,            'core'),
  NavSection('/app/cleaning',   'Cleaning',    Icons.cleaning_services_outlined,       'core'),

  // ── My house ─────────────────────────────────────────────────────────────────
  NavSection('/app/housemates',   'Housemates',           Icons.people_outline,           'house'),
  NavSection('/app/property',     'Property & lease',     Icons.description_outlined,     'house'),
  NavSection('/app/rules',        'House rules',          Icons.gavel_outlined,           'house'),
  NavSection('/app/calendar',     'Calendar',             Icons.calendar_month_outlined,  'house'),
  NavSection('/app/maintenance',  'Maintenance contacts', Icons.contact_phone_outlined,   'house'),

  // ── Money ─────────────────────────────────────────────────────────────────────
  NavSection('/app/subscriptions', 'Subscriptions', Icons.subscriptions_outlined,  'money'),
  NavSection('/app/groceries',     'Groceries',     Icons.shopping_cart_outlined,   'money'),
  NavSection('/app/necessities',   'Necessities',   Icons.soap_outlined,            'money'),

  // ── Activities ────────────────────────────────────────────────────────────────
  NavSection('/app/parties',    'Parties',      Icons.celebration_outlined, 'activities'),
  NavSection('/app/issues',     'House issues', Icons.build_outlined,       'activities'),
  NavSection('/app/complaints', 'Complaints',   Icons.flag_outlined,        'activities'),

  // ── Community ─────────────────────────────────────────────────────────────────
  NavSection('/app/listings',    'Rooms & housemates', Icons.storefront_outlined,           'marketplace'),
  NavSection('/app/essentials',  'Essentials',         Icons.local_mall_outlined,            'marketplace'),
  NavSection('/app/marketplace', 'Marketplace',        Icons.sell_outlined,                  'marketplace'),
  // Views/inquiries on anything this person has posted to Essentials or
  // Marketplace — open to every member (tenant or leaseholder), not just
  // business accounts, since anyone can post to either of those.
  NavSection('/app/business',    'My listings & analytics', Icons.insights_outlined,         'marketplace'),

  // ── Account ───────────────────────────────────────────────────────────────────
  NavSection('/app/profile',      'Your profile',     Icons.badge_outlined,      'account'),
  NavSection('/app/performance',  'Tenant performance', Icons.insights_outlined,  'account', leaseholderOnly: true),
  NavSection('/app/leaving',      'Leaving',          Icons.logout_outlined,     'account'),
];

const _drawerGroups = ['core', 'house', 'money', 'activities', 'marketplace', 'account'];

const groupLabels = {
  'core':        '',             // no label — top-level items need no heading
  'house':       'My house',
  'money':       'Money',
  'activities':  'Activities',
  'marketplace': 'Community',
  'account':     'Account',
};

const bottomNavPaths = ['/app', '/app/finance', '/app/marketplace', '/app/essentials'];

class AppShell extends StatefulWidget {
  final Widget child;
  final String currentLocation;
  const AppShell({super.key, required this.child, required this.currentLocation});

  @override
  State<AppShell> createState() => _AppShellState();
}

// `HomiesState.mutate()` calls notifyListeners() on every mutation app-wide
// (bills, chores, messages, etc.). Using `HomiesScope.of(context)` here would
// subscribe this whole chrome (app bar, drawer, bottom nav) to *all* of that
// via InheritedNotifier, forcing a full rebuild on every unrelated change.
//
// Instead — same discipline as `_AuthRefreshNotifier` in router.dart — we
// read the notifier without subscribing to the InheritedWidget (so no
// automatic rebuild), hand-roll a listener, and only setState() when one of
// the specific values this chrome actually displays changes.
class _AppShellState extends State<AppShell> {
  HomiesState? _state;

  User? _user;
  String? _userId;
  bool _userMember = false;
  String _userRole = '';
  String _propertyAddress = '';
  int _propertyBedrooms = 0;
  int _activeCount = 0;
  int _pendingComplaints = 0;
  int _pendingTasks = 0;
  int _notifCount = 0;
  int _unreadAppNotifs = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final element = context.getElementForInheritedWidgetOfExactType<HomiesScope>();
    final newState = (element?.widget as HomiesScope?)?.notifier;
    if (newState != _state) {
      _state?.removeListener(_handleStateChanged);
      _state = newState;
      _state?.addListener(_handleStateChanged);
      _recomputeChrome();
    }
  }

  @override
  void dispose() {
    _state?.removeListener(_handleStateChanged);
    super.dispose();
  }

  void _handleStateChanged() => _recomputeChrome();

  void _recomputeChrome() {
    final state = _state;
    if (state == null) return;
    final user = state.currentUser;

    if (user == null) {
      if (_user != null || _userId != null) {
        setState(() {
          _user = null;
          _userId = null;
        });
      }
      return;
    }

    final activeCount = state.activeHousemates.length;
    final pendingComplaints = state.complaints.where((c) => c.status == 'open').length;
    final pendingTasks = state.cleaningTasks.where((t) => !t.done && (t.excuse == null || t.excuse!.isEmpty)).length;
    final uid = user.id;
    final now = DateTime.now();
    final upcomingBills = state.bills.where((b) {
      if (b.paidBy[uid] == true) return false;
      final due = DateTime.tryParse(b.dueDate);
      if (due == null) return false;
      return due.isAfter(now.subtract(const Duration(days: 1))) &&
          due.isBefore(now.add(const Duration(days: 8)));
    }).length;
    final notifCount = pendingTasks + upcomingBills;
    final unreadAppNotifs = state.appNotifications.where((n) => n.forUserId == uid && !n.isRead).length;
    final address = state.property.address;
    final bedrooms = state.property.bedrooms;

    final unchanged = uid == _userId &&
        user.member == _userMember &&
        user.role == _userRole &&
        activeCount == _activeCount &&
        pendingComplaints == _pendingComplaints &&
        pendingTasks == _pendingTasks &&
        notifCount == _notifCount &&
        unreadAppNotifs == _unreadAppNotifs &&
        address == _propertyAddress &&
        bedrooms == _propertyBedrooms;
    if (unchanged) return;

    setState(() {
      _user = user;
      _userId = uid;
      _userMember = user.member;
      _userRole = user.role;
      _activeCount = activeCount;
      _pendingComplaints = pendingComplaints;
      _pendingTasks = pendingTasks;
      _notifCount = notifCount;
      _unreadAppNotifs = unreadAppNotifs;
      _propertyAddress = address;
      _propertyBedrooms = bedrooms;
    });
  }

  int get _bottomIndex {
    final currentLocation = widget.currentLocation;
    for (var i = 0; i < bottomNavPaths.length; i++) {
      if (currentLocation == bottomNavPaths[i]) return i;
    }
    if (currentLocation.startsWith('/app/finance')) return 1;
    if (currentLocation.startsWith('/app/bills')) return 1;
    if (currentLocation.startsWith('/app/marketplace')) return 2;
    if (currentLocation.startsWith('/app/essentials')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!user.member) {
      return _MarketplaceOnlyShell(currentLocation: widget.currentLocation, user: user, child: widget.child);
    }

    final activeCount = _activeCount;
    final pendingComplaints = _pendingComplaints;
    final pendingTasks = _pendingTasks;
    final notifCount = _notifCount;
    final unreadAppNotifs = _unreadAppNotifs;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _propertyAddress,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomiesColors.text),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '$_propertyBedrooms-bed · $activeCount living here',
              style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: HomiesColors.border),
        ),
        actions: [
          // Notification bell with activity badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
                onPressed: () => context.go('/app/notifications'),
              ),
              if (notifCount > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: HomiesColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: HomiesColors.surface, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '$notifCount',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Settings gear with unread-app-notif dot
          Padding(
            padding: const EdgeInsets.only(right: 10, left: 0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const _SettingsSheet(),
                  ),
                ),
                if (unreadAppNotifs > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: HomiesColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: HomiesColors.surface, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),

      drawer: Drawer(
        backgroundColor: HomiesColors.surface,
        width: 272,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: HomiesColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.home_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'homies',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: HomiesColors.text, letterSpacing: -0.3),
                  ),
                ]),
              ),
              Container(height: 1, color: HomiesColors.border),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
                  children: [
                    for (final group in _drawerGroups) ...[
                      if (groupLabels[group]!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 5),
                          child: Text(
                            groupLabels[group]!.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: HomiesColors.textFaint,
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      for (final s in navSections.where((n) =>
                          n.group == group && (user.role == 'leaseholder' || !n.leaseholderOnly)))
                        _DrawerItem(
                          section: s,
                          active: widget.currentLocation == s.path,
                          badge: s.path == '/app/complaints' && pendingComplaints > 0
                              ? pendingComplaints
                              : s.path == '/app/cleaning' && pendingTasks > 0
                                  ? pendingTasks
                                  : null,
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // `child` is go_router's ShellRoute Navigator (owns _appShellNavigatorKey).
      // Don't re-wrap it in a keyed AnimatedSwitcher: that put two transition
      // systems on the same GlobalKey'd subtree and caused the old screen's
      // last frame to linger onscreen during navigation.
      body: widget.child,

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: HomiesColors.border)),
          color: HomiesColors.surface,
        ),
        child: BottomNavigationBar(
          currentIndex: _bottomIndex,
          onTap: (i) => context.go(bottomNavPaths[i]),
          backgroundColor: Colors.transparent,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined),                    activeIcon: Icon(Icons.home_rounded),                    label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined),  activeIcon: Icon(Icons.account_balance_wallet_rounded),  label: 'Finance'),
            BottomNavigationBarItem(icon: Icon(Icons.storefront_outlined),              activeIcon: Icon(Icons.storefront_rounded),              label: 'Marketplace'),
            BottomNavigationBarItem(icon: Icon(Icons.local_mall_outlined),              activeIcon: Icon(Icons.local_mall_rounded),              label: 'Essentials'),
          ],
        ),
      ),
    );
  }
}

// ─── Settings sheet ───────────────────────────────────────────────────────────

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final user = state.currentUser!;
    final displayName = user.name.replaceAll(RegExp(r'^You \('), '').replaceAll(RegExp(r'\)$'), '');
    final unreadNotifs = state.appNotifications.where((n) => n.forUserId == user.id && !n.isRead).length;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(color: HomiesColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Profile header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(children: [
              Avatar(user: user),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: HomiesColors.text)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: HomiesColors.accentSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user.role[0].toUpperCase() + user.role.substring(1),
                      style: const TextStyle(fontSize: 11, color: HomiesColors.accentStrong, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),
            ]),
          ),

          Container(height: 1, color: HomiesColors.border),

          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            badge: unreadNotifs,
            onTap: () {
              Navigator.pop(context);
              context.go('/app/notifications');
            },
          ),

          // ── Remind me about ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
            child: Text(
              'REMIND ME ABOUT',
              style: const TextStyle(fontSize: 10, color: HomiesColors.textFaint, letterSpacing: 1.0, fontWeight: FontWeight.w700),
            ),
          ),
          _RemindToggle(
            icon: Icons.home_outlined,
            label: 'Rent due',
            value: state.notifPrefs.rent,
            onChanged: (v) {
              state.mutate(() => state.notifPrefs.rent = v);
              NotificationService.scheduleFromState(state);
            },
          ),
          _RemindToggle(
            icon: Icons.receipt_long_outlined,
            label: 'Bills due',
            value: state.notifPrefs.bills,
            onChanged: (v) {
              state.mutate(() => state.notifPrefs.bills = v);
              NotificationService.scheduleFromState(state);
            },
          ),
          _RemindToggle(
            icon: Icons.cleaning_services_outlined,
            label: 'Chores due',
            value: state.notifPrefs.chores,
            onChanged: (v) {
              state.mutate(() => state.notifPrefs.chores = v);
              NotificationService.scheduleFromState(state);
            },
          ),
          _RemindToggle(
            icon: Icons.swap_horiz_rounded,
            label: 'Chore swap requests',
            value: state.notifPrefs.parties,
            onChanged: (v) {
              state.mutate(() => state.notifPrefs.parties = v);
              NotificationService.scheduleFromState(state);
            },
          ),
          _RemindToggle(
            icon: Icons.event_repeat_outlined,
            label: 'Recurring service reminders',
            value: state.notifPrefs.essentialServices,
            onChanged: (v) {
              state.mutate(() => state.notifPrefs.essentialServices = v);
              NotificationService.scheduleFromState(state);
            },
          ),

          Container(height: 1, color: HomiesColors.border),

          // ── Theme ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
            child: Text(
              'APPEARANCE',
              style: const TextStyle(fontSize: 10, color: HomiesColors.textFaint, letterSpacing: 1.0, fontWeight: FontWeight.w700),
            ),
          ),
          _RemindToggle(
            icon: Icons.dark_mode_outlined,
            label: 'Dark mode',
            value: state.notifPrefs.darkMode,
            onChanged: (v) => state.mutate(() => state.notifPrefs.darkMode = v),
          ),

          Container(height: 1, color: HomiesColors.border),

          _SettingsTile(
            icon: Icons.badge_outlined,
            label: 'Your profile',
            onTap: () {
              Navigator.pop(context);
              context.go('/app/profile');
            },
          ),
          _SettingsTile(
            icon: Icons.insights_outlined,
            label: 'Tenant performance',
            onTap: () {
              Navigator.pop(context);
              context.go('/app/performance');
            },
          ),
          _SettingsTile(
            icon: Icons.gavel_outlined,
            label: 'Terms & conditions',
            onTap: () {
              Navigator.pop(context);
              context.go('/app/terms');
            },
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy policy & terms',
            onTap: () {
              Navigator.pop(context);
              context.push('/legal');
            },
          ),

          Container(height: 1, color: HomiesColors.border),

          // Demo account switching is a debug-only convenience — compiled out of release builds.
          if (kDebugMode)
            _SettingsTile(
              icon: Icons.swap_horiz_rounded,
              label: 'Switch demo account',
              onTap: () {
                Navigator.pop(context);
                context.push('/demo');
              },
            ),
          _SettingsTile(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            color: HomiesColors.danger,
            onTap: () async {
              Navigator.pop(context);
              await state.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
          _SettingsTile(
            icon: Icons.delete_forever_outlined,
            label: 'Delete account',
            color: HomiesColors.danger,
            onTap: () async {
              final deleted = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => const _DeleteAccountDialog(),
              );
              if (deleted == true && context.mounted) {
                Navigator.pop(context); // close the settings sheet
                context.go('/login');
              }
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Delete account (confirmation + reauth) ──────────────────────────────────
//
// Apple Guideline 5.1.1(v): apps that let users create an account must let them
// initiate account deletion from within the app. Firebase requires a recent
// login before deletion, so real accounts must re-enter their password here;
// demo / local-only sessions skip the password entirely.

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm(HomiesState state, {required bool needsPassword}) async {
    if (needsPassword && _passCtrl.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await state.deleteAccount(_passCtrl.text);
    if (!mounted) return;
    if (result.ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = result.error ?? 'Could not delete your account.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final needsPassword = state.hasFirebaseAccount;

    return AlertDialog(
      title: const Text('Delete account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently deletes your account. This cannot be undone.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 10),
          const Text('This removes:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...const [
            'Your sign-in and profile details',
            'Your membership of your current house',
            'Your saved reminders and preferences on this device',
          ].map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('•  $t', style: const TextStyle(fontSize: 13, height: 1.4, color: HomiesColors.textDim)),
              )),
          if (needsPassword) ...[
            const SizedBox(height: 14),
            const Text(
              'Re-enter your password to confirm.',
              style: TextStyle(fontSize: 13, color: HomiesColors.textDim),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              enabled: !_busy,
              decoration: const InputDecoration(hintText: 'Password'),
              onSubmitted: (_) => _busy ? null : _confirm(state, needsPassword: needsPassword),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(fontSize: 13, color: HomiesColors.danger)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _busy ? null : () => _confirm(state, needsPassword: needsPassword),
          style: TextButton.styleFrom(foregroundColor: HomiesColors.danger),
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Delete account'),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badge;
  final Color? color;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.badge = 0,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = color ?? HomiesColors.text;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(children: [
          Icon(icon, size: 20, color: color ?? HomiesColors.textDim),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14, color: fg, fontWeight: FontWeight.w500)),
          ),
          if (badge > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: HomiesColors.accent, borderRadius: BorderRadius.circular(20)),
              child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          if (color == null)
            const Icon(Icons.chevron_right, size: 18, color: HomiesColors.textFaint),
        ]),
      ),
    );
  }
}

// ─── Remind toggle (inline switch row in settings sheet) ─────────────────────

class _RemindToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _RemindToggle({required this.icon, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(children: [
        Icon(icon, size: 18, color: HomiesColors.textDim),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: HomiesColors.text))),
        Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }
}

// ─── Marketplace-only shell (non-member) ─────────────────────────────────────

const _businessNavPaths = ['/app/essentials', '/app/marketplace', '/app/business'];

class _MarketplaceOnlyShell extends StatelessWidget {
  final String currentLocation;
  final User user;
  final Widget child;
  const _MarketplaceOnlyShell({required this.currentLocation, required this.user, required this.child});

  int get _businessBottomIndex {
    final i = _businessNavPaths.indexOf(currentLocation);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final isBusiness = user.role == 'business';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isBusiness ? 'Business' : 'Marketplace',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomiesColors.text)),
            Text(isBusiness ? 'Manage your listings & analytics' : 'Get invited to unlock your house',
                style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: HomiesColors.border),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => SafeArea(
                  top: false,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: HomiesColors.textFaint, borderRadius: BorderRadius.circular(2)),
                    ),
                    ListTile(
                      leading: Avatar.sm(user),
                      title: Text(user.name),
                      subtitle: const Text('Browsing'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded, color: HomiesColors.danger),
                      title: const Text('Sign out', style: TextStyle(color: HomiesColors.danger)),
                      onTap: () async {
                        Navigator.pop(context);
                        await state.signOut();
                        if (context.mounted) context.go('/login');
                      },
                    ),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: isBusiness
          ? Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: HomiesColors.border)),
                color: HomiesColors.surface,
              ),
              child: BottomNavigationBar(
                currentIndex: _businessBottomIndex,
                onTap: (i) => context.go(_businessNavPaths[i]),
                backgroundColor: Colors.transparent,
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.local_mall_outlined),
                      activeIcon: Icon(Icons.local_mall_rounded),
                      label: 'Essentials'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.storefront_outlined),
                      activeIcon: Icon(Icons.storefront_rounded),
                      label: 'Marketplace'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.insights_outlined),
                      activeIcon: Icon(Icons.insights_rounded),
                      label: 'Analytics'),
                ],
              ),
            )
          : null,
    );
  }
}

// ─── Drawer item ──────────────────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final NavSection section;
  final bool active;
  final int? badge;
  const _DrawerItem({required this.section, required this.active, this.badge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () {
            final nav = Navigator.of(context);
            if (nav.canPop()) nav.pop();
            context.go(section.path);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: active ? HomiesColors.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  section.icon,
                  key: ValueKey(active),
                  color: active ? HomiesColors.accent : HomiesColors.textFaint,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.label,
                  style: TextStyle(
                    color: active ? HomiesColors.accentStrong : HomiesColors.text,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: HomiesColors.danger,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
