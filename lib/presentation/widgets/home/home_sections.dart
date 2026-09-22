import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/insets.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/services/budget_evaluator.dart';
import '../../providers/report_providers.dart';
import '../auth/auth_illustrations.dart';
import '../category_avatar.dart';

/// Building blocks of the Home dashboard, laid out to the approved mockup.
/// Each one is presentational: it is handed resolved data and callbacks.

bool _large(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.35;

String _ringgit(int minor) =>
    'RM ${NumberFormat('#,##0').format((minor / 100).round())}';

/// White rounded surface with a whisper of shadow.
class HomeCard extends StatelessWidget {
  const HomeCard({
    required this.child,
    this.padding = const EdgeInsets.all(Insets.md),
    this.gradient,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(20);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? Colors.white : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (action != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.xs,
                vertical: Insets.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    action!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// --- Header ---------------------------------------------------------------

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.name,
    required this.now,
    required this.onProfile,
    required this.syncIndicator,
    super.key,
  });

  final String name;
  final DateTime now;
  final VoidCallback onProfile;
  final Widget syncIndicator;

  String get _greeting => now.hour < 12
      ? 'Good morning,'
      : (now.hour < 17 ? 'Good afternoon,' : 'Good evening,');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(_greeting, style: theme.textTheme.bodyLarge),
        Text(
          '$name 👋',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: Insets.xs),
        Text(
          DateFormat('EEE, d MMM yyyy').format(now),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            syncIndicator,
            const SizedBox(width: Insets.sm),
            Semantics(
              button: true,
              label: 'Profile and settings',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onProfile,
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const LeafMark(size: 22),
            const SizedBox(width: Insets.xs),
            Text(
              '“Small steps,\nbrighter tomorrows.”',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
    if (_large(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          left,
          const SizedBox(height: Insets.md),
          right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: left),
        const SizedBox(width: Insets.sm),
        right,
      ],
    );
  }
}

// --- Total balance --------------------------------------------------------

class BalanceHeroCard extends StatelessWidget {
  const BalanceHeroCard({
    required this.balanceMinor,
    required this.monthNetMinor,
    required this.runningNetMinor,
    required this.hidden,
    required this.onToggleHidden,
    required this.onTap,
    super.key,
  });

  final int balanceMinor;
  final int monthNetMinor;
  final List<int> runningNetMinor;
  final bool hidden;
  final VoidCallback onToggleHidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onTrack = monthNetMinor >= 0;
    const mask = '••••••';
    final delta = hidden
        ? mask
        : '${onTrack ? '+' : '−'} ${formatMinor(monthNetMinor.abs())} this month';

    final deltaRow = Row(
      children: <Widget>[
        Icon(
          onTrack ? Icons.trending_up : Icons.trending_down,
          size: 20,
          color: onTrack ? scheme.income : scheme.expense,
        ),
        const SizedBox(width: Insets.sm),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              delta,
              maxLines: 1,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onTrack ? scheme.income : scheme.expense,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );

    final chart = SizedBox(
      width: 124,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          SizedBox(
            height: 52,
            width: 124,
            child: CustomPaint(
              painter: _SparklinePainter(
                values: runningNetMinor,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: Insets.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Flexible(
                child: Text(
                  onTrack ? "You're on track!" : 'Spending is ahead',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (onTrack) ...<Widget>[
                const SizedBox(width: Insets.xs),
                const LeafMark(size: 16),
              ],
            ],
          ),
        ],
      ),
    );

    return HomeCard(
      onTap: onTap,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          scheme.primaryContainer.withValues(alpha: 0.75),
          Colors.white,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Total Balance',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              InkWell(
                customBorder: const CircleBorder(),
                onTap: onToggleHidden,
                child: Padding(
                  padding: const EdgeInsets.all(Insets.sm),
                  child: Icon(
                    hidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    semanticLabel: hidden ? 'Show balance' : 'Hide balance',
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.sm + Insets.xs,
                  vertical: Insets.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Text('This month', style: theme.textTheme.labelMedium),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              hidden ? 'RM $mask' : formatMinor(balanceMinor),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: Insets.sm),
          if (_large(context))
            deltaRow
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(child: deltaRow),
                chart,
              ],
            ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = values.length < 2 ? <int>[0, 0] : values;
    final lo = pts.reduce(math.min);
    final hi = pts.reduce(math.max);
    final span = (hi - lo) == 0 ? 1 : (hi - lo);
    final dx = size.width / (pts.length - 1);
    Offset at(int i) => Offset(
      i * dx,
      size.height - 4 - ((pts[i] - lo) / span) * (size.height - 8),
    );
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < pts.length; i++) {
      final a = at(i - 1);
      final b = at(i);
      final mid = (a.dx + b.dx) / 2;
      line.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}

// --- Quick actions --------------------------------------------------------

class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback onTap;
  final bool filled;
}

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({required this.actions, super.key});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    if (_large(context)) {
      return LayoutBuilder(
        builder: (context, box) {
          final w = (box.maxWidth - Insets.sm) / 2;
          return Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: <Widget>[
              for (final a in actions)
                SizedBox(
                  width: w,
                  child: _QuickTile(action: a),
                ),
            ],
          );
        },
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < actions.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: Insets.sm + 2),
            Expanded(child: _QuickTile(action: actions[i])),
          ],
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = action.filled ? scheme.onPrimary : scheme.onSurface;
    final sub = action.filled
        ? scheme.onPrimary.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      label: '${action.label} ${action.sublabel}',
      child: ExcludeSemantics(
        child: Material(
          color: action.filled
              ? scheme.primary
              : scheme.primaryContainer.withValues(alpha: 0.6),
          elevation: action.filled ? 2 : 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: scheme.primary.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: action.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: Insets.md,
                horizontal: Insets.xs,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(action.icon, size: 28, color: fg),
                  const SizedBox(height: Insets.sm),
                  Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(color: fg),
                  ),
                  Text(
                    action.sublabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: sub),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Monthly spending -----------------------------------------------------

class MonthlySpendingCard extends StatelessWidget {
  const MonthlySpendingCard({
    required this.status,
    required this.onViewBudget,
    super.key,
  });

  final BudgetStatus? status;
  final VoidCallback onViewBudget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = status;
    final level = s?.level ?? BudgetLevel.safe;
    final color = switch (level) {
      BudgetLevel.safe => scheme.primary,
      BudgetLevel.approaching => scheme.warning,
      BudgetLevel.exceeded => scheme.error,
    };
    final fraction = s == null ? 0.0 : s.fractionUsed.clamp(0.0, 1.0);
    final percent = s == null ? '—' : '${(s.fractionUsed * 100).round()}%';

    final donut = SizedBox(
      width: 88,
      height: 88,
      child: CustomPaint(
        painter: _DonutPainter(
          fraction: fraction,
          color: color,
          track: scheme.outlineVariant,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    percent,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    s == null ? 'no budget' : 'spent',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Widget figure(String value, String label) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final Widget details;
    if (s == null) {
      details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'No monthly budget yet',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            'Set an overall limit to see how much you have left.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    } else {
      details = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: figure(formatMinor(s.spentMinor), 'spent')),
              Container(
                width: 1,
                height: 36,
                color: scheme.outlineVariant,
                margin: const EdgeInsets.symmetric(horizontal: Insets.sm),
              ),
              Expanded(
                child: figure(
                  formatMinor(s.remainingMinor < 0 ? 0 : s.remainingMinor),
                  'remaining',
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm + Insets.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              color: color,
              backgroundColor: scheme.outlineVariant,
            ),
          ),
          const SizedBox(height: Insets.xs + 2),
          Text(
            'Monthly budget: ${formatMinor(s.limitMinor)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (level != BudgetLevel.safe) ...<Widget>[
            const SizedBox(height: Insets.xs),
            Row(
              children: <Widget>[
                Icon(
                  level == BudgetLevel.exceeded
                      ? Icons.error_outline
                      : Icons.warning_amber_rounded,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: Insets.xs),
                Text(
                  level == BudgetLevel.exceeded
                      ? 'Over your limit'
                      : 'Nearing your limit',
                  style: theme.textTheme.labelMedium?.copyWith(color: color),
                ),
              ],
            ),
          ],
        ],
      );
    }

    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionHeader(
            title: 'Monthly Spending',
            action: s == null ? 'Set budget' : 'View budget',
            onAction: onViewBudget,
          ),
          const SizedBox(height: Insets.sm),
          if (_large(context))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                donut,
                const SizedBox(height: Insets.md),
                details,
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                donut,
                const SizedBox(width: Insets.md),
                Expanded(child: details),
              ],
            ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.fraction,
    required this.color,
    required this.track,
  });

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, base..color = track);
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * fraction,
        false,
        base..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}

// --- Top categories -------------------------------------------------------

class TopCategoriesCard extends StatelessWidget {
  const TopCategoriesCard({
    required this.slices,
    required this.categoriesById,
    required this.onSeeAll,
    super.key,
  });

  final List<CategorySlice> slices;
  final Map<String, Category> categoriesById;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget column(CategorySlice s) {
      final category = categoriesById[s.categoryId];
      final color = category == null
          ? scheme.outline
          : Color(category.colorValue);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CategoryAvatar(category: category, radius: 23),
          const SizedBox(height: Insets.sm),
          Text(
            category?.name ?? 'Uncategorised',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          Text(
            _ringgit(s.expenseMinor),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Insets.xs + 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: s.fractionOfExpense.clamp(0.0, 1.0),
              minHeight: 4,
              color: color,
              backgroundColor: scheme.outlineVariant,
            ),
          ),
        ],
      );
    }

    final Widget body;
    if (slices.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        child: Text(
          'No spending recorded this month yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    } else if (_large(context)) {
      body = Column(
        children: <Widget>[
          for (final s in slices) ...<Widget>[
            column(s),
            const SizedBox(height: Insets.md),
          ],
        ],
      );
    } else {
      body = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var i = 0; i < 4; i++) ...<Widget>[
              if (i > 0)
                VerticalDivider(
                  width: Insets.md,
                  thickness: 1,
                  color: scheme.outlineVariant,
                ),
              Expanded(
                child: i < slices.length
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: column(slices[i]),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
    }

    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SectionHeader(
            title: 'Top Categories',
            action: 'See all',
            onAction: onSeeAll,
          ),
          const SizedBox(height: Insets.sm),
          body,
        ],
      ),
    );
  }
}

// --- Recent transactions --------------------------------------------------

class RecentTransactionsCard extends StatelessWidget {
  const RecentTransactionsCard({
    required this.transactions,
    required this.categoriesById,
    required this.now,
    required this.onSeeAll,
    required this.onOpen,
    required this.onDelete,
    super.key,
  });

  final List<Transaction> transactions;
  final Map<String, Category> categoriesById;
  final DateTime now;
  final VoidCallback onSeeAll;
  final void Function(Transaction) onOpen;
  final void Function(Transaction) onDelete;

  String _when(DateTime d) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('d MMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget row(Transaction t) {
      final category = categoriesById[t.categoryId];
      final isIncome = t.type == TransactionType.income;
      final note = t.note?.trim();
      final hasNote = note != null && note.isNotEmpty;
      final title = hasNote ? note : (category?.name ?? 'Uncategorised');
      final sub = hasNote
          ? '${_when(t.date)} · ${category?.name ?? 'Uncategorised'}'
          : _when(t.date);
      return Dismissible(
        key: ValueKey<String>(t.id),
        direction: DismissDirection.endToStart,
        background: Container(
          color: scheme.errorContainer,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: Insets.md),
          child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
        ),
        onDismissed: (_) => onDelete(t),
        child: InkWell(
          onTap: () => onOpen(t),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.sm),
            child: Row(
              children: <Widget>[
                CategoryAvatar(category: category, radius: 20),
                const SizedBox(width: Insets.sm + Insets.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Text(
                  '${isIncome ? '+' : '−'} ${formatMinor(t.amountMinor)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isIncome ? scheme.income : scheme.expense,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SectionHeader(
            title: 'Recent Transactions',
            action: 'See all',
            onAction: onSeeAll,
          ),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.md),
              child: Text(
                'Nothing here yet. Tap Add to record your first transaction — '
                'it takes a few seconds.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (var i = 0; i < transactions.length; i++) ...<Widget>[
              if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
              row(transactions[i]),
            ],
        ],
      ),
    );
  }
}

// --- AI tip ---------------------------------------------------------------

class AiTipCard extends StatelessWidget {
  const AiTipCard({required this.tip, required this.onTap, super.key});

  final String? tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return HomeCard(
      onTap: onTap,
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          scheme.primaryContainer.withValues(alpha: 0.85),
          scheme.primaryContainer.withValues(alpha: 0.4),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.md,
        Insets.sm,
        Insets.md,
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.7),
            child: Icon(Icons.auto_awesome, color: scheme.primary),
          ),
          const SizedBox(width: Insets.sm + Insets.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        'Spendify AI',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'AI',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  tip ?? 'Get personalised tips based on your own spending.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (!_large(context))
            const SizedBox(width: 64, height: 78, child: AssistantMascot()),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
