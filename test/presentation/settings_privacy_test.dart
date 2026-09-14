import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/domain/entities/advice_item.dart';
import 'package:spendify/domain/entities/advice_record.dart';
import 'package:spendify/domain/entities/ai_consent.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/transaction.dart';
import 'package:spendify/presentation/providers/ai_providers.dart';
import 'package:spendify/presentation/screens/home_screen.dart';
import 'package:spendify/presentation/screens/settings_screen.dart';

import '../support/widget_test_scaffold.dart';

Transaction _txn(String id) => Transaction.create(
  id: id,
  userId: kLocalUserId,
  amountMinor: 1200,
  type: TransactionType.expense,
  categoryId: 'cat-0',
  date: DateTime(2026, 9, 6),
  now: DateTime.utc(2026, 9, 6),
);

Future<void> _tapItem(WidgetTester tester, String text) async {
  final f = find.text(text);
  await tester.scrollUntilVisible(
    f,
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  group('AI toggle', () {
    testWidgets('off (denied) hides the scan FAB and Insights', (tester) async {
      await pumpSpendify(
        tester,
        home: const HomeScreen(),
        geminiApiKey: 'test-key',
        aiConsent: AiConsent.denied,
      );

      expect(find.byTooltip('Scan receipt'), findsNothing);
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      expect(find.text('Insights'), findsNothing);
    });

    testWidgets('turning it on in Settings reveals the AI entry points', (
      tester,
    ) async {
      final repos = await pumpSpendify(
        tester,
        home: const HomeScreen(),
        geminiApiKey: 'test-key',
        aiConsent: AiConsent.denied,
      );
      expect(find.byTooltip('Scan receipt'), findsNothing);

      // Home menu -> Settings (value 3 when Insights is hidden).
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(SwitchListTile, 'AI features'),
        findsOneWidget,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(repos.container.read(aiConsentProvider), AiConsent.granted);
      expect(repos.aiPrefs.consent, AiConsent.granted);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Scan receipt'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      expect(find.text('Insights'), findsOneWidget);
    });

    testWidgets('no key -> AI row is disabled, no toggle', (tester) async {
      await pumpSpendify(tester, home: const SettingsScreen());
      expect(find.widgetWithText(SwitchListTile, 'AI features'), findsNothing);
      expect(
        find.textContaining('Not available in this build'),
        findsOneWidget,
      );
    });
  });

  testWidgets('Clear cached advice empties the cache', (tester) async {
    final repos = await pumpSpendify(
      tester,
      home: const SettingsScreen(),
      geminiApiKey: 'test-key',
    );
    repos.adviceCache.records.add(
      AdviceRecord(
        id: 'a1',
        userId: kLocalUserId,
        generatedAt: DateTime.utc(2026, 9, 1),
        summaryHash: 'h',
        adviceItems: const [AdviceItem(title: 't', body: 'b')],
      ),
    );

    await _tapItem(tester, 'Clear cached advice');
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(repos.adviceCache.records, isEmpty);
  });

  testWidgets('Delete all local data wipes the fakes and pops home', (
    tester,
  ) async {
    final repos = await pumpSpendify(
      tester,
      home: const _SettingsHost(),
      geminiApiKey: 'test-key',
    );
    await repos.seedTransaction(_txn('t1'));
    await repos.seedTransaction(_txn('t2'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open settings'));
    await tester.pumpAndSettle();

    await _tapItem(tester, 'Delete all local data');
    expect(find.textContaining('cloud backup is NOT deleted'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete everything'));
    await tester.pumpAndSettle();

    expect(repos.wiper.wiped, isTrue);
    expect(await repos.transactions.getAll(), isEmpty);
    expect(await repos.budgets.getAll(), isEmpty);
    expect(find.text('open settings'), findsOneWidget);
  });

  testWidgets('Export my data shows a dialog with a copy action', (
    tester,
  ) async {
    final repos = await pumpSpendify(
      tester,
      home: const SettingsScreen(),
      geminiApiKey: 'test-key',
    );
    await repos.seedTransaction(_txn('t1'));
    await tester.pumpAndSettle();

    await _tapItem(tester, 'Export my data');

    expect(find.text('Data exported'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Copy JSON'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Copy JSON'));
    await tester.pumpAndSettle();
  });

  testWidgets('privacy notice opens from settings', (tester) async {
    await pumpSpendify(
      tester,
      home: const SettingsScreen(),
      geminiApiKey: 'test-key',
    );
    await _tapItem(tester, 'Privacy notice');
    expect(find.text('Spendify privacy notice'), findsOneWidget);
  });

  testWidgets('"what is sent" shows the real advice payload', (tester) async {
    await pumpSpendify(
      tester,
      home: const SettingsScreen(),
      geminiApiKey: 'test-key',
    );
    await _tapItem(tester, 'What’s sent to Gemini');
    expect(find.text('What is sent to Gemini'), findsOneWidget);

    // the payload shown is a real JSON object built from the account
    await tester.scrollUntilVisible(
      find.textContaining('"currency": "MYR"'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('"currency": "MYR"'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('Never sent'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Never sent'), findsOneWidget);
  });
}

class _SettingsHost extends StatelessWidget {
  const _SettingsHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            child: const Text('open settings'),
          ),
        ),
      ),
    );
  }
}
