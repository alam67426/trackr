import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class TrackrLineChart extends StatelessWidget {
  const TrackrLineChart({super.key, required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final maxY = values.fold<double>(100, (m, v) => v > m ? v : m);
    return LineChart(
      LineChartData(
        maxY: maxY * 1.2,
        minY: 0,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
            leftTitles: AxisTitles(),
            topTitles: AxisTitles(),
            rightTitles: AxisTitles()),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < values.length; i++)
                FlSpot(i.toDouble(), values[i])
            ],
            isCurved: true,
            color: const Color(0xFF00CEC9),
            barWidth: 4,
            dotData: const FlDotData(show: false),
            belowBarData:
                BarAreaData(show: true, color: const Color(0x3300CEC9)),
          ),
        ],
      ),
    );
  }
}
