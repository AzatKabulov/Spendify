import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/domain/services/advice_json_parser.dart';

void main() {
  const clean =
      '{"advice":[{"title":"Ease off Food","body":"Your RM 500 on Food is '
      'over half your spending — aim for RM 400."},'
      '{"title":"Transport looks good","body":"Nicely under budget."}]}';

  test('clean JSON -> both items', () {
    final items = parseAdviceJson(clean);
    expect(items, hasLength(2));
    expect(items.first.title, 'Ease off Food');
    expect(items.first.body, contains('RM 500'));
  });

  test('wrapped in ```json fences', () {
    final items = parseAdviceJson('```json\n$clean\n```');
    expect(items, hasLength(2));
  });

  test('leading + trailing prose', () {
    final items = parseAdviceJson(
      "Here's your advice:\n$clean\nHope that helps!",
    );
    expect(items.first.title, 'Ease off Food');
  });

  test('a bare array with no wrapper object', () {
    final items = parseAdviceJson(
      '[{"title":"A","body":"one"},{"title":"B","body":"two"}]',
    );
    expect(items.map((i) => i.title), ['A', 'B']);
  });

  test('partial: one good item, one junk entry -> keeps the good one', () {
    final items = parseAdviceJson(
      '{"advice":[{"title":"Keep it up","body":"Doing well."},'
      '{"title":123,"body":null},'
      '{"nonsense":true}]}',
    );
    expect(items, hasLength(1));
    expect(items.single.title, 'Keep it up');
  });

  test('string items become body-only advice', () {
    final items = parseAdviceJson(
      '{"advice":["Just track your coffee spend."]}',
    );
    expect(items.single.title, '');
    expect(items.single.body, 'Just track your coffee spend.');
  });

  test('body missing but title present -> title used as body', () {
    final items = parseAdviceJson('{"advice":[{"title":"Cut delivery fees"}]}');
    expect(items.single.body, 'Cut delivery fees');
  });

  test('caps at 4 items', () {
    final items = parseAdviceJson(
      '{"advice":[{"body":"1"},{"body":"2"},{"body":"3"},{"body":"4"},'
      '{"body":"5"},{"body":"6"}]}',
    );
    expect(items, hasLength(4));
  });

  test('truncated tail still yields the complete items before it', () {
    final items = parseAdviceJson(
      '{"advice":[{"title":"One","body":"first tip"},{"title":"Two","bod',
    );
    expect(items, hasLength(1));
    expect(items.single.title, 'One');
  });

  test('no JSON at all -> AdviceUnparseableException', () {
    expect(
      () => parseAdviceJson('I could not generate advice.'),
      throwsA(isA<AdviceUnparseableException>()),
    );
    expect(
      () => parseAdviceJson(''),
      throwsA(isA<AdviceUnparseableException>()),
    );
  });

  test('object present but no usable items -> throws', () {
    expect(
      () => parseAdviceJson('{"advice":[{"foo":"bar"},"",null]}'),
      throwsA(isA<AdviceUnparseableException>()),
    );
  });

  test('a brace inside a body value does not truncate parsing', () {
    final items = parseAdviceJson(
      '{"advice":[{"title":"Note","body":"spend under {limit} each week"}]}',
    );
    expect(items.single.body, 'spend under {limit} each week');
  });
}
