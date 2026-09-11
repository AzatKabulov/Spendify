import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/remote/firebase_bootstrap.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/auth/auth_form_fields.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

/// First entry. Email + password sign-in against Firebase. On success the
/// [sessionProvider] flips and `AuthGate` swaps this screen for the home
/// screen — no manual navigation here.
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _Header(),
                      const SizedBox(height: 32),
                      if (!firebaseReady) ...<Widget>[
                        _UnavailableNotice(availability: availability),
                        const SizedBox(height: 16),
                      ],
                      if (form.errorMessage != null) ...<Widget>[
                        AuthErrorText(form.errorMessage!),
                        const SizedBox(height: 16),
                      ],
                      EmailField(
                        controller: _email,
                        autofocus: true,
                        onChanged: _clearError,
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 8),
                      AuthSubmitButton(
                        label: 'Sign in',
                        submitting: form.submitting,
                        onPressed: firebaseReady ? _submit : null,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          const Text("New here?"),
                          TextButton(
                            onPressed: form.submitting
                                ? null
                                : () => _open(const SignUpScreen()),
                            child: const Text('Create an account'),
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Icon(
          Icons.savings_outlined,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text('Spendly', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'Sign in to sync your budget',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
