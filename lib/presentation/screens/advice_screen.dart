import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/advice_item.dart';
import '../providers/advice_providers.dart';

/// "Insights" — AI-generated budgeting guidance from the user's own aggregated
/// spending (Phase 9). The disclaimer that this is not financial advice is
/// shown *with* the advice, never buried in settings (Phase 9 brief / CLAUDE.md
/// §7). Offline shows the last cached advice with its timestamp — never an
/// error screen, never an endless spinner.
class AdviceScreen extends ConsumerStatefulWidget {
  const AdviceScreen({super.key});

  @override
  ConsumerState<AdviceScreen> createState() => _AdviceScreenState();
}

class _AdviceScreenState extends ConsumerState<AdviceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(adviceControllerProvider.notifier).load(),
    );
  }

  Future<void> _refresh() =>
      ref.read(adviceControllerProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(adviceControllerProvider);
    final canRefresh = view.phase == AdvicePhase.ready && !view.busy;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: canRefresh ? _refresh : null,
          ),
        ],
        bottom: view.busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: switch (view.phase) {
        AdvicePhase.loading => const _Centered(
          icon: Icons.auto_awesome_outlined,
          title: 'Looking at your spending…',
        ),
        AdvicePhase.notConfigured => const _Centered(
          icon: Icons.cloud_off_outlined,
          title: 'Insights aren’t set up in this build',
          body:
              'AI advice needs a Gemini API key. The rest of Spendly works '
              'without it.',
        ),
        AdvicePhase.notEnoughData => _Centered(
          icon: Icons.eco_outlined,
          title: 'Keep logging for a few more days',
          body:
              'We’ll have something useful to say once there’s more '
              'to look at — ${view.transactionCount} of '
              '$kAdviceMinTransactions transactions so far.',
        ),
        AdvicePhase.emptyOffline => _Centered(
          icon: Icons.wifi_off_outlined,
          title: 'You’re offline',
          body:
              'Connect to the internet to get your first insights. Everything '
              'else in Spendly works offline.',
          onRetry: _refresh,
        ),
        AdvicePhase.emptyError => _Centered(
          icon: Icons.error_outline,
          title: 'Couldn’t generate advice',
          body: view.errorMessage ?? 'Try again in a little while.',
          onRetry: _refresh,
        ),
        AdvicePhase.ready => RefreshIndicator(
          onRefresh: _refresh,
          child: _AdviceList(view: view),
        ),
      },
    );
  }
}

class _AdviceList extends StatelessWidget {
  const _AdviceList({required this.view});

  final AdviceView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        const _Disclaimer(),
        const SizedBox(height: 12),
        if (view.banner != null) ...<Widget>[
          _Banner(text: view.banner!),
          const SizedBox(height: 12),
        ],
        if (view.generatedAt != null)
          Text(
            'Last updated ${_relativeTime(view.generatedAt!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 12),
        if (view.items.isEmpty)
          Text(
            'No suggestions yet — pull down to refresh.',
            style: theme.textTheme.bodyMedium,
          )
        else
          for (final item in view.items) ...<Widget>[
            _AdviceCard(item: item),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.item});

  final AdviceItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTitle = item.title.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (hasTitle) ...<Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item.title, style: theme.textTheme.titleSmall),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(item.body, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Always shown with the advice (Phase 9 brief: not hidden in settings).
class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI-generated guidance based on your spending. Not financial '
              'advice.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.icon,
    required this.title,
    this.body,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (body != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _relativeTime(DateTime at) {
  final now = DateTime.now();
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) {
    return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  }
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return DateFormat('d MMM yyyy').format(at.toLocal());
}
