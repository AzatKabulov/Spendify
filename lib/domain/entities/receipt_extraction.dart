/// The structured result of a Gemini receipt scan. Every field is nullable —
/// Gemini is asked to return `null` for anything it cannot read rather than
/// guess, and the parser accepts a partial object (a bad field never discards
/// the others).
///
/// This is handed to the confirmation screen, never saved directly (CLAUDE.md
/// §7: AI extraction is always confirm-before-save).
class ReceiptExtraction {
  const ReceiptExtraction({
    this.merchant,
    this.totalAmountMinor,
    this.currency,
    this.date,
    this.suggestedCategory,
    this.confidence = 0.0,
  });

  /// A fully-empty result (used when parsing fails but we still want to fall
  /// back to the manual form).
  static const ReceiptExtraction empty = ReceiptExtraction();

  final String? merchant;

  /// Total in sen (e.g. RM 12.50 -> 1250). Always `> 0` when present.
  final int? totalAmountMinor;

  /// Expected `"MYR"`.
  final String? currency;

  /// Date-only (time component stripped).
  final DateTime? date;

  /// Free-text category label from Gemini — mapped to a real category by
  /// `category_matcher.dart`, never used verbatim.
  final String? suggestedCategory;

  /// Model self-reported confidence, clamped to `[0.0, 1.0]`.
  final double confidence;

  bool get hasAnyField =>
      merchant != null ||
      totalAmountMinor != null ||
      date != null ||
      suggestedCategory != null;

  /// Below this, the confirmation screen tells the user to double-check.
  bool get isLowConfidence => confidence < 0.5;

  @override
  String toString() =>
      'ReceiptExtraction(merchant=$merchant, amount=$totalAmountMinor, '
      'currency=$currency, date=$date, category=$suggestedCategory, '
      'confidence=$confidence)';
}
