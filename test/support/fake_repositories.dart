import 'dart:async';

import 'package:spendify/core/clock.dart';
import 'package:spendify/data/repositories/default_categories.dart';
import 'package:spendify/data/repositories/local_data_wiper.dart';
import 'package:spendify/domain/entities/advice_item.dart';
import 'package:spendify/domain/entities/advice_record.dart';
import 'package:spendify/domain/entities/ai_consent.dart';
import 'package:spendify/domain/entities/budget.dart';
import 'package:spendify/domain/entities/category.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/gamification_state.dart';
import 'package:spendify/domain/entities/period_aggregate.dart';
import 'package:spendify/domain/entities/syncable.dart';
import 'package:spendify/domain/entities/transaction.dart';
import 'package:spendify/domain/repositories/advice_generator_repository.dart';
import 'package:spendify/domain/repositories/advice_record_repository.dart';
import 'package:spendify/domain/repositories/auth_repository.dart';
import 'package:spendify/domain/repositories/budget_repository.dart';
import 'package:spendify/domain/repositories/category_repository.dart';
import 'package:spendify/domain/repositories/gamification_state_repository.dart';
import 'package:spendify/domain/repositories/period_aggregate_repository.dart';
import 'package:spendify/domain/repositories/transaction_repository.dart';
import 'package:spendify/domain/services/advice_summary_builder.dart';
import 'package:spendify/data/local/ai_preferences_store.dart';
import 'package:spendify/data/local/app_preferences.dart';

/// In-memory synchronous stand-ins for the Hive repositories, for widget tests.
/// They apply the same CLAUDE.md §8 mutation rules as the real base repo, minus
/// the disk I/O that would need `tester.runAsync` in a widget test.
abstract class _InMemorySyncableRepository<E extends Syncable<E>> {
  final Map<String, E> _store = <String, E>{};
  final Set<void Function()> _listeners = <void Function()>{};

  DateTime now() => DateTime.utc(2026, 9, 8, 12);

  List<E> _live() =>
      _store.values.where((e) => !e.isDeleted).toList(growable: false);

  List<E> _all() => _store.values.toList(growable: false);

  void _notify() {
    for (final fn in _listeners.toList()) {
      fn();
    }
  }

  Future<List<E>> getAll() async => _live();

  Future<E?> getById(String id) async {
    final e = _store[id];
    return (e == null || e.isDeleted) ? null : e;
  }

  Stream<List<E>> watchAll() => _watch(_live);

  Stream<List<E>> watchAllIncludingDeleted() => _watch(_all);

  Stream<List<E>> _watch(List<E> Function() snapshot) {
    late final StreamController<List<E>> c;
    void emit() {
      if (!c.isClosed) c.add(snapshot());
    }

    c = StreamController<List<E>>(
      onListen: () {
        _listeners.add(emit);
        emit();
      },
      onCancel: () => _listeners.remove(emit),
    );
    return c.stream;
  }

  Future<E> add(E entity) async {
    final stamped = entity.markUpdated(at: now());
    _store[stamped.id] = stamped;
    _notify();
    return stamped;
  }

  Future<E> update(E entity) => add(entity);

  Future<void> delete(String id) async {
    final e = _store[id];
    if (e == null) return;
    _store[id] = e.markDeleted(at: now());
    _notify();
  }

  Future<void> restore(String id) async {
    final e = _store[id];
    if (e == null || !e.isDeleted) return;
    _store[id] = e.markRestored(at: now());
    _notify();
  }

  Future<List<E>> getPendingSync() async => _store.values
      .where((e) => e.syncStatus == SyncStatus.pending)
      .toList(growable: false);

  Future<E?> getByIdIncludingDeleted(String id) async => _store[id];

  /// Test-only hard wipe (backs [FakeLocalDataWiper]).
  void wipeForTest() {
    _store.clear();
    _notify();
  }

  Future<void> upsertFromRemote(E entity) async {
    _store[entity.id] = entity;
    _notify();
  }

  Future<void> markSynced(String id) async {
    final e = _store[id];
    if (e == null) return;
    _store[id] = e.markSynced();
    _notify();
  }
}

class FakeTransactionRepository extends _InMemorySyncableRepository<Transaction>
    implements TransactionRepository {
  @override
  Future<List<Transaction>> getInDateRange({
    required DateTime from,
    required DateTime to,
  }) async =>
      (await getAll())
          .where((t) => !t.date.isBefore(from) && t.date.isBefore(to))
          .toList(growable: false)
        ..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<List<Transaction>> getByCategory(String categoryId) async =>
      (await getAll())
          .where((t) => t.categoryId == categoryId)
          .toList(growable: false)
        ..sort((a, b) => b.date.compareTo(a.date));
}

class FakeBudgetRepository extends _InMemorySyncableRepository<Budget>
    implements BudgetRepository {
  @override
  Future<Budget?> getOverall() async {
    for (final b in _live()) {
      if (b.isOverall) return b;
    }
    return null;
  }

  @override
  Future<Budget?> getForCategory(String categoryId) async {
    for (final b in _live()) {
      if (b.categoryId == categoryId) return b;
    }
    return null;
  }
}

class FakeCategoryRepository extends _InMemorySyncableRepository<Category>
    implements CategoryRepository {
  bool _seeded = false;
  int _seq = 0;

  @override
  Future<void> ensureDefaultsSeeded() async {
    if (_seeded) return;
    _seeded = true;
    for (final seed in kDefaultCategories) {
      final c = Category.create(
        id: 'cat-${_seq++}',
        userId: 'local-user',
        name: seed.name,
        iconCode: seed.iconCode,
        colorValue: seed.colorValue,
        now: now(),
        isDefault: true,
      );
      _store[c.id] = c;
    }
    _notify();
  }
}

class FakePeriodAggregateRepository implements PeriodAggregateRepository {
  final Map<String, PeriodAggregate> store = <String, PeriodAggregate>{};
  final Set<void Function()> _listeners = <void Function()>{};

  void _notify() {
    for (final fn in _listeners.toList()) {
      fn();
    }
  }

  @override
  Future<PeriodAggregate?> getById(String id) async => store[id];

  @override
  Future<List<PeriodAggregate>> getAll() async =>
      store.values.toList(growable: false);

  @override
  Future<List<PeriodAggregate>> getByPeriodType(PeriodType periodType) async =>
      store.values.where((a) => a.periodType == periodType).toList();

  @override
  Future<List<PeriodAggregate>> getForPeriodKey({
    required PeriodType periodType,
    required String periodKey,
  }) async => store.values
      .where((a) => a.periodType == periodType && a.periodKey == periodKey)
      .toList();

  @override
  Future<void> put(PeriodAggregate aggregate) async {
    store[aggregate.id] = aggregate;
    _notify();
  }

  @override
  Future<void> putAll(List<PeriodAggregate> aggregates) async {
    for (final a in aggregates) {
      store[a.id] = a;
    }
    _notify();
  }

  @override
  Future<void> removeAll(List<String> ids) async {
    for (final id in ids) {
      store.remove(id);
    }
    _notify();
  }

  @override
  Future<void> clear() async {
    store.clear();
    _notify();
  }

  @override
  Stream<List<PeriodAggregate>> watchAll() {
    late final StreamController<List<PeriodAggregate>> c;
    void emit() {
      if (!c.isClosed) c.add(store.values.toList(growable: false));
    }

    c = StreamController<List<PeriodAggregate>>(
      onListen: () {
        _listeners.add(emit);
        emit();
      },
      onCancel: () => _listeners.remove(emit),
    );
    return c.stream;
  }
}

class FakeAppPreferences implements AppPreferences {
  String? _lastUsed;

  @override
  String? get lastUsedCategoryId => _lastUsed;

  @override
  Future<void> setLastUsedCategoryId(String categoryId) async {
    _lastUsed = categoryId;
  }
}

/// In-memory AI consent store (Phase 10).
class FakeAiPreferencesStore implements AiPreferencesStore {
  FakeAiPreferencesStore([this._consent = AiConsent.undecided]);

  AiConsent _consent;

  @override
  AiConsent get consent => _consent;

  @override
  Future<void> setConsent(AiConsent value) async => _consent = value;
}

/// [LocalDataWiper] that clears the in-memory fakes it is handed (Phase 10).
class FakeLocalDataWiper implements LocalDataWiper {
  FakeLocalDataWiper({
    required this.transactions,
    required this.categories,
    required this.budgets,
    required this.aggregates,
    required this.gamification,
    required this.adviceCache,
  });

  final FakeTransactionRepository transactions;
  final FakeCategoryRepository categories;
  final FakeBudgetRepository budgets;
  final FakePeriodAggregateRepository aggregates;
  final FakeGamificationStateRepository gamification;
  final FakeAdviceRecordRepository adviceCache;

  bool wiped = false;

  @override
  Future<void> wipe() async {
    transactions.wipeForTest();
    categories.wipeForTest();
    budgets.wipeForTest();
    await aggregates.clear();
    gamification.wipeForTest();
    await adviceCache.clear();
    wiped = true;
  }
}

/// In-memory [GamificationStateRepository]. `watch()` emits the current (or a
/// fresh initial) state on listen, then every change — matching the Hive repo.
class FakeGamificationStateRepository implements GamificationStateRepository {
  FakeGamificationStateRepository({String userId = 'u', Clock? clock})
    : _ownerId = userId,
      _clock = clock ?? systemClock;

  final String _ownerId;
  final Clock _clock;
  GamificationState? _state;
  final _controller = StreamController<GamificationState>.broadcast();

  @override
  Future<GamificationState?> get() async => _state;

  @override
  Future<GamificationState> getOrCreate() async =>
      _state ??= GamificationState.initial(userId: _ownerId, now: _clock());

  @override
  Stream<GamificationState> watch() async* {
    yield await getOrCreate();
    yield* _controller.stream;
  }

  @override
  Future<GamificationState> save(GamificationState state) async {
    _state = state.markUpdated(at: _clock());
    _controller.add(_state!);
    return _state!;
  }

  @override
  Future<void> upsertFromRemote(GamificationState state) async {
    _state = state;
    _controller.add(state);
  }

  /// Test-only hard wipe (Phase 10 delete-all-data).
  void wipeForTest() => _state = null;

  @override
  Future<void> markSynced() async {
    final s = _state;
    if (s != null) _state = s.markSynced();
  }
}

/// In-memory [AdviceRecordRepository] — the advice cache.
class FakeAdviceRecordRepository implements AdviceRecordRepository {
  final List<AdviceRecord> records = <AdviceRecord>[];

  @override
  Future<AdviceRecord?> getLatest() async => records.isEmpty
      ? null
      : records.reduce((a, b) => a.generatedAt.isAfter(b.generatedAt) ? a : b);

  @override
  Future<AdviceRecord?> getBySummaryHash(String summaryHash) async {
    for (final r in records) {
      if (r.summaryHash == summaryHash) return r;
    }
    return null;
  }

  @override
  Future<AdviceRecord> save(AdviceRecord record) async {
    records.add(record);
    return record;
  }

  @override
  Future<void> clear() async => records.clear();
}

/// Scriptable [AdviceGeneratorRepository] — no Gemini. Counts calls so tests
/// can assert "identical data -> no API call".
class FakeAdviceGenerator implements AdviceGeneratorRepository {
  int calls = 0;
  AdviceSummary? lastSummary;
  AdviceGenerationException? failWith;
  List<AdviceItem> next = const <AdviceItem>[
    AdviceItem(
      title: 'Ease off Food a little',
      body:
          'Food is your biggest category this month. Trying to keep it '
          'nearer RM 250 would free up some room.',
    ),
    AdviceItem(
      title: 'Nice work staying under on Transport',
      body:
          'You came in below your Transport budget — keep doing what you '
          'are doing there.',
    ),
  ];

  @override
  Future<List<AdviceItem>> generate(AdviceSummary summary) async {
    calls++;
    lastSummary = summary;
    final failure = failWith;
    if (failure != null) throw failure;
    return next;
  }
}

/// Scriptable [AuthRepository] for auth-screen widget tests — no Firebase.
class FakeAuthRepository implements AuthRepository {
  /// UID returned by a successful sign-in / sign-up.
  String nextUid = 'fake-uid-1';

  /// If set, every call throws this instead of succeeding.
  AuthException? failWith;

  /// If set, calls await this before completing — lets a test hold the request
  /// "in flight" to assert the submit button is disabled.
  Completer<void>? gate;

  int signInCalls = 0;
  int signUpCalls = 0;
  int signOutCalls = 0;
  int resetCalls = 0;

  @override
  String? currentUserId;

  @override
  String? currentUserEmail;

  Future<String> _authenticate(String email) async {
    if (gate != null) await gate!.future;
    final failure = failWith;
    if (failure != null) throw failure;
    currentUserId = nextUid;
    currentUserEmail = email.trim();
    return nextUid;
  }

  @override
  Future<String> signIn({required String email, required String password}) {
    signInCalls++;
    return _authenticate(email);
  }

  @override
  Future<String> signUp({required String email, required String password}) {
    signUpCalls++;
    return _authenticate(email);
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    resetCalls++;
    if (gate != null) await gate!.future;
    final failure = failWith;
    if (failure != null) throw failure;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    currentUserId = null;
    currentUserEmail = null;
  }
}
