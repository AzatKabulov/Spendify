import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/constants.dart';
import 'package:spendly/data/repositories/default_categories.dart';
import 'package:spendly/data/repositories/hive_category_repository.dart';
import 'package:spendly/domain/entities/category.dart';
import 'package:spendly/domain/entities/enums.dart';

import '../../support/hive_test_harness.dart';

void main() {
  late HiveTestHarness harness;
  late DateTime fakeNow;
  late HiveCategoryRepository repo;
  var idSeq = 0;

  Category sample({String id = 'c1', String name = 'Coffee'}) => Category(
    id: id,
    userId: kLocalUserId,
    name: name,
    iconCode: 0xe000,
    colorValue: 0xFF112233,
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 1),
    syncStatus: SyncStatus.synced,
  );

  setUp(() async {
    harness = await HiveTestHarness.start();
    fakeNow = DateTime.utc(2026, 9, 6, 12);
    idSeq = 0;
    repo = HiveCategoryRepository(
      harness.store.categories,
      metaBox: harness.store.meta,
      userId: kLocalUserId,
      clock: () => fakeNow,
      idGenerator: () => 'seed-${idSeq++}',
    );
  });

  tearDown(() => harness.dispose());

  test('CRUD round-trip', () async {
    final stored = await repo.add(sample());
    expect(await repo.getById('c1'), equals(stored));

    await repo.update(stored.copyWith(name: 'Flat White'));
    expect((await repo.getById('c1'))!.name, 'Flat White');

    await repo.delete('c1');
    expect(await repo.getById('c1'), isNull);
    expect(harness.store.categories.containsKey('c1'), isTrue);
  });

  test('mutations stamp updatedAt and syncStatus', () async {
    final stored = await repo.add(sample());
    expect(stored.updatedAt, fakeNow);
    expect(stored.syncStatus, SyncStatus.pending);
  });

  group('default seeding', () {
    test('seeds the full default set once, marked isDefault', () async {
      await repo.ensureDefaultsSeeded();

      final all = await repo.getAll();
      expect(all.length, kDefaultCategories.length);
      expect(all.every((c) => c.isDefault), isTrue);
      expect(
        all.map((c) => c.name).toSet(),
        kDefaultCategories.map((s) => s.name).toSet(),
      );
      expect(all.every((c) => c.syncStatus == SyncStatus.pending), isTrue);
      expect(all.every((c) => c.userId == kLocalUserId), isTrue);
    });

    test('is idempotent, and does not resurrect a deleted default', () async {
      await repo.ensureDefaultsSeeded();
      final food = (await repo.getAll()).firstWhere((c) => c.name == 'Food');
      await repo.delete(food.id);

      await repo.ensureDefaultsSeeded(); // second launch

      final live = await repo.getAll();
      expect(live.length, kDefaultCategories.length - 1);
      expect(live.any((c) => c.name == 'Food'), isFalse);
    });

    test('meta flag is what guards re-seeding', () async {
      expect(
        harness.store.meta.get(MetaKeys.defaultCategoriesSeeded),
        anyOf(isNull, isFalse),
      );
      await repo.ensureDefaultsSeeded();
      expect(harness.store.meta.get(MetaKeys.defaultCategoriesSeeded), isTrue);
    });
  });
}
