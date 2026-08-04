import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../utils/formatters.dart';
import '../widgets/charts/line_chart.dart';
import '../widgets/common/glass_card.dart';

class TrendDetailScreen extends StatelessWidget {
  const TrendDetailScreen({super.key, required this.transactions});

  final List<TrackrTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final values = _monthlyValues();
    final labels = List.generate(
        6,
        (index) => monthLabel(
                DateTime(DateTime.now().year, DateTime.now().month - 5 + index))
            .split(' ')
            .first
            .substring(0, 3));
    final latest = values.last;
    final previous = values[values.length - 2];
    final change =
        previous == 0 ? null : ((latest - previous) / previous * 100).round();
    return Scaffold(
      appBar: AppBar(title: const Text('Trend analysis')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        GlassCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Last six months',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Expense movement based on confirmed transactions.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 18),
          SizedBox(height: 210, child: TrackrLineChart(values: values)),
          const SizedBox(height: 10),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: labels
                  .map((label) => Text(label,
                      style: Theme.of(context).textTheme.labelSmall))
                  .toList()),
        ])),
        const SizedBox(height: 14),
        GlassCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('What changed', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(change == null
              ? 'This month has ${money(latest)} in confirmed expenses. Add more history to compare it with the previous month.'
              : change >= 0
                  ? 'This month is ${change.abs()}% higher than last month, with ${money(latest)} in confirmed expenses.'
                  : 'This month is ${change.abs()}% lower than last month, with ${money(latest)} in confirmed expenses.'),
          const SizedBox(height: 8),
          Text(
              'Use this as a reflection tool, not a prediction. Your data remains only on this device.',
              style: Theme.of(context).textTheme.bodySmall),
        ])),
        const SizedBox(height: 14),
        GlassCard(
            child: Column(
                children: List.generate(
                    6,
                    (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(children: [
                            Expanded(child: Text(labels[index])),
                            Text(money(values[index]),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800))
                          ]),
                        )))),
      ]),
    );
  }

  List<double> _monthlyValues() {
    final now = DateTime.now();
    return List.generate(6, (index) {
      final month = DateTime(now.year, now.month - 5 + index);
      return transactions
          .where((item) =>
              item.type == TransactionType.expense &&
              item.dateTime.year == month.year &&
              item.dateTime.month == month.month)
          .fold<double>(0, (sum, item) => sum + item.amount);
    });
  }
}
