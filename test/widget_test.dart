// Phase 0 smoke test: the scaffold builds and shows the placeholder home.
// Real feature tests arrive with their phases.

import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/main.dart';

void main() {
  testWidgets('App boots to the Spendly placeholder screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SpendlyApp());

    expect(find.text('Spendly'), findsWidgets);
    expect(find.text('Project scaffold — Phase 0'), findsOneWidget);
  });
}
