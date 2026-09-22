import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/insets.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/auth/auth_chrome.dart';
import '../../widgets/auth/auth_illustrations.dart';
import '../../widgets/auth/auth_form_fields.dart';

/// Sends a Firebase password-reset email. No sign-in happens here.
///
/// Fixed one-screen layout, matching [SignInScreen] — no illustration, no
/// footer band.
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Insets.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      AuthBackButton(),
                      Spacer(),
                      LeafMark(size: 30),
                    ],
                  ),
                  const SizedBox(height: Insets.lg),
                  if (form.done)
                    _SentNotice(
                      email: _email.text.trim(),
                      onBack: () => Navigator.of(context).pop(),
                    )
                  else ...<Widget>[
                    Icon(Icons.lock_reset, size: 48, color: scheme.primary),
                    const SizedBox(height: Insets.md),
                    Text(
                      'Forgot your password?',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      'No worries. Enter your email address and we\'ll send '
                      'you a link to reset it.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                    AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (form.errorMessage != null) ...<Widget>[
                              AuthErrorText(form.errorMessage!),
                              const SizedBox(height: Insets.md),
                            ],
                            EmailField(
                              controller: _email,
                              autofocus: true,
                              onChanged: () => ref
                                  .read(authFormControllerProvider.notifier)
                                  .clearError(),
                            ),
                            const SizedBox(height: Insets.md),
                            AuthSubmitButton(
                              label: 'Send reset link',
                              submitting: form.submitting,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: Insets.xs),
                            Center(
                              child: TextButton(
                                onPressed: form.submitting
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('Back to sign in'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
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
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mark_email_read_outlined,
            size: 36,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: Insets.md),
        Text('Check your email', style: theme.textTheme.titleLarge),
        const SizedBox(height: Insets.xs),
        Text(
          email.isEmpty
              ? 'If that account exists, a reset link is on its way.'
              : 'If $email has an account, a reset link is on its way.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Insets.lg),
        AuthSubmitButton(
          label: 'Back to sign in',
          submitting: false,
          onPressed: onBack,
        ),
      ],
    );
  }
}
