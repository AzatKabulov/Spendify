import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ai_providers.dart';
import '../../providers/auth_providers.dart';
import '../ai_consent_screen.dart';
import '../home_screen.dart';
import 'sign_in_screen.dart';

/// The app root. Routes on **local** session state only — never a
/// `FirebaseAuth` stream (CLAUDE.md §3/§6: an offline relaunch must go straight
/// to the data with no wait on Firebase).
///
///  - no session               -> [SignInScreen]
///  - session, prep running    -> brief loader (first sign-in runs the userId
///                                migration before the home screen renders)
///  - session, ready, AI key    -> [AiConsentScreen] once, until the user
///    present, consent undecided   accepts or declines (Phase 10)
///  - session, ready           -> [HomeScreen]
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    if (!session.isSignedIn) {
      return const SignInScreen();
    }
    if (!session.ready) {
      return _PreparingScreen(restoring: session.restoring);
    }
    if (ref.watch(aiConsentRequiredProvider)) {
      return const AiConsentScreen();
    }
    return const HomeScreen();
  }
}

class _PreparingScreen extends StatelessWidget {
  const _PreparingScreen({required this.restoring});

  final bool restoring;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              restoring
                  ? 'Restoring your data from backup…'
                  : 'Setting up your account…',
            ),
            if (restoring) ...const <Widget>[
              SizedBox(height: 8),
              Text(
                'This can take a moment on a large history.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
