import 'package:hive/hive.dart';

import '../../core/clock.dart';
import '../../core/constants.dart';
import '../../domain/entities/gamification_state.dart';
import '../../domain/repositories/gamification_state_repository.dart';
import '../local/mappers/gamification_state_mapper.dart';
import '../local/models/gamification_state_model.dart';

/// Single-row store, keyed by userId. No soft delete — the row is only ever
/// created or updated (CLAUDE.md §4).
class HiveGamificationStateRepository implements GamificationStateRepository {
  HiveGamificationStateRepository(
    this._box, {
    this.clock = systemClock,
    this.userId = kLocalUserId,
  });

  final Box<GamificationStateModel> _box;
  final Clock clock;
  final String userId;

  @override
  Future<GamificationState?> get() async => _box.get(userId)?.toDomain();

  @override
  Future<GamificationState> getOrCreate() async {
    final existing = _box.get(userId);
    if (existing != null) return existing.toDomain();

    final fresh = GamificationState.initial(userId: userId, now: clock());
    await _box.put(userId, fresh.toModel());
    return fresh;
  }

  @override
  Stream<GamificationState> watch() async* {
    yield await getOrCreate();
    await for (final _ in _box.watch(key: userId)) {
      final current = _box.get(userId);
      if (current != null) yield current.toDomain();
    }
  }

  @override
  Future<GamificationState> save(GamificationState state) async {
    final stamped = state.markUpdated(at: clock());
    await _box.put(userId, stamped.toModel());
    return stamped;
  }

  @override
  Future<void> upsertFromRemote(GamificationState state) async {
    await _box.put(userId, state.toModel());
  }

  @override
  Future<void> markSynced() async {
    final current = _box.get(userId);
    if (current == null) return;
    await _box.put(userId, current.toDomain().markSynced().toModel());
  }
}
