import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../transactions/presentation/providers/transaction_provider.dart';

class CategoryDistribution {
  final String categoryId;
  final String name;
  final String icon;
  final double total;
  final String color; // hex

  CategoryDistribution({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.total,
    required this.color,
  });
}

class MonthlyAggregate {
  final String label;
  final double income;
  final double expense;

  MonthlyAggregate({required this.label, required this.income, required this.expense});
}

class ReportProvider extends ChangeNotifier {
  final TransactionProvider txnProvider;

  ReportProvider({required this.txnProvider}) {
    // React when transactions update
    txnProvider.addListener(_recompute);
    _recompute();
  }

  List<MonthlyAggregate> _monthly = [];
  List<CategoryDistribution> _categories = [];

  List<MonthlyAggregate> get monthly => _monthly;
  List<CategoryDistribution> get categories => _categories;

  void _recompute() {
    final now = DateTime.now();
    // last 6 months
    final months = List.generate(6, (i) {
      final dt = DateTime(now.year, now.month - (5 - i));
      return DateFormat.MMM('id_ID').format(dt);
    });

    final List<MonthlyAggregate> tmp = [];
    for (int i = 0; i < 6; i++) {
      final dt = DateTime(now.year, now.month - (5 - i));
      final monthTx = txnProvider.transactions.where((t) => t.date.year == dt.year && t.date.month == dt.month);
      final income = monthTx.where((t) => t.type == 'income').fold<double>(0.0, (p, e) => p + e.amount);
      final expense = monthTx.where((t) => t.type == 'expense').fold<double>(0.0, (p, e) => p + e.amount);
      tmp.add(MonthlyAggregate(label: months[i], income: income, expense: expense));
    }

    // categories for current month
    final curMonth = DateTime(now.year, now.month);
    final monthTx = txnProvider.transactions.where((t) => t.date.year == curMonth.year && t.date.month == curMonth.month && t.type == 'expense');
    final Map<String, double> sums = {};
    final Map<String, String> names = {};
    final Map<String, String> colors = {};
    final Map<String, String> icons = {};
    for (final t in monthTx) {
      final cid = t.categoryId;
      sums[cid] = (sums[cid] ?? 0) + t.amount;
      names[cid] = t.category?.name ?? 'Lain-lain';
      colors[cid] = t.category?.color ?? '#CCCCCC';
      icons[cid] = t.category?.icon ?? '';
    }

    final List<CategoryDistribution> cats = sums.entries.map((e) {
      final name = names[e.key]!;
      final color = colors[e.key]!;
      final icon = icons[e.key] ?? '';
      return CategoryDistribution(
        categoryId: e.key,
        name: name,
        icon: icon,
        total: e.value,
        color: color,
      );
    }).toList();

    _monthly = tmp;
    _categories = cats;
    notifyListeners();
  }

  @override
  void dispose() {
    txnProvider.removeListener(_recompute);
    super.dispose();
  }
}
