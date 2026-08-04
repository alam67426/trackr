class CategoryBudget {
  const CategoryBudget({required this.categoryId, required this.monthlyLimit});

  final String categoryId;
  final double monthlyLimit;

  Map<String, dynamic> toJson() =>
      {'categoryId': categoryId, 'monthlyLimit': monthlyLimit};

  factory CategoryBudget.fromJson(Map<String, dynamic> json) => CategoryBudget(
        categoryId: json['categoryId'] as String,
        monthlyLimit: (json['monthlyLimit'] as num).toDouble(),
      );
}
