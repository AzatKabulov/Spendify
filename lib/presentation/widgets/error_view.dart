import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'centered_message.dart';

/// A plain-language error state (Phase 12 Part A). Never shows a raw exception
/// string to the user; the technical detail only prints to the debug console.
/// Offers a retry when [onRetry] is given.
class ErrorView extends StatelessWidget {
  const ErrorView({
    required this.message,
    this.detail,
    this.onRetry,
    super.key,
  });

  /// Plain-language, e.g. "Couldn't load your transactions."
  final String message;

  /// The underlying error — logged in debug, never rendered.
  final Object? detail;

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (detail != null && !kReleaseMode) {
      debugPrint('ErrorView: $message — $detail');
    }
    return CenteredMessage(
      icon: Icons.error_outline,
      title: message,
      action: onRetry == null
          ? null
          : FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
    );
  }
}
