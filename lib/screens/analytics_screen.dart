import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../services/local_intelligence_service.dart';
import 'insight_hub_screen.dart';
import 'trend_detail_screen.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/charts/bar_chart.dart';
import '../widgets/charts/line_chart.dart';
import '../widgets/common/glass_card.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionProvider);
    final smartInsights =
        LocalIntelligenceService.instance.buildInsights(transactions);
    final monthly = _lastSixMonths(transactions);
    final weekly = _lastFourWeeks(transactions);
    final expenses =
        transactions.where((t) => t.type == TransactionType.expense).toList();
    final largest = expenses.isEmpty
        ? null
        : (expenses..sort((a, b) => b.amount.compareTo(a.amount))).first;
    final categoryTotals = <String, double>{};
    for (final t in expenses) {
      categoryTotals[t.categoryId] =
          (categoryTotals[t.categoryId] ?? 0) + t.amount;
    }
    final topCategory = categoryTotals.entries.isEmpty
        ? null
        : (categoryTotals.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first;
    final total = expenses.fold<double>(0, (s, t) => s + t.amount);
    final days = transactions.isEmpty
        ? 1
        : DateTime.now()
            .difference(transactions.last.dateTime)
            .inDays
            .clamp(1, 9999);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('SPENDING INSIGHTS',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.muted,
                    letterSpacing: 1,
                  )),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InsightHubScreen())),
            child: GlassCard(
              padding: const EdgeInsets.all(0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF123E46), Color(0xFF23244B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: AppColors.teal),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Smart insights',
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      const Icon(Icons.lock_outline_rounded,
                          color: AppColors.muted, size: 18),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.muted, size: 20),
                    ]),
                    const SizedBox(height: 14),
                    ...smartInsights
                        .map((insight) => _SmartInsightTile(insight: insight)),
                    const SizedBox(height: 2),
                    Text('Calculated privately on this device',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: const Color(0xFFB9D9D9))),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      TrendDetailScreen(transactions: transactions))),
              child: GlassCard(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text('6-month trend',
                            style: Theme.of(context).textTheme.titleMedium)),
                    const Icon(Icons.open_in_new_rounded,
                        color: AppColors.muted, size: 18),
                  ]),
                  const SizedBox(height: 4),
                  Text('Expense movement over time',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  SizedBox(
                      height: 180, child: TrackrLineChart(values: monthly)),
                ],
              ))),
          const SizedBox(height: 14),
          GlassCard(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Weekly comparison',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Last four weekly totals',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              SizedBox(height: 164, child: TrackrBarChart(values: weekly)),
            ],
          )),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Insights',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _InsightRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'Transactions',
                    value: '${transactions.length}'),
                _InsightRow(
                    icon: Icons.calendar_month_outlined,
                    label: 'Average per day',
                    value: money(total / days)),
                _InsightRow(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Largest expense',
                    value: largest == null ? 'None' : money(largest.amount)),
                _InsightRow(
                    icon: Icons.category_outlined,
                    label: 'Top category',
                    value: topCategory == null
                        ? 'None'
                        : AppCategories.byId(topCategory.key).name),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<double> _lastSixMonths(List<TrackrTransaction> txs) {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final month = DateTime(now.year, now.month - (5 - i));
      return txs
          .where((t) =>
              t.type == TransactionType.expense &&
              t.dateTime.year == month.year &&
              t.dateTime.month == month.month)
          .fold<double>(0, (s, t) => s + t.amount);
    });
  }

  List<double> _lastFourWeeks(List<TrackrTransaction> txs) {
    final now = DateTime.now();
    return List.generate(4, (i) {
      final end = now.subtract(Duration(days: (3 - i) * 7));
      final start = end.subtract(const Duration(days: 7));
      return txs
          .where((t) =>
              t.type == TransactionType.expense &&
              t.dateTime.isAfter(start) &&
              t.dateTime.isBefore(end))
          .fold<double>(0, (s, t) => s + t.amount);
    });
  }
}

class _SmartInsightTile extends StatelessWidget {
  const _SmartInsightTile({required this.insight});

  final LocalInsight insight;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (insight.kind) {
      LocalInsightKind.focus => (
          Icons.pie_chart_outline_rounded,
          AppColors.teal
        ),
      LocalInsightKind.positive => (
          Icons.trending_down_rounded,
          const Color(0xFF00B894)
        ),
      LocalInsightKind.alert => (
          Icons.trending_up_rounded,
          const Color(0xFFFFB86B)
        ),
      LocalInsightKind.neutral => (Icons.insights_outlined, AppColors.muted),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(insight.title,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(insight.detail, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ]),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0x1A00CEC9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.teal),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );
}
