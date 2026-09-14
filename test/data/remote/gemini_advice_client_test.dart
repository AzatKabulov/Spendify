import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spendify/data/remote/gemini_advice_client.dart';
import 'package:spendify/domain/entities/budget.dart';
import 'package:spendify/domain/entities/category.dart';
import 'package:spendify/domain/entities/enums.dart';
import 'package:spendify/domain/entities/period_aggregate.dart';
import 'package:spendify/domain/repositories/advice_generator_repository.dart';
import 'package:spendify/domain/services/advice_summary_builder.dart';

String _geminiResponse(String text) => jsonEncode({
  'candidates': [
    {
      'content': {
        'parts': [
          {'text': text},
        ],
      },
      'finishReason': 'STOP',
    },
  ],
});

/// A summary built from aggregates that were themselves derived from
/// transactions with merchants/notes — none of which reach the builder.
AdviceSummary _summary() => buildAdviceSummary(
  aggregates: <PeriodAggregate>[
    PeriodAggregate(
      id: 't',
      userId: 'local-user',
      periodType: PeriodType.monthly,
      periodKey: '2026-09',
      totalIncomeMinor: 200000,
      totalExpenseMinor: 74000,
      transactionCount: 14,
      updatedAt: DateTime.utc(2026, 9, 15),
    ),
    PeriodAggregate(
      id: 'f',
      userId: 'local-user',
      periodType: PeriodType.monthly,
      periodKey: '2026-09',
      categoryId: 'cat-food',
      totalIncomeMinor: 0,
      totalExpenseMinor: 44000,
      transactionCount: 9,
      updatedAt: DateTime.utc(2026, 9, 15),
    ),
  ],
  budgets: <Budget>[
    Budget.create(
      id: 'b',
      userId: 'local-user',
      categoryId: 'cat-food',
      limitAmountMinor: 40000,
      period: BudgetPeriod.monthly,
      startDate: DateTime(2026, 1, 1),
      now: DateTime.utc(2026, 1, 1),
    ),
  ],
  categories: <Category>[
    Category.create(
      id: 'cat-food',
      userId: 'local-user',
      name: 'Food',
      iconCode: 0,
      colorValue: 0,
      now: DateTime.utc(2026, 1, 1),
    ),
  ],
  now: DateTime(2026, 9, 15),
);

GeminiAdviceClient _client(MockClient mock, {String apiKey = 'test-key'}) =>
    GeminiAdviceClient(
      apiKey: apiKey,
      httpClient: mock,
      endpoint: (m) => Uri.parse('https://example.test/$m'),
    );

void main() {
  test(
    'sends the API key as a header, never in the URL (security review)',
    () async {
      final client = _client(
        MockClient((req) async {
          expect(req.headers['x-goog-api-key'], 'test-key');
          expect(req.url.queryParameters.containsKey('key'), isFalse);
          expect(req.url.toString().contains('test-key'), isFalse);
          return http.Response(
            _geminiResponse('{"advice":[{"title":"t","body":"b"}]}'),
            200,
          );
        }),
      );
      await client.generate(_summary());
    },
  );

  test('no API key -> AdviceUnavailableException, no HTTP call', () async {
    var called = false;
    final client = _client(
      MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }),
      apiKey: '',
    );
    await expectLater(
      client.generate(_summary()),
      throwsA(isA<AdviceUnavailableException>()),
    );
    expect(called, isFalse);
  });

  test('happy path parses {advice:[...]} into items', () async {
    final client = _client(
      MockClient(
        (_) async => http.Response(
          _geminiResponse(
            '{"advice":[{"title":"Trim Food","body":"You are RM 40 over your '
            'Food budget."},{"title":"Good income buffer","body":"Keep it up."}]}',
          ),
          200,
        ),
      ),
    );
    final items = await client.generate(_summary());
    expect(items, hasLength(2));
    expect(items.first.title, 'Trim Food');
  });

  test(
    'PAYLOAD: request body carries only the aggregated summary + prompt',
    () async {
      late Map<String, dynamic> sentBody;
      final client = _client(
        MockClient((req) async {
          sentBody = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            _geminiResponse('{"advice":[{"title":"x","body":"y"}]}'),
            200,
          );
        }),
      );
      await client.generate(_summary());

      final parts = (sentBody['contents'] as List).first['parts'] as List;
      expect(parts, hasLength(1)); // text only — no inline_data / image
      final text = parts.first['text'] as String;

      // the real category name is expected…
      expect(text, contains('Food'));
      // …but nothing transaction-level or identifying
      for (final forbidden in <String>[
        'cat-food',
        'local-user',
        'userId',
        'merchant',
        'note',
        'inline_data',
      ]) {
        expect(text, isNot(contains(forbidden)));
      }
    },
  );

  test('fenced response still parses', () async {
    final client = _client(
      MockClient(
        (_) async => http.Response(
          _geminiResponse('```json\n{"advice":[{"body":"one tip"}]}\n```'),
          200,
        ),
      ),
    );
    final items = await client.generate(_summary());
    expect(items.single.body, 'one tip');
  });

  test('HTTP 429 -> AdviceRateLimitedException', () async {
    final client = _client(MockClient((_) async => http.Response('busy', 429)));
    await expectLater(
      client.generate(_summary()),
      throwsA(isA<AdviceRateLimitedException>()),
    );
  });

  test('HTTP 403 -> AdviceApiException', () async {
    final client = _client(MockClient((_) async => http.Response('no', 403)));
    await expectLater(
      client.generate(_summary()),
      throwsA(isA<AdviceApiException>()),
    );
  });

  test('HTTP 503 -> AdviceApiException', () async {
    final client = _client(MockClient((_) async => http.Response('down', 503)));
    await expectLater(
      client.generate(_summary()),
      throwsA(isA<AdviceApiException>()),
    );
  });

  test('safety block -> AdviceBlockedException', () async {
    final client = _client(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'promptFeedback': {'blockReason': 'SAFETY'},
          }),
          200,
        ),
      ),
    );
    await expectLater(
      client.generate(_summary()),
      throwsA(isA<AdviceBlockedException>()),
    );
  });

  test('empty candidate text -> AdviceBlockedException', () async {
    final client = _client(
      MockClient((_) async => http.Response(_geminiResponse('   '), 200)),
    );
    await expectLater(
      client.generate(_summary()),
      throwsA(isA<AdviceBlockedException>()),
    );
  });

  test(
    'unparseable candidate text -> AdviceApiException (not a crash)',
    () async {
      final client = _client(
        MockClient(
          (_) async =>
              http.Response(_geminiResponse('I have no advice today.'), 200),
        ),
      );
      await expectLater(
        client.generate(_summary()),
        throwsA(isA<AdviceApiException>()),
      );
    },
  );

  test('network error -> AdviceNetworkException', () async {
    final client = _client(MockClient((_) async => throw const _Down()));
    await expectLater(
      client.generate(_summary()),
      throwsA(isA<AdviceNetworkException>()),
    );
  });
}

class _Down implements Exception {
  const _Down();
}
