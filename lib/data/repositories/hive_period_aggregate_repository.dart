import 'dart:async';

import 'package:hive/hive.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/period_aggregate.dart';
import '../../domain/repositories/period_aggregate_repository.dart';
import '../local/mappers/period_aggregate_mapper.dart';
import '../local/models/period_aggregate_model.dart';

/// Local-only report cache. Keyed by the composite [PeriodAggregate.id].
class HivePeriodAggregateRepository implements PeriodAggregateRepository {
  HivePeriodAggregateRepository(this._box);

  final Box<PeriodAggregateModel> _box;

  @override
  Future<PeriodAggregate?> getById(String id) async => _box.get(id)?.toDomain();

  @override
  Future<List<PeriodAggregate>> getAll() async =>
      _box.values.map((a) => a.toDomain()).toList(growable: false);

  @override
  Stream<List<PeriodAggregate>> watchAll() {
    final controller = StreamController<List<PeriodAggregate>>();
    StreamSubscription<BoxEvent>? sub;
    Future<void> emit() async {
      if (!controller.isClosed) controller.add(await getAll());
    }

    controller
      ..onListen = () {
        sub = _box.watch().listen((_) => emit());
        emit();
      }
      ..onCancel = () async => sub?.cancel();
    return controller.stream;
  }

  @override
  Future<List<PeriodAggregate>> getByPeriodType(PeriodType periodType) async =>
      _box.values
          .where((a) => a.periodType == periodType)
          .map((a) => a.toDomain())
          .toList(growable: false);

  @override
  Future<List<PeriodAggregate>> getForPeriodKey({
    required PeriodType periodType,
    required String periodKey,
  }) async => _box.values
      .where((a) => a.periodType == periodType && a.periodKey == periodKey)
      .map((a) => a.toDomain())
      .toList(growable: false);

  @override
  Future<void> put(PeriodAggregate aggregate) =>
      _box.put(aggregate.id, aggregate.toModel());

  @override
  Future<void> putAll(List<PeriodAggregate> aggregates) =>
      _box.putAll(<String, PeriodAggregateModel>{
        for (final a in aggregates) a.id: a.toModel(),
      });

  @override
  Future<void> removeAll(List<String> ids) => _box.deleteAll(ids);

  @override
  Future<void> clear() => _box.clear();
}
