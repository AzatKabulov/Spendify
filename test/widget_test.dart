// Phase 1 smoke test: the scaffold still builds and shows the placeholder home.
// The data layer is exercised by the tests under test/data/ and test/domain/.

import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/main.dart';

void main() {
  testWidgets('App boots to the Spendly placeholder screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SpendlyApp());

    expect(find.text('Spendly'), findsWidgets);
    expect(find.text('Encrypted storage ready — Phase 1'), findsOneWidget);
  });
}
