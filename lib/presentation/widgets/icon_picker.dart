import 'package:flutter/material.dart';

import '../../core/category_icons.dart';

/// A wrap of the fixed [kCategoryIcons] set. No icon browser (Phase 3 spec).
class IconPicker extends StatelessWidget {
  const IconPicker({
    required this.selectedCode,
    required this.onSelected,
    super.key,
  });

  final int selectedCode;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final icon in kCategoryIcons)
          _Cell(
            selected: icon.codePoint == selectedCode,
            onTap: () => onSelected(icon.codePoint),
            child: Icon(
              icon,
              color: icon.codePoint == selectedCode
                  ? scheme.onPrimary
                  : scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      ),
    );
  }
}
