// Phase 2 smoke test: the app boots to the home screen with its add button.
// Feature behaviour is covered by the tests under test/presentation/,
// test/core/ and test/domain/.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/presentation/screens/home_screen.dart';

import 'support/widget_test_scaffold.dart';

void main() {
  testWidgets('home screen shows the title and a visible Add button', (
    tester,
  ) async {
    await pumpSpendify(tester, home: const HomeScreen());

    expect(find.text('Spendify'), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, 'Add'), findsOneWidget);
  });
}
