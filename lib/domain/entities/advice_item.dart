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
  const AdviceItem({required this.title, required this.body});

  final String title;
  final String body;

  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    'body': body,
  };

  factory AdviceItem.fromJson(Map<String, Object?> json) => AdviceItem(
    title: (json['title'] as String?)?.trim() ?? '',
    body: (json['body'] as String?)?.trim() ?? '',
  );

  @override
  bool operator ==(Object other) =>
      other is AdviceItem && other.title == title && other.body == body;

  @override
  int get hashCode => Object.hash(title, body);

  @override
  String toString() => 'AdviceItem($title)';
}
