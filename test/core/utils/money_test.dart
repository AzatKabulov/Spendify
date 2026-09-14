import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/core/utils/money.dart';

void main() {
  group('parseAmountToMinor', () {
    test('whole numbers', () {
      expect(parseAmountToMinor('12'), 1200);
      expect(parseAmountToMinor('0'), 0);
      expect(parseAmountToMinor('1000'), 100000);
    });

    test('one and two decimal places', () {
      expect(parseAmountToMinor('12.5'), 1250);
      expect(parseAmountToMinor('12.50'), 1250);
      expect(parseAmountToMinor('12.05'), 1205);
      expect(parseAmountToMinor('0.99'), 99);
    });

    test('leading dot', () {
      expect(parseAmountToMinor('.50'), 50);
      expect(parseAmountToMinor('.5'), 50);
      expect(parseAmountToMinor('.05'), 5);
    });

    test('trailing dot', () {
      expect(parseAmountToMinor('12.'), 1200);
    });

    test('surrounding whitespace is trimmed', () {
      expect(parseAmountToMinor('  12.50  '), 1250);
      expect(parseAmountToMinor('\t7\n'), 700);
    });

    test('comma thousands separators are stripped', () {
      expect(parseAmountToMinor('1,234.50'), 123450);
      expect(parseAmountToMinor('1,000'), 100000);
      expect(parseAmountToMinor('12,34'), 123400); // lenient: commas removed
    });

    test('a pasted RM prefix is tolerated', () {
      expect(parseAmountToMinor('RM 12.50'), 1250);
      expect(parseAmountToMinor('rm12.50'), 1250);
    });

    test('>2 decimals: rejected unless the extra digits are all zero', () {
      // Decision: REJECT (return null) rather than round — see money.dart.
      expect(parseAmountToMinor('12.999'), isNull);
      expect(parseAmountToMinor('12.001'), isNull);
      expect(parseAmountToMinor('0.005'), isNull);
      expect(parseAmountToMinor('12.5000'), 1250);
      expect(parseAmountToMinor('12.100'), 1210);
    });

    test('empty / blank -> null', () {
      expect(parseAmountToMinor(''), isNull);
      expect(parseAmountToMinor('   '), isNull);
      expect(parseAmountToMinor('.'), isNull);
      expect(parseAmountToMinor(','), isNull);
    });

    test('non-numeric -> null', () {
      expect(parseAmountToMinor('abc'), isNull);
      expect(parseAmountToMinor('12abc'), isNull);
      expect(parseAmountToMinor('12.3.4'), isNull);
      expect(parseAmountToMinor('1 2'), isNull);
      expect(parseAmountToMinor(r'$12'), isNull);
    });

    test('negative input -> null (amounts are always positive; §4)', () {
      expect(parseAmountToMinor('-5'), isNull);
      expect(parseAmountToMinor('-12.50'), isNull);
      expect(parseAmountToMinor('- 12'), isNull);
    });

    test('absurdly long input does not throw', () {
      expect(parseAmountToMinor('9' * 40), isNull);
    });
  });

  group('formatMinor', () {
    test('basic', () {
      expect(formatMinor(1250), 'RM 12.50');
      expect(formatMinor(0), 'RM 0.00');
      expect(formatMinor(5), 'RM 0.05');
      expect(formatMinor(100), 'RM 1.00');
    });

    test('thousands grouping', () {
      expect(formatMinor(123456), 'RM 1,234.56');
      expect(formatMinor(100000000), 'RM 1,000,000.00');
    });

    test('negative balance', () {
      expect(formatMinor(-1250), '-RM 12.50');
      expect(formatMinor(-5), '-RM 0.05');
    });

    test('round-trips with parseAmountToMinor', () {
      for (final minor in <int>[0, 5, 99, 100, 1250, 123456, 9999999]) {
        expect(parseAmountToMinor(minorToEditString(minor)), minor);
      }
    });
  });

  group('formatMinorSigned', () {
    test('explicit sign', () {
      expect(formatMinorSigned(1250), '+RM 12.50');
      expect(formatMinorSigned(-1250), '-RM 12.50');
      expect(formatMinorSigned(0), 'RM 0.00');
    });
  });

  group('minorToEditString', () {
    test('no prefix, always 2 dp', () {
      expect(minorToEditString(1250), '12.50');
      expect(minorToEditString(5), '0.05');
      expect(minorToEditString(0), '0.00');
    });
  });
}
