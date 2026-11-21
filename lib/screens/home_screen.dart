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
import '../services/sms_listener.dart';
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Clean Minimal Header
          Row(
            children: [
              if (profile.imagePath != null &&
                  File(profile.imagePath!).existsSync()) ...[
                CircleAvatar(
                    radius: 20,
                    backgroundImage: FileImage(File(profile.imagePath!))),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName.isEmpty
                          ? 'Good morning'
                          : 'Hi, ${profile.fullName.split(' ').first}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      monthLabel(month),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF96A2B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF171D2B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF303B50)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Previous month',
                      onPressed: () => ref
                          .read(currentMonthProvider.notifier)
                          .state = DateTime(month.year, month.month - 1),
                      icon: const Icon(Icons.chevron_left, size: 20),
                    ),
                    Container(
                        width: 1, height: 18, color: const Color(0xFF303B50)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Next month',
                      onPressed: () => ref
                          .read(currentMonthProvider.notifier)
                          .state = DateTime(month.year, month.month + 1),
                      icon: const Icon(Icons.chevron_right, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Pending Alert (only shows when there are items needing review)
          if (pendingCount > 0) ...[
            PendingBadge(count: pendingCount, onTap: widget.onOpenPending),
            const SizedBox(height: 14),
          ],

          // SMS Auto-Detection Onboarding Prompt (shown if not yet enabled)
          if (!settings.smsAutoDetection) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0x2200CEC9), Color(0x116C5CE7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x4400CEC9)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0x3300CEC9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sms_outlined,
                        color: Color(0xFF00CEC9), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Track Bank Expenses',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Enable auto-detection to track bank SMS offline',
                          style: TextStyle(
                            color: Color(0xFF96A2B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00CEC9),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    onPressed: () => _enableSmsDetection(context, ref),
                    child: const Text('Enable'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Hero Balance Card (Giant centered amount + horizontal In/Out pills)
          SpendingSummaryCard(
              transactions: monthTx, reimbursements: reimbursements),
          const SizedBox(height: 14),

          // Settlement Overview (if active split bills exist)
          if (monthTx.any((item) => item.splitWith.isNotEmpty) ||
              reimbursements.isNotEmpty) ...[
            SettlementOverviewCard(
                transactions: monthTx, reimbursements: reimbursements),
            const SizedBox(height: 14),
          ],

          // Today's Mini Spending Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF101724),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x22303B50)),
            ),
            child: Row(
              children: [
                const Icon(Icons.today_outlined,
                    size: 16, color: Color(0xFF00CEC9)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Today  ${money(todayTx.fold<double>(0, (s, t) => s + t.amount))}",
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Text(
                  '${todayTx.length} entries',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF96A2B8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Sleek Minimal Budget Card
          BudgetProgress(
              transactions: monthTx, monthlyBudget: settings.monthlyBudget),
          const SizedBox(height: 14),

          // Smooth Daily Rhythm Area Chart
          DailySpendingChart(transactions: monthTx),
          const SizedBox(height: 14),

          // Connected Timeline Recent Activity
          RecentTransactions(transactions: lastTen),
          const SizedBox(height: 14),

          // Smart Sarcastic / Helpful Saving Tips
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

          // Category Spending Breakdown
          CategoryChart(transactions: monthTx),
        ]
            .animate(interval: 35.ms)
            .fadeIn(duration: 220.ms)
            .slideY(begin: .03, end: 0),
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
  Future<void> _enableSmsDetection(BuildContext context, WidgetRef ref) async {
    final listener = SMSListener();
    final granted = await listener.requestPermission();
    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('SMS permission is required to detect bank messages.')),
        );
      }
      return;
    }
    await beginNewSmsDetectionWindow(lookback: const Duration(days: 30));
    final settings = ref.read(settingsProvider);
    await ref.read(settingsProvider.notifier).update(settings.copyWith(smsAutoDetection: true));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS auto-tracking enabled! Scanning recent transactions...')),
      );
    }
    var found = 0;
    await listener.rescanRecentInbox((pending) async {
      final added = await ref.read(pendingProvider.notifier).add(pending);
      if (added) found++;
    }, lookback: const Duration(days: 30));
    if (context.mounted && found > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Found $found recent transaction(s) ready for review!')),
      );
    }
  }
}