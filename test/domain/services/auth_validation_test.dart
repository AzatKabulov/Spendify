import 'package:flutter_test/flutter_test.dart';
import 'package:spendify/domain/services/auth_validation.dart';

void main() {
  group('validateEmail', () {
    test('accepts a normal address', () {
      expect(validateEmail('lara@example.com'), isNull);
      expect(validateEmail('  lara@example.com  '), isNull); // trimmed
      expect(validateEmail('a.b-c+tag@sub.domain.my'), isNull);
    });

    test('rejects empty', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail(null), isNotNull);
      expect(validateEmail('   '), isNotNull);
    });

    test('rejects obvious malformations', () {
      for (final bad in <String>[
        'notanemail',
        'missing@domain',
        '@no-local.com',
        'spaces in@email.com',
        'two@@at.com',
      ]) {
        expect(validateEmail(bad), isNotNull, reason: bad);
      }
    });
  });

  group('validatePassword', () {
    test('accepts 6+ characters', () {
      expect(validatePassword('123456'), isNull);
      expect(validatePassword('a really long passphrase'), isNull);
    });

    test('rejects empty and too-short (Firebase floor is 6)', () {
      expect(validatePassword(''), isNotNull);
      expect(validatePassword(null), isNotNull);
      expect(validatePassword('12345'), isNotNull);
      expect(kMinPasswordLength, 6);
    });
  });

  group('credentialsLookValid', () {
    test('true only when both fields pass', () {
      expect(credentialsLookValid('lara@example.com', 'secret1'), isTrue);
      expect(credentialsLookValid('lara@example.com', 'no'), isFalse);
      expect(credentialsLookValid('bad', 'secret1'), isFalse);
      expect(credentialsLookValid(null, null), isFalse);
    });
  });
}
