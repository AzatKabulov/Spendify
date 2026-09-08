import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spendly/data/remote/gemini_client.dart';
import 'package:spendly/domain/repositories/receipt_scanner_repository.dart';

final _bytes = Uint8List.fromList(List<int>.filled(64, 7));

/// A Gemini `generateContent` response whose single candidate part is [text].
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

GeminiReceiptClient _client(MockClient mock, {String apiKey = 'test-key'}) =>
    GeminiReceiptClient(
      apiKey: apiKey,
      httpClient: mock,
      endpoint: (m, k) => Uri.parse('https://example.test/$m'),
    );

void main() {
  test(
    'no API key -> ReceiptScannerUnavailableException, no HTTP call',
    () async {
      var called = false;
      final client = _client(
        MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
        apiKey: '',
      );
      await expectLater(
        client.extract(_bytes),
        throwsA(isA<ReceiptScannerUnavailableException>()),
      );
      expect(called, isFalse);
    },
  );

  test('happy path: parses the candidate JSON', () async {
    final client = _client(
      MockClient((req) async {
        // ethics: body carries only the prompt + image, nothing user-specific
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final parts = (body['contents'] as List).first['parts'] as List;
        expect(parts.length, 2);
        expect(parts[1]['inline_data']['mime_type'], 'image/jpeg');
        return http.Response(
          _geminiResponse(
            '{"merchant":"KK Mart","totalAmountMinor":880,"currency":"MYR",'
            '"date":"2026-09-08","suggestedCategory":"Groceries",'
            '"confidence":0.9}',
          ),
          200,
        );
      }),
    );

    final r = await client.extract(_bytes);
    expect(r.merchant, 'KK Mart');
    expect(r.totalAmountMinor, 880);
    expect(r.date, DateTime(2026, 9, 8));
  });

  test('response wrapped in fences still parses (defensive)', () async {
    final client = _client(
      MockClient(
        (_) async => http.Response(
          _geminiResponse('```json\n{"totalAmountMinor": 500}\n```'),
          200,
        ),
      ),
    );
    final r = await client.extract(_bytes);
    expect(r.totalAmountMinor, 500);
  });

  test('HTTP 429 -> ReceiptRateLimitedException', () async {
    final client = _client(
      MockClient((_) async => http.Response('rate limited', 429)),
    );
    await expectLater(
      client.extract(_bytes),
      throwsA(isA<ReceiptRateLimitedException>()),
    );
  });

  test('HTTP 403 -> ReceiptApiException (auth)', () async {
    final client = _client(
      MockClient((_) async => http.Response('forbidden', 403)),
    );
    await expectLater(
      client.extract(_bytes),
      throwsA(isA<ReceiptApiException>()),
    );
  });

  test('HTTP 503 -> ReceiptApiException (server)', () async {
    final client = _client(
      MockClient((_) async => http.Response('unavailable', 503)),
    );
    await expectLater(
      client.extract(_bytes),
      throwsA(isA<ReceiptApiException>()),
    );
  });

  test(
    'safety block (promptFeedback.blockReason) -> ReceiptBlockedException',
    () async {
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
        client.extract(_bytes),
        throwsA(isA<ReceiptBlockedException>()),
      );
    },
  );

  test('finishReason SAFETY -> ReceiptBlockedException', () async {
    final client = _client(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'candidates': [
              {'finishReason': 'SAFETY'},
            ],
          }),
          200,
        ),
      ),
    );
    await expectLater(
      client.extract(_bytes),
      throwsA(isA<ReceiptBlockedException>()),
    );
  });

  test('empty candidate text -> ReceiptBlockedException', () async {
    final client = _client(
      MockClient((_) async => http.Response(_geminiResponse('   '), 200)),
    );
    await expectLater(
      client.extract(_bytes),
      throwsA(isA<ReceiptBlockedException>()),
    );
  });

  test(
    'unparseable candidate text -> ReceiptApiException (not a crash)',
    () async {
      final client = _client(
        MockClient(
          (_) async => http.Response(
            _geminiResponse('I really cannot read this receipt.'),
            200,
          ),
        ),
      );
      await expectLater(
        client.extract(_bytes),
        throwsA(isA<ReceiptApiException>()),
      );
    },
  );

  test('network error -> ReceiptNetworkException', () async {
    final client = _client(MockClient((_) async => throw const _SocketDown()));
    await expectLater(
      client.extract(_bytes),
      throwsA(isA<ReceiptNetworkException>()),
    );
  });

  test(
    'a partial object still returns (bad field never discards the rest)',
    () async {
      final client = _client(
        MockClient(
          (_) async => http.Response(
            _geminiResponse(
              '{"merchant":"Shop","totalAmountMinor":null,'
              '"date":"2026-09-08"}',
            ),
            200,
          ),
        ),
      );
      final r = await client.extract(_bytes);
      expect(r.merchant, 'Shop');
      expect(r.totalAmountMinor, isNull);
      expect(r.date, DateTime(2026, 9, 8));
    },
  );
}

class _SocketDown implements Exception {
  const _SocketDown();
}
