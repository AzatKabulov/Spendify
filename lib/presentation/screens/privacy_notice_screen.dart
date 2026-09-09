import 'package:flutter/material.dart';

/// Plain-language privacy notice, aligned with Malaysia's Personal Data
/// Protection Act 2010 (Phase 10 / report §3.5.2). Deliberately short and
/// readable — the point is that it is not boilerplate.
class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy notice')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: <Widget>[
          Text('Spendly privacy notice', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Last updated: September 2026',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          for (final section in _sections) ...<Widget>[
            Text(section.$1, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(section.$2, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

const List<(String, String)> _sections = <(String, String)>[
  (
    'What this app collects',
    'Your transactions (amount, type, category, date and any note you add), '
        'the categories and spending limits you create, your reward progress, '
        'and — if you sign in — your email address and a Firebase account ID. '
        'Receipt photos are used once and then deleted; they are never stored.',
  ),
  (
    'Why it is collected',
    'To provide the budgeting features you asked for: recording spending, '
        'showing reports, warning you about limits, and (optionally) generating '
        'advice. There is no advertising and your data is not sold or shared '
        'for marketing.',
  ),
  (
    'Where it is stored',
    'On your device, in an encrypted local database (AES, with the key held in '
        'Android’s hardware-backed keystore). If you sign in, a copy is backed '
        'up to Google Cloud Firestore under your account so you can restore it '
        'on a new device. Firestore rules allow only your account to read or '
        'write your data.',
  ),
  (
    'Third-party processing — Google Gemini',
    'Only if you turn on AI features. Receipt scanning sends the receipt photo '
        'to Google Gemini to read the amount, date and merchant. Advice sends a '
        'rounded, aggregated summary of your spending (category totals, trends, '
        'budget limits). It never sends individual transactions, merchant '
        'names, notes, or your identity. You can turn AI features off at any '
        'time in Settings, and the rest of the app keeps working.',
  ),
  (
    'Retention',
    'Data stays until you delete it. “Delete all local data” in Settings '
        'erases everything on the device immediately. Your Firebase backup is '
        'kept until you delete your account; contact us to have it removed.',
  ),
  (
    'Your rights (PDPA)',
    'You can access your data (“Export my data” produces a complete JSON '
        'file), correct it (edit any transaction, category or budget), delete '
        'it (“Delete all local data”, or ask us to remove your backup), and '
        'withdraw consent for AI processing at any time. These controls are all '
        'in Settings.',
  ),
  (
    'Contact',
    'This is a university capstone project. For any data request, contact the '
        'developer at the address in the project submission.',
  ),
];
