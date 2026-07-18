import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homies_mobile/screens/login.dart';
import 'package:homies_mobile/state/app_state.dart';
import 'package:homies_mobile/theme.dart';

Widget _wrap(HomiesState state) => MaterialApp(
      theme: buildHomiesTheme(),
      home: HomiesScope(state: state, child: const LoginScreen()),
    );

void main() {
  testWidgets('renders email and password fields and the primary actions', (tester) async {
    await tester.pumpWidget(_wrap(HomiesState()));
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.widgetWithText(ElevatedButton, 'Sign in'), findsOneWidget);
    expect(find.text('New here? Create an account'), findsOneWidget);
    expect(find.text('Try demo accounts'), findsOneWidget);
  });

  testWidgets('submitting with empty fields shows a validation error and does not navigate', (tester) async {
    await tester.pumpWidget(_wrap(HomiesState()));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Email and password are required.'), findsOneWidget);
    // Still on the login screen.
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('submitting with only an email still shows the validation error', (tester) async {
    await tester.pumpWidget(_wrap(HomiesState()));
    await tester.enterText(find.byType(TextField).first, 'someone@example.com');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Email and password are required.'), findsOneWidget);
  });

  testWidgets('password field obscures input', (tester) async {
    await tester.pumpWidget(_wrap(HomiesState()));
    final passwordField = tester.widget<TextField>(find.byType(TextField).last);
    expect(passwordField.obscureText, isTrue);
  });
}
