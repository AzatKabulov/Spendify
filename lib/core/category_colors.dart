import 'package:flutter/material.dart';

/// Fixed palette of category colours. `Category.colorValue` stores one of these
/// as an ARGB `int` (CLAUDE.md §4). The create/edit form is a swatch picker
/// over this list — no colour wheel.
const List<int> kCategoryColors = <int>[
  0xFFEF6C00, // orange
  0xFFF9A825, // amber
  0xFFC62828, // red
  0xFFAD1457, // pink
  0xFF6A1B9A, // purple
  0xFF4527A0, // deep purple
  0xFF1565C0, // blue
  0xFF00838F, // cyan
  0xFF00695C, // teal
  0xFF2E7D32, // green
  0xFF9E9D24, // lime
  0xFF546E7A, // blue grey
];

/// Wrap a stored `colorValue` as a [Color]. Falls back to the last swatch for
/// an unrecognised value so a row never renders transparent.
Color categoryColorForValue(int colorValue) => Color(colorValue);

const int kFallbackCategoryColor = 0xFF546E7A;
