import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../models/weigh_in.dart';
import '../utils/units.dart';

/// Weigh-ins as dots, the smoothed trend as a line, and the goal (if any)
/// as a dashed line. X is days since [start].
class WeightChart extends StatelessWidget {
  const WeightChart({
    super.key,
    required this.weighIns,
    required this.trend,
    required this.start,
    required this.end,
    required this.units,
    this.goalKg,
  });

  final List<WeighIn> weighIns;
  final List<TrendPoint> trend;
  final DateTime start;
  final DateTime end;
  final Units units;
  final double? goalKg;

  double _y(double kg) => units == Units.imperial ? kgToLb(kg) : kg;
  double _x(DateTime d) => d.difference(start).inHours / 24;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final inRange = weighIns.where((w) => !w.day.isBefore(start)).toList();
    final trendInRange = trend.where((t) => !t.day.isBefore(start)).toList();

    final dots = [for (final w in inRange) FlSpot(_x(w.day), _y(w.kg))];
    final line = [for (final t in trendInRange) FlSpot(_x(t.day), _y(t.kg))];

    final ys = [
      ...dots.map((s) => s.y),
      ...line.map((s) => s.y),
    ];
    if (ys.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text('No weigh-ins in this range', style: text.bodyMedium),
        ),
      );
    }

    var minY = ys.reduce(min);
    var maxY = ys.reduce(max);
    final goal = goalKg == null ? null : _y(goalKg!);
    // Only stretch to show the goal if it's reasonably close.
    if (goal != null && (goal - minY).abs() < (maxY - minY + 10) * 1.5) {
      minY = min(minY, goal);
      maxY = max(maxY, goal);
    }
    final pad = max(1.0, (maxY - minY) * 0.15);
    minY = (minY - pad).floorToDouble();
    maxY = (maxY + pad).ceilToDouble();

    final spanDays = max(1.0, _x(end));
    final xInterval = max(1.0, (spanDays / 4).roundToDouble());

    return SizedBox(
      height: 240,
      child: Padding(
        padding: const EdgeInsets.only(right: 12, top: 8),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: spanDays,
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: colors.outlineVariant.withValues(alpha: 0.5),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      value.round().toString(),
                      textAlign: TextAlign.right,
                      style: text.labelSmall,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  interval: xInterval,
                  getTitlesWidget: (value, meta) {
                    final d = start.add(Duration(hours: (value * 24).round()));
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${d.month}/${d.day}',
                          style: text.labelSmall),
                    );
                  },
                ),
              ),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                if (goal != null && goal >= minY && goal <= maxY)
                  HorizontalLine(
                    y: goal,
                    color: colors.tertiary,
                    strokeWidth: 2,
                    dashArray: const [6, 4],
                  ),
              ],
            ),
            lineBarsData: [
              // Individual weigh-ins: dots only.
              LineChartBarData(
                spots: dots,
                barWidth: 0,
                color: Colors.transparent,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                    radius: 3,
                    color: colors.primary.withValues(alpha: 0.45),
                    strokeWidth: 0,
                  ),
                ),
              ),
              // Smoothed trend.
              LineChartBarData(
                spots: line,
                isCurved: true,
                preventCurveOverShooting: true,
                barWidth: 3,
                color: colors.primary,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: colors.primary.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
