import 'package:flutter/material.dart';

import '../../models/transaction_model.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../common/glass_card.dart';

class RecentTransactions extends StatelessWidget {
  const RecentTransactions({super.key, required this.transactions});

  final List<TrackrTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final lastTen = transactions.take(10).toList();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Recent activity',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Text('LAST 10',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.muted,
                        letterSpacing: 1,
                      )),
            ],
          ),
          const SizedBox(height: 10),
          if (lastTen.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('No confirmed transactions yet'))
          else
            ...lastTen.map((t) {
              final category = AppCategories.byId(t.categoryId);
              final sign = t.type == TransactionType.income ? '+' : '-';
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x22303B50))),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 3),
                  leading: CircleAvatar(
                      backgroundColor: category.color.withValues(alpha: .18),
                      child: Icon(category.icon, color: category.color)),
                  title: Text(t.description,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${category.name} • ${shortDate(t.dateTime)}'),
                  trailing: Text('$sign${money(t.amount)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: t.type == TransactionType.income
                              ? const Color(0xFF00B894)
                              : null)),
                ),
              );
            }),
        ],
      ),
    );
  }
}
