import '../../domain/repositories/auth_repository.dart';

/// Maps a `FirebaseAuthException.code` to a typed domain [AuthException] with a
/// specific user-facing message. Kept as a pure `String -> AuthException`
/// function (no `firebase_auth` import) so the mapping is unit-testable on its
/// own (Phase 5 tests: "Firebase error code -> domain error -> user message").
///
/// Unlisted codes fall through to [UnknownAuthException], which keeps the code
/// for the logs.
AuthException mapFirebaseAuthErrorCode(String code, {Object? cause}) {
  switch (code) {
    case 'invalid-credential':
    case 'invalid-login-credentials':
    case 'INVALID_LOGIN_CREDENTIALS':
    case 'wrong-password':
      return InvalidCredentialsException(cause: cause);

    case 'user-not-found':
      return UserNotFoundException(cause: cause);

    case 'email-already-in-use':
      return EmailAlreadyInUseException(cause: cause);

    case 'invalid-email':
      return InvalidEmailException(cause: cause);

    case 'weak-password':
      return WeakPasswordException(cause: cause);

    case 'network-request-failed':
      return AuthNetworkException(cause: cause);

    case 'too-many-requests':
      return TooManyRequestsException(cause: cause);

    case 'operation-not-allowed':
      return ProviderDisabledException(cause: cause);

    default:
      return UnknownAuthException(code: code, cause: cause);
  }
}
