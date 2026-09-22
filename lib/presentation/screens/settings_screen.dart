import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/insets.dart';
import '../providers/auth_providers.dart';
import '../providers/gamification_providers.dart';
import '../widgets/home/home_sections.dart';
import '../widgets/settings/settings_widgets.dart';
import 'account_screen.dart';
import 'ai_settings_screen.dart';
import 'appearance_screen.dart';
import 'budgets_screen.dart';
import 'categories_screen.dart';
import 'data_storage_screen.dart';
import 'notifications_info_screen.dart';
import 'privacy_screen.dart';

/// Settings — the hub the redesign's mockup shows: a profile row up top, then
/// grouped rows opening the real sub-screens. Restructured from a single flat
/// list (Phase 10) into this hub + sub-pages for the mockup pass; see
/// CLAUDE.md §9 for what each mockup row was kept, corrected or dropped, and
/// why (a "Goals" row was dropped — there is no such feature; the rest moved
/// to `AccountScreen`, `NotificationsInfoScreen`, `AppearanceScreen`,
/// `AiSettingsScreen`, `DataStorageScreen`, `PrivacyScreen`).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _signingOut = false;

  void _push(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your data stays on this device. You can sign back in any time.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _signingOut = true);
    await ref.read(signOutProvider)();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final email = ref.watch(currentUserEmailProvider);
    final name = ref.watch(currentUserFirstNameProvider);
    final level = ref.watch(gamificationStateProvider).value?.level;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            Insets.sm,
            Insets.md,
            Insets.lg,
          ),
          children: <Widget>[
            Text(
              'Settings',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Manage your account and preferences',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.md),
            HomeCard(
              onTap: () => _push(const AccountScreen()),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: Insets.sm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          <String>[
                            ?email,
                            if (level != null) 'Level $level',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
            const SizedBox(height: Insets.md - 2),
            SettingsGroup(
              rows: <Widget>[
                SettingsRow(
                  icon: Icons.person_outline,
                  title: 'Account',
                  subtitle: 'Profile, security and connected accounts',
                  onTap: () => _push(const AccountScreen()),
                ),
                SettingsRow(
                  icon: Icons.category_outlined,
                  title: 'Categories',
                  subtitle: 'Manage your spending categories',
                  onTap: () => _push(const CategoriesScreen()),
                ),
                SettingsRow(
                  icon: Icons.pie_chart_outline,
                  title: 'Budgets',
                  subtitle: 'Manage budget settings and alerts',
                  onTap: () => _push(const BudgetsScreen()),
                ),
                SettingsRow(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Alerts and reminders',
                  onTap: () => _push(const NotificationsInfoScreen()),
                ),
                SettingsRow(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: 'Theme, language and display',
                  onTap: () => _push(const AppearanceScreen()),
                ),
                SettingsRow(
                  icon: Icons.auto_awesome_outlined,
                  title: 'AI Settings',
                  subtitle: 'Spendify AI and data preferences',
                  onTap: () => _push(const AiSettingsScreen()),
                ),
                SettingsRow(
                  icon: Icons.storage_outlined,
                  title: 'Data & Storage',
                  subtitle: 'Backup, restore, export',
                  onTap: () => _push(const DataStorageScreen()),
                ),
                SettingsRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy',
                  subtitle: 'Your data and privacy controls',
                  onTap: () => _push(const PrivacyScreen()),
                ),
              ],
            ),
            const SizedBox(height: Insets.md - 2),
            SettingsGroup(
              rows: <Widget>[
                SettingsRow(
                  icon: Icons.logout,
                  title: 'Sign out',
                  danger: true,
                  enabled: !_signingOut,
                  onTap: _signOut,
                  trailing: _signingOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
