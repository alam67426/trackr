import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/transaction_model.dart';
import '../../utils/formatters.dart';
import '../common/glass_card.dart';

class DailySpendingChart extends StatelessWidget {
  const DailySpendingChart({super.key, required this.transactions});

  final List<TrackrTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final values = List<double>.filled(7, 0);
    final days = <DateTime>[];

    for (var i = 6; i >= 0; i--) {
      days.add(now.subtract(Duration(days: i)));
    }

    for (final t
        in transactions.where((t) => t.type == TransactionType.expense)) {
      final diff = now
          .difference(
              DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day))
          .inDays;
      if (diff >= 0 && diff < 7) {
        values[6 - diff] += t.amount;
      }
    }

    final maxY = values.fold<double>(0, (m, v) => v > m ? v : m);
    final effectiveMaxY = maxY > 0 ? maxY * 1.25 : 100.0;

    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DAILY RHYTHM',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF96A2B8),
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
              ),
              if (maxY > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x1A00CEC9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Peak: ${money(maxY)}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00CEC9),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: effectiveMaxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          money(spot.y),
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= days.length) {
                          return const SizedBox.shrink();
                        }
                        final day = days[idx];
                        final isToday = idx == 6;
                        final label = DateFormat('E').format(day); // Mon, Tue...
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 6,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  isToday ? FontWeight.w800 : FontWeight.w600,
                              color: isToday
                                  ? const Color(0xFF00CEC9)
                                  : const Color(0xFF96A2B8),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF00CEC9),
                    barWidth: 2.8,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, barData) {
                        return spot.y == maxY && maxY > 0;
                      },
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFF00CEC9),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF00CEC9).withValues(alpha: 0.28),
                          const Color(0xFF00CEC9).withValues(alpha: 0.0),
                        ],
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
