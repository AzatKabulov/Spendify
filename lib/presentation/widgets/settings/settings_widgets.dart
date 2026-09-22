import 'package:flutter/material.dart';

import '../../../core/theme/insets.dart';
import '../home/home_sections.dart';

/// Building blocks shared by Settings and its sub-pages (Account,
/// Notifications, Appearance, AI Settings, Data & Storage, Privacy, Your
/// Rights). Presentational only.

/// One navigational row inside a [SettingsGroup] — icon, title, optional
/// subtitle, and either a chevron (tap to open something) or a custom
/// [trailing] widget (a switch, a spinner).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.danger = false,
    this.enabled = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = danger ? scheme.error : scheme.onSurface;
    final iconBg = danger
        ? scheme.errorContainer.withValues(alpha: 0.5)
        : scheme.surfaceContainerHigh;
    final opacity = enabled ? 1.0 : 0.5;

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.xs,
            vertical: Insets.sm + 2,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 19, color: tint),
              ),
              const SizedBox(width: Insets.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: danger ? scheme.error : null,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              trailing ??
                  (onTap != null
                      ? Icon(
                          Icons.chevron_right,
                          color: scheme.onSurfaceVariant,
                        )
                      : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

/// A [HomeCard] holding a column of [SettingsRow]s with dividers between
/// them, and an optional group label above it.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.rows, this.label, super.key});

  final List<Widget> rows;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(left: Insets.xs, bottom: Insets.xs),
            child: Text(
              label!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        HomeCard(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.sm,
            vertical: Insets.xs,
          ),
          child: Column(
            children: <Widget>[
              for (var i = 0; i < rows.length; i++) ...<Widget>[
                rows[i],
                if (i != rows.length - 1)
                  Divider(height: 1, color: scheme.outlineVariant),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A plain informational card for a fact rather than an action — "no fake
/// toggle" screens (Notifications, Appearance) use this instead of pretending
/// a control does something.
class SettingsInfoCard extends StatelessWidget {
  const SettingsInfoCard({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return HomeCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: scheme.onSurfaceVariant),
          const SizedBox(width: Insets.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
