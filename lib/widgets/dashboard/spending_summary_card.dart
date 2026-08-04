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
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MONTH AT A GLANCE',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF96A2B8),
                    letterSpacing: 1,
                  )),
          const SizedBox(height: 14),
          Row(children: [
            _Metric(
                label: 'Spent',
                value: money(spent),
                color: const Color(0xFFFF6B6B)),
            const SizedBox(width: 12),
            _Metric(
                label: 'Income',
                value: money(income),
                color: const Color(0xFF00B894)),
            const SizedBox(width: 12),
            _Metric(
                label: 'Available',
                value: money(income - spent),
                color: const Color(0xFF00CEC9)),
          ]),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: color, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
