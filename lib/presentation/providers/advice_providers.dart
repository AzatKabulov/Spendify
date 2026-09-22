import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gemini_config.dart';
import '../../data/remote/gemini_advice_client.dart';
import '../../data/repositories/advice_coordinator.dart';
import '../../data/repositories/unavailable_advice_generator.dart';
import '../../domain/entities/advice_item.dart';
import '../../domain/entities/enums.dart';
import '../../domain/repositories/advice_generator_repository.dart';
import '../../domain/services/advice_summary_builder.dart';
import 'ai_providers.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';
import 'sync_providers.dart';

/// Below this many logged transactions, advice is skipped entirely — three
/// transactions produce noise, not insight (Phase 9 brief).
const int kAdviceMinTransactions = 10;

/// `true` when AI advice is usable — a key is present **and** the user has
/// granted AI consent (Phase 10). Shares the single Gemini key path with the
/// scanner (CLAUDE.md §9).
final adviceConfiguredProvider = Provider<bool>(
  (ref) => ref.watch(aiFeaturesEnabledProvider),
);

/// The Gemini text-advice client. A real `GeminiAdviceClient` only when AI is
/// enabled; otherwise a stub that fails fast with no network I/O (Phase 10).
final adviceGeneratorRepositoryProvider = Provider<AdviceGeneratorRepository>((
  ref,
) {
  if (!ref.watch(aiFeaturesEnabledProvider)) {
    return const UnavailableAdviceGenerator();
  }
  return GeminiAdviceClient(
    apiKey: ref.watch(geminiApiKeyProvider),
    model: kGeminiModel,
  );
});

final adviceCoordinatorProvider = Provider<AdviceCoordinator>((ref) {
  return AdviceCoordinator(
    generator: ref.watch(adviceGeneratorRepositoryProvider),
    cache: ref.watch(adviceRecordRepositoryProvider),
    connectivity: ref.watch(connectivityMonitorProvider),
    userId: requireCurrentUserId(ref),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  );
});

/// The exact aggregated summary that advice generation (or a chat message)
/// would send to Gemini right now, built fresh from the current data. Shared
/// by the Insights controller, the "Ask Spendify AI" chat controller, and the
/// Phase 10 "See exactly what is sent" transparency view. Reads repositories
/// directly, not a `StreamProvider` snapshot (which can still be loading).
Future<AdviceSummary> currentAdviceSummary(Ref ref) async {
  final uid = ref.read(currentUserIdProvider);
  final aggregates =
      (await ref.read(periodAggregateRepositoryProvider).getAll())
          .where((a) => a.userId == uid)
          .toList(growable: false);
  return buildAdviceSummary(
    aggregates: aggregates,
    budgets: await ref.read(budgetRepositoryProvider).getAll(),
    categories: await ref.read(categoryRepositoryProvider).getAll(),
    now: ref.read(localTimeProvider)(),
  );
}

/// [currentAdviceSummary] as a provider, for widgets that just want to watch
/// it — the Phase 10 "See exactly what is sent" transparency view.
final adviceSummaryPreviewProvider = FutureProvider<AdviceSummary>(
  (ref) => currentAdviceSummary(ref),
);

// --- view state -----------------------------------------------------

enum AdvicePhase {
  loading,
  notConfigured,
  notEnoughData,
  ready,
  emptyOffline,
  emptyError,
}

@immutable
class AdviceView {
  const AdviceView(
    this.phase, {
    this.items = const <AdviceItem>[],
    this.generatedAt,
    this.banner,
    this.busy = false,
    this.transactionCount = 0,
    this.cooldownRemaining,
    this.errorMessage,
  });

  final AdvicePhase phase;
  final List<AdviceItem> items;
  final DateTime? generatedAt;

  /// A contextual note shown *with* the advice (offline / stale / just-refreshed).
  final String? banner;

  /// A generation is in flight.
  final bool busy;
  final int transactionCount;

  /// How long until a manual refresh is allowed again (set on a throttle).
  final Duration? cooldownRemaining;
  final String? errorMessage;
}

final adviceControllerProvider = NotifierProvider<AdviceController, AdviceView>(
  AdviceController.new,
);

class AdviceController extends Notifier<AdviceView> {
  @override
  AdviceView build() => const AdviceView(AdvicePhase.loading);

  /// Called when the screen opens. Shows any cached advice immediately, then
  /// generates only if the data changed and the cooldown allows.
  Future<void> load() => _run(force: false);

  /// The manual refresh action — rate-limited by the coordinator.
  Future<void> refresh() => _run(force: true);

  Future<void> _run({required bool force}) async {
    if (!ref.read(adviceConfiguredProvider)) {
      state = const AdviceView(AdvicePhase.notConfigured);
      return;
    }

    // Read the data sources directly (not via a StreamProvider snapshot, which
    // can still be AsyncLoading the first time this runs).
    final uid = ref.read(currentUserIdProvider);
    final aggregates =
        (await ref.read(periodAggregateRepositoryProvider).getAll())
            .where((a) => a.userId == uid)
            .toList(growable: false);

    final count = aggregates
        .where((a) => a.periodType == PeriodType.yearly && a.categoryId == null)
        .fold<int>(0, (sum, a) => sum + a.transactionCount);
    if (count < kAdviceMinTransactions) {
      state = AdviceView(AdvicePhase.notEnoughData, transactionCount: count);
      return;
    }

    final cached = await ref.read(adviceRecordRepositoryProvider).getLatest();
    if (cached != null) {
      state = AdviceView(
        AdvicePhase.ready,
        items: cached.adviceItems,
        generatedAt: cached.generatedAt,
        busy: true,
      );
    } else {
      state = const AdviceView(AdvicePhase.loading, busy: true);
    }

    final summary = buildAdviceSummary(
      aggregates: aggregates,
      budgets: await ref.read(budgetRepositoryProvider).getAll(),
      categories: await ref.read(categoryRepositoryProvider).getAll(),
      now: ref.read(localTimeProvider)(),
    );
    AdviceOutcome outcome;
    try {
      outcome = await ref
          .read(adviceCoordinatorProvider)
          .getAdvice(summary, forceRefresh: force);
    } catch (error, stack) {
      if (!kReleaseMode) debugPrint('ADVICE: unexpected $error\n$stack');
      state = cached == null
          ? const AdviceView(
              AdvicePhase.emptyError,
              errorMessage: 'Something went wrong generating advice.',
            )
          : AdviceView(
              AdvicePhase.ready,
              items: cached.adviceItems,
              generatedAt: cached.generatedAt,
              banner:
                  "Couldn't refresh just now — showing your most recent "
                  'advice.',
            );
      return;
    }

    state = _mapOutcome(outcome);
  }

  AdviceView _mapOutcome(AdviceOutcome outcome) {
    switch (outcome) {
      case AdviceGenerated(:final record):
        return AdviceView(
          AdvicePhase.ready,
          items: record.adviceItems,
          generatedAt: record.generatedAt,
        );
      case AdviceFromCache(:final record):
        return AdviceView(
          AdvicePhase.ready,
          items: record.adviceItems,
          generatedAt: record.generatedAt,
        );
      case AdviceRefreshThrottled(:final record, :final retryAfter):
        return AdviceView(
          AdvicePhase.ready,
          items: record.adviceItems,
          generatedAt: record.generatedAt,
          cooldownRemaining: retryAfter,
          banner: 'Just updated a moment ago — you can refresh again shortly.',
        );
      case AdviceOffline(:final lastRecord):
        if (lastRecord == null) {
          return const AdviceView(AdvicePhase.emptyOffline);
        }
        return AdviceView(
          AdvicePhase.ready,
          items: lastRecord.adviceItems,
          generatedAt: lastRecord.generatedAt,
          banner: 'Offline — showing your most recent advice.',
        );
      case AdviceError(:final message, :final lastRecord):
        if (lastRecord == null) {
          return AdviceView(AdvicePhase.emptyError, errorMessage: message);
        }
        return AdviceView(
          AdvicePhase.ready,
          items: lastRecord.adviceItems,
          generatedAt: lastRecord.generatedAt,
          banner: message,
        );
    }
  }
}
