import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/data/repositories/aggregation_maintenance.dart';
import 'package:spendify/data/repositories/sync_manager.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/sync_snapshot.dart';
import 'package:spendify/domain/entities/transaction.dart';
import 'package:spendify/domain/repositories/remote_sync_gateway.dart';

import '../../support/fake_repositories.dart';
import '../../support/fake_sync.dart';

const _uid = 'u';
final _now = DateTime.utc(2026, 9, 9, 12);

Transaction _txn(
  String id, {
  int amountMinor = 2500,
  DateTime? updatedAt,
  bool isDeleted = false,
  SyncStatus syncStatus = SyncStatus.synced,
}) => Transaction(
  id: id,
  userId: _uid,
  amountMinor: amountMinor,
  type: TransactionType.expense,
  categoryId: 'food',
  date: _now,
  source: TransactionSource.manual,
  createdAt: _now,
  updatedAt: updatedAt ?? _now,
  isDeleted: isDeleted,
  syncStatus: syncStatus,
);

Map<String, Object?> _remoteTxn(
  String id, {
  int amountMinor = 999,
  DateTime? updatedAt,
  bool isDeleted = false,
}) => <String, Object?>{
  'id': id,
  'userId': _uid,
  'amountMinor': amountMinor,
  'type': 'expense',
  'categoryId': 'food',
  'date': _now,
  'note': null,
  'source': 'manual',
  'createdAt': _now,
  'updatedAt': updatedAt ?? _now,
  'isDeleted': isDeleted,
};

class _Stack {
  _Stack([FakeRemoteSyncGateway? sharedGateway])
    : gateway = sharedGateway ?? FakeRemoteSyncGateway() {
    final aggRepo = FakePeriodAggregateRepository();
    aggregates = aggRepo;
    manager = SyncManager(
      gateway: gateway,
      connectivity: connectivity,
      transactions: transactions,
      categories: categories,
      budgets: budgets,
      gamification: gamification,
      aggregates: AggregationMaintenance(
        aggRepo,
        userId: _uid,
        clock: () => _now,
      ),
      metadata: metadata,
      userId: _uid,
      clock: () => _now,
    );
  }

  final FakeRemoteSyncGateway gateway;
  final connectivity = FakeConnectivityMonitor(startOnline: true);
  final transactions = FakeTransactionRepository();
  final categories = FakeCategoryRepository();
  final budgets = FakeBudgetRepository();
  final gamification = FakeGamificationStateRepository(userId: _uid);
  final metadata = InMemorySyncMetadataStore();
  late final FakePeriodAggregateRepository aggregates;
  late final SyncManager manager;

  Future<void> dispose() async {
    await manager.dispose();
    await connectivity.close();
  }
}

void main() {
  test('pending records push, flip to synced, updatedAt unchanged', () async {
    final s = _Stack();
    addTearDown(s.dispose);

    await s.transactions.upsertFromRemote(
      _txn('t1', syncStatus: SyncStatus.pending, updatedAt: _now),
    );
    final before = (await s.transactions.getByIdIncludingDeleted('t1'))!;

    final outcome = await s.manager.syncNow();

    expect(outcome, SyncOutcome.success);
    expect(s.gateway.store['transactions']!.containsKey('t1'), isTrue);
    final after = (await s.transactions.getByIdIncludingDeleted('t1'))!;
    expect(after.syncStatus, SyncStatus.synced);
    expect(
      after.updatedAt,
      before.updatedAt,
      reason: 'markSynced must not re-stamp updatedAt (false "newer" on pull)',
    );
  });

  test('nothing pending -> no push call', () async {
    final s = _Stack();
    addTearDown(s.dispose);
    await s.manager.syncNow();
    expect(s.gateway.pushCallCount, 0);
  });

  test(
    'offline -> no push, snapshot goes offline, local write untouched',
    () async {
      final s = _Stack();
      addTearDown(s.dispose);
      s.connectivity.online = false;
      await s.transactions.upsertFromRemote(
        _txn('t1', syncStatus: SyncStatus.pending),
      );

      final outcome = await s.manager.syncNow();

      expect(outcome, SyncOutcome.offline);
      expect(s.gateway.pushCallCount, 0);
      expect(s.manager.snapshot.phase, SyncPhase.offline);
      expect(
        (await s.transactions.getByIdIncludingDeleted('t1'))!.syncStatus,
        SyncStatus.pending,
      );
    },
  );

  group('conflict resolution — last-write-wins on updatedAt', () {
    test('remote newer -> remote overwrites local', () async {
      final s = _Stack();
      addTearDown(s.dispose);
      await s.transactions.upsertFromRemote(_txn('t1', amountMinor: 100));
      s.gateway.seed(
        SyncCollection.transactions,
        't1',
        _remoteTxn(
          't1',
          amountMinor: 999,
          updatedAt: _now.add(const Duration(minutes: 5)),
        ),
      );

      await s.manager.syncNow();

      expect((await s.transactions.getById('t1'))!.amountMinor, 999);
    });

    test('local newer -> keep local', () async {
      final s = _Stack();
      addTearDown(s.dispose);
      await s.transactions.upsertFromRemote(
        _txn(
          't1',
          amountMinor: 100,
          updatedAt: _now.add(const Duration(minutes: 5)),
        ),
      );
      s.gateway.seed(
        SyncCollection.transactions,
        't1',
        _remoteTxn('t1', amountMinor: 999, updatedAt: _now),
      );

      await s.manager.syncNow();

      expect((await s.transactions.getById('t1'))!.amountMinor, 100);
    });

    test('equal updatedAt -> keep local (deterministic)', () async {
      final s = _Stack();
      addTearDown(s.dispose);
      await s.transactions.upsertFromRemote(_txn('t1', amountMinor: 100));
      s.gateway.seed(
        SyncCollection.transactions,
        't1',
        _remoteTxn('t1', amountMinor: 999, updatedAt: _now),
      );

      await s.manager.syncNow();

      expect((await s.transactions.getById('t1'))!.amountMinor, 100);
    });
  });

  test('a synced tombstone does NOT resurrect on a restoring device', () async {
    final shared = FakeRemoteSyncGateway();
    final device1 = _Stack(shared);
    addTearDown(device1.dispose);

    await device1.transactions.upsertFromRemote(
      _txn('t1', syncStatus: SyncStatus.pending),
    );
    await device1.manager.syncNow(); // uploads t1

    await device1.transactions.delete('t1'); // soft delete -> pending tombstone
    await device1.manager.syncNow(); // uploads the tombstone
    expect(shared.store['transactions']!['t1']!['isDeleted'], isTrue);

    // Fresh install, same account, same backend.
    final device2 = _Stack(shared);
    addTearDown(device2.dispose);
    await device2.manager.restoreFromBackup();

    expect(
      await device2.transactions.getById('t1'),
      isNull,
      reason: 'restored as deleted, not resurrected',
    );
    final tomb = await device2.transactions.getByIdIncludingDeleted('t1');
    expect(tomb, isNotNull);
    expect(tomb!.isDeleted, isTrue);
  });

  test('restore pulls everything and rebuilds aggregates', () async {
    final shared = FakeRemoteSyncGateway();
    final source = _Stack(shared);
    addTearDown(source.dispose);
    for (var i = 0; i < 5; i++) {
      await source.transactions.upsertFromRemote(
        _txn('t$i', amountMinor: 1000, syncStatus: SyncStatus.pending),
      );
    }
    await source.manager.syncNow();

    final fresh = _Stack(shared);
    addTearDown(fresh.dispose);
    expect(await fresh.transactions.getAll(), isEmpty);

    await fresh.manager.restoreFromBackup();

    expect((await fresh.transactions.getAll()).length, 5);
    final aggs = await fresh.aggregates.getAll();
    expect(aggs, isNotEmpty);
    final yearlyTotal = aggs.firstWhere(
      (a) => a.periodType == PeriodType.yearly && a.categoryId == null,
    );
    expect(yearlyTotal.totalExpenseMinor, 5000);
    expect(fresh.metadata.restoreCompleted, isTrue);
  });

  test('syncNow is single-flight — a second call joins the first', () async {
    final s = _Stack();
    addTearDown(s.dispose);
    await s.transactions.upsertFromRemote(
      _txn('t1', syncStatus: SyncStatus.pending),
    );
    s.gateway.pushGate = Completer<void>();

    final a = s.manager.syncNow();
    final b = s.manager.syncNow();
    expect(identical(a, b), isTrue);

    s.gateway.pushGate!.complete();
    await Future.wait([a, b]);
    expect(s.gateway.pushCallCount, 1); // one real run
  });

  test('an interrupted push loses nothing and does not duplicate', () async {
    final s = _Stack();
    addTearDown(s.dispose);
    await s.transactions.upsertFromRemote(
      _txn('t1', syncStatus: SyncStatus.pending),
    );
    await s.transactions.upsertFromRemote(
      _txn('t2', syncStatus: SyncStatus.pending),
    );

    s.gateway.throwOnNextPush = const RetryableSyncException('boom');
    expect(await s.manager.syncNow(), SyncOutcome.retryableFailure);
    // push failed -> nothing marked synced
    expect((await s.transactions.getPendingSync()).length, 2);

    final second = await s.manager.syncNow();
    expect(second, SyncOutcome.success);
    expect(await s.transactions.getPendingSync(), isEmpty);
    expect(s.gateway.store['transactions']!.keys.toSet(), {'t1', 't2'});
  });

  test('permanent failure is surfaced and not retried in a loop', () async {
    final s = _Stack();
    addTearDown(s.dispose);
    await s.transactions.upsertFromRemote(
      _txn('t1', syncStatus: SyncStatus.pending),
    );
    s.gateway.alwaysThrowOnPush = const PermanentSyncException(
      'permission denied',
    );

    final outcome = await s.manager.syncNow();

    expect(outcome, SyncOutcome.permanentFailure);
    expect(s.manager.snapshot.phase, SyncPhase.error);
    expect(s.manager.snapshot.lastError, contains('permission denied'));
    expect(s.gateway.pushCallCount, 1); // one attempt, no retry storm
  });
}
