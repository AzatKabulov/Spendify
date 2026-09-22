import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/advice_generator_repository.dart';
import 'advice_providers.dart';
import 'sync_providers.dart';

/// "Ask Spendify AI" — a minimal, real chat over the same aggregated summary
/// [currentAdviceSummary] builds for the main advice generation (never raw
/// transactions — CLAUDE.md §7).
///
/// **Redesign addition, flagged.** The mockup's chat screen is a genuinely new
/// capability, not a re-skin of the existing single-shot advice generator, so
/// it is built for real rather than faked: every message here is a live
/// `AdviceGeneratorRepository.ask()` call.
///
/// **Deliberately not persisted.** The conversation lives only in memory for
/// this app process — it survives leaving and reopening the screen, but a
/// full app restart loses it, and it is never written to Hive or synced to
/// Firestore. This is a considered choice, not an oversight: it keeps the
/// feature within CLAUDE.md §7's data-minimisation stance without inventing a
/// new synced entity for a capstone-scope feature. If that changes, this is
/// the one place to add persistence.

/// One line of the conversation as shown on screen.
enum ChatRole { assistant, user, error }

class ChatTurn {
  const ChatTurn({required this.role, required this.text});

  final ChatRole role;
  final String text;
}

/// The greeting shown before the user has typed anything — authored copy,
/// not a Gemini call, so it carries no "Powered by Google Gemini" mark.
const String kChatGreeting =
    "Hi! I'm Spendify AI 👋 Ask me anything about your finances. I can help "
    'with budgeting, saving, spending habits and more.';

/// Canned starting prompts. Deliberately worded as *questions* — the
/// assistant can only talk, never create or change anything in the account
/// (CLAUDE.md §7 confirm-before-save spirit extends here: nothing it says
/// takes an action), so no chip here promises otherwise.
const List<String> kChatQuickReplies = <String>[
  'How can I save more?',
  'Review my spending',
  'Where can I cut back?',
  'Am I spending too much?',
  'Tips for students like me',
];

class AdviceChatState {
  const AdviceChatState({
    this.messages = const <ChatTurn>[
      ChatTurn(role: ChatRole.assistant, text: kChatGreeting),
    ],
    this.sending = false,
  });

  final List<ChatTurn> messages;
  final bool sending;

  /// Quick replies only make sense before the conversation has really
  /// started — once the user has sent something, offering the same starter
  /// chips again is just clutter.
  bool get showQuickReplies =>
      messages.length <= 1 && messages.every((m) => m.role != ChatRole.user);

  AdviceChatState copyWith({List<ChatTurn>? messages, bool? sending}) =>
      AdviceChatState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
      );
}

final adviceChatControllerProvider =
    NotifierProvider<AdviceChatController, AdviceChatState>(
      AdviceChatController.new,
    );

class AdviceChatController extends Notifier<AdviceChatState> {
  @override
  AdviceChatState build() => const AdviceChatState();

  Future<void> send(String text) async {
    final question = text.trim();
    if (question.isEmpty || state.sending) return;

    final history = state.messages;
    state = state.copyWith(
      messages: <ChatTurn>[
        ...history,
        ChatTurn(role: ChatRole.user, text: question),
      ],
      sending: true,
    );

    if (!ref.read(adviceConfiguredProvider)) {
      _appendError(
        "AI is off, so I can't reply right now. Turn it on in Settings → "
        'AI Settings.',
      );
      return;
    }
    if (!await ref.read(connectivityMonitorProvider).isOnline) {
      _appendError(
        "You're offline — connect to the internet to keep chatting. "
        'Everything else in Spendify still works.',
      );
      return;
    }

    try {
      final summary = await currentAdviceSummary(ref);
      final reply = await ref
          .read(adviceGeneratorRepositoryProvider)
          .ask(
            summary: summary,
            question: question,
            history: <AdviceChatTurn>[
              for (final m in history)
                if (m.role != ChatRole.error)
                  AdviceChatTurn(isUser: m.role == ChatRole.user, text: m.text),
            ],
          );
      state = state.copyWith(
        messages: <ChatTurn>[
          ...state.messages,
          ChatTurn(role: ChatRole.assistant, text: reply),
        ],
        sending: false,
      );
    } on AdviceGenerationException catch (e) {
      _appendError(e.message);
    } catch (e) {
      if (!kReleaseMode) debugPrint('ADVICE CHAT: unexpected $e');
      _appendError('Something went wrong. Try again in a moment.');
    }
  }

  void _appendError(String message) {
    state = state.copyWith(
      messages: <ChatTurn>[
        ...state.messages,
        ChatTurn(role: ChatRole.error, text: message),
      ],
      sending: false,
    );
  }
}
