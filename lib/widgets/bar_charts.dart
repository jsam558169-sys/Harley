import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_colors.dart';

/// Ranked bar chart for Best Sellers — one bar per product, with the
/// product name shown in the touch tooltip (bar labels stay as short
/// "#1", "#2" rank numbers since full names rarely fit under narrow bars),
/// plus a small legend underneath mapping rank to name.
class RankedBarChart extends StatelessWidget {
  final List<MapEntry<String, num>> entries; // product name -> value, already sorted
  final Color color;

  const RankedBarChart({super.key, required this.entries, this.color = AppColors.rust});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal <= 0 ? 1 : maxVal * 1.25,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.brown,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final name = entries[group.x.toInt()].key;
                    return BarTooltipItem(
                      '$name\n',
                      const TextStyle(color: AppColors.white, fontWeight: FontWeight.w700, fontSize: 12),
                      children: [
                        TextSpan(
                          text: '${rod.toY.toInt()} sold',
                          style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w400, fontSize: 11),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: TextStyle(fontSize: 10, color: AppColors.brown.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('#${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.brown)),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(color: AppColors.cardBorder.withValues(alpha: 0.5), strokeWidth: 1),
              ),
              barGroups: List.generate(entries.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: entries[i].value.toDouble(),
                      color: color,
                      width: 28,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: entries.asMap().entries.map((e) {
            return Text(
              '#${e.key + 1} ${e.value.key}',
              style: TextStyle(fontSize: 11, color: AppColors.brown.withValues(alpha: 0.7)),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// A single compact bar chart showing one value relative to [maxValue] —
/// used per-row in the Product Sales list, so each product shows a real
/// (small) chart for whichever period is currently selected, rather than
/// always showing all three periods regardless of what's picked up top.
class SingleValueBarChart extends StatelessWidget {
  final num value;
  final num maxValue; // the largest value among the currently visible rows, so bars are comparable
  final Color color;

  const SingleValueBarChart({super.key, required this.value, required this.maxValue, this.color = AppColors.teal});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 44,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.center,
          maxY: maxValue <= 0 ? 1 : maxValue.toDouble() * 1.3,
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barTouchData: BarTouchData(
            enabled: false,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.transparent,
              tooltipPadding: EdgeInsets.zero,
              tooltipMargin: 2,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                rod.toY.toInt().toString(),
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.brown),
              ),
            ),
          ),
          barGroups: [
            BarChartGroupData(
              x: 0,
              showingTooltipIndicators: [0],
              barRods: [
                BarChartRodData(
                  toY: value.toDouble(),
                  color: color,
                  width: 24,
                  borderRadius: BorderRadius.circular(5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A small fixed-size comparison bar chart — e.g. Gross Revenue vs. Total
/// Cost vs. Net Profit, each with a real text label underneath (not rank
/// numbers, since there are only a few bars and the labels matter more
/// than ranking). Supports negative values (net profit can be negative),
/// and formats tooltips/axis as currency since that's its main use case.
class ComparisonBarChart extends StatelessWidget {
  final List<MapEntry<String, num>> entries;
  final List<Color> colors;
  final bool currency;

  const ComparisonBarChart({
    super.key,
    required this.entries,
    this.colors = const [AppColors.rust, AppColors.gold, AppColors.teal],
    this.currency = true,
  });

  String _format(num v) => currency ? '₱${v.toStringAsFixed(2)}' : v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final maxAbs = entries.map((e) => e.value.abs()).reduce((a, b) => a > b ? a : b).toDouble();
    final hasNegative = entries.any((e) => e.value < 0);
    final bound = maxAbs <= 0 ? 1.0 : maxAbs * 1.3;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: bound,
          minY: hasNegative ? -bound : 0,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.brown,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                _format(entries[group.x.toInt()].value),
                const TextStyle(color: AppColors.white, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                getTitlesWidget: (value, meta) => Text(
                  _format(value),
                  style: TextStyle(fontSize: 9, color: AppColors.brown.withValues(alpha: 0.6)),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      entries[i].key,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.brown),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: AppColors.cardBorder.withValues(alpha: 0.5), strokeWidth: 1),
          ),
          barGroups: List.generate(entries.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value.toDouble(),
                  color: colors[i % colors.length],
                  width: 36,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
