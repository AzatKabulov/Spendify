/// The single spacing scale for the whole app (Phase 12). Multiples of 4;
/// the common steps get names. Use these instead of bare numbers in new code.
///
///   Insets.xs = 4   Insets.sm = 8   Insets.md = 16   Insets.lg = 24   Insets.xl = 32
library;

import 'package:flutter/animation.dart';

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

/// Corner radii ("The Instrument" direction, Phase 12 redesign). Cards stay in
/// the 12–16px band deliberately — a precision instrument has a controlled
/// chamfer, not a bubbly one. Bigger surfaces (sheets, dialogs) that visually
/// leave the card language get more.
abstract final class AppRadius {
  /// Small controls: chips, badges, the from-receipt marker.
  static const double sm = 10;

  /// Cards, list tiles, input fields — the app's default surface radius.
  static const double md = 16;

  /// Sheets, dialogs, the AI-consent screen's feature cards.
  static const double lg = 24;
}

/// Motion constants ("The Instrument" direction). One considered feel used
/// everywhere rather than each screen picking its own duration — quick and
/// precise, never languid.
abstract final class AppMotion {
  /// Micro-feedback: a tactile button press, a checkbox toggling.
  static const Duration quick = Duration(milliseconds: 120);

  /// Standard: a card's content changing, a snackbar, a page element
  /// settling into place.
  static const Duration standard = Duration(milliseconds: 220);

  /// A full-screen transition (push/pop, sheet in/out).
  static const Duration screen = Duration(milliseconds: 320);

  /// Exponential-feeling ease-out — decisive arrival, no bounce, no linear
  /// coast. The one curve the app's motion is built from.
  static const Curve easeOut = Curves.easeOutCubic;

  /// For a press that must feel like it has *weight* on the way back up.
  static const Curve pressRelease = Curves.easeOutQuint;
}
