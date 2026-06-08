class BudgetAlertItem {
  final String categoryId;
  final String categoryName;
  final double budget;
  final double spent;
  final double percentage;

  BudgetAlertItem({
    required this.categoryId,
    required this.categoryName,
    required this.budget,
    required this.spent,
    required this.percentage,
  });

  factory BudgetAlertItem.fromJson(Map<String, dynamic> json) {
    return BudgetAlertItem(
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String,
      budget: (json['budget'] as num).toDouble(),
      spent: (json['spent'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}
