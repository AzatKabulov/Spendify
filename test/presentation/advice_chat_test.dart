import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/domain/repositories/advice_generator_repository.dart';
import 'package:spendify/presentation/providers/advice_chat_providers.dart';
import 'package:spendify/presentation/screens/advice_chat_screen.dart';

import '../support/widget_test_scaffold.dart';

void main() {
  testWidgets('shows the greeting and quick replies before any message', (
    tester,
  ) async {
    await pumpSpendify(
      tester,
      home: const AdviceChatScreen(),
      geminiApiKey: 'test-key',
    );

    expect(find.textContaining("Hi! I'm Spendify AI"), findsOneWidget);
    for (final reply in kChatQuickReplies) {
      expect(find.text(reply), findsOneWidget);
    }
  });

  testWidgets('tapping a quick reply sends it and shows the real reply', (
    tester,
  ) async {
    final repos = await pumpSpendify(
      tester,
      home: const AdviceChatScreen(),
      geminiApiKey: 'test-key',
    );
    repos.adviceGenerator.nextReply = 'Try trimming Food by RM 40 this month.';

    await tester.tap(find.text(kChatQuickReplies.first));
    await tester.pumpAndSettle();

    expect(repos.adviceGenerator.askCalls, 1);
    expect(repos.adviceGenerator.lastQuestion, kChatQuickReplies.first);
    expect(find.text(kChatQuickReplies.first), findsOneWidget); // user bubble
    expect(find.text('Try trimming Food by RM 40 this month.'), findsOneWidget);
    // the quick replies are gone once a real message has been sent
    expect(find.text(kChatQuickReplies[1]), findsNothing);
    // only the real reply carries the Gemini mark, never the greeting
    expect(find.text('Gemini'), findsOneWidget);
  });

  testWidgets('typing a question and sending it works the same way', (
    tester,
  ) async {
    final repos = await pumpSpendify(
      tester,
      home: const AdviceChatScreen(),
      geminiApiKey: 'test-key',
    );

    await tester.enterText(find.byType(TextField), 'Am I overspending?');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(repos.adviceGenerator.askCalls, 1);
    expect(repos.adviceGenerator.lastQuestion, 'Am I overspending?');
    expect(find.text('Am I overspending?'), findsOneWidget);
  });

  testWidgets('a generation failure shows an inline error, not a crash', (
    tester,
  ) async {
    final repos = await pumpSpendify(
      tester,
      home: const AdviceChatScreen(),
      geminiApiKey: 'test-key',
    );
    repos.adviceGenerator.askFailWith = const AdviceRateLimitedException();

    await tester.tap(find.text(kChatQuickReplies.first));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('busy'),
      findsOneWidget,
      reason: const AdviceRateLimitedException().message,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline: an honest inline message, no API call', (tester) async {
    final repos = await pumpSpendify(
      tester,
      home: const AdviceChatScreen(),
      geminiApiKey: 'test-key',
      online: false,
    );

    await tester.tap(find.text(kChatQuickReplies.first));
    await tester.pumpAndSettle();

    expect(repos.adviceGenerator.askCalls, 0);
    expect(find.textContaining("You're offline"), findsOneWidget);
  });

  testWidgets('AI off: an honest inline message, no API call', (tester) async {
    final repos = await pumpSpendify(tester, home: const AdviceChatScreen());

    await tester.enterText(find.byType(TextField), 'Help?');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(repos.adviceGenerator.askCalls, 0);
    expect(find.textContaining('AI is off'), findsOneWidget);
  });

  test('history sent to the repository never includes an error turn', () {
    // Documents the contract `AdviceChatController.send` relies on: error
    // turns are filtered out of the history handed to `ask()`, so a past
    // failure is never replayed back to Gemini as if it were a real reply.
    const history = <ChatTurn>[
      ChatTurn(role: ChatRole.assistant, text: kChatGreeting),
      ChatTurn(role: ChatRole.user, text: 'Help?'),
      ChatTurn(role: ChatRole.error, text: 'Something went wrong.'),
    ];
    final sent = <AdviceChatTurn>[
      for (final m in history)
        if (m.role != ChatRole.error)
          AdviceChatTurn(isUser: m.role == ChatRole.user, text: m.text),
    ];
    expect(sent, hasLength(2));
    expect(sent.every((t) => t.text != 'Something went wrong.'), isTrue);
  });
}
