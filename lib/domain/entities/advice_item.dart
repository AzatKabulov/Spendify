/// What kind of budgeting observation an [AdviceItem] is — Gemini classifies
/// each item as it generates it (see the prompt in `GeminiAdviceClient`).
///
/// Redesign deviation (flagged): added so the Insights screen's "For You /
/// Spending / Saving / Budgeting" tabs filter something real instead of being
/// decorative. `general` is the honest default for anything unclassified
/// (including every item generated before this field existed) — it still
/// shows under "For You" (which shows everything), just not under a specific
/// tab, rather than being guessed into the wrong one.
enum AdviceItemType {
  spending,
  saving,
  budgeting,
  general;

  static AdviceItemType fromWire(String? raw) =>
      switch (raw?.trim().toLowerCase()) {
        'spending' => AdviceItemType.spending,
        'saving' || 'savings' => AdviceItemType.saving,
        'budgeting' || 'budget' => AdviceItemType.budgeting,
        _ => AdviceItemType.general,
      };

  String get wireValue => name;
}

/// One piece of AI-generated budgeting guidance: a short [title] and a 1–3
/// sentence [body]. Plain Dart, no imports.
///
/// Phase 9 deviation from CLAUDE.md §4 (flagged): `AdviceRecord.adviceItems` was
/// `List<String>`; it is now `List<AdviceItem>`. The Gemini contract this phase
/// specifies returns `{ "title", "body" }` per item, and a titled card list is
/// materially better UX than a flat string. The Hive model still stores each
/// item as a JSON string, so there is no schema/`typeId` change — the mapper
/// bridges.
class AdviceItem {
  const AdviceItem({
    required this.title,
    required this.body,
    this.type = AdviceItemType.general,
  });

  final String title;
  final String body;

  /// Redesign addition (flagged, see [AdviceItemType]) — defaults to
  /// [AdviceItemType.general] so every item constructed before this field
  /// existed (including in tests) keeps compiling and rendering unchanged.
  final AdviceItemType type;

  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    'body': body,
    'type': type.wireValue,
  };

  factory AdviceItem.fromJson(Map<String, Object?> json) => AdviceItem(
    title: (json['title'] as String?)?.trim() ?? '',
    body: (json['body'] as String?)?.trim() ?? '',
    type: AdviceItemType.fromWire(json['type'] as String?),
  );

  @override
  bool operator ==(Object other) =>
      other is AdviceItem &&
      other.title == title &&
      other.body == body &&
      other.type == type;

  @override
  int get hashCode => Object.hash(title, body, type);

  @override
  String toString() => 'AdviceItem($title)';
}
