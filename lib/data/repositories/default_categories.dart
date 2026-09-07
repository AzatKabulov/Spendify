import 'package:flutter/material.dart';

/// Seed data for the default category set (CLAUDE.md §6 "Custom categories",
/// Phase 1 task 7). Seeded once per install with `isDefault = true`.
///
/// `iconCode` is a Material `IconData.codePoint` drawn from `kCategoryIcons`
/// (`core/category_icons.dart`) so it stays tree-shake-safe; `colorValue` is an
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

final List<DefaultCategorySeed> kDefaultCategories = <DefaultCategorySeed>[
  DefaultCategorySeed(
    name: 'Food',
    iconCode: Icons.restaurant.codePoint,
    colorValue: 0xFFEF6C00,
  ),
  DefaultCategorySeed(
    name: 'Transport',
    iconCode: Icons.directions_bus.codePoint,
    colorValue: 0xFF1565C0,
  ),
  DefaultCategorySeed(
    name: 'Groceries',
    iconCode: Icons.shopping_cart.codePoint,
    colorValue: 0xFF2E7D32,
  ),
  DefaultCategorySeed(
    name: 'Bills',
    iconCode: Icons.receipt_long.codePoint,
    colorValue: 0xFF6A1B9A,
  ),
  DefaultCategorySeed(
    name: 'Entertainment',
    iconCode: Icons.movie.codePoint,
    colorValue: 0xFFAD1457,
  ),
  DefaultCategorySeed(
    name: 'Health',
    iconCode: Icons.medical_services.codePoint,
    colorValue: 0xFFC62828,
  ),
  DefaultCategorySeed(
    name: 'Education',
    iconCode: Icons.school.codePoint,
    colorValue: 0xFF00838F,
  ),
  DefaultCategorySeed(
    name: 'Other',
    iconCode: Icons.category.codePoint,
    colorValue: 0xFF546E7A,
  ),
];
