import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homies_mobile/widgets/otp_input.dart';

void main() {
  Future<List<String>> pumpOtp(WidgetTester tester, {int length = 6}) async {
    final changes = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OtpInput(
          value: '',
          length: length,
          autoFocus: false,
          onChanged: changes.add,
        ),
      ),
    ));
    return changes;
  }

  testWidgets('renders one box per digit', (tester) async {
    await pumpOtp(tester, length: 6);
    expect(find.byType(TextField), findsNWidgets(6));
  });

  testWidgets('typing digits fills the code left to right', (tester) async {
    final changes = await pumpOtp(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '4');
    await tester.enterText(fields.at(1), '2');
    await tester.pump();
    expect(changes.isNotEmpty, isTrue);
    expect(changes.last, '42');
  });

  testWidgets('non-digit input is filtered out', (tester) async {
    final changes = await pumpOtp(tester);
    await tester.enterText(find.byType(TextField).first, 'a');
    await tester.pump();
    // The digits-only formatter rejects the character, so no code is emitted.
    expect(changes.where((c) => c.contains('a')), isEmpty);
  });
}
