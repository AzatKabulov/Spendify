import 'package:flutter/material.dart';

import '../../../domain/services/auth_validation.dart';

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
        border: OutlineInputBorder(),
      ),
      validator: validateEmail,
      onChanged: (_) => onChanged?.call(),
    );
  }
}

/// Password input with a show/hide toggle and a length rule. [newPassword]
/// switches the autofill hint (sign-up vs sign-in) and the "min 6" helper text.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.newPassword = false,
    this.label = 'Password',
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback? onChanged;
  final VoidCallback? onSubmitted;
  final bool newPassword;
  final String label;

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
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscured = !_obscured),
          icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
          tooltip: _obscured ? 'Show password' : 'Hide password',
        ),
      ),
      validator: validatePassword,
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
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: submitting ? null : onPressed,
        child: submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}
