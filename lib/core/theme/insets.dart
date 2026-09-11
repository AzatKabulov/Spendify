/// The single spacing scale for the whole app (Phase 12). Multiples of 4;
/// the common steps get names. Use these instead of bare numbers in new code.
///
///   Insets.xs = 4   Insets.sm = 8   Insets.md = 16   Insets.lg = 24   Insets.xl = 32
library;

abstract final class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Standard screen edge padding.
  static const double screen = md;

  /// Minimum interactive target (accessibility — WCAG 2.5.5 / Material).
  static const double minTapTarget = 48;
}
