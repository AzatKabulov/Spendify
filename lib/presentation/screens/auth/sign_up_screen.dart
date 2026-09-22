import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/insets.dart';
import '../../../domain/services/auth_validation.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/auth/auth_chrome.dart';
import '../../widgets/auth/auth_illustrations.dart';
import '../../widgets/auth/auth_form_fields.dart';
import '../privacy_notice_screen.dart';

/// Email + password registration. On success the [sessionProvider] flips; this
/// pushed route pops itself so `AuthGate` (now showing home) is revealed.
///
/// Fixed one-screen layout, matching [SignInScreen] — no illustration, no
/// footer band. The full name is passed on to Firebase as the account's
/// display name (best-effort — CLAUDE.md doesn't add a name field to any
/// synced entity, so this rides on Firebase's own built-in profile field
/// rather than growing the data model). Confirm-password and the terms
/// checkbox are purely client-side gates; there is no separate
/// Terms-of-Service document in this project, so that link (like Privacy
/// Policy) opens the one real policy page.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _agreedToTerms = false;

  late final TapGestureRecognizer _policyTap = TapGestureRecognizer()
    ..onTap = () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PrivacyNoticeScreen()),
    );

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _policyTap.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_agreedToTerms) return;
    await ref
        .read(authFormControllerProvider.notifier)
        .submit(
          AuthAction.signUp,
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
  }

  void _clearError() =>
      ref.read(authFormControllerProvider.notifier).clearError();

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(authFormControllerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Registered + prepared -> leave the auth stack.
    ref.listen<Session>(sessionProvider, (_, next) {
      if (next.isSignedIn && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });

    final canSubmit = !form.submitting && _agreedToTerms;

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
                      const Row(
                        children: <Widget>[
                          AuthBackButton(),
                          Spacer(),
                          LeafMark(size: 30),
                        ],
                      ),
                      const SizedBox(height: Insets.md),
                      Text(
                        'Create your account',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        'Join Spendify and take the first step towards a '
                        'brighter financial future.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                      if (form.errorMessage != null) ...<Widget>[
                        AuthErrorText(form.errorMessage!),
                        const SizedBox(height: Insets.sm),
                      ],
                      FullNameField(
                        controller: _name,
                        autofocus: true,
                        onChanged: _clearError,
                      ),
                      const SizedBox(height: Insets.sm + Insets.xs),
                      EmailField(controller: _email, onChanged: _clearError),
                      const SizedBox(height: Insets.sm + Insets.xs),
                      PasswordField(
                        controller: _password,
                        newPassword: true,
                        onChanged: _clearError,
                      ),
                      const SizedBox(height: Insets.sm + Insets.xs),
                      PasswordField(
                        controller: _confirmPassword,
                        label: 'Confirm password',
                        onChanged: _clearError,
                        onSubmitted: canSubmit ? _submit : null,
                        validator: (value) =>
                            validatePasswordConfirmation(_password.text, value),
                      ),
                      const SizedBox(height: Insets.sm),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            height: 40,
                            child: Checkbox(
                              value: _agreedToTerms,
                              onChanged: (value) => setState(
                                () => _agreedToTerms = value ?? false,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: Insets.sm),
                              child: Text.rich(
                                TextSpan(
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  children: <InlineSpan>[
                                    const TextSpan(text: 'I agree to the '),
                                    TextSpan(
                                      text: 'Terms of Service',
                                      style: TextStyle(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      recognizer: _policyTap,
                                    ),
                                    const TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: TextStyle(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      recognizer: _policyTap,
                                    ),
                                    const TextSpan(text: '.'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.xs),
                      AuthSubmitButton(
                        label: 'Create account',
                        submitting: form.submitting,
                        onPressed: canSubmit ? _submit : null,
                      ),
                      const SizedBox(height: Insets.sm + Insets.xs),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            'Already have an account?',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
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
