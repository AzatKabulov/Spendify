import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/insets.dart';
import '../providers/ai_providers.dart';
import '../widgets/auth/auth_chrome.dart';
import '../widgets/auth/auth_illustrations.dart';
import '../widgets/tactile_press.dart';
import 'data_sent_screen.dart';
import 'privacy_notice_screen.dart';

/// First-run consent for the two AI features (CLAUDE.md §7 ethics 4). Shown by
/// `AuthGate` once, before any AI feature can be used, whenever a Gemini key is
/// present and the user has not decided.
///
/// The disclosure is **specific** (the report explicitly rejects a generic
/// privacy blob): it names Google Gemini, states exactly what leaves the device
/// for each feature, and what never does. "No thanks" and "Turn on AI" are
/// deliberately equal in size and weight — a mockup pass for this screen
/// suggested a big primary "Continue" against a tiny "Maybe later" link, which
/// is exactly the consent-nudging pattern this screen was built to avoid.
/// Visual language matches the auth screens ("The Instrument"): same brand
/// row, accent-card and footer-band atoms from `auth_chrome.dart`.
class AiConsentScreen extends ConsumerWidget {
  const AiConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  Insets.md,
                  Insets.md,
                  Insets.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const AuthBrandRow(
                      taglineBelow: true,
                      tagline: 'Smarter spending.\nBrighter tomorrows.',
                    ),
                    const SizedBox(height: Insets.lg),
                    AuthHero(
                      illustrationWidth: 150,
                      illustration: const ConsentIllustration(),
                      text: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Your personal\nAI finance assistant',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: Insets.sm),
                          Text(
                            'Spendify can use Google Gemini for two optional '
                            'things: reading receipts and generating '
                            'spending advice. Both are off unless you turn '
                            'them on.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.xl),
                    Container(
                      padding: const EdgeInsets.all(Insets.md),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _Capability(
                            icon: Icons.document_scanner_outlined,
                            title: 'Receipt scanning',
                            description:
                                'Take a photo of a receipt and Gemini reads '
                                'the amount, date and merchant — only when '
                                'you tap Scan, and you confirm every field '
                                'before it saves.',
                          ),
                          SizedBox(height: Insets.lg),
                          _Capability(
                            icon: Icons.insights_outlined,
                            title: 'Personalised advice',
                            description:
                                'Gemini looks at a rounded, aggregated '
                                'summary of your spending — category totals '
                                'and trends, never individual purchases — '
                                'and suggests specific ways to improve.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    _NeverSent(scheme: scheme, theme: theme),
                    const SizedBox(height: Insets.xl),
                    Text(
                      'Your privacy matters',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: Insets.md),
                    const _PrivacyRow(
                      icon: Icons.lock_outline,
                      title: 'Your data stays private',
                      description:
                          'Only the receipt photo or the aggregated summary '
                          'above is ever sent — never your name, email, '
                          'notes or raw transaction history.',
                    ),
                    const SizedBox(height: Insets.md),
                    const _PrivacyRow(
                      icon: Icons.shield_outlined,
                      title: "You're in control",
                      description:
                          'Choosing "No thanks" keeps the whole app working '
                          'normally. Change your mind anytime in Settings → '
                          'AI Settings.',
                    ),
                    const SizedBox(height: Insets.md),
                    _PrivacyRow(
                      icon: Icons.visibility_outlined,
                      title: 'See exactly what is sent',
                      description:
                          'Open the exact JSON payload Spendify would send '
                          '— nothing is hidden behind this screen.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DataSentScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PrivacyNoticeScreen(),
                          ),
                        ),
                        child: const Text('Read the full privacy notice'),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                    const AuthFooterBand(
                      tagline: 'A more confident you\nstarts with small steps.',
                    ),
                  ],
                ),
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

class _Capability extends StatelessWidget {
  const _Capability({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 22, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Insets.xs),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: scheme.onSurface, size: 24),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: onTap != null ? scheme.primary : null,
                ),
              ),
              const SizedBox(height: Insets.xs),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null)
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      ],
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xs),
        child: content,
      ),
    );
  }
}

class _NeverSent extends StatelessWidget {
  const _NeverSent({required this.theme, required this.scheme});

  final ThemeData theme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Never sent',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            '• Individual transactions or their amounts\n'
            '• Shop or merchant names\n'
            '• Notes you write on a transaction\n'
            '• Your name, email address or account ID',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.sm,
        Insets.md,
        Insets.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: onDecline,
                child: const Text('No thanks'),
              ),
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: TactilePress(
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: onAccept,
                  child: const Text('Turn on AI'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
