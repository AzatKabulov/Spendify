import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../widgets/auth/auth_form_fields.dart';

/// Email + password registration. On success the [sessionProvider] flips; this
/// pushed route pops itself so `AuthGate` (now showing home) is revealed.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
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
          AuthAction.signUp,
          email: _email.text,
          password: _password.text,
        );
  }

  void _clearError() =>
      ref.read(authFormControllerProvider.notifier).clearError();

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(authFormControllerProvider);

    // Registered + prepared -> leave the auth stack.
    ref.listen<Session>(sessionProvider, (_, next) {
      if (next.isSignedIn && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
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
                        newPassword: true,
                        onChanged: _clearError,
                        onSubmitted: _submit,
                      ),
                      const SizedBox(height: 24),
                      AuthSubmitButton(
                        label: 'Create account',
                        submitting: form.submitting,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Text('Already have an account?'),
                          TextButton(
                            onPressed: form.submitting
                                ? null
                                : () {
                                    _clearError();
                                    Navigator.of(context).pop();
                                  },
                            child: const Text('Sign in'),
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
}
