// Phase 2 smoke test: the app boots to the home screen with its add button.
// Feature behaviour is covered by the tests under test/presentation/,
// test/core/ and test/domain/.

import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/presentation/screens/home_screen.dart';

import 'support/widget_test_scaffold.dart';

void main() {
  testWidgets('home screen shows the greeting and a visible Add action', (
    tester,
  ) async {
    await pumpSpendify(tester, home: const HomeScreen());

    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });
}
