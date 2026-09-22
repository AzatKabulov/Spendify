import 'package:flutter/material.dart';

import '../../core/theme/insets.dart';

/// The rounded segmented control used across the redesigned screens
/// (Reports tabs, Rewards filters, period pickers).
///
/// Labels are capped at 1.2x text scale: the control is a row of equal
/// segments, so beyond that the words stop fitting whatever the layout does.
/// Everything the segments *lead to* still scales fully.
class PillTabs<T> extends StatelessWidget {
  const PillTabs({
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    this.scrollable = false,
    super.key,
  });

  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Lay the segments out in a horizontal scroller instead of splitting the
  /// width evenly — for four or more segments with longer labels.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget segment(T value, {required bool expand}) {
      final isSelected = value == selected;
      final child = InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: AppMotion.quick,
          padding: EdgeInsets.symmetric(
            vertical: Insets.sm + 2,
            horizontal: expand ? Insets.sm : Insets.md,
          ),
          decoration: BoxDecoration(
            color: isSelected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            labelOf(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      return expand ? Expanded(child: child) : child;
    }

    final row = scrollable
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final v in values) ...<Widget>[
                  segment(v, expand: false),
                  if (v != values.last) const SizedBox(width: 2),
                ],
              ],
            ),
          )
        : Row(
            children: <Widget>[
              for (final v in values) segment(v, expand: true),
            ],
          );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: row,
      ),
    );
  }
}

/// Small outlined chips used for the achievements category filter.
class FilterChips<T> extends StatelessWidget {
  const FilterChips({
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final v in values) ...<Widget>[
            InkWell(
              onTap: () => onChanged(v),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: Insets.sm,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: v == selected
                      ? scheme.primaryContainer.withValues(alpha: 0.6)
                      : null,
                  border: Border.all(
                    color: v == selected
                        ? scheme.primary
                        : scheme.outlineVariant,
                    width: v == selected ? 2 : 1,
                  ),
                ),
                child: Text(
                  labelOf(v),
                  style: TextStyle(
                    color: v == selected ? scheme.primary : scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (v != values.last) const SizedBox(width: Insets.sm),
          ],
        ],
      ),
    );
  }
}
