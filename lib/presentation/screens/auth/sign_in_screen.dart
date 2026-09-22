import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/insets.dart';
import '../../../data/remote/firebase_bootstrap.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/auth/auth_form_fields.dart';
import '../../widgets/auth/auth_illustrations.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

/// First entry. Email + password sign-in against Firebase. On success the
/// [sessionProvider] flips and `AuthGate` swaps this screen for the home
/// screen — no manual navigation here.
///
/// Deliberately a **fixed one-screen layout** (no illustration hero, no
/// footer band): those pushed the form below the fold on a real phone,
/// which made the screen feel like a scrolling marketing page instead of a
/// native sign-in screen. `SingleChildScrollView` stays only as a safety net
/// for the keyboard on very short devices — it is not meant to be scrolled
/// in the resting state.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authFormControllerProvider.notifier)
        .submit(
          AuthAction.signIn,
          email: _email.text,
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(authFormControllerProvider);
    final availability = ref.watch(firebaseAvailabilityProvider);
    final firebaseReady = availability == FirebaseAvailability.ready;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Insets.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Center(child: LeafMark(size: 44)),
                      const SizedBox(height: Insets.sm),
                      Text(
                        'Spendify',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: Insets.lg + Insets.xs),
                      Text(
                        'Welcome back',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        "Sign in to continue your financial journey.",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Insets.lg),
                      if (!firebaseReady) ...<Widget>[
                        _UnavailableNotice(availability: availability),
                        const SizedBox(height: Insets.md),
                      ],
                      if (form.errorMessage != null) ...<Widget>[
                        AuthErrorText(form.errorMessage!),
                        const SizedBox(height: Insets.md),
                      ],
                      EmailField(
                        controller: _email,
                        autofocus: true,
                        onChanged: _clearError,
                      ),
                      const SizedBox(height: Insets.md),
                      PasswordField(
                        controller: _password,
                        onChanged: _clearError,
                        onSubmitted: firebaseReady ? _submit : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: form.submitting
                              ? null
                              : () => _open(const ForgotPasswordScreen()),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      AuthSubmitButton(
                        label: 'Sign in',
                        submitting: form.submitting,
                        onPressed: firebaseReady ? _submit : null,
                      ),
                      const SizedBox(height: Insets.md),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            "Don't have an account?",
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          TextButton(
                            onPressed: form.submitting
                                ? null
                                : () => _open(const SignUpScreen()),
                            child: const Text('Sign up'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _clearError() =>
      ref.read(authFormControllerProvider.notifier).clearError();

  void _open(Widget screen) {
    ref.read(authFormControllerProvider.notifier).clearError();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice({required this.availability});

  final FirebaseAvailability availability;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = availability == FirebaseAvailability.initFailed
        ? "Couldn't reach Firebase. Check your connection, then reopen the app."
        : 'Sign-in is not available in this build yet — Firebase has not been '
              'configured.';
    return Container(
      padding: const EdgeInsets.all(Insets.sm + Insets.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: Insets.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
