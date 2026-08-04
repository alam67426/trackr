import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/pending_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/reimbursement_provider.dart';
import '../providers/profile_provider.dart';
import '../models/budget_model.dart';
import '../models/transaction_model.dart';
import '../services/insight_engine.dart';
import '../services/low_power_ai_engine.dart';
import '../services/notification_service.dart';
import '../utils/formatters.dart';
import '../widgets/dashboard/budget_progress.dart';
import '../widgets/dashboard/category_chart.dart';
import '../widgets/dashboard/daily_spending_chart.dart';
import '../widgets/dashboard/pending_badge.dart';
import '../widgets/dashboard/recent_transactions.dart';
import '../widgets/dashboard/saving_tip_card.dart';
import '../widgets/dashboard/spending_summary_card.dart';
import '../widgets/dashboard/settlement_overview_card.dart';
import 'analytics_screen.dart';
import 'budget_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.onOpenPending});

  final VoidCallback onOpenPending;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _lastBudgetSignature;

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(currentMonthProvider);
    final monthTx = ref.watch(monthTransactionsProvider);
    final allTransactions = ref.watch(transactionProvider);
    final lastTen = ref.watch(lastTenTransactionsProvider);
    final pendingCount = ref.watch(pendingProvider).length;
    final settings = ref.watch(settingsProvider);
    final categoryBudgets = ref.watch(budgetProvider);
    final categoryUsage = ref.watch(budgetUsageProvider);
    final reimbursements = ref.watch(reimbursementProvider);
    final profile = ref.watch(profileProvider);
    final today = DateTime.now();
    final todayTx = allTransactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.dateTime.year == today.year &&
            t.dateTime.month == today.month &&
            t.dateTime.day == today.day)
        .toList();
    final insights = InsightEngine().generate(
      transactions: ref.watch(transactionProvider),
      categorySpending: categoryUsage,
      monthlyBudget: settings.monthlyBudget,
      totalIncome: monthTx
          .where((item) => item.type == TransactionType.income)
          .fold<double>(0, (sum, item) => sum + item.amount),
      categoryBudgets: categoryBudgets,
    );
    _scheduleBudgetChecks(categoryBudgets, categoryUsage);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              if (profile.imagePath != null &&
                  File(profile.imagePath!).existsSync()) ...[
                CircleAvatar(
                    radius: 21,
                    backgroundImage: FileImage(File(profile.imagePath!))),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YOUR MONEY',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: const Color(0xFF96A2B8),
                                  letterSpacing: 1.1,
                                )),
                    const SizedBox(height: 4),
                    Text(
                        profile.fullName.isEmpty
                            ? 'Trackr'
                            : 'Hi, ${profile.fullName.split(' ').first}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w900, fontSize: 30)),
                    Text(monthLabel(month),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: const Color(0xFF96A2B8))),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF171D2B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF303B50)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () => ref
                          .read(currentMonthProvider.notifier)
                          .state = DateTime(month.year, month.month - 1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Container(
                        width: 1, height: 22, color: const Color(0xFF303B50)),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: () => ref
                          .read(currentMonthProvider.notifier)
                          .state = DateTime(month.year, month.month + 1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PendingBadge(count: pendingCount, onTap: widget.onOpenPending),
          const SizedBox(height: 14),
          SpendingSummaryCard(
              transactions: monthTx, reimbursements: reimbursements),
          const SizedBox(height: 14),
          SettlementOverviewCard(
              transactions: monthTx, reimbursements: reimbursements),
          if (monthTx.any((item) => item.splitWith.isNotEmpty) ||
              reimbursements.isNotEmpty)
            const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF101724),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.today_outlined,
                    size: 18, color: Color(0xFF00CEC9)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    "Today  ${money(todayTx.fold<double>(0, (s, t) => s + t.amount))}",
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text('${todayTx.length} entries',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 14),
          BudgetProgress(
              transactions: monthTx, monthlyBudget: settings.monthlyBudget),
          const SizedBox(height: 14),
          SavingTipCard(
            insights: insights,
            onAction: (insight) {
              if (insight.actionTarget == 'budget') {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BudgetScreen()));
              } else if (insight.actionTarget == 'analytics') {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
              }
            },
          ),
          const SizedBox(height: 14),
          CategoryChart(transactions: monthTx),
          const SizedBox(height: 14),
          DailySpendingChart(transactions: monthTx),
          const SizedBox(height: 14),
          RecentTransactions(transactions: lastTen),
        ]
            .animate(interval: 35.ms)
            .fadeIn(duration: 220.ms)
            .slideY(begin: .04, end: 0),
      ),
    );
  }

  void _scheduleBudgetChecks(
      List<CategoryBudget> budgets, Map<String, double> usage) {
    final signature =
        '${budgets.map((item) => '${item.categoryId}:${item.monthlyLimit}').join('|')}|${usage.entries.map((item) => '${item.key}:${item.value}').join('|')}';
    if (_lastBudgetSignature == signature) return;
    _lastBudgetSignature = signature;
    unawaited(_checkBudgetAlerts(budgets, usage));
  }

  Future<void> _checkBudgetAlerts(
      List<CategoryBudget> budgets, Map<String, double> usage) async {
    final alerts = await LowPowerAiEngine.instance.freshBudgetAlerts(
      budgets: budgets,
      categoryUsage: usage,
    );
    for (final alert in alerts) {
      await NotificationService.instance.budgetAlert(alert.title, alert.body);
    }
  }
}
