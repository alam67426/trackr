import 'package:flutter/material.dart';

import '../../models/reimbursement_model.dart';
import '../../models/transaction_model.dart';
import '../../utils/formatters.dart';
import '../common/glass_card.dart';

class SettlementOverviewCard extends StatelessWidget {
  const SettlementOverviewCard(
      {super.key, required this.transactions, required this.reimbursements});
  final List<TrackrTransaction> transactions;
  final List<Reimbursement> reimbursements;
  @override
  Widget build(BuildContext context) {
    final recoverable = transactions
        .expand((item) => item.splitWith)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final received =
        reimbursements.fold<double>(0, (sum, item) => sum + item.amount);
    final pending = (recoverable - received).clamp(0, double.infinity);
    if (recoverable == 0 && received == 0) return const SizedBox.shrink();
    return GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('SETTLEMENTS', style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 12),
      Row(children: [
        _Value(label: 'Money to receive', value: money(recoverable)),
        _Value(label: 'Received', value: money(received)),
        _Value(label: 'Pending', value: money(pending))
      ]),
    ]));
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        FittedBox(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w900)))
      ]));
}
