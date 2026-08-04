import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/transaction_model.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../common/glass_card.dart';

class CategoryChart extends StatelessWidget {
  const CategoryChart({super.key, required this.transactions});

  final List<TrackrTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final usage = <String, double>{};
    for (final t
        in transactions.where((t) => t.type == TransactionType.expense)) {
      usage[t.categoryId] = (usage[t.categoryId] ?? 0) + t.amount;
    }
    final entries = usage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Category mix',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Text(money(total),
                  style: const TextStyle(
                      color: AppColors.teal, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            const SizedBox(
                height: 190,
                child: Center(child: Text('No expenses this month')))
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 184,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 50,
                        sectionsSpace: 2,
                        sections: entries.take(6).map((entry) {
                          final category = AppCategories.byId(entry.key);
                          return PieChartSectionData(
                            value: entry.value,
                            title: '',
                            color: category.color,
                            radius: 48,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 116,
                  child: Column(
                    children: entries.take(4).map((entry) {
                      final category = AppCategories.byId(entry.key);
                      final percent =
                          total == 0 ? 0 : (entry.value / total * 100).round();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Row(children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: category.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(category.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall),
                          ),
                          Text('$percent%',
                              style: Theme.of(context).textTheme.labelSmall),
                        ]),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
