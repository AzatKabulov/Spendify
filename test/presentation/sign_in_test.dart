import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/data/remote/firebase_bootstrap.dart';
import 'package:spendify/domain/repositories/auth_repository.dart';
import 'package:spendify/presentation/providers/auth_providers.dart';
import 'package:spendify/presentation/screens/auth/sign_in_screen.dart';

import '../support/fake_repositories.dart';

Future<FakeAuthRepository> _pumpSignIn(
  WidgetTester tester, {
  FirebaseAvailability availability = FirebaseAvailability.ready,
}) async {
  final auth = FakeAuthRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        firebaseAvailabilityProvider.overrideWithValue(availability),
      ],
      child: const MaterialApp(home: SignInScreen()),
    ),
  );
  return auth;
}

Future<void> _enterCredentials(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email'),
    'lara@example.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    'secret123',
  );
}

void main() {
  testWidgets('submit button is disabled and shows a spinner while in flight', (
    tester,
  ) async {
    final auth = await _pumpSignIn(tester);
    auth.gate = Completer<void>(); // hold the request open

    await _enterCredentials(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump(); // start the async submit

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull, reason: 'disabled while submitting');
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(auth.signInCalls, 1);

    // A second tap must not fire another sign-in (no double account).
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(auth.signInCalls, 1);

    // Resolve the held request as a failure so the flow ends here (a success
    // would run the post-sign-in data prep, which needs a Hive store).
    auth.failWith = const AuthNetworkException();
    auth.gate!.complete();
    await tester.pumpAndSettle();

    final after = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(after.onPressed, isNotNull, reason: 're-enabled after the attempt');
  });

  testWidgets('a mapped auth error renders inline', (tester) async {
    final auth = await _pumpSignIn(tester);
    auth.failWith = const InvalidCredentialsException();

    await _enterCredentials(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    // Button is usable again for a retry.
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('invalid email is rejected inline before any network call', (
    tester,
  ) async {
    final auth = await _pumpSignIn(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'not-an-email',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret123',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(
      find.text("That doesn't look like a valid email address."),
      findsWidgets,
    );
    expect(auth.signInCalls, 0);
  });

  testWidgets(
    'when Firebase is not configured, sign-in is blocked with a note',
    (tester) async {
      final auth = await _pumpSignIn(
        tester,
        availability: FirebaseAvailability.notConfigured,
      );

      expect(
        find.textContaining('not available in this build'),
        findsOneWidget,
      );

      await _enterCredentials(tester);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(auth.signInCalls, 0);
    },
  );
}
