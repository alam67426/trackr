import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class TrackrBarChart extends StatelessWidget {
  const TrackrBarChart({super.key, required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final maxY = values.fold<double>(100, (m, v) => v > m ? v : m);
    return BarChart(
      BarChartData(
        maxY: maxY * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
            leftTitles: AxisTitles(),
            topTitles: AxisTitles(),
            rightTitles: AxisTitles()),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                  toY: values[i],
                  width: 18,
                  color: const Color(0xFF6C5CE7),
                  borderRadius: BorderRadius.circular(8)),
            ]),
        ],
      ),
    );
  }
}
