import 'package:flutter/material.dart';

import '../../core/theme/insets.dart';
import '../widgets/form_header.dart';
import '../widgets/home/home_sections.dart';
import '../widgets/settings/settings_widgets.dart';
import 'ai_settings_screen.dart';
import 'data_storage_screen.dart';

/// Your Rights (mockup sub-screen). Every row maps to something the app
/// actually does — see the class-level notes on each divergence from the
/// mockup's exact wording.
class YourRightsScreen extends StatelessWidget {
  const YourRightsScreen({super.key});

  void _push(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _explainCorrections(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request a correction'),
        content: const Text(
          "There's no separate request to file — every transaction, "
          "category and budget is editable in place. Open it, change what's "
          "wrong, and it saves immediately. That's the correction.",
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const FormHeader(
              title: 'Your Rights',
              subtitle: "You're always in control",
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  0,
                  Insets.md,
                  Insets.lg,
                ),
                children: <Widget>[
                  HomeCard(
                    gradient: LinearGradient(
                      colors: <Color>[
                        scheme.primaryContainer.withValues(alpha: 0.8),
                        Colors.white,
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: scheme.primary,
                          child: const Icon(
                            Icons.person_outline,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: Insets.sm + 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Your data, your choice',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: Insets.xs),
                              Text(
                                'You can access, correct, export or delete '
                                'your data at any time — every control below '
                                'is a real, working action, not a promise.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  SettingsGroup(
                    rows: <Widget>[
                      SettingsRow(
                        icon: Icons.download_outlined,
                        title: 'Export your data',
                        subtitle:
                            'Download a copy of your transactions, '
                            'budgets and more',
                        onTap: () => _push(context, const DataStorageScreen()),
                      ),
                      SettingsRow(
                        icon: Icons.edit_outlined,
                        title: 'Request a correction',
                        subtitle:
                            "Edit any transaction, category or budget — it "
                            'saves immediately',
                        onTap: () => _explainCorrections(context),
                      ),
                      SettingsRow(
                        icon: Icons.delete_forever_outlined,
                        title: 'Delete all local data',
                        subtitle:
                            'Erases this device. Your cloud backup is kept '
                            'until you delete your account.',
                        danger: true,
                        onTap: () => _push(context, const DataStorageScreen()),
                      ),
                      SettingsRow(
                        icon: Icons.visibility_off_outlined,
                        title: 'Manage AI features',
                        subtitle:
                            'Control how your data is used for AI insights',
                        onTap: () => _push(context, const AiSettingsScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  Text(
                    'Key Points',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  const SettingsGroup(
                    rows: <Widget>[
                      SettingsRow(
                        icon: Icons.lock_outline,
                        title: 'You own your data',
                        subtitle: 'We do not sell your personal data.',
                      ),
                      SettingsRow(
                        icon: Icons.public_outlined,
                        title: 'Firebase and Gemini are Google Cloud services',
                        subtitle:
                            'Signing in and AI features (when you turn them '
                            'on) may process data outside Malaysia as a '
                            'result — this is a consequence of using those '
                            'named services, not a separate choice.',
                      ),
                      SettingsRow(
                        icon: Icons.gavel_outlined,
                        title: 'We follow applicable law',
                        subtitle:
                            "Aligned with Malaysia's Personal Data "
                            'Protection Act 2010.',
                      ),
                      SettingsRow(
                        icon: Icons.shield_outlined,
                        title: 'Industry-standard security',
                        subtitle:
                            'Local data is AES-encrypted with the key in '
                            "Android's hardware-backed keystore; every "
                            'network call is HTTPS.',
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md - 2),
                  const SettingsInfoCard(
                    icon: Icons.help_outline,
                    title: 'Have more questions?',
                    body:
                        'This is a university capstone project. For any data '
                        'request, contact the developer at the address in '
                        'the project submission.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
