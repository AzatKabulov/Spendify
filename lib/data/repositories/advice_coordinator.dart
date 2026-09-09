import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/clock.dart';
import '../../core/id_generator.dart';
import '../../domain/entities/advice_record.dart';
import '../../domain/repositories/advice_generator_repository.dart';
import '../../domain/repositories/advice_record_repository.dart';
import '../../domain/repositories/connectivity_monitor.dart';
import '../../domain/services/advice_summary_builder.dart';

/// SHA-256 over the spending-material fields of the summary (`stableOnly`), so
/// identical spending data hashes identically and a day merely elapsing does
/// not. Deterministic key order.
String hashAdviceSummary(AdviceSummary summary) {
  final canonical = jsonEncode(summary.toJson(stableOnly: true));
  return sha256.convert(utf8.encode(canonical)).toString();
}

/// Outcome of asking for advice — the coordinator decides whether an API call
/// is warranted at all (CLAUDE.md §3: AI is off the critical path and must
/// degrade gracefully).
sealed class AdviceOutcome {
  const AdviceOutcome();
}

/// A fresh Gemini call was made and cached.
class AdviceGenerated extends AdviceOutcome {
  const AdviceGenerated(this.record);
  final AdviceRecord record;
}

/// The summary hash matched the cache (or a change is still within the refresh
/// cooldown) — served from cache, **no API call**.
class AdviceFromCache extends AdviceOutcome {
  const AdviceFromCache(this.record);
  final AdviceRecord record;
}

/// A manual refresh was requested too soon after the last one.
class AdviceRefreshThrottled extends AdviceOutcome {
  const AdviceRefreshThrottled(this.record, this.retryAfter);
  final AdviceRecord record;
  final Duration retryAfter;
}

/// Offline and the data has changed since the last advice — show the last
/// cached advice ([lastRecord], possibly `null` if there is none yet).
class AdviceOffline extends AdviceOutcome {
  const AdviceOffline(this.lastRecord);
  final AdviceRecord? lastRecord;
}

/// The API call failed — fall back to [lastRecord] (possibly `null`).
class AdviceError extends AdviceOutcome {
  const AdviceError(this.message, this.lastRecord);
  final String message;
  final AdviceRecord? lastRecord;
}

/// Coordinates summary-hash caching, the manual-refresh rate limit, the offline
/// fallback and the Gemini call. Not a Riverpod thing — the provider layer maps
/// an [AdviceOutcome] onto view state.
class AdviceCoordinator {
  AdviceCoordinator({
    required this.generator,
    required this.cache,
    required this.connectivity,
    required this.userId,
    required this.clock,
    required this.newId,
    this.refreshCooldown = const Duration(minutes: 3),
  });

  final AdviceGeneratorRepository generator;
  final AdviceRecordRepository cache;
  final ConnectivityMonitor connectivity;
  final String userId;
  final Clock clock;
  final IdGenerator newId;
  final Duration refreshCooldown;

  Future<AdviceOutcome> getAdvice(
    AdviceSummary summary, {
    bool forceRefresh = false,
  }) async {
    final hash = hashAdviceSummary(summary);
    final latest = await cache.getLatest();

    // 1. Identical data -> serve cache, never call the API.
    if (!forceRefresh && latest != null && latest.summaryHash == hash) {
      return AdviceFromCache(latest);
    }

    // 2. Rate limit. A manual refresh gets a "too soon" outcome; an automatic
    //    regen after a data change just quietly serves the recent cache.
    if (latest != null) {
      final since = clock().difference(latest.generatedAt);
      if (since < refreshCooldown) {
        if (forceRefresh) {
          return AdviceRefreshThrottled(latest, refreshCooldown - since);
        }
        return AdviceFromCache(latest);
      }
    }

    // 3. Offline -> last cached advice with its timestamp, never an error.
    if (!await connectivity.isOnline) {
      return AdviceOffline(latest);
    }

    // 4. Generate.
    try {
      final items = await generator.generate(summary);
      final record = await cache.save(
        AdviceRecord(
          id: newId(),
          userId: userId,
          generatedAt: clock(),
          summaryHash: hash,
          adviceItems: items,
        ),
      );
      return AdviceGenerated(record);
    } on AdviceGenerationException catch (e) {
      return AdviceError(e.message, latest);
    }
  }
}
