import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/badge_catalogue.dart';
import '../../domain/services/gamification_engine.dart';
import '../providers/gamification_providers.dart';

/// Wraps a screen and turns each [GamificationResult] posted to
/// [gamificationFeedbackProvider] into a brief SnackBar — the "reward appears
/// right after the action that earned it" requirement (CLAUDE.md §6 usability /
/// build plan Phase 8, visibility of system status).
///
/// Deliberately modest: one floating SnackBar, no full-screen takeover, no
/// long animation — the 2-second / 60-second performance targets come first.
/// It also drains any reward posted *before* it mounted (the launch reconciler
/// completing a budget period), so that celebration isn't lost.
class GamificationFeedbackListener extends ConsumerStatefulWidget {
  const GamificationFeedbackListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<GamificationFeedbackListener> createState() =>
      _GamificationFeedbackListenerState();
}

class _GamificationFeedbackListenerState
    extends ConsumerState<GamificationFeedbackListener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
  }

  void _drain() {
    if (!mounted) return;
    final result = ref.read(gamificationFeedbackProvider.notifier).consume();
    if (result == null) return;
    final line = _feedbackLine(result);
    if (line == null) return;

    final scheme = Theme.of(context).colorScheme;
    final celebratory = result.newlyUnlockedBadgeIds.isNotEmpty;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: celebratory ? 4 : 2),
          backgroundColor: celebratory ? scheme.primary : null,
          content: Row(
            children: <Widget>[
              Icon(
                celebratory
                    ? Icons.workspace_premium_outlined
                    : (result.leveledUp
                          ? Icons.arrow_circle_up_outlined
                          : Icons.stars_outlined),
                color: celebratory ? scheme.onPrimary : null,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  line,
                  style: celebratory
                      ? TextStyle(color: scheme.onPrimary)
                      : null,
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GamificationResult?>(gamificationFeedbackProvider, (_, next) {
      if (next != null) _drain();
    });
    return widget.child;
  }
}

/// The single line shown for a result. `null` when there is nothing to say
/// (a silent reversal, or a no-op).
String? _feedbackLine(GamificationResult result) {
  if (result.newlyUnlockedBadgeIds.isNotEmpty) {
    final ids = result.newlyUnlockedBadgeIds;
    final name = badgeById(ids.first)?.name ?? 'New badge';
    final extra = ids.length - 1;
    return extra > 0
        ? 'Badge unlocked: $name  (+$extra more)'
        : 'Badge unlocked: $name';
  }
  if (result.leveledUp) {
    return result.xpAwarded > 0
        ? 'Level ${result.newLevel}!  +${result.xpAwarded} XP'
        : 'Level ${result.newLevel}!';
  }
  if (result.xpAwarded > 0) {
    return result.coinsAwarded > 0
        ? '+${result.xpAwarded} XP · +${result.coinsAwarded} coins'
        : '+${result.xpAwarded} XP';
  }
  return null;
}
