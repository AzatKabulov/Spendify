import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/insets.dart';
import '../providers/advice_chat_providers.dart';
import '../widgets/advice/advice_widgets.dart';
import '../widgets/auth/auth_illustrations.dart';
import '../widgets/form_header.dart';

/// "Ask Spendify AI" — a real, minimal chat over the user's own aggregated
/// spending summary (see `advice_chat_providers.dart` for what is and is not
/// sent, and why the conversation is never persisted).
class AdviceChatScreen extends ConsumerStatefulWidget {
  const AdviceChatScreen({super.key});

  @override
  ConsumerState<AdviceChatScreen> createState() => _AdviceChatScreenState();
}

class _AdviceChatScreenState extends ConsumerState<AdviceChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _input.clear();
    _scrollToBottom();
    await ref.read(adviceChatControllerProvider.notifier).send(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adviceChatControllerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const FormHeader(
              title: 'Ask Spendify AI',
              subtitle: 'Get personalised financial advice',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Insets.md),
              child: Align(
                alignment: Alignment.centerRight,
                child: GeminiMark(),
              ),
            ),
            const SizedBox(height: Insets.sm),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                itemCount: state.messages.length + (state.sending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == state.messages.length) {
                    return const _TypingRow();
                  }
                  return _MessageBubble(
                    turn: state.messages[index],
                    isGreeting: index == 0,
                  );
                },
              ),
            ),
            if (state.showQuickReplies)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  Insets.sm,
                  Insets.md,
                  0,
                ),
                child: Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: <Widget>[
                    for (final reply in kChatQuickReplies)
                      ActionChip(
                        label: Text(reply),
                        onPressed: state.sending ? null : () => _send(reply),
                      ),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  Insets.sm,
                  Insets.md,
                  Insets.sm,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _input,
                        enabled: !state.sending,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _send,
                        decoration: InputDecoration(
                          hintText: 'Ask a follow-up question…',
                          filled: true,
                          fillColor: scheme.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: Insets.md,
                            vertical: Insets.sm + 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    IconButton.filled(
                      onPressed: state.sending
                          ? null
                          : () => _send(_input.text),
                      icon: const Icon(Icons.arrow_upward),
                      tooltip: 'Send',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.turn, required this.isGreeting});

  final ChatTurn turn;
  final bool isGreeting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (turn.role == ChatRole.error) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        child: Row(
          children: <Widget>[
            Icon(Icons.info_outline, size: 16, color: scheme.error),
            const SizedBox(width: Insets.xs + 2),
            Expanded(
              child: Text(
                turn.text,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          ],
        ),
      );
    }

    final isUser = turn.role == ChatRole.user;
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm + 2,
      ),
      decoration: BoxDecoration(
        color: isUser ? scheme.primary : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        turn.text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isUser ? scheme.onPrimary : scheme.onSurface,
        ),
      ),
    );

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xs + 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[bubble],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(
                width: 28,
                height: 36,
                child: FittedBox(child: AssistantMascot()),
              ),
              const SizedBox(width: Insets.sm),
              Flexible(child: bubble),
            ],
          ),
          // Only a real Gemini reply is marked as such — the opening
          // greeting is authored UI copy, not a model output.
          if (!isGreeting)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.auto_awesome, size: 11, color: scheme.primary),
                  const SizedBox(width: 3),
                  Text(
                    'Gemini',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TypingRow extends StatelessWidget {
  const _TypingRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: Insets.xs + 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 28,
            height: 36,
            child: FittedBox(child: AssistantMascot()),
          ),
          SizedBox(width: Insets.sm),
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
    );
  }
}
