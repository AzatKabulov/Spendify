import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/presentation/providers/auth_providers.dart';
import 'package:spendify/presentation/screens/auth/auth_gate.dart';
import 'package:spendify/presentation/screens/auth/sign_in_screen.dart';

void main() {
  testWidgets('with no persisted session, routes to the sign-in screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AuthGate())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('a signed-in-but-not-ready session shows the preparing screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_NotReadySession.new)],
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();

    expect(find.byType(SignInScreen), findsNothing);
    expect(find.text('Setting up your account…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

class _NotReadySession extends SessionNotifier {
  @override
  Session build() =>
      const Session(uid: 'u1', email: 'lara@example.com', ready: false);
}
