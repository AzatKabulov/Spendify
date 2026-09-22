import 'package:flutter/material.dart';

import '../../../domain/services/auth_validation.dart';
import '../tactile_press.dart';

/// Email input with inline format validation. Used on every auth screen.
class EmailField extends StatelessWidget {
  const EmailField({
    required this.controller,
    this.onChanged,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: TextInputAction.next,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: const InputDecoration(
        labelText: 'Email',
        prefixIcon: Icon(Icons.mail_outline),
      ),
      validator: validateEmail,
      onChanged: (_) => onChanged?.call(),
    );
  }
}

/// Full name input for sign-up — passed on to Firebase as the account's
/// display name (best-effort; never blocks account creation).
class FullNameField extends StatelessWidget {
  const FullNameField({
    required this.controller,
    this.onChanged,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
      autofillHints: const [AutofillHints.name],
      textInputAction: TextInputAction.next,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: const InputDecoration(
        labelText: 'Full name',
        prefixIcon: Icon(Icons.person_outline),
      ),
      validator: validateFullName,
      onChanged: (_) => onChanged?.call(),
    );
  }
}

/// Password input with a show/hide toggle and a length rule. [newPassword]
/// switches the autofill hint (sign-up vs sign-in) and the "min 6" helper text.
/// [validator] overrides the default length-only check — used by the sign-up
/// confirm-password field to also check it matches the first password.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.newPassword = false,
    this.label = 'Password',
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback? onChanged;
  final VoidCallback? onSubmitted;
  final bool newPassword;
  final String label;
  final String? Function(String?)? validator;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      textInputAction: TextInputAction.done,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.newPassword
            ? 'At least $kMinPasswordLength characters'
            : null,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscured = !_obscured),
          icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
          tooltip: _obscured ? 'Show password' : 'Hide password',
        ),
      ),
      validator: widget.validator ?? validatePassword,
      onChanged: (_) => widget.onChanged?.call(),
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
    );
  }
}

/// Inline error banner for a mapped [AuthException] message.
class AuthErrorText extends StatelessWidget {
  const AuthErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, size: 20, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width submit button that shows a spinner and blocks re-taps while
/// [submitting] (so a double tap cannot create two accounts — Phase 5, Part D).
/// Wrapped in [TactilePress] — the app's one shared press-feedback motion,
/// also used on the home FAB and every form's primary Save button.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    required this.label,
    required this.submitting,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool submitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TactilePress(
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: submitting ? null : onPressed,
          child: submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Text(label),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Icon(Icons.arrow_forward_rounded, size: 22),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
