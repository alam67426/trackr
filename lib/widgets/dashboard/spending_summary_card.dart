import 'package:flutter/material.dart';

import '../../models/transaction_model.dart';
import '../../models/reimbursement_model.dart';
import '../../utils/formatters.dart';
import '../common/glass_card.dart';

class SpendingSummaryCard extends StatelessWidget {
  const SpendingSummaryCard(
      {super.key, required this.transactions, required this.reimbursements});

  final List<TrackrTransaction> transactions;
  final List<Reimbursement> reimbursements;

  @override
  Widget build(BuildContext context) {
    final spent = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (s, t) => s + t.amount);
    final income = transactions
        .where((t) => t.type == TransactionType.income)
        .fold<double>(0, (s, t) => s + t.amount);
    final available = income - spent;
    final isAvailablePositive = available >= 0;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        children: [
          Text(
            "YOU'VE SPENT",
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF96A2B8),
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              money(spent),
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isAvailablePositive
                ? '${money(available)} left from ${money(income)}'
                : 'Exceeded income by ${money(available.abs())}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isAvailablePositive
                  ? const Color(0xFF00B894)
                  : const Color(0xFFFF6B6B),
            ),
          ),
          const SizedBox(height: 16),
          // Clean horizontal pills
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatPill(
                symbol: '↑',
                label: 'In',
                amount: money(income),
                color: const Color(0xFF00B894),
              ),
              const SizedBox(width: 10),
              _StatPill(
                symbol: '↓',
                label: 'Out',
                amount: money(spent),
                color: const Color(0xFFFF6B6B),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.symbol,
    required this.label,
    required this.amount,
    required this.color,
  });

  final String symbol;
  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                symbol,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$amount $label',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
