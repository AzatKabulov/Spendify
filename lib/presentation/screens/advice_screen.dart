import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/insets.dart';
import '../../domain/entities/advice_item.dart';
import '../providers/advice_providers.dart';
import '../widgets/advice/advice_widgets.dart';
import '../widgets/auth/auth_illustrations.dart';
import '../widgets/form_header.dart';
import '../widgets/home/home_sections.dart';
import '../widgets/pill_tabs.dart';
import 'advice_chat_screen.dart';
import 'advice_detail_screen.dart';

/// "Insights" — AI-generated budgeting guidance from the user's own aggregated
/// spending (Phase 9, restyled for the redesign). The disclaimer that this is
/// not financial advice travels *with* the advice, never buried in settings
/// (Phase 9 brief / CLAUDE.md §7). Offline shows the last cached advice with
/// its timestamp — never an error screen, never an endless spinner.
class AdviceScreen extends ConsumerStatefulWidget {
  const AdviceScreen({super.key});

  @override
  ConsumerState<AdviceScreen> createState() => _AdviceScreenState();
}

class _AdviceScreenState extends ConsumerState<AdviceScreen> {
  AdviceItemType? _tab; // null = "For You" (everything)

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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const FormHeader(
              title: 'Insights',
              subtitle: 'Your personal AI financial advisor',
            ),
            Expanded(
              child: switch (view.phase) {
                AdvicePhase.loading => const AdviceStateView(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Looking at your spending…',
                ),
                AdvicePhase.notConfigured => const AdviceStateView(
                  icon: Icons.cloud_off_outlined,
                  title: 'AI insights are off',
                  body:
                      'Turn on AI features in Settings → AI Settings to get '
                      'advice from your spending. The rest of Spendify works '
                      'without it.',
                ),
                AdvicePhase.notEnoughData => AdviceStateView(
                  icon: Icons.eco_outlined,
                  title: 'Keep logging for a few more days',
                  body:
                      "We'll have something useful to say once there's more "
                      'to look at — ${view.transactionCount} of '
                      '$kAdviceMinTransactions transactions so far.',
                ),
                AdvicePhase.emptyOffline => AdviceStateView(
                  icon: Icons.wifi_off_outlined,
                  title: "You're offline",
                  body:
                      'Connect to the internet to get your first insights. '
                      'Everything else in Spendify works offline.',
                  onRetry: _refresh,
                ),
                AdvicePhase.emptyError => AdviceStateView(
                  icon: Icons.error_outline,
                  title: "Couldn't generate advice",
                  body: view.errorMessage ?? 'Try again in a little while.',
                  onRetry: _refresh,
                ),
                AdvicePhase.ready => RefreshIndicator(
                  onRefresh: _refresh,
                  child: _InsightsBody(
                    view: view,
                    tab: _tab,
                    onTabChanged: (t) => setState(() => _tab = t),
                  ),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsBody extends StatelessWidget {
  const _InsightsBody({
    required this.view,
    required this.tab,
    required this.onTabChanged,
  });

  final AdviceView view;
  final AdviceItemType? tab;
  final ValueChanged<AdviceItemType?> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filtered = tab == null
        ? view.items
        : view.items.where((i) => i.type == tab).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.lg),
      children: <Widget>[
        HomeCard(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              scheme.primaryContainer.withValues(alpha: 0.85),
              Colors.white,
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SizedBox(
                width: 64,
                height: 82,
                child: FittedBox(child: AssistantMascot()),
              ),
              const SizedBox(width: Insets.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Smarter choices,\na brighter tomorrow.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      'Personalised tips and recommendations based on your '
                      'own spending habits.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md - 2),
        const AdviceDisclaimer(),
        const SizedBox(height: Insets.md),
        const Align(alignment: Alignment.centerRight, child: GeminiMark()),
        const SizedBox(height: Insets.sm),
        PillTabs<AdviceItemType?>(
          values: const <AdviceItemType?>[
            null,
            AdviceItemType.spending,
            AdviceItemType.saving,
            AdviceItemType.budgeting,
          ],
          labelOf: (t) => t?.label ?? 'For You',
          selected: tab,
          onChanged: onTabChanged,
          scrollable: true,
        ),
        const SizedBox(height: Insets.md),
        Text(
          'Key Insights',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: Insets.sm),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.md),
            child: Text(
              tab == null
                  ? 'No suggestions yet — pull down to refresh.'
                  : "Nothing under ${tab!.label} right now — check For You.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final item in filtered) ...<Widget>[
            InsightCard(
              item: item,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AdviceDetailScreen(item: item),
                ),
              ),
            ),
            const SizedBox(height: Insets.sm),
          ],
        if (view.banner != null) ...<Widget>[
          const SizedBox(height: Insets.xs),
          _Banner(text: view.banner!),
        ],
        if (view.generatedAt != null) ...<Widget>[
          const SizedBox(height: Insets.sm),
          Text(
            'Generated ${DateFormat('d MMM, HH:mm').format(view.generatedAt!.toLocal())}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: Insets.md),
        _AskCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AdviceChatScreen()),
          ),
        ),
      ],
    );
  }
}

class _AskCard extends StatelessWidget {
  const _AskCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return HomeCard(
      onTap: onTap,
      gradient: LinearGradient(
        colors: <Color>[scheme.primary, scheme.onPrimaryContainer],
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.chat_bubble_outline, color: Colors.white),
          const SizedBox(width: Insets.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Ask Spendify AI',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Get personalised advice about your finances',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward, color: Colors.white),
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
      padding: const EdgeInsets.all(Insets.sm + 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: Insets.sm),
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
