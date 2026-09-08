/// Pure email / password validation for the auth forms. No imports, no I/O —
/// directly unit-testable (CLAUDE.md §5). The UI calls these for inline
/// validation *before* hitting [AuthRepository]; Firebase re-checks server-side.
library;

/// Firebase Authentication's own minimum. Do not lower it.
const int kMinPasswordLength = 6;

/// Deliberately permissive — matches "something@something.something" without
/// trying to fully implement RFC 5322. Firebase is the real authority; this
/// just catches obvious typos early.
final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Returns a user-facing error message, or `null` if [email] is acceptable.
String? validateEmail(String? email) {
  final value = email?.trim() ?? '';
  if (value.isEmpty) return 'Enter your email address.';
  if (!_emailPattern.hasMatch(value)) {
    return "That doesn't look like a valid email address.";
  }
  return null;
}

/// Returns a user-facing error message, or `null` if [password] is acceptable.
String? validatePassword(String? password) {
  final value = password ?? '';
  if (value.isEmpty) return 'Enter a password.';
  if (value.length < kMinPasswordLength) {
    return 'Password must be at least $kMinPasswordLength characters.';
  }
  return null;
}

/// `true` when both fields pass — used to enable/disable the submit button.
bool credentialsLookValid(String? email, String? password) =>
    validateEmail(email) == null && validatePassword(password) == null;
