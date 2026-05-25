import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homies_mobile/state/app_state.dart';
import 'package:homies_mobile/theme.dart';
import 'package:homies_mobile/widgets/avatar.dart';

void main() {
  testWidgets('Avatar renders user initials', (tester) async {
    final state = HomiesState();
    final user = state.users.first;
    await tester.pumpWidget(MaterialApp(
      theme: buildHomiesTheme(),
      home: Scaffold(body: Avatar(user: user)),
    ));
    expect(find.text(user.initials), findsOneWidget);
  });
}
