import '../data/sarcastic_insights.dart';
import '../models/budget_model.dart';
import '../models/financial_insight.dart';
import '../models/transaction_model.dart';
import '../utils/formatters.dart';

/// Pure, deterministic and entirely offline financial education engine.
class InsightEngine {
  static const _wants = {
    'shopping',
    'entertainment',
    'dining',
    'subscriptions',
    'fitness'
  };
  static const _needs = {
    'rent',
    'bills',
    'groceries',
    'commute',
    'fuel',
    'healthcare',
    'education'
  };

  List<FinancialInsight> generate({
    required List<TrackrTransaction> transactions,
    required Map<String, double> categorySpending,
    required double monthlyBudget,
    required double totalIncome,
    List<CategoryBudget> categoryBudgets = const [],
    List<String> previousMonthCategories = const [],
  }) {
    final now = DateTime.now();
    final current = transactions
        .where((item) =>
            item.dateTime.year == now.year && item.dateTime.month == now.month)
        .toList();
    final expenses =
        current.where((item) => item.type == TransactionType.expense).toList();
    final totalExpenses =
        expenses.fold<double>(0, (sum, item) => sum + item.amount);
    final income = totalIncome > 0
        ? totalIncome
        : current
            .where((item) => item.type == TransactionType.income)
            .fold<double>(0, (sum, item) => sum + item.amount);
    final savings = income - totalExpenses;
    final savingsRate = income <= 0 ? null : savings / income;
    final wants = _sum(categorySpending, _wants);
    final needs = _sum(categorySpending, _needs);
    final seed = current.fold<int>(
        current.length + now.day, (sum, item) => sum + item.id.hashCode);
    final insights = <FinancialInsight>[];

    void add(FinancialInsight insight) {
      if (insights.length < 8 && !insights.any((item) => item.id == insight.id))
        insights.add(insight);
    }

    // Keep the home carousel tied to the user's most recent money movement.
    // This is deliberately first so fresh expenses/income do not get hidden
    // behind a long-running monthly budget message.
    if (current.isNotEmpty) {
      final latest = [...current]
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      final transaction = latest.first;
      final isIncome = transaction.type == TransactionType.income;
      add(FinancialInsight(
        id: 'latest_${transaction.id}',
        title: isIncome ? 'Fresh money in' : 'Latest spend spotted',
        description: isIncome
            ? SarcasticInsights.latestIncome(
                source: transaction.description,
                amount: money(transaction.amount),
                seed: seed + transaction.id.hashCode,
              )
            : SarcasticInsights.latestExpense(
                category: transaction.categoryId,
                amount: money(transaction.amount),
                seed: seed + transaction.id.hashCode,
              ),
        category: isIncome ? 'savings' : 'spending',
        actionLabel: 'View breakdown',
        actionTarget: 'analytics',
      ));
    }

    if (income <= 0) {
      add(FinancialInsight(
          id: 'income_missing',
          title: 'Income entry missing',
          description:
              'Salary entry ke bina savings ka report bas guesswork hai. Add it once and let Trackr do the gossip. 📝',
          category: 'general'));
    } else if (savings < 0) {
      add(FinancialInsight(
          id: 'expenses_exceed_income',
          title: 'Budget plot twist',
          description: SarcasticInsights.savings(savingsRate!, seed),
          category: 'budgeting',
          actionLabel: 'Review budget',
          actionTarget: 'budget'));
    } else if (savingsRate! < .10) {
      add(FinancialInsight(
          id: 'low_savings',
          title: 'Savings are shy',
          description: SarcasticInsights.savings(savingsRate, seed),
          category: 'savings'));
    } else if (savingsRate < .20) {
      add(FinancialInsight(
          id: 'improve_savings',
          title: 'Savings are showing up',
          description: SarcasticInsights.savings(savingsRate, seed),
          category: 'savings'));
    } else {
      add(FinancialInsight(
          id: 'excellent_savings',
          title: 'Savings flex detected',
          description: SarcasticInsights.savings(savingsRate, seed),
          category: 'savings'));
    }

    if (income > 0) {
      final wantsRatio = wants / income;
      final needsRatio = needs / income;
      if (wantsRatio > .30)
        add(FinancialInsight(
            id: 'high_wants',
            title: 'Wants are doing the most',
            description:
                'Wants are ${_percent(wantsRatio)} of income. The cart has confidence; the budget needs a turn. 🛒',
            category: 'budgeting',
            actionLabel: 'View spending',
            actionTarget: 'analytics'));
      if (needsRatio > .50)
        add(FinancialInsight(
            id: 'high_needs',
            title: 'Essentials took the spotlight',
            description:
                'Needs are ${_percent(needsRatio)} of income. Bills really said “main character energy.” 💡',
            category: 'budgeting'));
      if (savings > 0 && savingsRate! < .20)
        add(FinancialInsight(
            id: 'target_20',
            title: 'Savings level-up pending',
            description: SarcasticInsights.savings(savingsRate, seed + 1),
            category: 'savings'));
      if (wantsRatio <= .30 && needsRatio <= .50 && savingsRate! >= .20)
        add(const FinancialInsight(
            id: 'balanced_502030',
            title: 'Suspiciously organised money',
            description:
                '50/30/20 looks balanced. Responsible adult mode is clearly working today. 🏅',
            category: 'general'));
    }

    final investments = current
        .where((item) => {'sip', 'mutual_funds', 'insurance', 'returns'}
            .contains(item.categoryId))
        .map((item) => item.categoryId)
        .toSet();
    if (investments.isEmpty)
      add(FinancialInsight(
          id: 'start_investing',
          title: 'Investment tab is waiting',
          description: SarcasticInsights.investment(0, seed),
          category: 'investment'));
    else if (investments.length == 1)
      add(FinancialInsight(
          id: 'diversify',
          title: 'Portfolio has one friend',
          description: SarcasticInsights.investment(1, seed),
          category: 'investment'));
    else
      add(FinancialInsight(
          id: 'diversified',
          title: 'Portfolio has company',
          description: SarcasticInsights.investment(investments.length, seed),
          category: 'investment'));
    if (!investments.contains('insurance'))
      add(const FinancialInsight(
          id: 'insurance_check',
          title: 'Review insurance cover',
          description:
              'Insurance can protect against large unexpected costs. Review cover, exclusions, and affordability; this is education, not a product recommendation.',
          category: 'investment'));

    final emergency = current
        .where((item) => item.categoryId == 'emergency')
        .fold<double>(0, (sum, item) => sum + item.amount);
    if (emergency == 0)
      add(const FinancialInsight(
          id: 'emergency_start',
          title: 'Build an emergency fund',
          description:
              'No emergency fund contribution is recorded this month. A separate buffer for 3–6 months of essential expenses can reduce financial stress.',
          category: 'savings'));
    else if (emergency < 10000)
      add(FinancialInsight(
          id: 'emergency_low',
          title: 'Emergency fund is low',
          description:
              'You recorded ${money(emergency)} for emergencies. Consider building it gradually toward a personal target.',
          category: 'savings'));

    var overBudget = false;
    for (final budget in categoryBudgets) {
      if (budget.monthlyLimit <= 0) continue;
      final spent = categorySpending[budget.categoryId] ?? 0;
      final ratio = spent / budget.monthlyLimit;
      if (ratio >= 1) {
        overBudget = true;
        add(FinancialInsight(
            id: 'over_${budget.categoryId}',
            title: '${budget.categoryId.replaceAll('_', ' ')} went overboard',
            description:
                '${SarcasticInsights.budget(budget.categoryId, ratio, seed)} ${money(spent)} spent against ${money(budget.monthlyLimit)}.',
            category: 'budgeting',
            actionLabel: 'Review budget',
            actionTarget: 'budget'));
      } else if (ratio >= .8)
        add(FinancialInsight(
            id: 'near_${budget.categoryId}',
            title: '${budget.categoryId.replaceAll('_', ' ')} is near the edge',
            description: SarcasticInsights.budget(
                budget.categoryId, ratio, seed + budget.categoryId.hashCode),
            category: 'budgeting',
            actionLabel: 'Review budget',
            actionTarget: 'budget'));
    }
    if (categoryBudgets.isNotEmpty && !overBudget)
        add(const FinancialInsight(
            id: 'budget_adherence',
            title: 'Budget behaved itself',
            description:
                'Within every category limit. Who are you and what happened to the old spending spree? 😄',
          category: 'budgeting'));

    final small = expenses.where((item) => item.amount < 200).length;
    if (small > 20)
      add(FinancialInsight(
          id: 'small_transactions',
            title: 'Tiny spends formed a union',
            description:
                '$small spends below ₹200 this month. Individually innocent, together very dramatic. 💬',
          category: 'spending'));
    if (totalExpenses > 0) {
      _addExpenseShare(insights, 'dining', categorySpending['dining'] ?? 0,
          'Dining is having a moment', .15, totalExpenses);
      _addExpenseShare(insights, 'shopping', categorySpending['shopping'] ?? 0,
          'Shopping cart has opinions', .20, totalExpenses);
      final transport =
          (categorySpending['fuel'] ?? 0) + (categorySpending['commute'] ?? 0);
      if (transport / totalExpenses > .10)
        add(FinancialInsight(
            id: 'transport_high',
            title: 'Commute is collecting rent',
            description: SarcasticInsights.categoryShare(
                'commute', transport / totalExpenses, seed),
            category: 'spending'));
      _addExpenseShare(insights, 'healthcare',
          categorySpending['healthcare'] ?? 0, 'Healthcare took priority', .10,
          totalExpenses);
    }

    if (insights.length < 5) {
      add(FinancialInsight(
          id: 'education_${seed.abs() % 5}',
          title: 'Trackr has a note',
          description: SarcasticInsights.general(seed),
          category: 'general'));
    }
    return insights.isEmpty
        ? [
            FinancialInsight(
                id: 'welcome',
                title: 'Welcome to the money story',
                description:
                    'Add a few transactions and Trackr will bring the numbers and the gentle roast. 😄',
                category: 'general')
          ]
        : insights.take(8).toList();
  }

  void _addExpenseShare(List<FinancialInsight> target, String id, double amount,
      String title, double threshold, double total) {
    if (total <= 0 || amount / total <= threshold || target.length >= 8) return;
    target.add(FinancialInsight(
      id: '${id}_high',
      title: title,
      description: SarcasticInsights.categoryShare(
          id, amount / total, id.hashCode + amount.round()),
      category: 'spending',
    ));
  }

  double _sum(Map<String, double> totals, Set<String> ids) =>
      ids.fold(0.0, (sum, id) => sum + (totals[id] ?? 0));
  String _percent(double value) => '${(value * 100).round()}%';
}
