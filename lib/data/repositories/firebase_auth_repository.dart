import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../domain/repositories/auth_repository.dart';
import '../local/auth_session_store.dart';
import 'firebase_auth_error_mapper.dart';

/// The single file in the app that imports `firebase_auth` (CLAUDE.md §6:
/// the auth provider must be replaceable — swap this class, keep the rest).
///
/// Offline-first contract:
///  - [currentUserId] / [currentUserEmail] read an in-memory copy of the
///    locally persisted [AuthSession], hydrated once by [hydrate] at startup.
///    No `authStateChanges()` stream gates the UI (it can hang or emit null
///    offline — Phase 5 brief).
///  - Firebase calls are time-boxed so a dead network fails fast instead of
///    spinning forever.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required FirebaseAuth firebaseAuth,
    required AuthSessionStore sessionStore,
    this.timeout = const Duration(seconds: 20),
  }) : _auth = firebaseAuth,
       _sessions = sessionStore;

  /// Wires up against `FirebaseAuth.instance`. Only call once
  /// `Firebase.initializeApp` has succeeded — keeps the `firebase_auth` import
  /// inside this one file (CLAUDE.md §6).
  factory FirebaseAuthRepository.instance({
    required AuthSessionStore sessionStore,
    Duration timeout = const Duration(seconds: 20),
  }) => FirebaseAuthRepository(
    firebaseAuth: FirebaseAuth.instance,
    sessionStore: sessionStore,
    timeout: timeout,
  );

  final FirebaseAuth _auth;
  final AuthSessionStore _sessions;

  /// Time box on every Firebase call so a dead network fails fast.
  final Duration timeout;

  AuthSession? _cached;

  /// Seed the in-memory session from the value `main()` already read from
  /// secure storage, so [currentUserId] / [currentUserEmail] answer correctly
  /// after a cold start without another storage round-trip.
  void primeCache(AuthSession session) => _cached = session;

  /// Load the persisted session into memory (alternative to [primeCache] when
  /// the caller does not already have it). Safe to call repeatedly.
  Future<AuthSession?> hydrate() async {
    _cached = await _sessions.read();
    return _cached;
  }

  @override
  String? get currentUserId => _cached?.uid;

  @override
  String? get currentUserEmail => _cached?.email;

  @override
  Future<String> signUp({
    required String email,
    required String password,
  }) async {
    final credential = await _run(
      () => _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
    return _persist(credential, fallbackEmail: email.trim());
  }

  @override
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _run(
      () => _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
    return _persist(credential, fallbackEmail: email.trim());
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    await _run(() => _auth.sendPasswordResetEmail(email: email.trim()));
  }

  @override
  Future<void> signOut() async {
    // Local first — this is what routing depends on, and it must not depend on
    // the network succeeding.
    _cached = null;
    await _sessions.clear();
    try {
      await _auth.signOut().timeout(timeout);
    } catch (error) {
      // Best-effort. The local session is already gone; a failed remote
      // sign-out only matters for token refresh, which re-login fixes.
      if (!kReleaseMode) {
        debugPrint('AUTH: remote signOut failed (ignored): $error');
      }
    }
  }

  /// Runs a Firebase call, converting every failure into a typed
  /// [AuthException]. Never lets `FirebaseAuthException` escape.
  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call().timeout(timeout);
    } on FirebaseAuthException catch (e, stack) {
      if (!kReleaseMode) {
        debugPrint('AUTH: FirebaseAuthException(${e.code})\n$stack');
      }
      throw mapFirebaseAuthErrorCode(e.code, cause: e);
    } on TimeoutException catch (e) {
      throw AuthNetworkException(cause: e);
    } on AuthException {
      rethrow;
    } catch (e) {
      // e.g. `[core/no-app]` when init failed — surface as "not available".
      final text = e.toString();
      if (text.contains('no-app') || text.contains('not been configured')) {
        throw AuthUnavailableException(cause: e);
      }
      throw UnknownAuthException(cause: e);
    }
  }

  Future<String> _persist(
    UserCredential credential, {
    required String fallbackEmail,
  }) async {
    final user = credential.user;
    if (user == null) {
      throw const UnknownAuthException(code: 'null-user');
    }
    final session = AuthSession(
      uid: user.uid,
      email: user.email ?? fallbackEmail,
    );
    await _sessions.write(session);
    _cached = session;
    return user.uid;
  }
}
