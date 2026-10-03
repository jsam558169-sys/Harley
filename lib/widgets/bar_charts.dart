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

/// Small 3-bar chart (Today / This Week / This Month) embedded inside a
/// product card, replacing plain text pills with an actual chart.
class MultiPeriodBarChart extends StatelessWidget {
  final List<MapEntry<String, num>> values; // label -> value, e.g. [('Today', 5), ('Week', 20), ('Month', 80)]
  final Color color;

  const MultiPeriodBarChart({super.key, required this.values, this.color = AppColors.teal});

  @override
  Widget build(BuildContext context) {
    final maxVal = values.map((e) => e.value).fold<num>(0, (a, b) => a > b ? a : b).toDouble();

    return SizedBox(
      height: 90,
      width: values.length * 56,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal <= 0 ? 1 : maxVal * 1.3,
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= values.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(values[i].key, style: TextStyle(fontSize: 10, color: AppColors.brown.withValues(alpha: 0.6))),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: List.generate(values.length, (i) {
            return BarChartGroupData(
              x: i,
              showingTooltipIndicators: [0],
              barRods: [
                BarChartRodData(
                  toY: values[i].value.toDouble(),
                  color: color,
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
          barTouchData: BarTouchData(
            enabled: false,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.transparent,
              tooltipPadding: EdgeInsets.zero,
              tooltipMargin: 2,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  rod.toY.toInt().toString(),
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.brown),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
