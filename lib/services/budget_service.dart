import '../models/budget_model.dart';
import 'storage_service.dart';

class BudgetService {
  BudgetService(this._storage);

  final StorageService _storage;
  static const _key = 'trackr_budgets';

  Future<List<CategoryBudget>> load() async {
    final rows = await _storage.readSecureList(_key);
    final migrated = <String, double>{};
    var changed = false;
    for (final row in rows) {
      final budget = CategoryBudget.fromJson(row);
      final id = budget.categoryId == 'public_transport'
          ? 'commute'
          : budget.categoryId;
      changed = changed || id != budget.categoryId;
      migrated[id] = (migrated[id] ?? 0) + budget.monthlyLimit;
    }
    final budgets = migrated.entries
        .map((entry) =>
            CategoryBudget(categoryId: entry.key, monthlyLimit: entry.value))
        .toList();
    if (changed) await save(budgets);
    return budgets;
  }

  Future<void> save(List<CategoryBudget> budgets) {
    return _storage.writeSecureList(
        _key, budgets.map((e) => e.toJson()).toList());
  }
}
