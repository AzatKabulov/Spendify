import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/domain/services/receipt_json_parser.dart';

void main() {
  const clean = '''
{"merchant":"Family Mart","totalAmountMinor":1250,"currency":"MYR",
 "date":"2026-09-05","suggestedCategory":"Groceries","confidence":0.92}''';

  test('clean JSON parses every field', () {
    final r = parseReceiptJson(clean);
    expect(r.merchant, 'Family Mart');
    expect(r.totalAmountMinor, 1250);
    expect(r.currency, 'MYR');
    expect(r.date, DateTime(2026, 9, 5));
    expect(r.suggestedCategory, 'Groceries');
    expect(r.confidence, 0.92);
  });

  test('wrapped in ```json fences', () {
    final r = parseReceiptJson('```json\n$clean\n```');
    expect(r.merchant, 'Family Mart');
    expect(r.totalAmountMinor, 1250);
  });

  test('leading + trailing prose around the object', () {
    final r = parseReceiptJson(
      "Sure! Here is the extracted data:\n$clean\nLet me know if you need more.",
    );
    expect(r.totalAmountMinor, 1250);
    expect(r.date, DateTime(2026, 9, 5));
  });

  test('missing fields -> nulls, the rest survive', () {
    final r = parseReceiptJson('{"totalAmountMinor": 999, "confidence": 0.4}');
    expect(r.totalAmountMinor, 999);
    expect(r.confidence, 0.4);
    expect(r.merchant, isNull);
    expect(r.date, isNull);
    expect(r.suggestedCategory, isNull);
  });

  test('wrong types are dropped independently, not fatal', () {
    final r = parseReceiptJson(
      '{"merchant": 12345, "totalAmountMinor": "abc", '
      '"date": true, "suggestedCategory": ["a","b"], "confidence": "high"}',
    );
    expect(r.merchant, isNull); // number, not string
    expect(r.totalAmountMinor, isNull); // unparseable
    expect(r.date, isNull);
    expect(r.suggestedCategory, isNull);
    expect(r.confidence, 0.0); // "high" -> default
  });

  test('amount as a numeric string / float / with symbols', () {
    expect(
      parseReceiptJson('{"totalAmountMinor":"1250"}').totalAmountMinor,
      1250,
    );
    expect(
      parseReceiptJson('{"totalAmountMinor":1250.0}').totalAmountMinor,
      1250,
    );
    expect(
      parseReceiptJson('{"totalAmountMinor":"RM 1,250"}').totalAmountMinor,
      1250,
    );
  });

  test('non-positive or non-finite amount -> null', () {
    expect(parseReceiptJson('{"totalAmountMinor":0}').totalAmountMinor, isNull);
    expect(
      parseReceiptJson('{"totalAmountMinor":-500}').totalAmountMinor,
      isNull,
    );
  });

  test('confidence is clamped to 0..1', () {
    expect(parseReceiptJson('{"confidence": 1.7}').confidence, 1.0);
    expect(parseReceiptJson('{"confidence": -0.3}').confidence, 0.0);
  });

  test('the string "null" and "N/A" are treated as null', () {
    final r = parseReceiptJson(
      '{"merchant": "null", "currency": "N/A", "suggestedCategory": "  "}',
    );
    expect(r.merchant, isNull);
    expect(r.currency, isNull);
    expect(r.suggestedCategory, isNull);
  });

  test('non-ISO date formats fall back, unreadable -> null', () {
    expect(
      parseReceiptJson('{"date":"05/09/2026"}').date,
      DateTime(2026, 9, 5),
    );
    expect(
      parseReceiptJson('{"date":"2026-09-05T14:30:00"}').date,
      DateTime(2026, 9, 5),
    );
    expect(parseReceiptJson('{"date":"last tuesday"}').date, isNull);
  });

  test('truncated / unbalanced object still yields what it can', () {
    // no closing brace — jsonDecode of the raw fails, brace-scan returns null,
    // but the fenced/trimmed candidates also fail -> unparseable
    expect(
      () => parseReceiptJson('{"merchant":"Shop","totalAmountMinor":125'),
      throwsA(isA<ReceiptUnparseableException>()),
    );
  });

  test('empty string and pure prose throw ReceiptUnparseableException', () {
    expect(
      () => parseReceiptJson(''),
      throwsA(isA<ReceiptUnparseableException>()),
    );
    expect(
      () => parseReceiptJson('I could not read this receipt, sorry.'),
      throwsA(isA<ReceiptUnparseableException>()),
    );
  });

  test('a value containing a brace does not truncate the object', () {
    final r = parseReceiptJson('{"merchant":"a} b {c","totalAmountMinor":50}');
    expect(r.merchant, 'a} b {c');
    expect(r.totalAmountMinor, 50);
  });
}
