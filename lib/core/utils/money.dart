/// Money helpers. Currency is Malaysian Ringgit (RM); the minor unit is the
/// sen (1/100). Amounts are `int` sen everywhere — never `double` (CLAUDE.md §4).
///
/// These are pure functions with no Flutter or storage dependency.
library;

const String _currencyPrefix = 'RM ';

/// Parses a user-typed amount into sen, or returns `null` if it is not a
/// well-formed non-negative amount.
///
/// Accepted: `"12"` → 1200, `"12.5"` → 1250, `"12.50"` → 1250, `".50"` → 50,
/// `"0"` → 0, `"  1,234.50 "` → 123450, a leading `"RM"` is tolerated.
///
/// Rejected (returns `null`): empty/blank, non-numeric, negative (`"-5"`),
/// more than one decimal point, and **more than two decimal places when the
/// extra digits are not all zero** (`"12.999"` → `null`, but `"12.5000"` →
/// 1250). Rejecting rather than rounding is deliberate: silently turning
/// `12.999` into `13.00` on a financial record is worse than a one-time inline
/// "use at most 2 decimal places" nudge.
int? parseAmountToMinor(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;

  // Tolerate a currency prefix the user may have pasted.
  if (s.toUpperCase().startsWith('RM')) {
    s = s.substring(2).trim();
  }

  // Thousands separators.
  s = s.replaceAll(',', '');
  if (s.isEmpty) return null;

  // Only digits and at most one dot; no sign (negatives are not valid amounts).
  if (!RegExp(r'^\d*\.?\d*$').hasMatch(s)) return null;

  final parts = s.split('.');
  final intPart = parts[0];
  final fracPart = parts.length == 2 ? parts[1] : '';

  // "." or "" with nothing on either side.
  if (intPart.isEmpty && fracPart.isEmpty) return null;

  var frac = fracPart;
  if (frac.length > 2) {
    final overflow = frac.substring(2);
    if (overflow.replaceAll('0', '').isNotEmpty) return null;
    frac = frac.substring(0, 2);
  }
  frac = frac.padRight(2, '0');

  try {
    final ringgit = intPart.isEmpty ? 0 : int.parse(intPart);
    final sen = int.parse(frac);
    return ringgit * 100 + sen;
  } on FormatException {
    return null; // absurdly long input overflowing int64
  }
}

/// Formats sen for display: `1250` → `"RM 12.50"`, `123456` → `"RM 1,234.56"`,
/// `-1250` → `"-RM 12.50"`, `0` → `"RM 0.00"`.
String formatMinor(int minor) {
  final sign = minor < 0 ? '-' : '';
  final abs = minor.abs();
  final ringgit = abs ~/ 100;
  final sen = abs % 100;
  return '$sign$_currencyPrefix${_groupThousands(ringgit)}.'
      '${sen.toString().padLeft(2, '0')}';
}

/// Same as [formatMinor] but with an explicit leading `+` / `-` — for showing
/// a transaction's signed effect on the balance.
String formatMinorSigned(int minor) {
  if (minor == 0) return formatMinor(0);
  final sign = minor > 0 ? '+' : '-';
  return '$sign$_currencyPrefix${_groupThousands(minor.abs() ~/ 100)}.'
      '${(minor.abs() % 100).toString().padLeft(2, '0')}';
}

/// Plain editable representation for a text field: `1250` → `"12.50"`,
/// `5` → `"0.05"`. No currency prefix, no grouping. Round-trips through
/// [parseAmountToMinor].
String minorToEditString(int minor) {
  final abs = minor.abs();
  return '${minor < 0 ? '-' : ''}${abs ~/ 100}.'
      '${(abs % 100).toString().padLeft(2, '0')}';
}

String _groupThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
