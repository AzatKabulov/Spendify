import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/data/repositories/firebase_auth_error_mapper.dart';
import 'package:spendly/domain/repositories/auth_repository.dart';

void main() {
  // code -> (expected type, expected user-facing message)
  final cases = <String, (Type, String)>{
    'wrong-password': (
      InvalidCredentialsException,
      'Incorrect email or password.',
    ),
    'invalid-credential': (
      InvalidCredentialsException,
      'Incorrect email or password.',
    ),
    'INVALID_LOGIN_CREDENTIALS': (
      InvalidCredentialsException,
      'Incorrect email or password.',
    ),
    'user-not-found': (
      UserNotFoundException,
      'No account found for that email.',
    ),
    'email-already-in-use': (
      EmailAlreadyInUseException,
      'That email is already registered. Try signing in instead.',
    ),
    'invalid-email': (
      InvalidEmailException,
      "That doesn't look like a valid email address.",
    ),
    'weak-password': (
      WeakPasswordException,
      'Password is too weak — use at least 6 characters.',
    ),
    'network-request-failed': (
      AuthNetworkException,
      'You need an internet connection to sign in for the first time.',
    ),
    'too-many-requests': (
      TooManyRequestsException,
      'Too many attempts. Wait a minute and then try again.',
    ),
    'operation-not-allowed': (
      ProviderDisabledException,
      'Email/password sign-in is not enabled for this project. Enable it in '
          'the Firebase console under Authentication → Sign-in method.',
    ),
  };

  cases.forEach((code, expected) {
    test('"$code" -> ${expected.$1} with its own message', () {
      final mapped = mapFirebaseAuthErrorCode(code);
      expect(mapped.runtimeType, expected.$1);
      expect(mapped.message, expected.$2);
      expect(mapped.message, isNot('An error occurred'));
      expect(mapped.message.trim(), isNotEmpty);
    });
  });

  test('an unrecognised code falls through to UnknownAuthException', () {
    final mapped = mapFirebaseAuthErrorCode('some-new-code-2027');
    expect(mapped, isA<UnknownAuthException>());
    expect((mapped as UnknownAuthException).code, 'some-new-code-2027');
    expect(mapped.message, isNotEmpty);
  });

  test('the original error is retained as cause for logging', () {
    final original = Exception('boom');
    final mapped = mapFirebaseAuthErrorCode('wrong-password', cause: original);
    expect(mapped.cause, same(original));
  });

  test('every mapped message is specific, not generic', () {
    for (final code in cases.keys) {
      final msg = mapFirebaseAuthErrorCode(code).message.toLowerCase();
      expect(
        msg,
        isNot(anyOf(contains('an error occurred'), equals('error'))),
        reason: code,
      );
    }
  });
}
