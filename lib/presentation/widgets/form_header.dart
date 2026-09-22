import 'package:flutter/material.dart';

import '../../core/theme/insets.dart';

/// A circular icon button for [FormHeader]'s leading/trailing slot.
class FormHeaderButton {
  const FormHeaderButton._({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.danger = false,
  });

  /// Pops the current route (back navigation).
  factory FormHeaderButton.back({VoidCallback? onPressed}) =>
      FormHeaderButton._(
        icon: Icons.arrow_back,
        tooltip: 'Back',
        onPressed: onPressed,
      );

  /// Dismisses a modal add-flow.
  factory FormHeaderButton.close({VoidCallback? onPressed}) =>
      FormHeaderButton._(
        icon: Icons.close,
        tooltip: 'Close',
        onPressed: onPressed,
      );

  /// A destructive action (delete), tinted with the error colour.
  factory FormHeaderButton.delete({required VoidCallback onPressed}) =>
      FormHeaderButton._(
        icon: Icons.delete_outline,
        tooltip: 'Delete',
        onPressed: onPressed,
        danger: true,
      );

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool danger;
}

/// Shared header for the create/edit form screens (transaction, category,
/// budget, receipt scan): a circular leading button, a bold title with a
/// muted subtitle, and an optional trailing action — matched to the
/// approved mockups in place of a plain `AppBar`.
class FormHeader extends StatelessWidget {
  const FormHeader({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final FormHeaderButton? leading;
  final FormHeaderButton? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget circle(FormHeaderButton b) {
      final color = b.danger ? scheme.error : scheme.onSurface;
      final bg = b.danger
          ? scheme.errorContainer.withValues(alpha: 0.6)
          : scheme.surfaceContainerHigh;
      return Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: b.onPressed ?? () => Navigator.of(context).maybePop(),
          child: SizedBox(
            width: Insets.minTapTarget,
            height: Insets.minTapTarget,
            child: Icon(b.icon, color: color, size: 20),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.sm,
        Insets.md,
        Insets.sm,
      ),
      child: Row(
        children: <Widget>[
          circle(leading ?? FormHeaderButton.back()),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Insets.md),
          if (trailing != null)
            circle(trailing!)
          else
            const SizedBox(width: Insets.minTapTarget),
        ],
      ),
    );
  }
}

/// A small red error line, matched to a `TextFormField`'s own error style —
/// for a picker-style field (category chips, colour swatches) that isn't
/// itself a `FormField` and so has no built-in error slot.
class FormFieldError extends StatelessWidget {
  const FormFieldError({required this.errorText, super.key});

  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final text = errorText;
    if (text == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.xs, left: Insets.sm),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: scheme.error),
      ),
    );
  }
}
