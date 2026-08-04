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

/// A small, explainable financial coaching engine. It runs entirely on the
/// device and uses only the user's locally stored transactions.
class OfflineCoachService {
  CoachReply reply({
    required CoachTopic topic,
    required List<TrackrTransaction> transactions,
    required double monthlyBudget,
  }) {
    final now = DateTime.now();
    final current = transactions
        .where((item) =>
            item.dateTime.year == now.year && item.dateTime.month == now.month)
        .toList();
    final expenses = current
        .where((item) => item.type == TransactionType.expense)
        .toList();
    final spent = expenses.fold<double>(0, (sum, item) => sum + item.amount);
    final income = current
        .where((item) => item.type == TransactionType.income)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final seed = current.fold<int>(now.day, (sum, item) => sum + item.id.hashCode);

    return switch (topic) {
      CoachTopic.spending => _spendingReply(spent, monthlyBudget, now, seed),
      CoachTopic.savings => _savingsReply(income, spent, seed),
      CoachTopic.investing => _investmentReply(current, seed),
      CoachTopic.emi => _emiReply(expenses, income, seed),
    };
  }

  CoachReply _spendingReply(
      double spent, double monthlyBudget, DateTime now, int seed) {
    if (monthlyBudget <= 0) {
      return const CoachReply(
          title: 'Set a monthly budget',
          message:
              'Add a monthly budget to compare your spending pace with a clear plan.',
          topic: CoachTopic.spending);
    }
    final days = DateTime(now.year, now.month + 1, 0).day;
    final expectedByToday = monthlyBudget * now.day / days;
    final remaining = monthlyBudget - spent;
    if (spent > monthlyBudget) {
      return CoachReply(
          title: 'Budget exceeded',
          message:
              'You are ${money(spent - monthlyBudget)} above your monthly plan. Pause optional spending and review the highest category before your next purchase.',
          topic: CoachTopic.spending);
    }
    if (spent > expectedByToday) {
      final variants = [
        'Your spending pace is ahead of the monthly plan by ${money(spent - expectedByToday)}. Keeping daily optional spending lighter can protect the remaining ${money(remaining)}.',
        'You have used ${money(spent)} so far, which is above the pace for today. A short review of shopping and dining may help keep ${money(remaining)} available.',
      ];
      return CoachReply(
          title: 'Spending pace is high',
          message: variants[seed.abs() % variants.length],
          topic: CoachTopic.spending);
    }
    return CoachReply(
        title: 'Spending is on track',
        message:
            '${money(remaining)} remains in this month\'s plan. Keep reviewing pending transactions so the picture stays accurate.',
        topic: CoachTopic.spending);
  }

  CoachReply _savingsReply(double income, double spent, int seed) {
    if (income <= 0) {
      return const CoachReply(
          title: 'Record income first',
          message:
              'Add salary, freelance, or other income to calculate a useful savings rate.',
          topic: CoachTopic.savings);
    }
    final saved = income - spent;
    final rate = saved / income;
    if (saved <= 0) {
      return const CoachReply(
          title: 'Protect next month\'s savings',
          message:
              'This month\'s expenses are above recorded income. Start with fixed bills, then set a small automatic saving amount after income arrives.',
          topic: CoachTopic.savings);
    }
    final variants = rate >= .20
        ? [
            'You have kept ${money(saved)}, or ${(rate * 100).round()}% of income. Consider moving part of it to a separate emergency or goal account.',
            'Your current savings rate is ${(rate * 100).round()}%. Keep the habit steady and review whether your emergency buffer is growing.',
          ]
        : [
            'You have saved ${money(saved)}, or ${(rate * 100).round()}% of income. A 20% goal is a useful guideline; increase it gradually when practical.',
            'Savings are at ${(rate * 100).round()}% of income. Try choosing one optional category to trim and move that amount after your next income entry.',
          ];
    return CoachReply(
        title: rate >= .20 ? 'Savings habit looks healthy' : 'Build savings gradually',
        message: variants[seed.abs() % variants.length],
        topic: CoachTopic.savings);
  }

  CoachReply _investmentReply(List<TrackrTransaction> current, int seed) {
    final investmentCount = current
        .where((item) => const {'sip', 'mutual_funds', 'insurance'}
            .contains(item.categoryId))
        .length;
    final variants = investmentCount == 0
        ? [
            'Before investing, build an emergency buffer and avoid using money needed for upcoming bills. Learn the product risk, fees, and time horizon first.',
            'Start with your goal and timeline, not a product tip. Keep an emergency buffer and read costs and risk disclosures before investing.',
          ]
        : [
            'You have recorded $investmentCount investment-related entries this month. Review your goal, time horizon, fees, and risk rather than changing plans based on short-term moves.',
            'Your investment entries are visible in Trackr. Periodically check whether the amount and risk still suit your goal and cash-flow needs.',
          ];
    return CoachReply(
        title: 'Investment learning',
        message:
            '${variants[seed.abs() % variants.length]} This is general education, not investment advice.',
        topic: CoachTopic.investing);
  }

  CoachReply _emiReply(
      List<TrackrTransaction> expenses, double income, int seed) {
    final emi = expenses
        .where((item) => item.description.toLowerCase().contains('emi'))
        .fold<double>(0, (sum, item) => sum + item.amount);
    if (emi <= 0) {
      return const CoachReply(
          title: 'Keep EMIs visible',
          message:
              'Add each EMI with “EMI” in its description and a fixed category. Trackr can then include it in your monthly cash-flow review.',
          topic: CoachTopic.emi);
    }
    final ratio = income <= 0 ? null : emi / income;
    final advice = ratio != null && ratio > .35
        ? 'This is a large share of recorded income. Avoid adding new fixed commitments until you review the full repayment plan.'
        : 'Keep this amount reserved before optional spending and check the interest rate, tenure, and foreclosure conditions.';
    return CoachReply(
        title: 'EMI check-in',
        message:
            'EMIs recorded this month: ${money(emi)}. $advice',
        topic: CoachTopic.emi);
  }
}
