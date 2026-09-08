import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../widgets/auth/auth_form_fields.dart';

/// Sends a Firebase password-reset email. No sign-in happens here.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authFormControllerProvider.notifier)
        .submit(AuthAction.resetPassword, email: _email.text, password: '');
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(authFormControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: form.done
                  ? _SentNotice(
                      email: _email.text.trim(),
                      onBack: () => Navigator.of(context).pop(),
                    )
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'Enter your email and we\'ll send you a link to '
                            'set a new password.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 20),
                          if (form.errorMessage != null) ...<Widget>[
                            AuthErrorText(form.errorMessage!),
                            const SizedBox(height: 16),
                          ],
                          EmailField(
                            controller: _email,
                            autofocus: true,
                            onChanged: () => ref
                                .read(authFormControllerProvider.notifier)
                                .clearError(),
                          ),
                          const SizedBox(height: 24),
                          AuthSubmitButton(
                            label: 'Send reset link',
                            submitting: form.submitting,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SentNotice extends StatelessWidget {
  const _SentNotice({required this.email, required this.onBack});

  final String email;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Icon(
          Icons.mark_email_read_outlined,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          email.isEmpty
              ? 'If that account exists, a reset link is on its way.'
              : 'If $email has an account, a reset link is on its way.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: onBack, child: const Text('Back to sign in')),
      ],
    );
  }
}
