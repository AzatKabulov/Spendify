/// The authentication boundary.
///
/// CLAUDE.md §6 (maintainability): the auth provider must be replaceable, so
/// nothing outside `data/repositories/firebase_auth_repository.dart` may import
/// `firebase_auth`. Firebase's `FirebaseAuthException` is mapped to the sealed
/// [AuthException] in the data layer and never leaks past this interface.
///
/// CLAUDE.md §3 / §6 (offline-first): [currentUserId] and [currentUserEmail]
/// answer from **local persisted state only** — no network call — so startup
/// routing never waits on Firebase.
library;

abstract interface class AuthRepository {
  /// Create an account, persist the session locally, and return the new UID.
  /// Throws [AuthException] on failure (already-in-use, weak password, offline…).
  /// [displayName], if given, is set best-effort on the Firebase profile — a
  /// failure to set it never fails account creation.
  Future<String> signUp({
    required String email,
    required String password,
    String? displayName,
  });

  /// Sign in, persist the session locally, and return the UID.
  /// Throws [AuthException] on failure.
  Future<String> signIn({required String email, required String password});

  /// Clear the locally persisted session. Best-effort remote sign-out too, but
  /// it never throws and never blocks. Does **not** touch local Hive data
  /// (that may be unsynced — CLAUDE.md Phase 6).
  Future<void> signOut();

  /// Send a password-reset email. Throws [AuthException] on failure.
  Future<void> sendPasswordReset({required String email});

  /// The signed-in user's UID from local storage, or `null` if signed out.
  /// Synchronous: hydrated once at startup, updated on sign-in / sign-out.
  String? get currentUserId;

  /// The signed-in user's email from local storage (shown in Settings while
  /// offline), or `null` if signed out.
  String? get currentUserEmail;

  /// The signed-in user's display name from local storage, if they set one.
  String? get currentUserDisplayName;
}

/// Every failure the auth layer can surface, each with a specific, user-facing
/// [message]. "An error occurred" is never acceptable (Phase 5 brief, Part B).
sealed class AuthException implements Exception {
  const AuthException(this.message, {this.cause});

  /// Shown directly to the user, inline on the form.
  final String message;
  final Object? cause;

  @override
  String toString() => 'AuthException($runtimeType: $message)';
}

/// Sign-in: the email/password pair did not match. Firebase deliberately does
/// not say which half was wrong (account-enumeration protection), and newer
/// SDKs report this as `invalid-credential` — all map here.
final class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException({Object? cause})
    : super('Incorrect email or password.', cause: cause);
}

/// Sign-in: no account exists for that email (older SDK behaviour;
/// newer ones fold this into [InvalidCredentialsException]).
final class UserNotFoundException extends AuthException {
  const UserNotFoundException({Object? cause})
    : super('No account found for that email.', cause: cause);
}

/// Sign-up: the email is already registered.
final class EmailAlreadyInUseException extends AuthException {
  const EmailAlreadyInUseException({Object? cause})
    : super(
        'That email is already registered. Try signing in instead.',
        cause: cause,
      );
}

/// The email address is malformed.
final class InvalidEmailException extends AuthException {
  const InvalidEmailException({Object? cause})
    : super("That doesn't look like a valid email address.", cause: cause);
}

/// Sign-up: the password is below Firebase's strength floor.
final class WeakPasswordException extends AuthException {
  const WeakPasswordException({Object? cause})
    : super('Password is too weak — use at least 6 characters.', cause: cause);
}

/// No usable network connection reached Firebase.
final class AuthNetworkException extends AuthException {
  const AuthNetworkException({Object? cause})
    : super(
        'You need an internet connection to sign in for the first time.',
        cause: cause,
      );
}

/// Firebase is rate-limiting this device after repeated attempts.
final class TooManyRequestsException extends AuthException {
  const TooManyRequestsException({Object? cause})
    : super(
        'Too many attempts. Wait a minute and then try again.',
        cause: cause,
      );
}

/// Auth is not usable at all because Firebase was never configured on this
/// build (no `flutterfire configure` yet). Surfaced on the sign-in screen so
/// the state is obvious rather than looking like a transient failure.
final class AuthUnavailableException extends AuthException {
  const AuthUnavailableException({Object? cause})
    : super(
        'Sign-in is not available in this build yet. Firebase has not been '
        'configured.',
        cause: cause,
      );
}

/// Firebase is reachable but the Email/Password sign-in provider has not been
/// enabled in the console (`operation-not-allowed`). A setup step, not a user
/// error — worth its own message so it is obvious during first bring-up.
final class ProviderDisabledException extends AuthException {
  const ProviderDisabledException({Object? cause})
    : super(
        'Email/password sign-in is not enabled for this project. Enable it in '
        'the Firebase console under Authentication → Sign-in method.',
        cause: cause,
      );
}

/// Anything else. Keeps a copy of the original code for the logs.
final class UnknownAuthException extends AuthException {
  const UnknownAuthException({this.code, Object? cause})
    : super('Something went wrong. Please try again.', cause: cause);

  final String? code;

  @override
  String toString() =>
      'AuthException(UnknownAuthException: $message'
      '${code == null ? '' : ' <code=$code>'})';
}
