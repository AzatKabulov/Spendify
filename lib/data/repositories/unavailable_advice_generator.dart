import '../../domain/entities/advice_item.dart';
import '../../domain/repositories/advice_generator_repository.dart';
import '../../domain/services/advice_summary_builder.dart';

/// Stand-in used when AI features are off (no key, or consent not granted —
/// Phase 10). Every call fails fast with no network I/O; the real
/// `GeminiAdviceClient` is never constructed. Mirrors
/// `UnavailableAuthRepository` (Phase 5).
class UnavailableAdviceGenerator implements AdviceGeneratorRepository {
  const UnavailableAdviceGenerator();

  @override
  Future<List<AdviceItem>> generate(AdviceSummary summary) async =>
      throw const AdviceUnavailableException();
}
