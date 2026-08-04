import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_model.dart';
import '../providers/budget_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/common/glass_card.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetProvider);
    final usage = ref.watch(budgetUsageProvider);
    final settings = ref.watch(settingsProvider);
    final byId = {for (final b in budgets) b.categoryId: b.monthlyLimit};
    return Scaffold(
      appBar: AppBar(title: const Text('Budget planner')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('50 / 30 / 20 plan',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                    'A simple guide for your ${money(settings.monthlyBudget)} monthly budget.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                Row(children: [
                  _BudgetSplit(
                      label: 'Needs',
                      value: settings.monthlyBudget * .5,
                      color: AppColors.teal),
                  const SizedBox(width: 10),
                  _BudgetSplit(
                      label: 'Wants',
                      value: settings.monthlyBudget * .3,
                      color: AppColors.purple),
                  const SizedBox(width: 10),
                  _BudgetSplit(
                      label: 'Save',
                      value: settings.monthlyBudget * .2,
                      color: AppColors.warning),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('CATEGORY LIMITS',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.muted,
                    letterSpacing: 1,
                  )),
          const SizedBox(height: 8),
          for (final category in AppCategories.all
              .where((c) => c.group != CategoryGroup.income))
            _BudgetRow(
              category: category,
              spent: usage[category.id] ?? 0,
              limit: byId[category.id] ??
                  suggestedBudgetForCategory(category, settings.monthlyBudget),
              onSave: (amount) =>
                  ref.read(budgetProvider.notifier).upsert(category.id, amount),
            ),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatefulWidget {
  const _BudgetRow(
      {required this.category,
      required this.spent,
      required this.limit,
      required this.onSave});

  final ExpenseCategory category;
  final double spent;
  final double limit;
  final ValueChanged<double> onSave;

  @override
  State<_BudgetRow> createState() => _BudgetRowState();
}

class _BudgetRowState extends State<_BudgetRow> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.limit.toStringAsFixed(0));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio =
        widget.limit <= 0 ? 0.0 : (widget.spent / widget.limit).clamp(0.0, 1.0);
    final color = ratio >= 1
        ? AppColors.danger
        : ratio >= .8
            ? AppColors.warning
            : widget.category.color;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.category.color.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.category.icon,
                    size: 19, color: widget.category.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(widget.category.name,
                      style: const TextStyle(fontWeight: FontWeight.w800))),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(prefixText: '₹', isDense: true),
                  onSubmitted: (value) =>
                      widget.onSave(double.tryParse(value) ?? widget.limit),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              color: color,
              backgroundColor: Colors.white12),
          const SizedBox(height: 6),
          Align(
              alignment: Alignment.centerRight,
              child: Text('${money(widget.spent)} spent')),
        ],
      ),
    );
  }
}

class _BudgetSplit extends StatelessWidget {
  const _BudgetSplit(
      {required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(money(value),
                  style: TextStyle(color: color, fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
      );
}
