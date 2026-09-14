// Phase 11 Part B — on-device performance measurement for the "core actions
// < 2 s" commitment (CLAUDE.md §6).
//
// Seeds a realistic large dataset into the REAL encrypted Hive stack on the
// device, then times how long each core screen takes to build and settle with
// that data (which includes the Keystore key fetch + AES decryption the
// shipping app pays), plus the full save-a-transaction flow. Pure algorithmic
// cost is in `test/performance/perf_scaling_test.dart`.
//
// Run:  flutter test integration_test/performance_test.dart -d <device>

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:spendify/core/constants.dart';
import 'package:spendify/data/local/hive_initializer.dart';
import 'package:spendify/data/local/hive_registrar.dart';
import 'package:spendify/data/local/models/transaction_model.dart';
import 'package:spendify/data/remote/firebase_bootstrap.dart';
import 'package:spendify/data/repositories/aggregation_maintenance.dart';
import 'package:spendify/data/repositories/hive_category_repository.dart';
import 'package:spendify/data/repositories/hive_period_aggregate_repository.dart';
import 'package:spendify/data/repositories/hive_transaction_repository.dart';
import 'package:spendify/domain/entities/category.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/presentation/providers/ai_providers.dart';
import 'package:spendify/presentation/providers/auth_providers.dart';
import 'package:spendify/presentation/providers/repository_providers.dart';
import 'package:spendify/presentation/screens/budgets_screen.dart';
import 'package:spendify/presentation/screens/home_screen.dart';
import 'package:spendify/presentation/screens/reports_screen.dart';
import 'package:spendify/presentation/screens/stats_screen.dart';
import 'package:spendify/presentation/screens/transaction_form_screen.dart';

const _seedCount = 5000;
const _categoryCount = 15;
const _runs = 5;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('core-action timings, $_seedCount transactions', (tester) async {
    // --- boot + seed the real encrypted Hive stack once -----------------
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) registerSpendifyHiveAdapters();
    await Hive.close();
    for (final name in HiveBoxes.all) {
      await Hive.deleteBoxFromDisk(name);
    }
    final HiveStore store = await bootstrapHive();

    // real categories, so the add-transaction form can resolve a default
    final catRepo = HiveCategoryRepository(
      store.categories,
      metaBox: store.meta,
      userId: kLocalUserId,
      clock: () => DateTime.utc(2026, 9, 8, 12),
    );
    await catRepo.ensureDefaultsSeeded();
    var extra = 0;
    while ((await catRepo.getAll()).length < _categoryCount) {
      await catRepo.add(
        Category.create(
          id: 'extra-${extra++}',
          userId: kLocalUserId,
          name: 'Extra $extra',
          iconCode: 0xe574,
          colorValue: 0xFF546E7A,
          now: DateTime.utc(2026, 9, 8, 12),
        ),
      );
    }
    final cats = [for (final c in await catRepo.getAll()) c.id];

    final rng = Random(42);
    final now = DateTime(2026, 9, 15);
    final models = <String, TransactionModel>{};
    for (var i = 0; i < _seedCount; i++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day - rng.nextInt(365 * 3),
      );
      final isIncome = rng.nextInt(12) == 0;
      models['t$i'] = TransactionModel(
        id: 't$i',
        userId: kLocalUserId,
        amountMinor: isIncome
            ? 150000 + rng.nextInt(400000)
            : 200 + rng.nextInt(20000),
        type: isIncome ? TransactionType.income : TransactionType.expense,
        categoryId: isIncome
            ? cats.last
            : cats[rng.nextInt(_categoryCount - 1)],
        date: date,
        note: null,
        source: TransactionSource.manual,
        createdAt: date,
        updatedAt: date,
        isDeleted: false,
        syncStatus: SyncStatus.pending,
      );
    }
    await store.transactions.putAll(models);

    final txnRepo = HiveTransactionRepository(
      store.transactions,
      userId: kLocalUserId,
      clock: () => DateTime.utc(2026, 9, 8, 12),
    );
    await AggregationMaintenance(
      HivePeriodAggregateRepository(store.periodAggregates),
      userId: kLocalUserId,
      clock: () => DateTime.utc(2026, 9, 8, 12),
    ).rebuildAll(await txnRepo.getAll());
    await store.meta.put(MetaKeys.aggregatesBuilt, true);

    Widget app(Widget home) => ProviderScope(
      overrides: [
        hiveStoreProvider.overrideWithValue(store),
        firebaseAvailabilityProvider.overrideWithValue(
          FirebaseAvailability.notConfigured,
        ),
        geminiApiKeyProvider.overrideWithValue(''),
        localTimeProvider.overrideWithValue(() => DateTime(2026, 9, 15, 10)),
        sessionProvider.overrideWith(_ReadySession.new),
      ],
      child: MaterialApp(home: home),
    );

    final rows = <String, ({double median, double worst, int budget})>{};

    /// Builds [screen] from scratch [_runs] times and records build+settle time.
    Future<void> screenTime(String label, Widget Function() screen) async {
      final samples = <int>[];
      for (var i = 0; i < _runs; i++) {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        final sw = Stopwatch()..start();
        await tester.pumpWidget(app(screen()));
        await tester.pumpAndSettle();
        sw.stop();
        samples.add(sw.elapsedMilliseconds);
      }
      samples.sort();
      rows[label] = (
        median: samples[samples.length ~/ 2].toDouble(),
        worst: samples.last.toDouble(),
        budget: 2000,
      );
    }

    await screenTime('Cold start → home rendered', () => const HomeScreen());
    await screenTime('Open monthly report', () => const ReportsScreen());
    await screenTime('Open budget list', () => const BudgetsScreen());
    await screenTime('Open rewards / stats screen', () => const StatsScreen());

    // --- save a transaction: split into open-form + save-and-return ----
    // "persisted" = the form has closed and the user is back on the list; the
    // gamification toast that follows is not part of the action.
    Future<void> pumpUntilGone(Finder f) async {
      final limit = Stopwatch()..start();
      while (f.evaluate().isNotEmpty && limit.elapsed.inSeconds < 6) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> pumpUntilPresent(Finder f) async {
      final limit = Stopwatch()..start();
      while (f.evaluate().isEmpty && limit.elapsed.inSeconds < 6) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    final openForm = <int>[];
    final saveReturn = <int>[];
    for (var i = 0; i < _runs; i++) {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(app(const HomeScreen()));
      await tester.pumpAndSettle();
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsWidgets, reason: 'home FAB present');

      final sw1 = Stopwatch()..start();
      await tester.tap(fab.last);
      await pumpUntilPresent(find.widgetWithText(TextFormField, 'Amount'));
      sw1.stop();
      openForm.add(sw1.elapsedMilliseconds);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount').first,
        '${13 + i}.50',
      );
      await tester.pump();

      final sw2 = Stopwatch()..start();
      await tester.tap(find.widgetWithText(FilledButton, 'Add transaction'));
      await pumpUntilGone(find.byType(TransactionFormScreen));
      sw2.stop();
      saveReturn.add(sw2.elapsedMilliseconds);
      await tester.pumpAndSettle();
    }
    openForm.sort();
    saveReturn.sort();
    rows['Open the add-transaction form'] = (
      median: openForm[openForm.length ~/ 2].toDouble(),
      worst: openForm.last.toDouble(),
      budget: 2000,
    );
    rows['Save a transaction (tap → back on list)'] = (
      median: saveReturn[saveReturn.length ~/ 2].toDouble(),
      worst: saveReturn.last.toDouble(),
      budget: 2000,
    );

    // --- report ---------------------------------------------------
    final buf = StringBuffer()
      ..writeln()
      ..writeln('=' * 74)
      ..writeln(
        'ON-DEVICE PERFORMANCE — $_seedCount txns / 3 years / '
        '$_categoryCount categories',
      )
      ..writeln('=' * 74)
      ..writeln(
        '${'action'.padRight(44)}'
        '${'budget'.padLeft(8)}${'median'.padLeft(9)}${'worst'.padLeft(9)}',
      );
    rows.forEach((k, v) {
      buf.writeln(
        '${k.padRight(44)}'
        '${'${v.budget}ms'.padLeft(8)}'
        '${'${v.median.toStringAsFixed(0)}ms'.padLeft(9)}'
        '${'${v.worst.toStringAsFixed(0)}ms'.padLeft(9)}'
        '   ${v.median < v.budget ? 'PASS' : 'FAIL'}',
      );
    });
    buf.writeln('=' * 74);
    // ignore: avoid_print
    print(buf);
    binding.reportData = <String, dynamic>{
      'perf': {
        for (final e in rows.entries)
          e.key: {
            'budgetMs': e.value.budget,
            'medianMs': e.value.median,
            'worstMs': e.value.worst,
          },
      },
    };

    for (final e in rows.entries) {
      expect(
        e.value.median,
        lessThan(e.value.budget),
        reason: '${e.key}: median ${e.value.median}ms',
      );
    }
  });
}

class _ReadySession extends SessionNotifier {
  @override
  Session build() =>
      const Session(uid: kLocalUserId, email: 'demo@example.com', ready: true);
}
