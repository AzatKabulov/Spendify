import 'package:flutter/material.dart';

import '../../core/theme/insets.dart';
import '../widgets/form_header.dart';
import '../widgets/home/home_sections.dart';
import '../widgets/settings/settings_widgets.dart';
import 'your_rights_screen.dart';

/// Plain-language privacy notice, aligned with Malaysia's Personal Data
/// Protection Act 2010 (Phase 10 / report §3.5.2), restyled to the redesign's
/// visual language for the mockup pass. Deliberately short and readable —
/// the point is that it is not boilerplate.
///
/// The content below is the same real information the plain Phase 10 version
/// stated (nothing here is new copy invented for the mockup) — only the
/// grouping changed, into the mockup's eight topics instead of the original
/// six, splitting "where it's stored" into a security topic and a sharing
/// topic to match.
class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  void _push(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _openTopic(BuildContext context, (String, String) section) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _PolicyDetailScreen(title: section.$1, body: section.$2),
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
              title: 'Privacy Notice',
              subtitle: 'Your privacy matters',
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
                            Icons.shield_outlined,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: Insets.sm + 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Your data. Your control.',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: Insets.xs),
                              Text(
                                'This notice explains what Spendify collects, '
                                'why, and your rights over it — in plain '
                                'language, not a generic blob.',
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
                      for (final section in _topics)
                        SettingsRow(
                          icon: section.icon,
                          title: section.title,
                          subtitle: section.subtitle,
                          onTap: () => _openTopic(context, (
                            section.title,
                            section.body,
                          )),
                        ),
                      SettingsRow(
                        icon: Icons.verified_user_outlined,
                        title: 'Your rights',
                        subtitle: 'Access, correct, export or delete anytime',
                        onTap: () => _push(context, const YourRightsScreen()),
                      ),
                      SettingsRow(
                        icon: Icons.mail_outline,
                        title: 'Contact us',
                        subtitle: 'Questions about privacy? Reach out.',
                        onTap: () => _openTopic(context, _contact),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md - 2),
                  const SettingsInfoCard(
                    icon: Icons.eco_outlined,
                    title: 'A more open financial future',
                    body:
                        'We believe in transparent, responsible, user-first '
                        'data practices.',
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

class _PolicyDetailScreen extends StatelessWidget {
  const _PolicyDetailScreen({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            FormHeader(title: title),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  0,
                  Insets.md,
                  Insets.lg,
                ),
                children: <Widget>[
                  Text(body, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const (String, String) _contact = (
  'Contact us',
  'This is a university capstone project. For any data request, contact '
      'the developer at the address in the project submission.',
);

/// The same real information the original Phase 10 notice stated, split to
/// match the mockup's topic list.
class _Topic {
  const _Topic(this.title, this.subtitle, this.body, this.icon);

  final String title;
  final String subtitle;
  final String body;
  final IconData icon;
}

final List<_Topic> _topics = <_Topic>[
  const _Topic(
    'What data we collect',
    'Information you provide, and what the app generates for you',
    'Your transactions (amount, type, category, date and any note you add), '
        'the categories and spending limits you create, your reward '
        'progress, and — if you sign in — your email address and a Firebase '
        'account ID. Receipt photos are used once and then deleted; they '
        'are never stored.',
    Icons.storage_outlined,
  ),
  const _Topic(
    'How we use your data',
    'To provide and improve the budgeting features you asked for',
    'To provide the budgeting features you asked for: recording spending, '
        'showing reports, warning you about limits, and (optionally) '
        'generating advice. There is no advertising and your data is not '
        'sold or shared for marketing.',
    Icons.settings_outlined,
  ),
  const _Topic(
    'Data sharing',
    'When and with whom we share data',
    "Your data is not shared with anyone except the infrastructure that "
        "runs the app: Firestore holds your backup under rules that let "
        'only your own account read or write it, and — only if you turn AI '
        'on — Google Gemini receives what AI Settings → "What\'s sent to '
        'Gemini" discloses. Nothing is sold, and nothing goes to '
        'advertisers.',
    Icons.people_outline,
  ),
  const _Topic(
    'Data security',
    'How we protect your information',
    'Local data is encrypted at rest (AES) with the key held in Android\'s '
        'hardware-backed Keystore. Every network call, to Firebase or to '
        'Gemini, is HTTPS.',
    Icons.shield_outlined,
  ),
  const _Topic(
    'AI and Google Gemini',
    'How your data is used for AI insights',
    'Only if you turn on AI features. Receipt scanning sends the receipt '
        'photo to Google Gemini to read the amount, date and merchant. '
        'Advice sends a rounded, aggregated summary of your spending '
        '(category totals, trends, budget limits). It never sends '
        'individual transactions, merchant names, notes, or your identity. '
        'You can turn AI features off at any time in Settings → AI '
        'Settings, and the rest of the app keeps working.',
    Icons.auto_awesome_outlined,
  ),
  const _Topic(
    'Data retention',
    'How long we keep your data',
    'Data stays until you delete it. "Delete all local data" in Settings → '
        'Data & Storage erases everything on the device immediately. Your '
        'Firebase backup is kept until you delete your account; contact us '
        'to have it removed.',
    Icons.delete_outline,
  ),
];
