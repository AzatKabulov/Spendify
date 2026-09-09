/// The advice-generation boundary (Phase 9). The Gemini transport is imported
/// by exactly one implementation (`data/remote/gemini_advice_client.dart`) so
/// the AI layer stays replaceable (CLAUDE.md §6).
///
/// **Ethics (CLAUDE.md §7):** the implementation sends **only** the aggregated
/// [AdviceSummary] — category totals, trends, budget adherence. Never raw
/// transactions, merchants, notes, or user identifiers.
library;

import '../entities/advice_item.dart';
import '../services/advice_summary_builder.dart';

abstract interface class AdviceGeneratorRepository {
  /// Turn the aggregated [summary] into 2–4 suggestions. Throws
  /// [AdviceGenerationException] on a transport/API failure; the caller then
  /// falls back to the last cached advice.
  Future<List<AdviceItem>> generate(AdviceSummary summary);
}

/// Why advice generation failed. Each maps to a short, non-alarming message;
/// the UI always falls back to the last cached advice, never a dead end.
sealed class AdviceGenerationException implements Exception {
  const AdviceGenerationException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType($message)';
}

final class AdviceNetworkException extends AdviceGenerationException {
  const AdviceNetworkException({Object? cause})
    : super(
        "Couldn't reach the advice service. Showing your most recent advice.",
        cause: cause,
      );
}

final class AdviceTimeoutException extends AdviceGenerationException {
  const AdviceTimeoutException({Object? cause})
    : super('The advice service took too long. Try again later.', cause: cause);
}

final class AdviceRateLimitedException extends AdviceGenerationException {
  const AdviceRateLimitedException({Object? cause})
    : super(
        'The advice service is busy. Try again in a little while.',
        cause: cause,
      );
}

/// Gemini refused to answer (safety filters) or returned an empty candidate.
final class AdviceBlockedException extends AdviceGenerationException {
  const AdviceBlockedException({Object? cause})
    : super(
        "Couldn't generate advice for this data. Try again later.",
        cause: cause,
      );
}

/// A non-2xx response, or a body we could not make any advice out of.
final class AdviceApiException extends AdviceGenerationException {
  const AdviceApiException(super.message, {super.cause});
}

/// No API key configured on this build (CLAUDE.md §9 A/B decision pending).
final class AdviceUnavailableException extends AdviceGenerationException {
  const AdviceUnavailableException()
    : super('AI advice is not set up in this build.');
}
