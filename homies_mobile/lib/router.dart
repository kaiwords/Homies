import 'package:go_router/go_router.dart';

import 'screens/accept_invite.dart';
import 'screens/bills.dart';
import 'screens/cleaning.dart';
import 'screens/complaints.dart';
import 'screens/dashboard.dart';
import 'screens/groceries.dart';
import 'screens/house_rules.dart';
import 'screens/housemates.dart';
import 'screens/issues.dart';
import 'screens/leaseholder_onboarding.dart';
import 'screens/leaving.dart';
import 'screens/login.dart';
import 'screens/messages.dart';
import 'screens/necessities.dart';
import 'screens/parties.dart';
import 'screens/property.dart';
import 'screens/signup.dart' show SignupScreen, InviteHandoff;
import 'screens/subscriptions.dart';
import 'screens/tenant_onboarding.dart';
import 'screens/termination.dart';
import 'screens/welcome.dart';
import 'widgets/app_shell.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
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
          GoRoute(path: '/app/property', builder: (_, __) => const PropertyScreen()),
          GoRoute(path: '/app/housemates', builder: (_, __) => const HousematesScreen()),
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
          GoRoute(path: '/app/leaving', builder: (_, __) => const LeavingScreen()),
          GoRoute(path: '/app/termination', builder: (_, __) => const TerminationScreen()),
        ],
      ),
    ],
  );
}
