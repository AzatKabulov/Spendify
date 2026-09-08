import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../home_screen.dart';
import 'sign_in_screen.dart';

/// The app root. Routes on **local** session state only — never a
/// `FirebaseAuth` stream (CLAUDE.md §3/§6: an offline relaunch must go straight
/// to the data with no wait on Firebase).
///
///  - no session            -> [SignInScreen]
///  - session, prep running -> brief loader (first sign-in runs the userId
///                             migration before the home screen renders)
///  - session, ready        -> [HomeScreen]
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    if (!session.isSignedIn) {
      return const SignInScreen();
    }
    if (!session.ready) {
      return const _PreparingScreen();
    }
    return const HomeScreen();
  }
}

class _PreparingScreen extends StatelessWidget {
  const _PreparingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Setting up your account…'),
          ],
        ),
      ),
    );
  }
}
