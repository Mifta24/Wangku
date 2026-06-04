import 'package:flutter/material.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../transactions/domain/models/transaction_model.dart';

class DashboardMetrics {
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final double weeklyExpense;
  final List<TransactionModel> recentTransactions;

  DashboardMetrics({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.weeklyExpense,
    required this.recentTransactions,
  });
}

class DashboardProvider extends ChangeNotifier {
  TransactionProvider? _transactionProvider;
  DashboardMetrics? _metrics;
  bool _isLoading = false;
  String? _errorMessage;

  DashboardMetrics? get metrics => _metrics;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Initialize dengan TransactionProvider
  void initialize(TransactionProvider transactionProvider) {
    if (_transactionProvider == transactionProvider) return;
    _transactionProvider?.removeListener(_onTransactionChanged);
    _transactionProvider = transactionProvider;
    _transactionProvider!.addListener(_onTransactionChanged);
    _updateMetrics();
  }

  /// Listener untuk perubahan data transaksi
  void _onTransactionChanged() {
    _updateMetrics();
  }

  /// Update metrics dari TransactionProvider
  void _updateMetrics() {
    try {
      _clearError();
      _setLoading(true);

      final transactions = _transactionProvider?.monthTransactions ?? [];

      // Calculate totals
      double totalIncome = 0;
      double totalExpense = 0;

      for (final tx in transactions) {
        if (tx.type == 'income') {
          totalIncome += tx.amount;
        } else {
          totalExpense += tx.amount;
        }
      }

      // Calculate weekly expense (last 7 days)
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      double weeklyExpense = 0;

      for (final tx in transactions) {
        if (tx.type == 'expense' && tx.date.isAfter(sevenDaysAgo)) {
          weeklyExpense += tx.amount;
        }
      }

      // Get recent transactions (limit 5)
      final recent = transactions.take(5).toList();

      _metrics = DashboardMetrics(
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        balance: totalIncome - totalExpense,
        weeklyExpense: weeklyExpense,
        recentTransactions: recent,
      );

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Error updating metrics: ${e.toString()}');
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Get spending by category (top 3)
  List<Map<String, dynamic>> getTopCategories() {
    final transactions = (_transactionProvider?.monthTransactions ?? [])
        .where((t) => t.type == 'expense')
        .toList();

    // Group by category
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final tx in transactions) {
      final catName = tx.category?.name ?? 'Uncategorized';
      final catColor = tx.category?.color ?? '#CCCCCC';

      if (!grouped.containsKey(catName)) {
        grouped[catName] = {
          'category': catName,
          'total': 0.0,
          'color': catColor,
        };
      }
      grouped[catName]!['total'] += tx.amount;
    }

    // Sort by total descending and take top 3
    final sorted = grouped.values.toList()
      ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

    return sorted.take(3).toList();
  }

  /// Get progress data untuk progress bar
  /// Return: % of spending vs income
  double getMonthlyProgress() {
    if (_metrics == null || _metrics!.totalIncome == 0) return 0;
    return (_metrics!.totalExpense / _metrics!.totalIncome).clamp(0, 1);
  }

  /// Refresh dashboard data
  Future<void> refresh() async {
    _updateMetrics();
  }

  /// Cleanup
  @override
  void dispose() {
    _transactionProvider?.removeListener(_onTransactionChanged);
    super.dispose();
  }

  // Private helpers
  void _setLoading(bool value) => _isLoading = value;
  void _setError(String? message) => _errorMessage = message;
  void _clearError() => _errorMessage = null;
}
