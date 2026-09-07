import 'package:flutter/material.dart';

/// The fixed palette of category icons.
///
/// `Category.iconCode` is stored as an `int` codepoint (CLAUDE.md §4). Flutter's
/// release build tree-shakes icon fonts and refuses non-const `IconData`, so
/// every icon the app can render must appear here as a **const** `IconData`.
/// [categoryIconForCode] maps a stored codepoint back to one of these.
const List<IconData> kCategoryIcons = <IconData>[
  Icons.restaurant, // Food
  Icons.directions_bus, // Transport
  Icons.shopping_cart, // Groceries
  Icons.receipt_long, // Bills
  Icons.movie, // Entertainment
  Icons.medical_services, // Health
  Icons.school, // Education
  Icons.category, // Other / fallback
  Icons.home,
  Icons.pets,
  Icons.fitness_center,
  Icons.local_cafe,
  Icons.flight,
  Icons.card_giftcard,
  Icons.savings,
  Icons.work,
  Icons.phone_android,
  Icons.checkroom,
  Icons.sports_esports,
  Icons.attach_money,
];

const IconData kFallbackCategoryIcon = Icons.category;

/// Resolves a stored codepoint to a palette icon, falling back to
/// [kFallbackCategoryIcon] for anything unrecognised.
IconData categoryIconForCode(int codePoint) {
  for (final icon in kCategoryIcons) {
    if (icon.codePoint == codePoint) return icon;
  }
  return kFallbackCategoryIcon;
}
