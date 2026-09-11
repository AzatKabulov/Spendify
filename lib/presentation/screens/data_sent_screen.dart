import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/advice_providers.dart';

/// "See exactly what is sent" — the unusually-transparent view the report's
/// data-minimisation claim points at (§3.5.3). Shows the *real* advice payload
/// built from the user's current data, plus a plain statement of what the
/// receipt scanner sends and what neither feature ever sends.
class DataSentScreen extends ConsumerWidget {
  const DataSentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(adviceSummaryPreviewProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('What is sent to Gemini')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Text('Receipt scanning', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Just the photo you take, compressed to a small JPEG (usually '
            '200–500 KB). The image is deleted from your device as soon as it '
            'has been read. Nothing else goes with it — no transactions, no '
            'account details.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          Text('Spending advice', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'This exact summary — and nothing else. Amounts are rounded to '
            'whole ringgit and percentages to whole numbers, so it cannot be '
            'traced back to individual purchases:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          summaryAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text(
              'Could not build the preview right now. Reopen this screen to '
              'try again.',
              style: theme.textTheme.bodyMedium,
            ),
            data: (summary) {
              final pretty = const JsonEncoder.withIndent(
                '  ',
              ).convert(summary.toJson());
              return _PayloadBox(json: pretty);
            },
          ),
          const SizedBox(height: 24),

          Container(
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
                  '• Individual transactions or their exact amounts\n'
                  '• Shop or merchant names\n'
                  '• Notes on a transaction\n'
                  '• Your name, email address or account ID\n'
                  '• Your full history — only the current period is summarised',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
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
