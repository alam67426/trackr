import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/budget_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import 'transaction_provider.dart';

final budgetServiceProvider =
    Provider((ref) => BudgetService(StorageService.instance));

final monthlyBudgetProvider = StateProvider<double>((ref) => 50000);

final budgetProvider =
    StateNotifierProvider<BudgetNotifier, List<CategoryBudget>>((ref) {
  return BudgetNotifier(ref.watch(budgetServiceProvider))..load();
});

class BudgetNotifier extends StateNotifier<List<CategoryBudget>> {
  BudgetNotifier(this._service) : super(const []);

  final BudgetService _service;

  Future<void> load() async => state = await _service.load();

  Future<void> upsert(String categoryId, double amount) async {
    state = [
      for (final budget in state)
        if (budget.categoryId == categoryId)
          CategoryBudget(categoryId: categoryId, monthlyLimit: amount)
        else
          budget,
      if (!state.any((budget) => budget.categoryId == categoryId))
        CategoryBudget(categoryId: categoryId, monthlyLimit: amount),
    ];
    await _service.save(state);
  }
}

final budgetUsageProvider = Provider<Map<String, double>>((ref) {
  final transactions = ref.watch(monthTransactionsProvider);
  final usage = <String, double>{};
  for (final t in transactions.where((t) =>
      t.type == TransactionType.expense ||
      t.type == TransactionType.transfer)) {
    usage[t.categoryId] = (usage[t.categoryId] ?? 0) + t.amount;
  }
  return usage;
});

Map<CategoryGroup, double> fiftyThirtyTwentySuggestions(double income) => {
      CategoryGroup.essentials: income * .5,
      CategoryGroup.lifestyle: income * .3,
      CategoryGroup.transfers: income * .2,
    };

double suggestedBudgetForCategory(
    ExpenseCategory category, double monthlyIncome) {
  final groupTotal =
      fiftyThirtyTwentySuggestions(monthlyIncome)[category.group] ?? 0;
  final count =
      AppCategories.all.where((c) => c.group == category.group).length;
  return count == 0 ? 0 : groupTotal / count;
}
