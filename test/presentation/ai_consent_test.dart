import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/data/remote/gemini_advice_client.dart';
import 'package:spendify/data/remote/gemini_client.dart';
import 'package:spendify/data/repositories/unavailable_advice_generator.dart';
import 'package:spendify/data/repositories/unavailable_receipt_scanner.dart';
import 'package:spendify/domain/entities/ai_consent.dart';
import 'package:spendify/presentation/providers/advice_providers.dart';
import 'package:spendify/presentation/providers/ai_providers.dart';
import 'package:spendify/presentation/providers/receipt_scan_providers.dart';
import 'package:spendify/presentation/screens/ai_consent_screen.dart';
import 'package:spendify/presentation/screens/auth/auth_gate.dart';
import 'package:spendify/presentation/screens/home_screen.dart';

import '../support/fake_repositories.dart';
import '../support/widget_test_scaffold.dart';

ProviderContainer _container({
  String key = 'test-key',
  AiConsent consent = AiConsent.undecided,
}) {
  final c = ProviderContainer(
    overrides: [
      geminiApiKeyProvider.overrideWithValue(key),
      aiPreferencesStoreProvider.overrideWithValue(
        FakeAiPreferencesStore(consent),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('gates', () {
    test('undecided: features disabled, consent required', () {
      final c = _container(consent: AiConsent.undecided);
      expect(c.read(aiFeaturesEnabledProvider), isFalse);
      expect(c.read(aiConsentRequiredProvider), isTrue);
    });

    test('granted: features enabled, consent not required', () {
      final c = _container(consent: AiConsent.granted);
      expect(c.read(aiFeaturesEnabledProvider), isTrue);
      expect(c.read(aiConsentRequiredProvider), isFalse);
    });

    test('denied: features disabled, and NOT re-prompted', () {
      final c = _container(consent: AiConsent.denied);
      expect(c.read(aiFeaturesEnabledProvider), isFalse);
      expect(c.read(aiConsentRequiredProvider), isFalse);
    });

    test('no key: features disabled regardless of consent', () {
      final c = _container(key: '', consent: AiConsent.granted);
      expect(c.read(aiFeaturesEnabledProvider), isFalse);
      expect(c.read(aiConsentRequiredProvider), isFalse);
    });
  });

  group('no Gemini client is constructed when AI is off', () {
    test('advice + receipt providers return the Unavailable stubs', () {
      final c = _container(consent: AiConsent.denied);
      expect(
        c.read(adviceGeneratorRepositoryProvider),
        isA<UnavailableAdviceGenerator>(),
      );
      expect(
        c.read(receiptScannerRepositoryProvider),
        isA<UnavailableReceiptScanner>(),
      );
    });

    test('with consent granted they return the real Gemini clients', () {
      final c = _container(consent: AiConsent.granted);
      expect(
        c.read(adviceGeneratorRepositoryProvider),
        isA<GeminiAdviceClient>(),
      );
      expect(
        c.read(receiptScannerRepositoryProvider),
        isA<GeminiReceiptClient>(),
      );
    });
  });

  group('consent controller', () {
    test('grant / revoke persist and update the state', () async {
      final store = FakeAiPreferencesStore();
      final c = ProviderContainer(
        overrides: [
          geminiApiKeyProvider.overrideWithValue('k'),
          aiPreferencesStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(c.dispose);

      expect(c.read(aiConsentProvider), AiConsent.undecided);

      await c.read(aiConsentProvider.notifier).grant();
      expect(c.read(aiConsentProvider), AiConsent.granted);
      expect(store.consent, AiConsent.granted);

      await c.read(aiConsentProvider.notifier).revoke();
      expect(c.read(aiConsentProvider), AiConsent.denied);
      expect(store.consent, AiConsent.denied);
    });
  });

  group('AuthGate routing', () {
    testWidgets('key present + undecided -> consent screen before home', (
      tester,
    ) async {
      await pumpSpendify(
        tester,
        home: const AuthGate(),
        signedInSession: true,
        geminiApiKey: 'k',
        aiConsent: AiConsent.undecided,
      );
      expect(find.byType(AiConsentScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('declining consent -> straight to home, AI stays off', (
      tester,
    ) async {
      final repos = await pumpSpendify(
        tester,
        home: const AuthGate(),
        signedInSession: true,
        geminiApiKey: 'k',
        aiConsent: AiConsent.undecided,
      );

      await tester.tap(find.text('No thanks'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(repos.container.read(aiConsentProvider), AiConsent.denied);
      expect(repos.container.read(aiFeaturesEnabledProvider), isFalse);
    });

    testWidgets('accepting consent -> home, AI enabled', (tester) async {
      final repos = await pumpSpendify(
        tester,
        home: const AuthGate(),
        signedInSession: true,
        geminiApiKey: 'k',
        aiConsent: AiConsent.undecided,
      );

      await tester.tap(find.text('Turn on AI'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(repos.container.read(aiFeaturesEnabledProvider), isTrue);
    });

    testWidgets('no key -> no consent screen, straight to home', (
      tester,
    ) async {
      await pumpSpendify(
        tester,
        home: const AuthGate(),
        signedInSession: true,
        aiConsent: AiConsent.undecided,
      );
      expect(find.byType(AiConsentScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
