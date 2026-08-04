import 'package:flutter/material.dart';

import '../../models/transaction_model.dart';
import '../../utils/formatters.dart';
import '../common/glass_card.dart';

class BudgetProgress extends StatelessWidget {
  const BudgetProgress(
      {super.key, required this.transactions, required this.monthlyBudget});

  final List<TrackrTransaction> transactions;
  final double monthlyBudget;

  @override
  Widget build(BuildContext context) {
    final spent = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (s, t) => s + t.amount);
    final ratio =
        monthlyBudget <= 0 ? 0.0 : (spent / monthlyBudget).clamp(0.0, 1.0);
    final color = ratio >= 1
        ? const Color(0xFFFF6B6B)
        : ratio >= .8
            ? const Color(0xFFFDCB6E)
            : const Color(0xFF00CEC9);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Monthly budget',
                  style: Theme.of(context).textTheme.titleMedium),
              Text('${money(spent)} / ${money(monthlyBudget)}'),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
                value: ratio,
                minHeight: 12,
                color: color,
                backgroundColor: Colors.white12),
          ),
        ],
      ),
    );
  }
}
