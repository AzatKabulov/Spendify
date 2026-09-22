import '../../domain/repositories/auth_repository.dart';

/// Stands in for [AuthRepository] when Firebase did not come up (no
/// `flutterfire configure` yet, or init failed). Every call fails with a clear
/// [AuthUnavailableException] so the sign-in screen can say so plainly instead
/// of spinning. A user with an existing local session never reaches this — that
/// path reads the session store directly and skips Firebase entirely.
class UnavailableAuthRepository implements AuthRepository {
  const UnavailableAuthRepository();

  @override
  String? get currentUserId => null;

  @override
  String? get currentUserEmail => null;

  @override
  String? get currentUserDisplayName => null;

  @override
  Future<String> signIn({
    required String email,
    required String password,
  }) async => throw const AuthUnavailableException();

  @override
  Future<String> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async => throw const AuthUnavailableException();

  @override
  Future<void> sendPasswordReset({required String email}) async =>
      throw const AuthUnavailableException();

  @override
  Future<void> signOut() async {
    // Nothing remote to do; the caller still clears local session state.
  }
}
