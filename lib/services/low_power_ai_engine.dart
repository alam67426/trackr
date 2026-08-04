import '../models/budget_model.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import 'storage_service.dart';

/// A deterministic, low-power suggestion engine. It uses only on-device
/// totals, has no model download, and never sends personal financial data out.
class LowPowerAiEngine {
  LowPowerAiEngine._();

  static final instance = LowPowerAiEngine._();

  AiTip nextTip({
    required List<TrackrTransaction> transactions,
    required double monthlyBudget,
    required Map<String, double> categoryUsage,
  }) {
    final now = DateTime.now();
    final monthExpenses = transactions.where((item) =>
        item.type == TransactionType.expense &&
        item.dateTime.year == now.year &&
        item.dateTime.month == now.month);
    final spent =
        monthExpenses.fold<double>(0, (sum, item) => sum + item.amount);
    final ratio = monthlyBudget <= 0 ? 0.0 : spent / monthlyBudget;
    final highest = _highestCategory(categoryUsage);
    final options = <AiTip>[
      if (ratio >= 1)
        AiTip(
            title: 'Monthly budget exceeded',
            message:
                'You are ${money(spent - monthlyBudget)} over your monthly plan. Pause optional spends until the next review.',
            kind: AiTipKind.alert)
      else if (ratio >= .8)
        AiTip(
            title: 'Budget watch',
            message:
                '${(ratio * 100).round()}% of your monthly budget is used. Keep the remaining ${money(monthlyBudget - spent)} for essentials.',
            kind: AiTipKind.watch),
      if (highest != null)
        AiTip(
            title: 'Focus on ${AppCategories.byId(highest.key).name}',
            message:
                'This is your largest tracked category right now. A small weekly cap here can make the month easier to manage.',
            kind: AiTipKind.focus),
      const AiTip(
          title: 'A steady savings habit',
          message:
              'Move a fixed amount to savings after income arrives, then plan day-to-day spending around what remains.',
          kind: AiTipKind.tip),
      const AiTip(
          title: 'Investment checklist',
          message:
              'Keep an emergency buffer and understand risk, fees, and time horizon before choosing any investment.',
          kind: AiTipKind.tip),
      const AiTip(
          title: 'Weekly money reset',
          message:
              'Review your top three categories once a week. Small course corrections are usually easier than month-end cuts.',
          kind: AiTipKind.tip),
      const AiTip(
          title: 'Subscriptions audit',
          message:
              'Check recurring services before they renew. Keeping only the ones you use is an easy way to protect your budget.',
          kind: AiTipKind.tip),
      const AiTip(
          title: 'Make transfers visible',
          message:
              'Record lending separately from spending, so repayments and personal expenses remain easy to understand.',
          kind: AiTipKind.tip),
    ];
    final index =
        (now.year * 367 + now.day * 24 + now.hour + transactions.length) %
            options.length;
    return options[index];
  }

  Future<List<BudgetAlert>> freshBudgetAlerts({
    required List<CategoryBudget> budgets,
    required Map<String, double> categoryUsage,
  }) async {
    final prefs = await StorageService.instance.prefs();
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final alerts = <BudgetAlert>[];
    for (final budget in budgets) {
      if (budget.monthlyLimit <= 0) continue;
      final spent = categoryUsage[budget.categoryId] ?? 0;
      final ratio = spent / budget.monthlyLimit;
      final level = ratio >= 1
          ? 'over'
          : ratio >= .8
              ? 'near'
              : null;
      if (level == null) continue;
      final key = 'trackr_budget_alert_${monthKey}_${budget.categoryId}_$level';
      if (prefs.getBool(key) == true) continue;
      await prefs.setBool(key, true);
      final category = AppCategories.byId(budget.categoryId).name;
      final title = level == 'over'
          ? '$category budget exceeded'
          : '$category budget is nearly used';
      final body = level == 'over'
          ? '${money(spent)} spent against a ${money(budget.monthlyLimit)} limit. Review this category before the next payment.'
          : '${(ratio * 100).round()}% used: ${money(spent)} of ${money(budget.monthlyLimit)}.';
      alerts.add(BudgetAlert(title: title, body: body));
    }
    return alerts;
  }

  MapEntry<String, double>? _highestCategory(Map<String, double> usage) {
    if (usage.isEmpty) return null;
    return usage.entries
        .reduce((first, next) => first.value >= next.value ? first : next);
  }
}

enum AiTipKind { tip, focus, watch, alert }

class AiTip {
  const AiTip({required this.title, required this.message, required this.kind});
  final String title;
  final String message;
  final AiTipKind kind;
}

class BudgetAlert {
  const BudgetAlert({required this.title, required this.body});
  final String title;
  final String body;
}
