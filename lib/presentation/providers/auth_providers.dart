import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/auth_session_store.dart';
import '../../data/remote/firebase_bootstrap.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../data/repositories/unavailable_auth_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import 'repository_providers.dart';
import 'sync_providers.dart';
import 'user_data_preparer.dart';

/// Result of `initializeFirebase()` in `main()`. Overridden there; the default
/// keeps tests and any un-bootstrapped context in "not configured".
final firebaseAvailabilityProvider = Provider<FirebaseAvailability>(
  (ref) => FirebaseAvailability.notConfigured,
);

/// Persisted-session store (secure storage). Overridable in tests.
final authSessionStoreProvider = Provider<AuthSessionStore>(
  (ref) => SecureStorageAuthSessionStore(),
);

/// Per-user local data prep (migration, default categories, aggregate cache),
/// run once the real UID is known.
final userDataPreparerProvider = Provider<UserDataPreparer>((ref) {
  return UserDataPreparer(
    ref.watch(hiveStoreProvider),
    clock: ref.watch(clockProvider),
  );
});

/// The auth boundary. Real Firebase impl only when Firebase actually came up;
/// otherwise a stub whose every call explains that auth is unavailable.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final availability = ref.watch(firebaseAvailabilityProvider);
  if (availability != FirebaseAvailability.ready) {
    return const UnavailableAuthRepository();
  }
  final repo = FirebaseAuthRepository.instance(
    sessionStore: ref.watch(authSessionStoreProvider),
  );
  // `currentUserId` / `currentUserEmail` must answer from local state right
  // after a cold start, not just after an in-session sign-in.
  final startup = ref.read(startupSessionProvider);
  if (startup != null) repo.primeCache(startup);
  return repo;
});

/// The session known at startup (from the secure-storage read in `main()`),
/// already migration-prepared. Overridden in `main()`; `null` = signed out.
final startupSessionProvider = Provider<AuthSession?>((ref) => null);

/// Signed-in identity + whether the per-user data prep (migration, default
/// categories, aggregate cache) has finished. Routing reads this — never a
/// `FirebaseAuth` stream (CLAUDE.md §3/§6: offline launch must not wait on
/// Firebase).
class Session {
  const Session({
    this.uid,
    this.email,
    this.ready = false,
    this.restoring = false,
  });

  const Session.signedOut()
    : uid = null,
      email = null,
      ready = false,
      restoring = false;

  final String? uid;
  final String? email;

  /// `true` once this user's local data is ready to show.
  final bool ready;

  /// `true` while a fresh-install restore pull is running (Phase 6) — the
  /// preparing screen says "Restoring…" instead of "Setting up…".
  final bool restoring;

  bool get isSignedIn => uid != null;

  Session copyWith({
    String? uid,
    String? email,
    bool? ready,
    bool? restoring,
  }) => Session(
    uid: uid ?? this.uid,
    email: email ?? this.email,
    ready: ready ?? this.ready,
    restoring: restoring ?? this.restoring,
  );
}

final sessionProvider = NotifierProvider<SessionNotifier, Session>(
  SessionNotifier.new,
);

class SessionNotifier extends Notifier<Session> {
  @override
  Session build() {
    final startup = ref.read(startupSessionProvider);
    if (startup == null) return const Session.signedOut();
    // main() already ran the migration for this session before us.
    return Session(uid: startup.uid, email: startup.email, ready: true);
  }

  /// Called by the auth controller after Firebase confirms a sign-in/up. Sets
  /// the uid immediately (so uid-scoped repositories resolve), runs the
  /// per-user prep, then flips [Session.ready] to enter the app.
  ///
  /// A prep failure is logged but not fatal — the session is already persisted,
  /// so the app proceeds (Settings → "Rebuild report data" is the recovery, and
  /// the next launch retries the migration anyway).
  Future<void> enter({required String uid, required String email}) async {
    state = Session(uid: uid, email: email, ready: false);
    try {
      await ref.read(userDataPreparerProvider).prepareFor(uid);
      // Phase 6: fresh install with an existing account -> pull the backup
      // before showing home.
      final bootstrap = ref.read(syncBootstrapProvider);
      if (bootstrap.shouldRestore()) {
        state = state.copyWith(restoring: true);
        await bootstrap.restore();
      }
    } catch (error, stack) {
      if (!kReleaseMode) {
        debugPrint('SESSION: data prep failed on sign-in: $error\n$stack');
      }
    }
    state = state.copyWith(ready: true, restoring: false);
    ref.read(syncBootstrapProvider).startBackgroundSync();
  }

  void leave() => state = const Session.signedOut();
}

/// The active user's id, or `null` when signed out. uid-scoped repositories and
/// the report/aggregate layer read this.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(sessionProvider).uid,
);

/// The signed-in uid, or a hard failure — for providers / action classes that
/// only ever run behind `AuthGate`, where `null` means a screen leaked past
/// sign-in (a bug, not a state to handle gracefully).
String requireCurrentUserId(Ref ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    throw StateError(
      'No signed-in user. This provider is only valid behind AuthGate.',
    );
  }
  return uid;
}

/// The active user's email for display (Settings), from local state.
final currentUserEmailProvider = Provider<String?>(
  (ref) => ref.watch(sessionProvider).email,
);

// --- Form submission ------------------------------------------------------

enum AuthAction { signIn, signUp, resetPassword }

/// Transient state for an auth form submit: in-flight flag + last error
/// message. The screens watch this to disable the button and show errors.
class AuthFormState {
  const AuthFormState({
    this.submitting = false,
    this.errorMessage,
    this.done = false,
  });

  final bool submitting;
  final String? errorMessage;

  /// `true` after a password-reset email was sent (the screen shows a notice).
  final bool done;
}

final authFormControllerProvider =
    NotifierProvider<AuthFormController, AuthFormState>(AuthFormController.new);

class AuthFormController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  Future<void> submit(
    AuthAction action, {
    required String email,
    required String password,
  }) async {
    if (state.submitting) return;
    state = const AuthFormState(submitting: true);
    try {
      final auth = ref.read(authRepositoryProvider);
      switch (action) {
        case AuthAction.signIn:
          final uid = await auth.signIn(email: email, password: password);
          await ref
              .read(sessionProvider.notifier)
              .enter(uid: uid, email: auth.currentUserEmail ?? email.trim());
        case AuthAction.signUp:
          final uid = await auth.signUp(email: email, password: password);
          await ref
              .read(sessionProvider.notifier)
              .enter(uid: uid, email: auth.currentUserEmail ?? email.trim());
        case AuthAction.resetPassword:
          await auth.sendPasswordReset(email: email);
          state = const AuthFormState(done: true);
          return;
      }
      state = const AuthFormState();
    } on AuthException catch (e) {
      state = AuthFormState(errorMessage: e.message);
    } catch (e) {
      if (!kReleaseMode) debugPrint('AUTH form: unexpected $e');
      state = const AuthFormState(
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
  }

  /// Clear a shown error when the user edits a field.
  void clearError() {
    if (state.errorMessage != null || state.done) {
      state = const AuthFormState();
    }
  }
}

/// Sign-out action for the Settings screen. Clears the persisted session
/// (authoritative — this is what routing reads) and best-effort remote
/// sign-out. Does **not** touch local Hive data: it may be unsynced and wiping
/// it would be silent data loss (Phase 5 brief; Phase 6 handles sync).
final signOutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(authRepositoryProvider).signOut();
    await ref.read(authSessionStoreProvider).clear();
    ref.read(sessionProvider.notifier).leave();
  };
});
