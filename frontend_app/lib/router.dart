import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
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
      GoRoute(path: '/demo', builder: (_, _) => const DemoLoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (_, s) {
          final extra = s.extra;
          return SignupScreen(invite: extra is InviteHandoff ? extra : null);
        },
      ),
      GoRoute(path: '/invite/:code', builder: (_, s) => AcceptInviteScreen(code: s.pathParameters['code']!)),
      GoRoute(path: '/onboarding/leaseholder', builder: (_, _) => const LeaseholderOnboardingScreen()),
      GoRoute(path: '/onboarding/tenant', builder: (_, _) => const TenantOnboardingScreen()),
      ShellRoute(
        navigatorKey: _appShellNavigatorKey,
        builder: (context, state, child) => AppShell(currentLocation: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/app', builder: (_, _) => const DashboardScreen()),
          GoRoute(path: '/app/profile', builder: (_, _) => const ProfileScreen()),
          GoRoute(path: '/app/property', builder: (_, _) => const PropertyScreen()),
          GoRoute(path: '/app/housemates', builder: (_, _) => const HousematesScreen()),
          GoRoute(path: '/app/performance', builder: (_, _) => const TenantPerformanceScreen()),
          GoRoute(path: '/app/listings', builder: (_, _) => const ListingsScreen()),
          GoRoute(path: '/app/bills', builder: (_, _) => const BillsScreen()),
          GoRoute(path: '/app/subscriptions', builder: (_, _) => const SubscriptionsScreen()),
          GoRoute(path: '/app/groceries', builder: (_, _) => const GroceriesScreen()),
          GoRoute(path: '/app/necessities', builder: (_, _) => const NecessitiesScreen()),
          GoRoute(path: '/app/cleaning', builder: (_, _) => const CleaningScreen()),
          GoRoute(path: '/app/rules', builder: (_, _) => const HouseRulesScreen()),
          GoRoute(path: '/app/parties', builder: (_, _) => const PartiesScreen()),
          GoRoute(path: '/app/messages', builder: (_, _) => const MessagesScreen()),
          GoRoute(path: '/app/issues', builder: (_, _) => const IssuesScreen()),
          GoRoute(path: '/app/complaints', builder: (_, _) => const ComplaintsScreen()),
          GoRoute(path: '/app/finance', builder: (_, _) => const FinanceScreen()),
          GoRoute(path: '/app/my-spending', builder: (_, _) => const MySpendingScreen()),
          GoRoute(path: '/app/shopping', builder: (_, s) => const ShoppingListScreen()),
          GoRoute(path: '/app/notifications', builder: (_, s) => const NotificationsScreen()),
          GoRoute(path: '/app/calendar', builder: (_, s) => const CalendarScreen()),
          GoRoute(path: '/app/maintenance', builder: (_, _) => const MaintenanceContactsScreen()),
          GoRoute(path: '/app/welcome-guide', builder: (_, _) => const WelcomeGuideScreen()),
          GoRoute(path: '/app/leaving', builder: (_, _) => const LeavingScreen()),
          GoRoute(path: '/app/terms', builder: (_, _) => const TermsScreen()),
          GoRoute(path: '/app/essentials', builder: (_, _) => const EssentialsScreen()),
          GoRoute(path: '/app/marketplace', builder: (_, _) => const GoodsMarketplaceScreen()),
          GoRoute(path: '/app/business', builder: (_, _) => const BusinessDashboardScreen()),
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
