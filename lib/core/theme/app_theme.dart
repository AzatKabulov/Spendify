import 'package:flutter/material.dart';

import 'insets.dart';

/// The single source of truth for Spendify's look (Phase 12). One seed colour,
/// Material 3, component themes so widgets don't re-specify shape/padding.
///
/// Light only for now — a half-finished dark theme is worse than none
/// (Phase 12 brief); dark mode is listed as future work in the README. The
/// palette is defined so a dark `ColorScheme.fromSeed(..., brightness: dark)`
/// is a one-line addition later.
abstract final class AppTheme {
  /// Malaysian-green seed — matches the launcher icon.
  static const Color seed = Color(0xFF2E7D32);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    return _build(scheme);
  }

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: Insets.xs),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, Insets.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, Insets.minTapTarget),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, Insets.minTapTarget),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(Insets.minTapTarget, Insets.minTapTarget),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: Insets.sm,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: Insets.md,
      ),
    );
  }
}

/// Semantic money colours + sign, so income vs expense is shown by **colour
/// paired with a sign** — colour is never the only cue (Phase 12 accessibility).
extension MoneySemantics on ColorScheme {
  /// Positive / income.
  Color get income => const Color(0xFF1B5E20);

  /// Negative / expense — deliberately the normal text colour, not red, so the
  /// list doesn't read as all-alarming. The leading `−` carries the meaning.
  Color get expense => onSurface;

  /// A budget approaching its limit.
  Color get warning => const Color(0xFFE65100);
}

/// The `+` / `−` prefix for a money amount. Always shown next to the value.
String moneySign({required bool isIncome}) => isIncome ? '+' : '−';
