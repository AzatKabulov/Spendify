import 'package:flutter/material.dart';

import '../../core/theme/insets.dart';

/// A centred icon + title + message used for empty and informational states
/// (no transactions, no budgets, an empty report period, …).
///
/// It centres when there is room and becomes scrollable when there is not, so
/// it never overflows — which matters at large system text scales, where a
/// fixed column of text can exceed a short body area (Phase 12 Part C).
class CenteredMessage extends StatelessWidget {
  const CenteredMessage({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// Optional call-to-action below the message (e.g. a "Try again" button).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(Insets.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 56, color: theme.colorScheme.outline),
                  const SizedBox(height: Insets.md),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (message != null) ...<Widget>[
                    const SizedBox(height: Insets.sm),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (action != null) ...<Widget>[
                    const SizedBox(height: Insets.lg),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
