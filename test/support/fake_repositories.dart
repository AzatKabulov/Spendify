import 'dart:async';

import 'package:spendly/data/repositories/default_categories.dart';
import 'package:spendly/domain/entities/category.dart';
import 'package:spendly/domain/entities/enums.dart';
import 'package:spendly/domain/entities/syncable.dart';
import 'package:spendly/domain/entities/transaction.dart';
import 'package:spendly/domain/repositories/category_repository.dart';
import 'package:spendly/domain/repositories/transaction_repository.dart';
import 'package:spendly/data/local/app_preferences.dart';

/// In-memory synchronous stand-ins for the Hive repositories, for widget tests.
/// They apply the same CLAUDE.md §8 mutation rules as the real base repo, minus
/// the disk I/O that would need `tester.runAsync` in a widget test.
abstract class _InMemorySyncableRepository<E extends Syncable<E>> {
  final Map<String, E> _store = <String, E>{};
  final Set<StreamController<List<E>>> _listeners =
      <StreamController<List<E>>>{};

  DateTime now() => DateTime.utc(2026, 9, 8, 12);

  List<E> _live() =>
      _store.values.where((e) => !e.isDeleted).toList(growable: false);

  void _notify() {
    for (final c in _listeners) {
      if (!c.isClosed) c.add(_live());
    }
  }

  Future<List<E>> getAll() async => _live();

  Future<E?> getById(String id) async {
    final e = _store[id];
    return (e == null || e.isDeleted) ? null : e;
  }

  Stream<List<E>> watchAll() {
    late final StreamController<List<E>> c;
    c = StreamController<List<E>>(
      onListen: () {
        _listeners.add(c);
        c.add(_live());
      },
      onCancel: () => _listeners.remove(c),
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

class FakeAppPreferences implements AppPreferences {
  String? _lastUsed;

  @override
  String? get lastUsedCategoryId => _lastUsed;

  @override
  Future<void> setLastUsedCategoryId(String categoryId) async {
    _lastUsed = categoryId;
  }
}
