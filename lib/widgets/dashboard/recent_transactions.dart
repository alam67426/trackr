import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/transaction_model.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../common/glass_card.dart';

class RecentTransactions extends StatelessWidget {
  const RecentTransactions({super.key, required this.transactions});

  final List<TrackrTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final recent = transactions.take(6).toList();

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT ACTIVITY',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF96A2B8),
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
              ),
              Text(
                'TIMELINE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF00CEC9),
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'No transactions recorded yet',
                  style: TextStyle(color: Color(0xFF96A2B8), fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final t = recent[index];
                final category = AppCategories.byId(t.categoryId);
                final isIncome = t.type == TransactionType.income;
                final sign = isIncome ? '+' : '−';
                final amountColor =
                    isIncome ? const Color(0xFF00B894) : const Color(0xFFFF6B6B);
                final isLast = index == recent.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline indicator column
                      Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: category.color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: category.color.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 1.5,
                                color: const Color(0xFF303B50),
                                margin: const EdgeInsets.symmetric(vertical: 2),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      // Transaction Details
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${category.name} · ${_formatTime(t.dateTime)}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF96A2B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$sign${money(t.amount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: amountColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final timeStr = DateFormat('h:mm a').format(dt);
    if (isToday) {
      return 'Today, $timeStr';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day;
    if (isYesterday) {
      return 'Yesterday, $timeStr';
    }
    return '${shortDate(dt)}, $timeStr';
  }
}
