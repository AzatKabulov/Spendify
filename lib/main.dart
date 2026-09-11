import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'core/dev/demo_seed.dart';
import 'core/theme/app_theme.dart';
import 'data/local/auth_session_store.dart';
import 'data/local/hive_initializer.dart';
import 'data/remote/firebase_bootstrap.dart';
import 'presentation/providers/auth_providers.dart';
import 'presentation/providers/gamification_providers.dart';
import 'presentation/providers/repository_providers.dart';
import 'presentation/providers/sync_providers.dart';
import 'presentation/screens/auth/auth_gate.dart';

/// Entry point.
///
/// Order matters for the offline-first guarantee (CLAUDE.md §3/§6):
///   1. open encrypted local storage (Hive + Keystore key);
///   2. initialise Firebase — *never fatal*: a failure still reaches the
///      sign-in screen with a message, not a white screen;
///   3. read the persisted session from secure storage — **local only**, no
///      Firebase call — so a logged-in user opening the app offline goes
///      straight in;
///   4. if there is a session, finish that user's data prep (resume an
///      interrupted userId migration, seed defaults, rebuild the aggregate
///      cache) before the first frame.
Future<void> main() async {
  final startupStopwatch = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();

  final HiveStore store = await bootstrapHive();
  final FirebaseBootstrapResult firebase = await initializeFirebase();
  AuthSession? session = await SecureStorageAuthSessionStore().read();

  // Debug-only demo dataset (Phase 12). Loads a realistic history when
  // `--dart-define=DEMO_SEED=true` is passed; if there is no real session it
  // also runs the app as a local demo user, so `AuthGate` opens straight on the
  // home screen without Firebase. Inert (and tree-shaken) otherwise.
  if (await maybeDemoSeed(store)) {
    session ??= const AuthSession(uid: kLocalUserId, email: 'demo@spendly.app');
  }

  final container = ProviderContainer(
    overrides: [
      hiveStoreProvider.overrideWithValue(store),
      firebaseAvailabilityProvider.overrideWithValue(firebase.availability),
      startupSessionProvider.overrideWithValue(session),
    ],
  );

  if (session != null) {
    try {
      await container.read(userDataPreparerProvider).prepareFor(session.uid);
    } catch (error, stack) {
      // A failed prep must not white-screen the app. The user still reaches
      // home; Settings → "Rebuild report data" is the recovery path.
      if (!kReleaseMode) {
        debugPrint('STARTUP: user data prep failed: $error\n$stack');
      }
    }
    // Phase 6: start background sync (never blocks the first frame). If local
    // data is missing (fresh reinstall), kick a non-blocking restore too.
    final syncBootstrap = container.read(syncBootstrapProvider);
    syncBootstrap.startBackgroundSync();
    if (syncBootstrap.shouldRestore()) {
      unawaited(syncBootstrap.restore());
    }
    // Phase 8: award any budget period that ended while the app was closed.
    // Off the first-frame path — fire-and-forget.
    unawaited(container.read(gamificationReconcilerProvider).runIfSignedIn());
  }

  if (!kReleaseMode) {
    final bootMs = startupStopwatch.elapsedMilliseconds;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      debugPrint(
        'STARTUP: bootstrap=${bootMs}ms, '
        'firstFrame=${startupStopwatch.elapsedMilliseconds}ms, '
        'firebase=${firebase.availability.name}, '
        'session=${session == null ? "none" : "present"}, '
        'transactions=${store.transactions.length}',
      );
    });
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const SpendlyApp()),
  );
}

class SpendlyApp extends ConsumerStatefulWidget {
  const SpendlyApp({super.key});

  @override
  ConsumerState<SpendlyApp> createState() => _SpendlyAppState();
}

class _SpendlyAppState extends ConsumerState<SpendlyApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Phase 6: opportunistic backup when the app comes back to the foreground.
      ref.read(syncManagerProvider)?.onAppResumed();
      // Phase 8: a budget period may have ended while we were backgrounded.
      unawaited(ref.read(gamificationReconcilerProvider).runIfSignedIn());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spendly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthGate(),
    );
  }
}
