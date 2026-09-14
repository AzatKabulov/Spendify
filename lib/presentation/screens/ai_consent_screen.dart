import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ai_providers.dart';
import 'data_sent_screen.dart';
import 'privacy_notice_screen.dart';

/// First-run consent for the two AI features (CLAUDE.md §7 ethics 4). Shown by
/// `AuthGate` once, before any AI feature can be used, whenever a Gemini key is
/// present and the user has not decided.
///
/// The disclosure is **specific** (the report explicitly rejects a generic
/// privacy blob): it names Google Gemini, states exactly what leaves the device
/// for each feature, and what never does. Accept and Decline are equally
/// prominent — declining keeps the whole app usable.
class AiConsentScreen extends ConsumerWidget {
  const AiConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                children: <Widget>[
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Two optional AI features',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Spendify can use Google Gemini for two things. Both are '
                    'optional — everything else in Spendify works without them, '
                    'offline.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  const _Feature(
                    icon: Icons.document_scanner_outlined,
                    title: 'Receipt scanning',
                    sends:
                        'The photo you take of a receipt, compressed. '
                        'Nothing else.',
                    when: 'Only when you tap “Scan receipt” and take a photo.',
                  ),
                  const SizedBox(height: 16),
                  const _Feature(
                    icon: Icons.insights_outlined,
                    title: 'Spending advice',
                    sends:
                        'A rounded, aggregated summary of your spending — '
                        'category totals, trends and budget limits.',
                    when:
                        'Only when you open “Insights” and your data has '
                        'changed since last time.',
                  ),

                  const SizedBox(height: 24),
                  _NeverSent(theme: theme),

                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DataSentScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('See exactly what is sent'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PrivacyNoticeScreen(),
                      ),
                    ),
                    child: const Text('Read the full privacy notice'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can change this any time in Settings → Privacy & AI.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _Actions(
              onDecline: () => ref.read(aiConsentProvider.notifier).revoke(),
              onAccept: () => ref.read(aiConsentProvider.notifier).grant(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.sends,
    required this.when,
  });

  final IconData icon;
  final String title;
  final String sends;
  final String when;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text('Sends: $sends', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text('When: $when', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeverSent extends StatelessWidget {
  const _NeverSent({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Never sent', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            '• Individual transactions or their amounts\n'
            '• Shop or merchant names\n'
            '• Notes you write on a transaction\n'
            '• Your name, email address or account ID',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onDecline, required this.onAccept});

  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton(
              onPressed: onDecline,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No thanks'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: onAccept,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Turn on AI'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
