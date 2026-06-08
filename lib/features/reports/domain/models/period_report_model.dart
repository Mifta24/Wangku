enum PeriodType { week, month, year }

enum TransactionType { expense, income }

class PeriodReportResult {
  final double currentIncome;
  final double currentExpense;
  final double prevIncome;
  final double prevExpense;
  final List<RpcCategoryData> categories;
  final List<RpcTrendPoint> trend;

  PeriodReportResult({
    required this.currentIncome,
    required this.currentExpense,
    required this.prevIncome,
    required this.prevExpense,
    required this.categories,
    required this.trend,
  });

  factory PeriodReportResult.fromJson(Map<String, dynamic> json) {
    return PeriodReportResult(
      currentIncome: (json['current_income'] as num).toDouble(),
      currentExpense: (json['current_expense'] as num).toDouble(),
      prevIncome: (json['prev_income'] as num).toDouble(),
      prevExpense: (json['prev_expense'] as num).toDouble(),
      categories: (json['categories'] as List<dynamic>)
          .map((e) => RpcCategoryData.fromJson(e as Map<String, dynamic>))
          .toList(),
      trend: (json['trend'] as List<dynamic>)
          .map((e) => RpcTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RpcCategoryData {
  final String categoryId;
  final String name;
  final String icon;
  final String color;
  final String type;
  final double total;

  RpcCategoryData({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    required this.total,
  });

  factory RpcCategoryData.fromJson(Map<String, dynamic> json) {
    return RpcCategoryData(
      categoryId: json['category_id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? '',
      color: json['color'] as String? ?? '#CCCCCC',
      type: json['type'] as String,
      total: (json['total'] as num).toDouble(),
    );
  }
}

class RpcTrendPoint {
  final String bucket;
  final double income;
  final double expense;

  RpcTrendPoint({
    required this.bucket,
    required this.income,
    required this.expense,
  });

  factory RpcTrendPoint.fromJson(Map<String, dynamic> json) {
    return RpcTrendPoint(
      bucket: json['bucket'] as String,
      income: (json['income'] as num).toDouble(),
      expense: (json['expense'] as num).toDouble(),
    );
  }
}
