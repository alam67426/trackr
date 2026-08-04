import '../models/transaction_model.dart';
import '../utils/formatters.dart';

enum CoachTopic { spending, savings, investing, emi }

class CoachReply {
  const CoachReply({
    required this.title,
    required this.message,
    required this.topic,
  });

  final String title;
  final String message;
  final CoachTopic topic;
}

/// Explainable local coaching; it never opens a network connection.
class OfflineCoachService {
  CoachReply reply({
    required CoachTopic topic,
    required List<TrackrTransaction> transactions,
    required double monthlyBudget,
  }) {
    final now = DateTime.now();
    final current = transactions.where((item) =>
        item.dateTime.year == now.year && item.dateTime.month == now.month);
    final expenses =
        current.where((item) => item.type == TransactionType.expense).toList();
    final spent = expenses.fold<double>(0, (sum, item) => sum + item.amount);
    final income = current
        .where((item) => item.type == TransactionType.income)
        .fold<double>(0, (sum, item) => sum + item.amount);

    return switch (topic) {
      CoachTopic.spending => _spending(spent, monthlyBudget, now),
      CoachTopic.savings => _savings(income, spent),
      CoachTopic.investing => _investing(current.toList()),
      CoachTopic.emi => _emi(expenses, income),
    };
  }

  CoachReply _spending(double spent, double budget, DateTime now) {
    if (budget <= 0) {
      return const CoachReply(
          title: 'Set a monthly budget',
          message: 'Add a budget to compare spending against a clear plan.',
          topic: CoachTopic.spending);
    }
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final plannedToday = budget * now.day / daysInMonth;
    if (spent > budget) {
      return CoachReply(
          title: 'Budget exceeded',
          message:
              'You are ${money(spent - budget)} above your monthly plan. Review optional spending before the next purchase.',
          topic: CoachTopic.spending);
    }
    if (spent > plannedToday) {
      return CoachReply(
          title: 'Spending pace is high',
          message:
              'You have used ${money(spent)} so far, above the planned pace for today. ${money(budget - spent)} remains for the month.',
          topic: CoachTopic.spending);
    }
    return CoachReply(
        title: 'Spending is on track',
        message:
            '${money(budget - spent)} remains in this month\'s plan. Keep reviewing pending transactions so the picture stays accurate.',
        topic: CoachTopic.spending);
  }

  CoachReply _savings(double income, double spent) {
    if (income <= 0) {
      return const CoachReply(
          title: 'Record income first',
          message: 'Add income to calculate a useful savings rate.',
          topic: CoachTopic.savings);
    }
    final saved = income - spent;
    final rate = saved / income;
    if (saved <= 0) {
      return const CoachReply(
          title: 'Protect next month\'s savings',
          message:
              'Expenses are above recorded income. Review fixed costs and set a small saving amount after income arrives.',
          topic: CoachTopic.savings);
    }
    return CoachReply(
        title: rate >= .20
            ? 'Savings habit looks healthy'
            : 'Build savings gradually',
        message:
            'You have saved ${money(saved)}, or ${(rate * 100).round()}% of income. A 20% goal is a useful guideline, not a rule.',
        topic: CoachTopic.savings);
  }

  CoachReply _investing(List<TrackrTransaction> transactions) {
    final recorded = transactions
        .where((item) => const {'sip', 'mutual_funds', 'insurance'}
            .contains(item.categoryId))
        .length;
    final context = recorded == 0
        ? 'Build an emergency buffer and avoid investing money needed for upcoming bills.'
        : '$recorded investment-related entries are recorded this month. Review your goal, time horizon, fees, and risk periodically.';
    return CoachReply(
        title: 'Investment learning',
        message:
            '$context This is general education, not personal investment advice.',
        topic: CoachTopic.investing);
  }

  CoachReply _emi(List<TrackrTransaction> expenses, double income) {
    final emi = expenses
        .where((item) => item.description.toLowerCase().contains('emi'))
        .fold<double>(0, (sum, item) => sum + item.amount);
    if (emi == 0) {
      return const CoachReply(
          title: 'Keep EMIs visible',
          message:
              'Add “EMI” in the description of each fixed repayment so it can be included in your cash-flow review.',
          topic: CoachTopic.emi);
    }
    final ratio = income <= 0 ? null : emi / income;
    return CoachReply(
        title: 'EMI check-in',
        message: ratio != null && ratio > .35
            ? 'EMIs are ${money(emi)}, a large share of recorded income. Review the full repayment plan before adding another fixed commitment.'
            : 'EMIs recorded this month: ${money(emi)}. Reserve this amount before optional spending and check your loan terms regularly.',
        topic: CoachTopic.emi);
  }
}
