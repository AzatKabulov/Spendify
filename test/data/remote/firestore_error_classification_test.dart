import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/data/remote/firestore_sync_gateway.dart';
import 'package:spendly/domain/repositories/remote_sync_gateway.dart';

void main() {
  RemoteSyncException classify(String code) =>
      classifyFirestoreError(code, 'msg', what: 'push transactions');

  group('retryable (a backoff retry can succeed)', () {
    for (final code in const [
      'unavailable',
      'deadline-exceeded',
      'aborted',
      'cancelled',
      'internal',
      'timeout',
      'some-unknown-future-code',
    ]) {
      test('"$code" -> RetryableSyncException', () {
        expect(classify(code), isA<RetryableSyncException>());
      });
    }
  });

  group('permanent (retrying in a loop only makes it worse)', () {
    for (final code in const [
      'permission-denied',
      'unauthenticated',
      'invalid-argument',
      'not-found',
      'failed-precondition',
      'resource-exhausted', // quota
      'data-loss',
    ]) {
      test('"$code" -> PermanentSyncException', () {
        expect(classify(code), isA<PermanentSyncException>());
      });
    }
  });

  test('the original code + message are retained for logging', () {
    final e = classifyFirestoreError(
      'permission-denied',
      'Missing or insufficient permissions.',
      what: 'pull budgets',
    );
    expect(e.code, 'permission-denied');
    expect(e.message, contains('insufficient permissions'));
    expect(e.message, contains('pull budgets'));
  });
}
