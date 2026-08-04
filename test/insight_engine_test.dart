import 'package:flutter_test/flutter_test.dart';
import 'package:trackr/models/budget_model.dart';
import 'package:trackr/models/transaction_model.dart';
import 'package:trackr/services/insight_engine.dart';

TrackrTransaction transaction({
  required String id,
  required TransactionType type,
  required double amount,
  required String category,
}) =>
    TrackrTransaction(
      id: id,
      type: type,
      amount: amount,
      description: category,
      categoryId: category,
      dateTime: DateTime.now(),
    );

void main() {
  test('generates low-savings and over-budget insights deterministically', () {
    final items = [
      transaction(
          id: 'income',
          type: TransactionType.income,
          amount: 10000,
          category: 'salary'),
      transaction(
          id: 'shop',
          type: TransactionType.expense,
          amount: 9500,
          category: 'shopping'),
    ];
    final insights = InsightEngine().generate(
      transactions: items,
      categorySpending: {'shopping': 9500},
      monthlyBudget: 10000,
      totalIncome: 10000,
      categoryBudgets: const [
        CategoryBudget(categoryId: 'shopping', monthlyLimit: 5000)
      ],
    );
    expect(insights.length, lessThanOrEqualTo(8));
    expect(insights.map((item) => item.id), contains('low_savings'));
    expect(insights.map((item) => item.id), contains('over_shopping'));
  });
}
