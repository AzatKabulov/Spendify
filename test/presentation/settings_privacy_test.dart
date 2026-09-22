import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/domain/entities/advice_item.dart';
import 'package:spendify/domain/entities/advice_record.dart';
import 'package:spendify/domain/entities/ai_consent.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/transaction.dart';
import 'package:spendify/presentation/providers/ai_providers.dart';
import 'package:spendify/presentation/screens/ai_settings_screen.dart';
import 'package:spendify/presentation/screens/data_sent_screen.dart';
import 'package:spendify/presentation/screens/data_storage_screen.dart';
import 'package:spendify/presentation/screens/home_screen.dart';
import 'package:spendify/presentation/screens/privacy_screen.dart';
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
    testWidgets('off (denied) hides the scan action and Insights', (
      tester,
    ) async {
      await pumpSpendify(
        tester,
        home: const HomeScreen(),
        geminiApiKey: 'test-key',
        aiConsent: AiConsent.denied,
      );

      expect(find.text('Scan'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Insights'),
        ),
        findsNothing,
      );
    });

    testWidgets('turning it on in AI Settings reveals the AI entry points', (
      tester,
    ) async {
      final repos = await pumpSpendify(
        tester,
        home: const HomeScreen(),
        geminiApiKey: 'test-key',
        aiConsent: AiConsent.denied,
      );
      expect(find.text('Scan'), findsNothing);

      // Bottom navigation -> Profile (Settings) -> AI Settings.
      final nav = find.byType(NavigationBar);
      await tester.tap(
        find.descendant(of: nav, matching: find.text('Profile')),
      );
      await tester.pumpAndSettle();
      await _tapItem(tester, 'AI Settings');
      expect(find.byType(AiSettingsScreen), findsOneWidget);

      expect(find.widgetWithText(SwitchListTile, 'AI features'), findsNothing);
      expect(find.byType(Switch), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(repos.container.read(aiConsentProvider), AiConsent.granted);
      expect(repos.aiPrefs.consent, AiConsent.granted);

      // AiSettingsScreen uses the custom FormHeader, not a Material
      // AppBar, so there is no standard BackButton for pageBack() to find.
      Navigator.of(tester.element(find.byType(AiSettingsScreen))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: nav, matching: find.text('Home')));
      await tester.pumpAndSettle();
      expect(find.text('Scan'), findsOneWidget);
      // Insights is not a nav tab; the Home AI card is the entry point.
      expect(find.text('Spendify AI'), findsOneWidget);
    });

    testWidgets('no key -> AI row is disabled, no toggle', (tester) async {
      await pumpSpendify(tester, home: const AiSettingsScreen());
      expect(find.byType(Switch), findsNothing);
      expect(
        find.textContaining('Not available in this build'),
        findsOneWidget,
      );
    });
  });

  testWidgets('Clear cached advice empties the cache', (tester) async {
    final repos = await pumpSpendify(
      tester,
      home: const AiSettingsScreen(),
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
    await _tapItem(tester, 'Data & Storage');
    expect(find.byType(DataStorageScreen), findsOneWidget);

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
      home: const DataStorageScreen(),
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

  testWidgets('privacy notice opens from settings -> privacy', (tester) async {
    await pumpSpendify(
      tester,
      home: const SettingsScreen(),
      geminiApiKey: 'test-key',
    );
    await _tapItem(tester, 'Privacy');
    expect(find.byType(PrivacyScreen), findsOneWidget);

    await _tapItem(tester, 'Privacy Notice');
    expect(find.text('Your privacy matters'), findsOneWidget);
  });

  testWidgets("Your Rights opens from Privacy Notice and from Privacy", (
    tester,
  ) async {
    await pumpSpendify(
      tester,
      home: const PrivacyScreen(),
      geminiApiKey: 'test-key',
    );
    await _tapItem(tester, 'Your Rights');
    expect(find.text('Your data, your choice'), findsOneWidget);
    // The real capability, not the mockup's "Delete your account" (there is
    // no account-deletion feature — only local data can be wiped).
    expect(find.text('Delete your account'), findsNothing);
    expect(find.text('Delete all local data'), findsOneWidget);
  });

  testWidgets(
    '"what\'s sent" -> Spending summary shows the real advice payload',
    (tester) async {
      await pumpSpendify(
        tester,
        home: const SettingsScreen(),
        geminiApiKey: 'test-key',
      );
      await _tapItem(tester, 'Privacy');
      await _tapItem(tester, "What's sent to Gemini");
      expect(find.text("What's Sent to Gemini"), findsOneWidget);

      await _tapItem(tester, 'Spending summary');
      expect(find.text('Data included'), findsOneWidget);

      // the payload shown is a real JSON object built from the account
      await tester.scrollUntilVisible(
        find.textContaining('"currency": "MYR"'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('"currency": "MYR"'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Data not included'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Data not included'), findsOneWidget);
      expect(find.textContaining('Shop or merchant names'), findsOneWidget);
    },
  );

  testWidgets(
    "the spending-summary detail lists merchant/notes as NOT included",
    (tester) async {
      // Regression guard for the correction: the mockup's "Transaction
      // data" screen claimed merchant name and transaction notes are sent
      // to Gemini. They are not (`advice_summary_builder.dart` never
      // includes them) — this screen must say so under "Data not
      // included", never under "Data included".
      await pumpSpendify(
        tester,
        home: const DataSentScreen(),
        geminiApiKey: 'test-key',
      );
      await _tapItem(tester, 'Spending summary');
      await tester.pumpAndSettle();

      final merchantRow = find.ancestor(
        of: find.textContaining('merchant'),
        matching: find.byType(Row),
      );
      expect(merchantRow, findsOneWidget);
      // that row sits under "Data not included", not "Data included".
      final excludedHeading = find.text('Data not included');
      final includedHeading = find.text('Data included');
      final merchantY = tester.getTopLeft(merchantRow).dy;
      expect(tester.getTopLeft(excludedHeading).dy, lessThan(merchantY));
      expect(tester.getTopLeft(includedHeading).dy, lessThan(merchantY));
    },
  );
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
