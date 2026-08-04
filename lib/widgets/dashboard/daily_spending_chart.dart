import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/transaction_model.dart';
import '../common/glass_card.dart';

class DailySpendingChart extends StatelessWidget {
  const DailySpendingChart({super.key, required this.transactions});

  final List<TrackrTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final values = List<double>.filled(7, 0);
    for (final t
        in transactions.where((t) => t.type == TransactionType.expense)) {
      final diff = now
          .difference(
              DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day))
          .inDays;
      if (diff >= 0 && diff < 7) values[6 - diff] += t.amount;
    }
    final maxY = values.fold<double>(100, (m, v) => v > m ? v : m);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily spending',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.2,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final day =
                            now.subtract(Duration(days: 6 - value.toInt()));
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text('${day.day}',
                              style: Theme.of(context).textTheme.labelSmall),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < values.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                          toY: values[i],
                          width: 16,
                          borderRadius: BorderRadius.circular(6),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00CEC9), Color(0xFF6C5CE7)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          )),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
