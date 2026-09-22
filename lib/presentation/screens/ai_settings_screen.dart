import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/insets.dart';
import '../../domain/entities/ai_consent.dart';
import '../providers/ai_providers.dart';
import '../providers/repository_providers.dart';
import '../widgets/form_header.dart';
import '../widgets/settings/settings_widgets.dart';
import 'data_sent_screen.dart';

/// AI Settings (mockup: "Spendify AI and data preferences") — the on/off
/// toggle and the transparency views that were flat in the old Settings list,
/// now grouped under one roof to match the new Settings hub's IA.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  bool _clearing = false;

  Future<void> _setAi(bool on) async {
    final notifier = ref.read(aiConsentProvider.notifier);
    if (on) {
      await notifier.grant();
    } else {
      await notifier.revoke();
    }
  }

  Future<void> _clearAdvice() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cached advice?'),
        content: const Text(
          'The last set of AI suggestions is removed. New advice is '
          'generated next time you open Insights.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _clearing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adviceRecordRepositoryProvider).clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Cached advice cleared')),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final aiKeyPresent = ref.watch(aiKeyPresentProvider);
    final aiOn = ref.watch(aiConsentProvider) == AiConsent.granted;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const FormHeader(
              title: 'AI Settings',
              subtitle: 'Spendify AI and data preferences',
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
                  SettingsGroup(
                    rows: <Widget>[
                      if (aiKeyPresent)
                        SettingsRow(
                          icon: Icons.auto_awesome_outlined,
                          title: 'AI features',
                          subtitle: aiOn
                              ? 'Receipt scanning and spending advice are on. '
                                    'They send data to Google Gemini.'
                              : 'Off. Receipt scanning and advice are hidden; '
                                    'nothing is sent to Google Gemini.',
                          trailing: Switch(value: aiOn, onChanged: _setAi),
                        )
                      else
                        const SettingsRow(
                          icon: Icons.auto_awesome_outlined,
                          title: 'AI features',
                          subtitle:
                              'Not available in this build (no Gemini API '
                              'key). Everything else works.',
                          enabled: false,
                        ),
                    ],
                  ),
                  const SizedBox(height: Insets.md - 2),
                  SettingsGroup(
                    rows: <Widget>[
                      SettingsRow(
                        icon: Icons.visibility_outlined,
                        title: "What's sent to Gemini",
                        subtitle: 'See the exact data, built from your account',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const DataSentScreen(),
                          ),
                        ),
                      ),
                      SettingsRow(
                        icon: Icons.psychology_alt_outlined,
                        title: 'Clear cached advice',
                        enabled: !_clearing,
                        onTap: _clearAdvice,
                        trailing: _clearing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
                    child: Text(
                      'Turning AI off does not delete anything already '
                      'generated — it only stops new requests.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
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
