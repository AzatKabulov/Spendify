/// Seed data for the default category set (CLAUDE.md §6 "Custom categories",
/// Phase 1 task 7). Seeded once per install with `isDefault = true`.
///
/// `iconCode` values are Material `IconData.codePoint`s; `colorValue` is an
/// ARGB int. Both are resolved to Flutter types only in the UI.
class DefaultCategorySeed {
  const DefaultCategorySeed({
    required this.name,
    required this.iconCode,
    required this.colorValue,
  });

  final String name;
  final int iconCode;
  final int colorValue;
}

const List<DefaultCategorySeed> kDefaultCategories = <DefaultCategorySeed>[
  DefaultCategorySeed(name: 'Food', iconCode: 0xe57a, colorValue: 0xFFEF6C00),
  DefaultCategorySeed(
    name: 'Transport',
    iconCode: 0xe1d5,
    colorValue: 0xFF1565C0,
  ),
  DefaultCategorySeed(
    name: 'Groceries',
    iconCode: 0xe8cb,
    colorValue: 0xFF2E7D32,
  ),
  DefaultCategorySeed(name: 'Bills', iconCode: 0xe19c, colorValue: 0xFF6A1B9A),
  DefaultCategorySeed(
    name: 'Entertainment',
    iconCode: 0xe01d,
    colorValue: 0xFFAD1457,
  ),
  DefaultCategorySeed(name: 'Health', iconCode: 0xe1d7, colorValue: 0xFFC62828),
  DefaultCategorySeed(
    name: 'Education',
    iconCode: 0xe80c,
    colorValue: 0xFF00838F,
  ),
  DefaultCategorySeed(name: 'Other', iconCode: 0xe148, colorValue: 0xFF546E7A),
];
