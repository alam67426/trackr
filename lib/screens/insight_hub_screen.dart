import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/financial_insight.dart';
import '../providers/budget_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/insight_engine.dart';
import '../services/offline_coach_service.dart';
import '../utils/constants.dart';
import '../widgets/common/glass_card.dart';

class InsightHubScreen extends ConsumerStatefulWidget {
  const InsightHubScreen({super.key});

  @override
  ConsumerState<InsightHubScreen> createState() => _InsightHubScreenState();
}

class _InsightHubScreenState extends ConsumerState<InsightHubScreen> {
  CoachTopic _topic = CoachTopic.spending;

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionProvider);
    final usage = ref.watch(budgetUsageProvider);
    final settings = ref.watch(settingsProvider);
    final budgets = ref.watch(budgetProvider);
    final income = transactions
        .where((item) => item.type.name == 'income')
        .fold<double>(0, (sum, item) => sum + item.amount);
    final insights = InsightEngine().generate(
      transactions: transactions,
      categorySpending: usage,
      monthlyBudget: settings.monthlyBudget,
      totalIncome: income,
      categoryBudgets: budgets,
    );
    final reply = OfflineCoachService().reply(
      topic: _topic,
      transactions: transactions,
      monthlyBudget: settings.monthlyBudget,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Trackr Intelligence')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const _PrivacyHeader(),
        const SizedBox(height: 18),
        Text('ASK YOUR MONEY COACH',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: AppColors.muted, letterSpacing: 1)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _TopicChip(
              label: 'Spending',
              icon: Icons.account_balance_wallet_outlined,
              selected: _topic == CoachTopic.spending,
              onTap: () => setState(() => _topic = CoachTopic.spending)),
          _TopicChip(
              label: 'Savings',
              icon: Icons.savings_outlined,
              selected: _topic == CoachTopic.savings,
              onTap: () => setState(() => _topic = CoachTopic.savings)),
          _TopicChip(
              label: 'Investing',
              icon: Icons.trending_up_rounded,
              selected: _topic == CoachTopic.investing,
              onTap: () => setState(() => _topic = CoachTopic.investing)),
          _TopicChip(
              label: 'EMIs',
              icon: Icons.receipt_long_outlined,
              selected: _topic == CoachTopic.emi,
              onTap: () => setState(() => _topic = CoachTopic.emi)),
        ]),
        const SizedBox(height: 12),
        _CoachReplyCard(reply: reply),
        const SizedBox(height: 22),
        Text('PERSONALISED INSIGHTS',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: AppColors.muted, letterSpacing: 1)),
        const SizedBox(height: 10),
        for (final insight in insights)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _InsightCard(insight: insight),
          ),
        const SizedBox(height: 8),
        const Text(
          'Calculated privately on this device. Trackr provides general education, not investment, tax, credit, or legal advice.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ]),
    );
  }
}

class _PrivacyHeader extends StatelessWidget {
  const _PrivacyHeader();

  @override
  Widget build(BuildContext context) => GlassCard(
        child: Row(children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(14)),
            child:
                const Icon(Icons.lock_outline_rounded, color: AppColors.teal),
          ),
          const SizedBox(width: 12),
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Private on-device intelligence',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 3),
                Text(
                    'No cloud account, API key, or transaction upload required.'),
              ])),
        ]),
      );
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        avatar: Icon(icon, size: 18),
        selected: selected,
        onSelected: (_) => onTap(),
      );
}

class _CoachReplyCard extends StatelessWidget {
  const _CoachReplyCard({required this.reply});
  final CoachReply reply;

  @override
  Widget build(BuildContext context) => GlassCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(13)),
            child:
                const Icon(Icons.auto_awesome_rounded, color: AppColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(reply.title,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                Text(reply.message),
              ])),
        ]),
      );
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});
  final FinancialInsight insight;

  @override
  Widget build(BuildContext context) {
    final color = switch (insight.category) {
      'savings' => AppColors.success,
      'investment' => AppColors.purple,
      'budgeting' => AppColors.warning,
      'spending' => AppColors.danger,
      _ => AppColors.teal,
    };
    return GlassCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.insights_outlined, color: color),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(insight.title,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(insight.description),
        ])),
      ]),
    );
  }
}
