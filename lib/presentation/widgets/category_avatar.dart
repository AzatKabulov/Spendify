import 'package:flutter/material.dart';

import '../../core/category_icons.dart';
import '../../domain/entities/category.dart';

/// A round category badge: the category colour tinted behind its icon.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({required this.category, this.radius = 20, super.key});

  final Category? category;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = category == null
        ? Theme.of(context).colorScheme.outline
        : Color(category!.colorValue);
    final icon = category == null
        ? kFallbackCategoryIcon
        : categoryIconForCode(category!.iconCode);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color, size: radius * 1.1),
    );
  }
}
