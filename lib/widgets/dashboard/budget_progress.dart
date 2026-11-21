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
    final percent = (ratio * 100).toInt();
    final remaining = monthlyBudget - spent;
    final isExceeded = remaining < 0;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget ($percent%)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                isExceeded
                    ? 'Exceeded by ${money(remaining.abs())}'
                    : '${money(remaining)} left',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isExceeded
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF00CEC9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF171D2B),
              borderRadius: BorderRadius.circular(99),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(
                    colors: isExceeded
                        ? [const Color(0xFFFF6B6B), const Color(0xFFE17055)]
                        : ratio >= 0.8
                            ? [const Color(0xFFFDCB6E), const Color(0xFFE17055)]
                            : [const Color(0xFF00CEC9), const Color(0xFF6C5CE7)],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${money(spent)} spent',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF96A2B8))),
              Text('Limit: ${money(monthlyBudget)}',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF96A2B8))),
            ],
          ),
        ],
      ),
    );
  }
}
