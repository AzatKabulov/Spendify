import 'package:flutter/material.dart';

/// The fixed palette of badge icons.
///
/// `Badge.iconCode` is stored as an `int` codepoint so the domain catalogue
/// (`domain/entities/badge_catalogue.dart`) stays free of Flutter imports.
/// Flutter's release build tree-shakes icon fonts and refuses non-const
/// `IconData`, so every icon a badge can render must appear here as a **const**
/// `IconData`. [badgeIconForCode] maps a stored codepoint back to one of these.
const List<IconData> kBadgeIcons = <IconData>[
  Icons.flag, // first_transaction
  Icons.receipt_long, // transactions_10
  Icons.menu_book, // transactions_50
  Icons.auto_stories, // transactions_100
  Icons.savings, // first_budget
  Icons.verified, // budget_kept
  Icons.local_fire_department, // streak_3 / streak_7
  Icons.whatshot, // streak_30
  Icons.document_scanner, // first_scan
  Icons.donut_large, // all_categories
  Icons.star, // level_5
  Icons.military_tech, // level_10
  Icons.emoji_events, // fallback
];

const IconData kFallbackBadgeIcon = Icons.emoji_events;

/// Resolves a stored codepoint to a palette icon, falling back to
/// [kFallbackBadgeIcon] for anything unrecognised.
IconData badgeIconForCode(int codePoint) {
  for (final icon in kBadgeIcons) {
    if (icon.codePoint == codePoint) return icon;
  }
  return kFallbackBadgeIcon;
}
