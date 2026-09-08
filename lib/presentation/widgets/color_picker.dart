import 'package:flutter/material.dart';

import '../../core/category_colors.dart';

/// A wrap of the fixed [kCategoryColors] swatches. No colour wheel (Phase 3).
class ColorPicker extends StatelessWidget {
  const ColorPicker({
    required this.selectedValue,
    required this.onSelected,
    super.key,
  });

  final int selectedValue;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        for (final value in kCategoryColors)
          InkResponse(
            onTap: () => onSelected(value),
            radius: 26,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(value),
                shape: BoxShape.circle,
                border: Border.all(
                  color: value == selectedValue
                      ? scheme.onSurface
                      : Colors.transparent,
                  width: 3,
                ),
              ),
              child: value == selectedValue
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          ),
      ],
    );
  }
}
