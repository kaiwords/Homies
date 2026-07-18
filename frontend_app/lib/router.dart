import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'state/app_state.dart';
import 'screens/accept_invite.dart';
import 'screens/admin_verifications.dart';
import 'screens/business_dashboard.dart';
import 'screens/finance.dart';
import 'screens/bills.dart';
import 'screens/cleaning.dart';
import 'screens/complaints.dart';
import 'screens/dashboard.dart';
import 'screens/essentials.dart';
import 'screens/demo_login.dart';
import 'screens/groceries.dart';
import 'screens/house_rules.dart';
import 'screens/housemates.dart';
import 'screens/issues.dart';
import 'screens/leaseholder_onboarding.dart';
import 'screens/leaving.dart';
import 'screens/legal.dart';
import 'screens/listings.dart';
import 'screens/login.dart';
import 'screens/marketplace.dart';
import 'screens/messages.dart';
import 'screens/calendar.dart';
import 'screens/my_spending.dart';
import 'screens/necessities.dart';
import 'screens/maintenance_contacts.dart';
import 'screens/welcome_guide.dart';
import 'screens/notifications.dart';
import 'screens/shopping_list.dart';
import 'screens/parties.dart';
import 'screens/profile.dart';
import 'screens/property.dart';
import 'screens/tenant_performance.dart';
import 'screens/signup.dart' show SignupScreen, InviteHandoff;
import 'screens/subscriptions.dart';
import 'screens/tenant_onboarding.dart';
import 'screens/terms.dart';
import 'screens/welcome.dart';
import 'widgets/admin_shell.dart';
import 'widgets/app_shell.dart';

/// Notifies GoRouter only when auth-relevant state changes (sign-in, sign-out,
/// role/member change). Using the full HomiesState as refreshListenable triggers
/// a redirect re-evaluation on every mutate() call (bills, messages, etc.),
/// which races with in-progress navigations and causes GoRouter/Navigator
/// assertion failures.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(HomiesState state) {
    // Firebase auth state (real sign-in / sign-out).
    // Deferred to post-frame so we never call notifyListeners() while Flutter
    // is mid-build / mid-navigation, which causes the lifecycle assertion.
    //
    // The router is built on the very first frame (see main.dart), before
    // the background Firebase.initializeApp() call has necessarily finished,
    // so FirebaseAuth.instance can throw core/no-app here. Wait for the
    // default app to exist before subscribing.
    _listenForAuthChanges();

    // Demo / local session changes — only fire when session.userId, role, or
    // member actually changes, not on every unrelated mutate().
    String? lastUserId;
    String? lastRole;
    bool? lastMember;
    state.addListener(() {
      final id = state.session.userId;
      final role = state.currentUser?.role;
      final member = state.currentUser?.member;
      if (id != lastUserId || role != lastRole || member != lastMember) {
        lastUserId = id;
        lastRole = role;
        lastMember = member;
        _notify();
      }
    });
  }

  void _listenForAuthChanges() {
    if (Firebase.apps.isEmpty) {
      Future.delayed(const Duration(milliseconds: 200), _listenForAuthChanges);
      return;
    }
    fb.FirebaseAuth.instance.authStateChanges().listen((_) => _notify());
  }

  bool _pending = false;

  void _notify() {
    if (_pending) return;
    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (hasListeners) notifyListeners();
    });
  }
}

// go_router keys each Navigator internally via GlobalObjectKey(navigatorKey.hashCode).
// Left unspecified, it auto-generates a fresh GlobalKey<NavigatorState> per
// route/rebuild, and if an old one is still referenced when a new one is
// created, their hashCodes can collide and throw "Duplicate GlobalKey" during
// tree finalization -- observed on Flutter Web, where identity hashCodes have
// a much smaller range than on the native VM. Explicit, stable, module-level
// keys sidestep that entirely.
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _appShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'app');
final _adminShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'admin');

GoRouter buildRouter(HomiesState state) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: _AuthRefreshNotifier(state),
    redirect: (context, goState) {
      final loc = goState.uri.path;
      final inApp = loc.startsWith('/app');
      final inAdmin = loc.startsWith('/admin');
      final user = state.currentUser;
      // Admins live in the admin console; keep them out of the house app.
      if (user != null && user.role == 'admin') {
        return inAdmin ? null : '/admin';
      }
      // Non-admins can't reach the admin console.
      if (inAdmin) return user == null ? '/login' : '/app';
      if (!inApp) return null;
      // Not signed in — bounce protected routes to login.
      if (user == null) return '/login';
      // Signed in but not invited into a house — restricted to a small set of
      // pages. Business accounts have no house/lease features at all, so they
      // get their own seller-focused pages instead of the room marketplace.
      if (!user.member) {
        final allowed = user.role == 'business'
            ? const {'/app/essentials', '/app/marketplace', '/app/business'}
            : const {'/app/listings'};
        if (!allowed.contains(loc)) {
          return user.role == 'business' ? '/app/essentials' : '/app/listings';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      // Demo login is a debug-only convenience — compiled out of release builds
      // so it can't be used as a backdoor into the app.
      if (kDebugMode) GoRoute(path: '/demo', builder: (_, _) => const DemoLoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (_, s) {
          final extra = s.extra;
          return SignupScreen(invite: extra is InviteHandoff ? extra : null);
        },
      ),
      GoRoute(path: '/invite/:code', builder: (_, s) => AcceptInviteScreen(code: s.pathParameters['code']!)),
      // Privacy Policy + Terms of Service. A normal (non-debug) top-level route
      // so it's reachable both before sign-in (from signup) and from settings,
      // and can be surfaced in store metadata.
      GoRoute(path: '/legal', builder: (_, _) => const LegalScreen()),
      GoRoute(path: '/onboarding/leaseholder', builder: (_, _) => const LeaseholderOnboardingScreen()),
      GoRoute(path: '/onboarding/tenant', builder: (_, _) => const TenantOnboardingScreen()),
      ShellRoute(
        navigatorKey: _appShellNavigatorKey,
        builder: (context, state, child) => AppShell(currentLocation: state.uri.path, child: child),
        routes: [
          // These are flat sibling "destinations" reached via the bottom nav
          // bar / drawer, not a drill-down stack -- every one of them shares
          // the single `_appShellNavigatorKey` Navigator, so switching between
          // any two of them is a same-navigator page *replace* (old route's
          // key leaves the pages list, new route's key enters it), not a
          // push/pop of a growing stack.
          //
          // With the default `builder:` (no `pageBuilder:`), go_router wraps
          // each screen in a plain `MaterialPage`, so that replace plays the
          // theme's full push/pop transition (Android: ZoomPageTransitionsBuilder
          // fade+scale, ~300ms) between the two *independent* screens. None of
          // these screens own an opaque Scaffold (they're bare `SafeArea`s that
          // rely on AppShell's single outer Scaffold for background/chrome), so
          // for the whole transition window both the outgoing and incoming
          // screen are simultaneously partially visible/animating in the same
          // body area -- what reads as "the previous screen lingers before the
          // next one appears" when tapping between tabs (e.g. Essentials <->
          // Marketplace). `NoTransitionPage` makes the swap instant (matching
          // how a tab bar is expected to behave) and removes that window
          // entirely. Drill-down navigation from within a screen (e.g. opening
          // a listing's detail page) is unaffected -- those go through plain
          // `Navigator.push(MaterialPageRoute(...))` on the inner navigator,
          // not through these GoRoutes, so they keep their normal push
          // animation.
          GoRoute(path: '/app', pageBuilder: (_, _) => const NoTransitionPage(child: DashboardScreen())),
          GoRoute(path: '/app/profile', pageBuilder: (_, _) => const NoTransitionPage(child: ProfileScreen())),
          GoRoute(path: '/app/property', pageBuilder: (_, _) => const NoTransitionPage(child: PropertyScreen())),
          GoRoute(path: '/app/housemates', pageBuilder: (_, _) => const NoTransitionPage(child: HousematesScreen())),
          GoRoute(path: '/app/performance', pageBuilder: (_, _) => const NoTransitionPage(child: TenantPerformanceScreen())),
          GoRoute(path: '/app/listings', pageBuilder: (_, _) => const NoTransitionPage(child: ListingsScreen())),
          GoRoute(path: '/app/bills', pageBuilder: (_, _) => const NoTransitionPage(child: BillsScreen())),
          GoRoute(path: '/app/subscriptions', pageBuilder: (_, _) => const NoTransitionPage(child: SubscriptionsScreen())),
          GoRoute(path: '/app/groceries', pageBuilder: (_, _) => const NoTransitionPage(child: GroceriesScreen())),
          GoRoute(path: '/app/necessities', pageBuilder: (_, _) => const NoTransitionPage(child: NecessitiesScreen())),
          GoRoute(path: '/app/cleaning', pageBuilder: (_, _) => const NoTransitionPage(child: CleaningScreen())),
          GoRoute(path: '/app/rules', pageBuilder: (_, _) => const NoTransitionPage(child: HouseRulesScreen())),
          GoRoute(path: '/app/parties', pageBuilder: (_, _) => const NoTransitionPage(child: PartiesScreen())),
          GoRoute(path: '/app/messages', pageBuilder: (_, _) => const NoTransitionPage(child: MessagesScreen())),
          GoRoute(path: '/app/issues', pageBuilder: (_, _) => const NoTransitionPage(child: IssuesScreen())),
          GoRoute(path: '/app/complaints', pageBuilder: (_, _) => const NoTransitionPage(child: ComplaintsScreen())),
          GoRoute(path: '/app/finance', pageBuilder: (_, _) => const NoTransitionPage(child: FinanceScreen())),
          GoRoute(path: '/app/my-spending', pageBuilder: (_, _) => const NoTransitionPage(child: MySpendingScreen())),
          GoRoute(path: '/app/shopping', pageBuilder: (_, s) => const NoTransitionPage(child: ShoppingListScreen())),
          GoRoute(path: '/app/notifications', pageBuilder: (_, s) => const NoTransitionPage(child: NotificationsScreen())),
          GoRoute(path: '/app/calendar', pageBuilder: (_, s) => const NoTransitionPage(child: CalendarScreen())),
          GoRoute(path: '/app/maintenance', pageBuilder: (_, _) => const NoTransitionPage(child: MaintenanceContactsScreen())),
          GoRoute(path: '/app/welcome-guide', pageBuilder: (_, _) => const NoTransitionPage(child: WelcomeGuideScreen())),
          GoRoute(path: '/app/leaving', pageBuilder: (_, _) => const NoTransitionPage(child: LeavingScreen())),
          GoRoute(path: '/app/terms', pageBuilder: (_, _) => const NoTransitionPage(child: TermsScreen())),
          GoRoute(path: '/app/essentials', pageBuilder: (_, _) => const NoTransitionPage(child: EssentialsScreen())),
          GoRoute(path: '/app/marketplace', pageBuilder: (_, _) => const NoTransitionPage(child: GoodsMarketplaceScreen())),
          GoRoute(path: '/app/business', pageBuilder: (_, _) => const NoTransitionPage(child: BusinessDashboardScreen())),
        ],
      ),
      ShellRoute(
        navigatorKey: _adminShellNavigatorKey,
        builder: (context, state, child) => AdminShell(currentLocation: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/admin', builder: (_, _) => const AdminVerificationsScreen()),
        ],
      ),
    ],
  );
}
