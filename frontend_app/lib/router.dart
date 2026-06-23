import 'package:go_router/go_router.dart';

import 'state/app_state.dart';
import 'screens/accept_invite.dart';
import 'screens/admin_users.dart';
import 'screens/admin_verifications.dart';
import 'screens/finance.dart';
import 'screens/bills.dart';
import 'screens/cleaning.dart';
import 'screens/complaints.dart';
import 'screens/dashboard.dart';
import 'screens/demo_login.dart';
import 'screens/groceries.dart';
import 'screens/house_rules.dart';
import 'screens/housemates.dart';
import 'screens/issues.dart';
import 'screens/leaseholder_onboarding.dart';
import 'screens/leaving.dart';
import 'screens/listings.dart';
import 'screens/login.dart';
import 'screens/messages.dart';
import 'screens/necessities.dart';
import 'screens/parties.dart';
import 'screens/profile.dart';
import 'screens/property.dart';
import 'screens/tenant_performance.dart';
import 'screens/signup.dart' show SignupScreen, InviteHandoff;
import 'screens/subscriptions.dart';
import 'screens/tenant_onboarding.dart';
import 'screens/termination.dart';
import 'screens/welcome.dart';
import 'widgets/admin_shell.dart';
import 'widgets/app_shell.dart';

GoRouter buildRouter(HomiesState state) {
  return GoRouter(
    initialLocation: '/',
    // Rebuild/re-evaluate redirects whenever auth/session state changes
    // (login, logout, profile hydration) so gating happens declaratively
    // instead of via context.go() during widget build.
    refreshListenable: state,
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
      // Signed in but not invited into a house — marketplace only.
      if (!user.member && loc != '/app/listings') return '/app/listings';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/demo', builder: (_, __) => const DemoLoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (_, s) {
          final extra = s.extra;
          return SignupScreen(invite: extra is InviteHandoff ? extra : null);
        },
      ),
      GoRoute(path: '/invite/:code', builder: (_, s) => AcceptInviteScreen(code: s.pathParameters['code']!)),
      GoRoute(path: '/onboarding/leaseholder', builder: (_, __) => const LeaseholderOnboardingScreen()),
      GoRoute(path: '/onboarding/tenant', builder: (_, __) => const TenantOnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(currentLocation: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/app', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/app/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(path: '/app/property', builder: (_, __) => const PropertyScreen()),
          GoRoute(path: '/app/housemates', builder: (_, __) => const HousematesScreen()),
          GoRoute(path: '/app/performance', builder: (_, __) => const TenantPerformanceScreen()),
          GoRoute(path: '/app/listings', builder: (_, __) => const ListingsScreen()),
          GoRoute(path: '/app/bills', builder: (_, __) => const BillsScreen()),
          GoRoute(path: '/app/subscriptions', builder: (_, __) => const SubscriptionsScreen()),
          GoRoute(path: '/app/groceries', builder: (_, __) => const GroceriesScreen()),
          GoRoute(path: '/app/necessities', builder: (_, __) => const NecessitiesScreen()),
          GoRoute(path: '/app/cleaning', builder: (_, __) => const CleaningScreen()),
          GoRoute(path: '/app/rules', builder: (_, __) => const HouseRulesScreen()),
          GoRoute(path: '/app/parties', builder: (_, __) => const PartiesScreen()),
          GoRoute(path: '/app/messages', builder: (_, __) => const MessagesScreen()),
          GoRoute(path: '/app/issues', builder: (_, __) => const IssuesScreen()),
          GoRoute(path: '/app/complaints', builder: (_, __) => const ComplaintsScreen()),
          GoRoute(path: '/app/finance', builder: (_, __) => const FinanceScreen()),
          GoRoute(path: '/app/leaving', builder: (_, __) => const LeavingScreen()),
          GoRoute(path: '/app/termination', builder: (_, __) => const TerminationScreen()),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(currentLocation: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/admin', builder: (_, __) => const AdminVerificationsScreen()),
          GoRoute(path: '/admin/users', builder: (_, __) => const AdminUsersScreen()),
        ],
      ),
    ],
  );
}
