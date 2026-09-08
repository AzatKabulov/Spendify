import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/local/auth_session_store.dart';
import 'data/local/hive_initializer.dart';
import 'data/remote/firebase_bootstrap.dart';
import 'presentation/providers/auth_providers.dart';
import 'presentation/providers/repository_providers.dart';
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
  final AuthSession? session = await SecureStorageAuthSessionStore().read();

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

class SpendlyApp extends StatelessWidget {
  const SpendlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spendly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
