import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/category_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/insets.dart';
import '../../../core/utils/money.dart';
import '../../../domain/entities/category.dart';
import '../../providers/report_trend_providers.dart';
import '../category_avatar.dart';
import '../home/home_sections.dart';

/// Building blocks for the redesigned Reports screens. Presentational only —
/// each is handed resolved figures.

String compactRinggit(int minor) {
  final ringgit = minor / 100;
  if (ringgit.abs() >= 1000) {
    final k = ringgit / 1000;
    return '${k.toStringAsFixed(k.abs() >= 10 ? 0 : 1)}K';
  }
  return NumberFormat('#,##0').format(ringgit);
}

/// A up/down delta pill — "↓ 12%". For spending, down is good; for income and
/// net balance, up is good, so [goodWhenDown] flips the colour.
class DeltaPill extends StatelessWidget {
  const DeltaPill({required this.change, this.goodWhenDown = false, super.key});

  /// `null` when there is no previous period to compare against.
  final double? change;
  final bool goodWhenDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = change;
    if (value == null || value == 0) return const SizedBox.shrink();

    final isUp = value > 0;
    final isGood = goodWhenDown ? !isUp : isUp;
    final color = isGood ? scheme.income : scheme.error;
    final percent = (value.abs() * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isUp ? Icons.arrow_upward : Icons.arrow_downward,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '$percent%',
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The tappable "September 2026" period chip.
class PeriodChip extends StatelessWidget {
  const PeriodChip({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.sm + 2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: Insets.sm),
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Icon(Icons.expand_more, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bar chart of the trailing periods, with the viewed one highlighted and
/// labelled — the Reports overview chart.
class TrendBars extends StatelessWidget {
  const TrendBars({required this.points, super.key});

  final List<PeriodPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (points.isEmpty) return const SizedBox.shrink();

    final maxValue = points
        .map((p) => p.expenseMinor)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (final p in points)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    if (p.isCurrent)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.xs),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Insets.sm,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.inverseSurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              formatMinor(p.expenseMinor),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onInverseSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final fraction = maxValue == 0
                              ? 0.0
                              : p.expenseMinor / maxValue;
                          final height = math.max(
                            4.0,
                            box.maxHeight * fraction,
                          );
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: height,
                              decoration: BoxDecoration(
                                color: p.isCurrent
                                    ? scheme.primary
                                    : scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        p.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: p.isCurrent
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Line chart of the trailing periods with a soft fill — the Trends screen.
/// [showIncome] adds a second line for income.
class TrendLines extends StatelessWidget {
  const TrendLines({required this.points, this.showIncome = false, super.key});

  final List<PeriodPoint> points;
  final bool showIncome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (points.isEmpty) return const SizedBox.shrink();

    return Column(
      children: <Widget>[
        SizedBox(
          height: 160,
          child: CustomPaint(
            painter: _LinePainter(
              points: points,
              expenseColor: scheme.primary,
              incomeColor: showIncome ? scheme.income : null,
              gridColor: scheme.outlineVariant,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: Insets.xs),
        Row(
          children: <Widget>[
            for (final p in points)
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    p.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: p.isCurrent
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (showIncome) ...<Widget>[
          const SizedBox(height: Insets.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _LegendDot(color: scheme.primary, label: 'Expense'),
              const SizedBox(width: Insets.md),
              _LegendDot(color: scheme.income, label: 'Income'),
            ],
          ),
        ],
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: Insets.xs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.expenseColor,
    required this.incomeColor,
    required this.gridColor,
  });

  final List<PeriodPoint> points;
  final Color expenseColor;
  final Color? incomeColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    var maxValue = 0;
    for (final p in points) {
      maxValue = math.max(maxValue, p.expenseMinor);
      if (incomeColor != null) maxValue = math.max(maxValue, p.incomeMinor);
    }
    if (maxValue == 0) maxValue = 1;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final dx = size.width / (points.length - 1);
    Offset at(int i, int value) => Offset(
      i * dx,
      size.height - (value / maxValue) * (size.height - 8) - 4,
    );

    void drawSeries(int Function(PeriodPoint) valueOf, Color color, bool fill) {
      final path = Path()
        ..moveTo(at(0, valueOf(points[0])).dx, at(0, valueOf(points[0])).dy);
      for (var i = 1; i < points.length; i++) {
        final a = at(i - 1, valueOf(points[i - 1]));
        final b = at(i, valueOf(points[i]));
        final mid = (a.dx + b.dx) / 2;
        path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
      }

      if (fill) {
        final area = Path.from(path)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(
          area,
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
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      for (var i = 0; i < points.length; i++) {
        final centre = at(i, valueOf(points[i]));
        final isLast = i == points.length - 1;
        canvas.drawCircle(centre, isLast ? 5 : 3, Paint()..color = color);
        if (isLast) {
          canvas.drawCircle(
            centre,
            2.5,
            Paint()..color = const Color(0xFFFFFFFF),
          );
        }
      }
    }

    drawSeries((p) => p.expenseMinor, expenseColor, true);
    final income = incomeColor;
    if (income != null) drawSeries((p) => p.incomeMinor, income, false);
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.points != points ||
      old.expenseColor != expenseColor ||
      old.incomeColor != incomeColor;
}

/// A donut with the total in the middle — the category-breakdown chart.
class BreakdownDonut extends StatelessWidget {
  const BreakdownDonut({
    required this.rows,
    required this.categoriesById,
    required this.totalMinor,
    required this.caption,
    super.key,
  });

  final List<CategoryTotal> rows;
  final Map<String, Category> categoriesById;
  final int totalMinor;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      height: 190,
      width: 190,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: const Size(190, 190),
            painter: _DonutPainter(
              rows: rows,
              colorOf: (id) => Color(
                categoriesById[id]?.colorValue ?? kFallbackCategoryColor,
              ),
              emptyColor: scheme.outlineVariant,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(48),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    formatMinor(totalMinor),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    caption,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.rows,
    required this.colorOf,
    required this.emptyColor,
  });

  final List<CategoryTotal> rows;
  final Color Function(String) colorOf;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 34.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    if (rows.isEmpty) {
      canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = emptyColor);
      return;
    }

    var start = -math.pi / 2;
    for (final row in rows) {
      final sweep = math.pi * 2 * row.fraction;
      // A hair of spacing between slices, without letting a tiny slice vanish.
      final gap = sweep > 0.08 ? 0.03 : 0.0;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(sweep - gap, 0.004),
        false,
        paint..color = colorOf(row.categoryId),
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.rows != rows;
}

/// The colour-dot legend beside the donut.
class BreakdownLegend extends StatelessWidget {
  const BreakdownLegend({
    required this.rows,
    required this.categoriesById,
    super.key,
  });

  final List<CategoryTotal> rows;
  final Map<String, Category> categoriesById;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Color(
                      categoriesById[row.categoryId]?.colorValue ??
                          kFallbackCategoryColor,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        categoriesById[row.categoryId]?.name ?? 'Uncategorised',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        formatMinor(row.amountMinor),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Text(
                  '${(row.fraction * 100).round()}%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A category row with its amount, share and a progress bar — the
/// "Top Categories" list and the breakdown list.
class CategoryAmountRow extends StatelessWidget {
  const CategoryAmountRow({
    required this.row,
    required this.category,
    this.showBar = true,
    this.onTap,
    super.key,
  });

  final CategoryTotal row;
  final Category? category;
  final bool showBar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = category == null
        ? scheme.outline
        : Color(category!.colorValue);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
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
                    category?.name ?? 'Uncategorised',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    formatMinor(row.amountMinor),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (showBar) ...<Widget>[
                    const SizedBox(height: Insets.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: row.fraction.clamp(0.0, 1.0),
                        minHeight: 5,
                        color: color,
                        backgroundColor: scheme.outlineVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            Text(
              '${(row.fraction * 100).round()}%',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// A headline figure card — "Total Income RM 2,500.00 ↑ 8%".
class FigureCard extends StatelessWidget {
  const FigureCard({
    required this.label,
    required this.amountMinor,
    this.change,
    this.goodWhenDown = false,
    super.key,
  });

  final String label;
  final int amountMinor;
  final double? change;
  final bool goodWhenDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Insets.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMinor(amountMinor),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (change != null) ...<Widget>[
            const SizedBox(height: Insets.xs),
            DeltaPill(change: change, goodWhenDown: goodWhenDown),
          ],
        ],
      ),
    );
  }
}
