import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Whether Firebase came up on this launch.
enum FirebaseAvailability {
  /// `Firebase.initializeApp` succeeded — auth is live.
  ready,

  /// No real config on this build yet (`flutterfire configure` not run). The
  /// app still starts; the sign-in screen says auth is unavailable.
  notConfigured,

  /// Real config present but init threw. The app still starts and reaches the
  /// sign-in screen with a message rather than a white screen (Phase 5, Part A).
  initFailed,
}

class FirebaseBootstrapResult {
  const FirebaseBootstrapResult(this.availability, {this.error});

  final FirebaseAvailability availability;
  final Object? error;

  bool get isReady => availability == FirebaseAvailability.ready;
}

/// `true` while [firebase_options.dart] still holds the checked-in placeholder
/// values. A real `flutterfire configure` project id never contains
/// "placeholder".
bool looksLikePlaceholder(FirebaseOptions options) =>
    options.projectId.contains('placeholder') ||
    options.apiKey == 'PLACEHOLDER_API_KEY';

/// Initialise Firebase, never throwing. `main()` uses the result to decide
/// whether the auth layer is live; the app boots regardless.
Future<FirebaseBootstrapResult> initializeFirebase() async {
  if (looksLikePlaceholder(DefaultFirebaseOptions.android)) {
    if (!kReleaseMode) {
      debugPrint(
        'FIREBASE: placeholder config — auth disabled. Run `flutterfire '
        'configure` to enable it.',
      );
    }
    return const FirebaseBootstrapResult(FirebaseAvailability.notConfigured);
  }

  try {
    // `initializeApp` with explicit options is local (no network), but time-box
    // it anyway so a wedged init can never hold up an offline launch.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
    return const FirebaseBootstrapResult(FirebaseAvailability.ready);
  } catch (error, stack) {
    if (!kReleaseMode) {
      debugPrint('FIREBASE: initializeApp failed: $error\n$stack');
    }
    return FirebaseBootstrapResult(
      FirebaseAvailability.initFailed,
      error: error,
    );
  }
}
