import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/insets.dart';
import '../providers/advice_providers.dart';
import '../widgets/advice/advice_widgets.dart';
import '../widgets/form_header.dart';
import '../widgets/home/home_sections.dart';
import '../widgets/settings/settings_widgets.dart';
import 'privacy_notice_screen.dart';

/// "What's Sent to Gemini" — the unusually-transparent view the report's
/// data-minimisation claim points at (§3.5.3 / CLAUDE.md §7.3).
///
/// **Correction from the mockup, flagged.** The mockup's "Transaction data"
/// detail screen listed merchant name, transaction note and exact date as
/// sent to Gemini. That is false for this app: `buildAdviceSummary` (see
/// `domain/services/advice_summary_builder.dart`) sends only category
/// *totals* rounded to whole ringgit, a period label ("September 2026", not
/// a date), and counts — never a merchant, a note, or an individual amount.
/// Copying the mockup's claim verbatim would have made this "transparency"
/// screen state something untrue, which is the opposite of what CLAUDE.md
/// §7.4 commits to ("consent must be specific... not a generic blob"). The
/// rows below describe the real payload instead.
class DataSentScreen extends ConsumerWidget {
  const DataSentScreen({super.key});

  void _push(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const FormHeader(
              title: "What's Sent to Gemini",
              subtitle: "Transparency. You're always in control.",
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const GeminiMark(),
                        const SizedBox(height: Insets.sm),
                        Text(
                          'Your data. Your control.',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: Insets.xs),
                        Text(
                          'Spendify uses Google Gemini, only when you turn it '
                          'on, for two things: reading a receipt photo, and '
                          'generating spending advice. Here is exactly what '
                          'goes with each.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  Text(
                    'What we send to Gemini',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  SettingsGroup(
                    rows: <Widget>[
                      SettingsRow(
                        icon: Icons.receipt_long_outlined,
                        title: 'Receipt photo',
                        subtitle: 'Only when you tap Scan',
                        onTap: () => _push(context, const _ReceiptDetail()),
                      ),
                      SettingsRow(
                        icon: Icons.pie_chart_outline,
                        title: 'Spending summary',
                        subtitle: 'Category totals and trends — for advice',
                        onTap: () => _push(context, const _SummaryDetail()),
                      ),
                      SettingsRow(
                        icon: Icons.description_outlined,
                        title: 'Your questions and messages',
                        subtitle: 'Only inside Ask Spendify AI',
                        onTap: () => _push(context, const _ChatDetail()),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md - 2),
                  const SettingsInfoCard(
                    icon: Icons.shield_outlined,
                    title: "We don't send unnecessary data",
                    body:
                        'We send only the information relevant to your '
                        'request — never your name, email, password, bank '
                        'details, or anything else not required for it.',
                  ),
                  const SizedBox(height: Insets.md - 2),
                  SettingsGroup(
                    rows: <Widget>[
                      SettingsRow(
                        icon: Icons.menu_book_outlined,
                        title: 'Learn more',
                        subtitle: 'The full privacy notice',
                        onTap: () =>
                            _push(context, const PrivacyNoticeScreen()),
                      ),
                    ],
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

class _ReceiptDetail extends StatelessWidget {
  const _ReceiptDetail();

  @override
  Widget build(BuildContext context) {
    return const _CategoryDetail(
      title: 'Receipt photo',
      subtitle: 'Details about what is sent and why',
      lead:
          'Used to read the amount, date and merchant off a receipt you '
          'choose to scan.',
      included: <String>[
        'The photo you take, compressed to a small JPEG (usually 200–500 KB)',
      ],
      excluded: <String>[
        'Any other transaction, budget or account data',
        'Your name, email or account ID',
        'Anything, unless you tap Scan',
      ],
      footer:
          'The image is deleted from your device as soon as it has been '
          'read — Spendify never keeps a copy (CLAUDE.md §7.5).',
    );
  }
}

class _ChatDetail extends StatelessWidget {
  const _ChatDetail();

  @override
  Widget build(BuildContext context) {
    return const _CategoryDetail(
      title: 'Your questions and messages',
      subtitle: 'Details about what is sent and why',
      lead:
          'Used to answer your question inside "Ask Spendify AI" with real '
          'context about your spending.',
      included: <String>[
        'The question you type',
        'The same spending summary described under "Spending summary"',
        "The last few messages of that conversation, so Gemini's answer "
            'stays on-topic',
      ],
      excluded: <String>[
        'Your name, email or account ID',
        'Anything from before you opened the chat',
        'Any other transaction data beyond the same summary',
      ],
      footer:
          'The conversation is never saved — it exists only while the chat '
          'screen is open, and is not written to this device or synced '
          'anywhere.',
    );
  }
}

class _SummaryDetail extends ConsumerWidget {
  const _SummaryDetail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summaryAsync = ref.watch(adviceSummaryPreviewProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const FormHeader(
              title: 'Spending summary',
              subtitle: 'Details about what is sent and why',
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
                  const SettingsInfoCard(
                    icon: Icons.pie_chart_outline,
                    title: 'Spending summary',
                    body:
                        'Used to generate personalised advice — category '
                        'totals, trends and budget adherence for the current '
                        'month, rounded so it cannot be traced back to an '
                        'individual purchase.',
                  ),
                  const SizedBox(height: Insets.md - 2),
                  const _IncludedExcluded(
                    included: <String>[
                      'Category names (e.g. "Food")',
                      'Category totals, rounded to the nearest ringgit',
                      "Each category's share of your spending, as a percent",
                      'Whether spending is trending up, down or flat vs last '
                          'period',
                      'Budget limits and whether they were kept, and by '
                          'roughly how much if not',
                      'How many days you logged something, and how many '
                          'transactions — as counts, not the transactions',
                      'Which month is being summarised (e.g. "September '
                          '2026") — never an exact date',
                    ],
                    excluded: <String>[
                      'Individual transactions or their exact amounts',
                      'Shop or merchant names',
                      'Notes you write on a transaction',
                      'Your name, email address or account ID',
                      'Your full history — only the current month',
                    ],
                  ),
                  const SizedBox(height: Insets.md - 2),
                  Text(
                    'This exact object, live',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    'Not a sample — this is the real payload, built fresh '
                    'from your account right now.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  summaryAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(Insets.lg),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text(
                      'Could not build the preview right now. Reopen this '
                      'screen to try again.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    data: (summary) => _PayloadBox(
                      json: const JsonEncoder.withIndent(
                        '  ',
                      ).convert(summary.toJson()),
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

/// Shared shape for the receipt/chat detail screens (the spending-summary one
/// also shows the live JSON preview, so it is its own widget above).
class _CategoryDetail extends StatelessWidget {
  const _CategoryDetail({
    required this.title,
    required this.subtitle,
    required this.lead,
    required this.included,
    required this.excluded,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final String lead;
  final List<String> included;
  final List<String> excluded;
  final String footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            FormHeader(title: title, subtitle: subtitle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  0,
                  Insets.md,
                  Insets.lg,
                ),
                children: <Widget>[
                  SettingsInfoCard(
                    icon: Icons.info_outline,
                    title: title,
                    body: lead,
                  ),
                  const SizedBox(height: Insets.md - 2),
                  _IncludedExcluded(included: included, excluded: excluded),
                  const SizedBox(height: Insets.md - 2),
                  SettingsInfoCard(
                    icon: Icons.delete_outline,
                    title: 'Not stored by Spendify',
                    body: footer,
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

class _IncludedExcluded extends StatelessWidget {
  const _IncludedExcluded({required this.included, required this.excluded});

  final List<String> included;
  final List<String> excluded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget list(String heading, List<String> items, IconData mark, Color tint) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            heading,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Insets.sm),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(mark, size: 18, color: tint),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(item, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          list(
            'Data included',
            included,
            Icons.check_circle_outline,
            scheme.income,
          ),
          const SizedBox(height: Insets.sm),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: Insets.sm),
          list(
            'Data not included',
            excluded,
            Icons.cancel_outlined,
            scheme.error,
          ),
        ],
      ),
    );
  }
}

class _PayloadBox extends StatelessWidget {
  const _PayloadBox({required this.json});

  final String json;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(Insets.sm + 4),
            child: SelectableText(
              json,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: json));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Copied')));
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy'),
            ),
          ),
        ],
      ),
    );
  }
}
