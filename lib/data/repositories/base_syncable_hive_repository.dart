import 'dart:async';

import 'package:hive/hive.dart';

import '../../core/clock.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/syncable.dart';
import '../../domain/repositories/syncable_repository.dart';

/// Shared Hive implementation of [SyncableRepository]. This is the one place
/// the CLAUDE.md §8 mutation rules live, so no call site can bypass them:
///
///   - [add] / [update] stamp `updatedAt` (from the injected [Clock]) and set
///     `syncStatus = pending` via `entity.markUpdated`;
///   - [delete] never removes a row — `entity.markDeleted` sets `isDeleted`;
///   - [getAll] / [getById] / [watchAll] filter out `isDeleted`.
///
/// The box is keyed by `entity.id`.
abstract class BaseSyncableHiveRepository<E extends Syncable<E>, M>
    implements SyncableRepository<E> {
  BaseSyncableHiveRepository(this.box, {this.clock = systemClock});

  final Box<M> box;
  final Clock clock;

  M toModel(E entity);
  E toDomain(M model);

  /// Current time, from the injected clock. Subclasses use it for any extra
  /// stamping they do.
  DateTime nowUtc() => clock();

  Iterable<E> _allDomain() => box.values.map(toDomain);

  @override
  Future<List<E>> getAll() async =>
      _allDomain().where((e) => !e.isDeleted).toList(growable: false);

  @override
  Future<E?> getById(String id) async {
    final model = box.get(id);
    if (model == null) return null;
    final entity = toDomain(model);
    return entity.isDeleted ? null : entity;
  }

  @override
  Stream<List<E>> watchAll() => _watch(() async => getAll());

  @override
  Stream<List<E>> watchAllIncludingDeleted() =>
      _watch(() async => _allDomain().toList(growable: false));

  /// Emits [snapshot]() now and on every box change. A `StreamController`
  /// (rather than `async*`) so the box subscription is attached synchronously
  /// on listen — otherwise a mutation made immediately after subscribing can
  /// land before the loop starts and be missed.
  Stream<List<E>> _watch(Future<List<E>> Function() snapshot) {
    final controller = StreamController<List<E>>();
    StreamSubscription<BoxEvent>? watchSub;

    Future<void> emit() async {
      if (!controller.isClosed) controller.add(await snapshot());
    }

    controller
      ..onListen = () {
        watchSub = box.watch().listen((_) => emit());
        emit();
      }
      ..onCancel = () async {
        await watchSub?.cancel();
      };
    return controller.stream;
  }

  @override
  Future<E> add(E entity) => _put(entity.markUpdated(at: nowUtc()));

  @override
  Future<E> update(E entity) => _put(entity.markUpdated(at: nowUtc()));

  @override
  Future<void> delete(String id) async {
    final model = box.get(id);
    if (model == null) return;
    await _put(toDomain(model).markDeleted(at: nowUtc()));
  }

  @override
  Future<void> restore(String id) async {
    final model = box.get(id);
    if (model == null) return;
    final entity = toDomain(model);
    if (!entity.isDeleted) return;
    await _put(entity.markRestored(at: nowUtc()));
  }

  @override
  Future<List<E>> getPendingSync() async => _allDomain()
      .where((e) => e.syncStatus == SyncStatus.pending)
      .toList(growable: false);

  @override
  Future<E?> getByIdIncludingDeleted(String id) async {
    final model = box.get(id);
    return model == null ? null : toDomain(model);
  }

  @override
  Future<void> upsertFromRemote(E entity) async {
    await box.put(entity.id, toModel(entity));
  }

  @override
  Future<void> markSynced(String id) async {
    final model = box.get(id);
    if (model == null) return;
    await box.put(id, toModel(toDomain(model).markSynced()));
  }

  Future<E> _put(E entity) async {
    await box.put(entity.id, toModel(entity));
    return entity;
  }
}
