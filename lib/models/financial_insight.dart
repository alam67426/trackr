class FinancialInsight {
  const FinancialInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.actionLabel,
    this.actionTarget,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String? actionLabel;
  final String? actionTarget;
}
