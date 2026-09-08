import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/enums.dart';
import '../providers/category_providers.dart';
import '../providers/report_providers.dart';
import '../widgets/category_pie.dart';
import '../widgets/report_breakdown_list.dart';
import '../widgets/report_summary_header.dart';
import '../widgets/spend_over_time_chart.dart';

/// Weekly / monthly / yearly visual reports, backed entirely by the cached
/// `PeriodAggregate`s (CLAUDE.md §6).
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(reportSelectionProvider);
    final controller = ref.read(reportSelectionProvider.notifier);
    final data = ref.watch(reportDataProvider);
    final bars = ref.watch(spendOverTimeProvider);
    final categoriesById = ref.watch(allCategoriesByIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<PeriodType>(
              segments: const <ButtonSegment<PeriodType>>[
                ButtonSegment(value: PeriodType.weekly, label: Text('Weekly')),
                ButtonSegment(
                  value: PeriodType.monthly,
                  label: Text('Monthly'),
                ),
                ButtonSegment(value: PeriodType.yearly, label: Text('Yearly')),
              ],
              selected: <PeriodType>{selection.type},
              onSelectionChanged: (s) => controller.setType(s.first),
            ),
          ),
          _PeriodNav(
            label: _periodLabel(selection),
            onPrevious: controller.previous,
            onNext: controller.canGoNext ? controller.next : null,
          ),
          if (data.isEmpty)
            const _EmptyPeriod()
          else ...<Widget>[
            ReportSummaryHeader(
              incomeMinor: data.incomeMinor,
              expenseMinor: data.expenseMinor,
            ),
            if (data.expenseMinor > 0) ...<Widget>[
              const _SectionLabel('Where it went'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CategoryPie(
                  slices: data.byCategory,
                  categoriesById: categoriesById,
                ),
              ),
            ],
            const _SectionLabel('Spending over time'),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
              child: SpendOverTimeChart(bars: bars),
            ),
            if (data.byCategory.isNotEmpty) ...<Widget>[
              const _SectionLabel('By category'),
              ReportBreakdownList(
                slices: data.byCategory,
                categoriesById: categoriesById,
              ),
            ] else
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Only income this period — no expenses to break down.',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _periodLabel(ReportSelection s) {
    switch (s.type) {
      case PeriodType.monthly:
        return DateFormat('MMMM yyyy').format(s.bounds.start);
      case PeriodType.yearly:
        return s.periodKey;
      case PeriodType.weekly:
        final b = s.bounds;
        final last = b.end.subtract(const Duration(days: 1));
        final fmt = DateFormat('d MMM');
        return '${fmt.format(b.start)} – ${fmt.format(last)} · ${s.periodKey}';
    }
  }
}

class _PeriodNav extends StatelessWidget {
  const _PeriodNav({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous period',
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next period',
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _EmptyPeriod extends StatelessWidget {
  const _EmptyPeriod();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.insights_outlined,
            size: 56,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions this period',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Use the arrows above to look at another week, month or year.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
