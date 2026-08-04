import 'package:flutter/material.dart';

import '../../models/pending_transaction_model.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../common/glass_card.dart';

class PendingTransactionTile extends StatelessWidget {
  const PendingTransactionTile({
    super.key,
    required this.pending,
    required this.onConfirm,
    required this.onReject,
    this.onEdit,
    this.onReview,
  });

  final PendingTransaction pending;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback? onEdit;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final tx = pending.transaction;
    final category = AppCategories.byId(tx.categoryId);
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(category.icon, color: category.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx.description,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                        '${money(tx.amount)} • ${(tx.confidence * 100).round()}% confidence'),
                  ],
                ),
              ),
              if (pending.needsReview)
                ActionChip(
                  avatar: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Review'),
                  onPressed: onReview,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x66101724),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(pending.rawSms,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit')),
              const SizedBox(width: 4),
              TextButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject')),
              const SizedBox(width: 8),
              FilledButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirm')),
            ],
          ),
        ],
      ),
    );
  }
}
