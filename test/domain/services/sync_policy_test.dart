import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/domain/services/sync_policy.dart';

void main() {
  group('remoteWins (last-write-wins)', () {
    final t0 = DateTime.utc(2026, 9, 9, 12);

    test('remote strictly newer -> remote wins', () {
      expect(
        remoteWins(
          localUpdatedAt: t0,
          remoteUpdatedAt: t0.add(const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });

    test('local strictly newer -> keep local', () {
      expect(
        remoteWins(
          localUpdatedAt: t0.add(const Duration(seconds: 1)),
          remoteUpdatedAt: t0,
        ),
        isFalse,
      );
    });

    test('equal timestamps -> keep local (deterministic)', () {
      expect(remoteWins(localUpdatedAt: t0, remoteUpdatedAt: t0), isFalse);
    });
  });

  group('chunkForBatch (Firestore 500-op write-batch limit)', () {
    test('600 records -> [500, 100]', () {
      final chunks = chunkForBatch(List<int>.generate(600, (i) => i));
      expect(chunks.length, 2);
      expect(chunks[0].length, 500);
      expect(chunks[1].length, 100);
      // nothing lost or duplicated
      expect(
        chunks.expand((c) => c).toList(),
        List<int>.generate(600, (i) => i),
      );
    });

    test('exactly 500 -> a single full chunk', () {
      expect(chunkForBatch(List<int>.filled(500, 0)).map((c) => c.length), [
        500,
      ]);
    });

    test('501 -> [500, 1]', () {
      expect(chunkForBatch(List<int>.filled(501, 0)).map((c) => c.length), [
        500,
        1,
      ]);
    });

    test('empty -> no chunks', () {
      expect(chunkForBatch(<int>[]), isEmpty);
    });

    test('custom chunk size', () {
      expect(
        chunkForBatch(
          List<int>.generate(7, (i) => i),
          maxPerChunk: 3,
        ).map((c) => c.length),
        [3, 3, 1],
      );
    });
  });

  group('backoffDelay (exponential, capped ~5 min)', () {
    test('doubles from ~2s', () {
      expect(backoffDelay(1), const Duration(seconds: 2));
      expect(backoffDelay(2), const Duration(seconds: 4));
      expect(backoffDelay(3), const Duration(seconds: 8));
      expect(backoffDelay(4), const Duration(seconds: 16));
      expect(backoffDelay(5), const Duration(seconds: 32));
    });

    test('caps at 5 minutes and never exceeds it', () {
      expect(backoffDelay(8), const Duration(seconds: 256)); // not yet at cap
      expect(backoffDelay(9), const Duration(minutes: 5)); // 512s -> capped
      expect(backoffDelay(20), const Duration(minutes: 5));
      expect(backoffDelay(1000), const Duration(minutes: 5));
      for (var a = 1; a <= 50; a++) {
        expect(backoffDelay(a) <= const Duration(minutes: 5), isTrue);
      }
    });

    test('attempt < 1 -> zero', () {
      expect(backoffDelay(0), Duration.zero);
      expect(backoffDelay(-3), Duration.zero);
    });
  });
}
