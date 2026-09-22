// ---------------------------------------------------------------------------
// DIRECTION CONTRACT — "The Instrument" (Phase 12 visual redesign)
//
// THESIS: Spendify treats your money the way a well-made instrument treats
//   its controls — precise, tactile, calm — refusing both the cold blue-gray
//   dashboard every fintech app defaults to and the loud gamified-app look
//   its own ethics reject.
// OWN-WORLD: warm neutral surfaces (never stark white, never cool gray);
//   ONE warm amber accent spent only on the single action that matters per
//   screen; every state reads by icon shape before colour; money set in
//   tabular figures, like a readout.
// STORY: the user recognises, in the first screen, an app that respects
//   their attention — nothing shouts, the one thing to do is obvious, and
//   checking a budget feels like reading a well-made gauge, not a warning
//   label.
// FIRST VIEWPORT (home): a balance card with a warm amber-tinted fill and a
//   large tabular-figure balance readout, a budget-warning strip that reads
//   by icon before colour, then the transaction list; one FAB, amber, the
//   only saturated mark on the screen.
// FORM: catalog challenger "a creator-hardware desk instrument" (source id
//   design-canon-creator-hardware-bench), won its fusion round against this
//   app's own top-ranked grounded candidate on both audience-identification
//   and product-clarity axes; raised with two donated disciplines — state by
//   shape not hue (declined challenger operate-b-normalled-jackfield) and
//   colour confined to accents against an achromatic field (declined
//   challenger clouds-storms-auroras-iridescent-cloud-edge). Seed key
//   c3b204a1eed6.
// FINISH: unreviewed and undocumented is unfinished; this build ends with
//   the finish review, the verdict, DESIGN.md, and every shipping raster
//   carrying its provenance.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import 'insets.dart';

/// Raw colour tokens for "The Instrument" (Phase 12). Every text-on-surface
/// and text-on-fill pairing below is checked against WCAG AA (4.5:1 body
/// text) before use — see the ratio noted on each pairing. Functional
/// boundaries (an input field's resting edge) are checked against the 3:1
/// non-text-contrast minimum instead; purely decorative hairlines (a card's
/// outline variant, a divider) are not, by design — that is what makes them
/// read as quiet rather than as an edge to focus on.
abstract final class _Palette {
  // Soft off-white surfaces with a faint green cast.
  static const surface = Color(0xFFF7F8F6);
  static const surfaceContainer = Color(0xFFEFF3F0);
  static const surfaceContainerHigh = Color(0xFFE6ECE8);
  static const surfaceContainerHighest = Color(0xFFDCE4DF);

  static const onSurface = Color(0xFF1B1F1D); // 13.7:1 on surface
  static const onSurfaceVariant = Color(0xFF636B66); // 5.3:1 on surface

  static const outline = Color(0xFF7C857F); // 3.5:1 — functional borders
  static const outlineVariant = Color(0xFFDDE3DF); // decorative only

  // The one accent (deep green, matched to the approved mockups) — spent on
  // exactly one action per screen.
  static const primary = Color(0xFF226A4B); // 4.6:1 on surface, 5.0:1 w/white
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFE1EEE6);
  static const onPrimaryContainer = Color(0xFF14402C); // 8.9:1

  // Quiet secondary/tertiary — desaturated on purpose, never a second loud
  // hue. They exist to fill Material's role set, not to compete with primary.
  static const secondary = Color(0xFF5E6B63);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFE6ECE8);
  static const onSecondaryContainer = Color(0xFF26302A);

  static const tertiary = Color(0xFF8A4F0E);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFFF6E3CC);
  static const onTertiaryContainer = Color(0xFF5C3200);

  // Money semantics — distinct from the brand accent, so a green income
  // figure is never mistaken for a tappable action.
  static const income = Color(0xFF1B6B3A); // 6.0:1 on surface
  static const budgetApproaching = Color(0xFF8A4F0E); // 6.0:1 — icon-led
  static const budgetExceeded = Color(0xFFB3261E); // 6.0:1 / 6.5:1 w/white
  static const errorContainer = Color(0xFFF9DEDC);
  static const onErrorContainer = Color(0xFF410E0B);

  static const shadow = Color(0xFF101412); // warm, not neutral black
  static const inverseSurface = Color(0xFF2B312E);
  static const onInverseSurface = Color(0xFFF7F8F6);
  static const inversePrimary = Color(0xFF9AD3B3);
}

/// The single source of truth for Spendify's look ("The Instrument", Phase
/// 12). Material 3 throughout — Android-native navigation and components,
/// per the redesign's own brief — themed with one considered warm palette
/// instead of the generic seeded-teal Material default.
///
/// Light only for now — a half-finished dark theme is worse than none
/// (decided Phase 12, carried forward through this redesign); dark mode
/// stays future work. See `docs/DESIGN.md` for the full system.
abstract final class AppTheme {
  static const Color seed = _Palette.primary;
  static const String fontFamily = 'Inter';

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _Palette.primary,
          brightness: Brightness.light,
        ).copyWith(
          // Override every role this direction actually art-directs; leave the
          // seed-derived roles Material still needs (surfaceTint, scrim, the
          // rarely-touched surfaceBright/Dim ladder) as the algorithm's warm,
          // amber-seeded derivation — already close, and correct by construction.
          surface: _Palette.surface,
          onSurface: _Palette.onSurface,
          onSurfaceVariant: _Palette.onSurfaceVariant,
          outline: _Palette.outline,
          outlineVariant: _Palette.outlineVariant,
          surfaceContainerLowest: _Palette.surface,
          surfaceContainerLow: _Palette.surfaceContainer,
          surfaceContainer: _Palette.surfaceContainer,
          surfaceContainerHigh: _Palette.surfaceContainerHigh,
          surfaceContainerHighest: _Palette.surfaceContainerHighest,
          primary: _Palette.primary,
          onPrimary: _Palette.onPrimary,
          primaryContainer: _Palette.primaryContainer,
          onPrimaryContainer: _Palette.onPrimaryContainer,
          secondary: _Palette.secondary,
          onSecondary: _Palette.onSecondary,
          secondaryContainer: _Palette.secondaryContainer,
          onSecondaryContainer: _Palette.onSecondaryContainer,
          tertiary: _Palette.tertiary,
          onTertiary: _Palette.onTertiary,
          tertiaryContainer: _Palette.tertiaryContainer,
          onTertiaryContainer: _Palette.onTertiaryContainer,
          error: _Palette.budgetExceeded,
          onError: Colors.white,
          errorContainer: _Palette.errorContainer,
          onErrorContainer: _Palette.onErrorContainer,
          shadow: _Palette.shadow,
          scrim: Colors.black,
          inverseSurface: _Palette.inverseSurface,
          onInverseSurface: _Palette.onInverseSurface,
          inversePrimary: _Palette.inversePrimary,
          surfaceTint: _Palette.primary,
        );
    return _build(scheme);
  }

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      splashFactory: InkSparkle.splashFactory,
    );

    final textTheme = _instrumentTextTheme(base.textTheme, scheme);

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: Insets.xs),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, Insets.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          animationDuration: AppMotion.quick,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, Insets.minTapTarget),
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, Insets.minTapTarget),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(Insets.minTapTarget, Insets.minTapTarget),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 4,
        extendedTextStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
        shape: const StadiumBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        labelStyle: textTheme.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: Insets.sm,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: Insets.md,
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Inter through Material's type-scale roles — the roles stay Material's
  /// own (no hand-picked sizes per screen), only the face and weight steps
  /// are art-directed.
  static TextTheme _instrumentTextTheme(TextTheme base, ColorScheme scheme) {
    return base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          displayMedium: base.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          headlineLarge: base.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          labelSmall: base.labelSmall?.copyWith(fontWeight: FontWeight.w600),
          bodyLarge: base.bodyLarge?.copyWith(
            fontWeight: FontWeight.w400,
            height: 1.35,
          ),
          bodyMedium: base.bodyMedium?.copyWith(
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
          bodySmall: base.bodySmall?.copyWith(fontWeight: FontWeight.w400),
        )
        .apply(displayColor: scheme.onSurface, bodyColor: scheme.onSurface);
  }
}

/// Semantic money colours + sign, so income vs expense is shown by **colour
/// paired with a sign** — colour is never the only cue. "The Instrument"
/// direction (Phase 12): these stay deliberately distinct from
/// [ColorScheme.primary] — the brand accent marks an action, these mark a
/// fact about a number, and conflating the two would make every income row
/// look like a button.
extension MoneySemantics on ColorScheme {
  /// Positive / income.
  Color get income => _Palette.income;

  /// Negative / expense — deliberately the normal text colour, not red, so
  /// the list doesn't read as all-alarming. The leading `−` carries the
  /// meaning, paired with the colour (never colour alone).
  Color get expense => onSurface;

  /// A budget approaching its limit. Always paired with a distinct icon
  /// shape (never colour alone) — see `budget_visuals.dart`.
  Color get warning => _Palette.budgetApproaching;
}

/// The `+` / `−` prefix for a money amount. Always shown next to the value.
String moneySign({required bool isIncome}) => isIncome ? '+' : '−';
