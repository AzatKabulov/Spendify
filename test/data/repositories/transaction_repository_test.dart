import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/constants.dart';
import 'package:spendly/data/repositories/hive_transaction_repository.dart';
import 'package:spendly/domain/entities/enums.dart';
import 'package:spendly/domain/entities/transaction.dart';

import '../../support/hive_test_harness.dart';

void main() {
  late HiveTestHarness harness;
  late DateTime fakeNow;
  late HiveTransactionRepository repo;

  Transaction sample({String id = 't1', int amountMinor = 1500}) => Transaction(
    id: id,
    userId: kLocalUserId,
    amountMinor: amountMinor,
    type: TransactionType.expense,
    categoryId: 'cat-food',
    date: DateTime.utc(2026, 9, 1),
    note: 'Nasi lemak',
    source: TransactionSource.manual,
    createdAt: DateTime.utc(2026, 9, 1, 8),
    updatedAt: DateTime.utc(2026, 9, 1, 8),
    syncStatus: SyncStatus.synced,
  );

  setUp(() async {
    harness = await HiveTestHarness.start();
    fakeNow = DateTime.utc(2026, 9, 6, 12);
    repo = HiveTransactionRepository(
      harness.store.transactions,
      userId: kLocalUserId,
      clock: () => fakeNow,
    );
  });

  tearDown(() => harness.dispose());

  test('add then getById returns an equal transaction', () async {
    final stored = await repo.add(sample());

    final fetched = await repo.getById('t1');
    expect(fetched, isNotNull);
    expect(fetched, equals(stored));
    expect(fetched!.amountMinor, 1500);
    expect(fetched.note, 'Nasi lemak');
    expect(fetched.categoryId, 'cat-food');
  });

  test(
    'add stamps updatedAt from the clock and sets syncStatus = pending',
    () async {
      final stored = await repo.add(sample());

      expect(stored.updatedAt, fakeNow);
      expect(stored.syncStatus, SyncStatus.pending);
      // createdAt is preserved, not overwritten.
      expect(stored.createdAt, DateTime.utc(2026, 9, 1, 8));
    },
  );

  test(
    'update re-stamps updatedAt and flips syncStatus back to pending',
    () async {
      await repo.add(sample());
      final synced = (await repo.getById('t1'))!.markSynced();
      await repo.upsertFromRemote(synced); // simulate a completed sync
      expect((await repo.getById('t1'))!.syncStatus, SyncStatus.synced);

      fakeNow = DateTime.utc(2026, 9, 7, 9);
      final edited = await repo.update(synced.copyWith(amountMinor: 2000));

      expect(edited.amountMinor, 2000);
      expect(edited.updatedAt, DateTime.utc(2026, 9, 7, 9));
      expect(edited.syncStatus, SyncStatus.pending);
    },
  );

  test('getAll returns only live transactions, newest first by date', () async {
    await repo.add(sample(id: 'a').copyWith(date: DateTime.utc(2026, 9, 1)));
    await repo.add(sample(id: 'b').copyWith(date: DateTime.utc(2026, 9, 3)));
    await repo.add(sample(id: 'c').copyWith(date: DateTime.utc(2026, 9, 2)));

    final all = await repo.getAll();
    expect(all.map((t) => t.id), <String>['a', 'b', 'c']);

    final ranged = await repo.getInDateRange(
      from: DateTime.utc(2026, 9, 2),
      to: DateTime.utc(2026, 9, 4),
    );
    expect(ranged.map((t) => t.id), <String>['b', 'c']);
  });

  group('soft delete', () {
    test('hides the record from queries but keeps it in the box', () async {
      await repo.add(sample());
      await repo.delete('t1');

      expect(await repo.getById('t1'), isNull);
      expect(await repo.getAll(), isEmpty);

      // The row is still physically present, as a tombstone.
      expect(harness.store.transactions.containsKey('t1'), isTrue);
      final tombstone = await repo.getByIdIncludingDeleted('t1');
      expect(tombstone, isNotNull);
      expect(tombstone!.isDeleted, isTrue);
      expect(tombstone.syncStatus, SyncStatus.pending);
      expect(tombstone.updatedAt, fakeNow);
    });

    test('delete of an unknown id is a no-op', () async {
      await repo.delete('does-not-exist');
      expect(harness.store.transactions.isEmpty, isTrue);
    });
  });

  test('getPendingSync includes tombstones', () async {
    await repo.add(sample(id: 'keep'));
    await repo.add(sample(id: 'gone'));
    await repo.markSynced('keep');
    await repo.markSynced('gone');
    await repo.delete('gone');

    final pending = await repo.getPendingSync();
    expect(pending.map((t) => t.id), <String>['gone']);
    expect(pending.single.isDeleted, isTrue);
  });

  test('watchAll first emission is the current live list', () async {
    await repo.add(sample(id: 'x'));
    await repo.add(sample(id: 'y'));
    await repo.delete('x');

    final first = await repo.watchAll().first;
    expect(first.map((t) => t.id), <String>['y']);
  });

  test('watchAll pushes a fresh list when a row changes', () async {
    await repo.add(sample(id: 'x'));

    final next = repo
        .watchAll()
        .skip(1)
        .first
        .timeout(const Duration(seconds: 5));
    await repo.add(sample(id: 'y'));

    expect((await next).map((t) => t.id), containsAll(<String>['x', 'y']));
  });

  group('cross-user isolation (security review, Phase 12)', () {
    // A second repository over the SAME Hive box, scoped to a different
    // userId — simulating a record that ended up in this box but is owned
    // by someone else (a userId-migration remnant, or a future
    // multi-account scenario). Every id-based mutation must treat it as if
    // it doesn't exist, exactly like `getById` already does.
    late HiveTransactionRepository otherUserRepo;

    setUp(() {
      otherUserRepo = HiveTransactionRepository(
        harness.store.transactions,
        userId: 'someone-else',
        clock: () => fakeNow,
      );
    });

    test('delete leaves a foreign-owned record untouched', () async {
      await repo.add(sample(id: 'mine'));

      await otherUserRepo.delete('mine');

      // Not soft-deleted, not touched at all — the attempt was a no-op.
      final stillMine = await repo.getById('mine');
      expect(stillMine, isNotNull);
      expect(stillMine!.isDeleted, isFalse);
    });

    test('restore cannot resurrect a foreign-owned tombstone', () async {
      await repo.add(sample(id: 'mine'));
      await repo.delete('mine');

      await otherUserRepo.restore('mine');

      expect((await repo.getByIdIncludingDeleted('mine'))!.isDeleted, isTrue);
    });

    test('markSynced cannot flip a foreign-owned record to synced', () async {
      await repo.add(sample(id: 'mine')); // starts pending

      await otherUserRepo.markSynced('mine');

      expect((await repo.getById('mine'))!.syncStatus, SyncStatus.pending);
    });

    test('getByIdIncludingDeleted is invisible to a different user', () async {
      await repo.add(sample(id: 'mine'));

      expect(await otherUserRepo.getByIdIncludingDeleted('mine'), isNull);
    });

    test('upsertFromRemote refuses a document owned by another user', () async {
      final foreign = Transaction(
        id: 'not-mine',
        userId: 'someone-else',
        amountMinor: 500,
        type: TransactionType.expense,
        categoryId: 'cat-food',
        date: DateTime.utc(2026, 9, 1),
        source: TransactionSource.manual,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
        syncStatus: SyncStatus.synced,
      );

      await repo.upsertFromRemote(foreign);

      // Never written into this user's view of the box at all.
      expect(await repo.getById('not-mine'), isNull);
      expect(await repo.getByIdIncludingDeleted('not-mine'), isNull);
    });

    test(
      'upsertFromRemote still applies a document owned by this user',
      () async {
        final mine = sample(id: 'mine');

        await repo.upsertFromRemote(mine);

        expect(await repo.getById('mine'), isNotNull);
      },
    );
  });
}
