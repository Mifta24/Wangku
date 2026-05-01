import 'package:flutter/foundation.dart';

import '../../../../core/database/hive_manager.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';

class BudgetProvider extends ChangeNotifier {
  final TransactionProvider txnProvider;
  final HiveManager _hiveManager = HiveManager.instance;

  double? _monthlyBudget;
  Map<String, double> _categoryBudgets = {};
  bool _isLoading = false;
  String? _errorMessage;
  String? _userId;
  DateTime? _lastBudgetAlertDate;
  bool _alertInProgress = false;

  BudgetProvider({required this.txnProvider}) {
    txnProvider.addListener(_onTransactionsChanged);
  }

  double? get monthlyBudget => _monthlyBudget;
  Map<String, double> get categoryBudgets => _categoryBudgets;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get monthExpense => txnProvider.monthExpense;

  double categoryExpense(String categoryId) {
    return txnProvider.monthTransactions
        .where((t) => t.type == 'expense' && t.categoryId == categoryId)
        .fold<double>(0.0, (p, e) => p + e.amount);
  }

  double? categoryBudget(String categoryId) => _categoryBudgets[categoryId];

  double categoryProgress(String categoryId) {
    final budget = categoryBudget(categoryId);
    if (budget == null || budget <= 0) return 0.0;
    final ratio = categoryExpense(categoryId) / budget;
    return ratio.clamp(0.0, 1.0);
  }

  double categoryRemaining(String categoryId) {
    final budget = categoryBudget(categoryId);
    if (budget == null) return 0.0;
    return (budget - categoryExpense(categoryId)).clamp(0.0, double.infinity);
  }

  double get remaining {
    if (_monthlyBudget == null) return 0.0;
    return (_monthlyBudget! - monthExpense).clamp(0.0, double.infinity);
  }

  double get progress {
    if (_monthlyBudget == null || _monthlyBudget! <= 0) return 0.0;
    final ratio = monthExpense / _monthlyBudget!;
    return ratio.clamp(0.0, 1.0);
  }

  Future<void> loadBudget(String userId) async {
    _userId = userId;
    _setLoading(true);
    _errorMessage = null;
    try {
      _monthlyBudget = await _hiveManager.getBudget(userId);
      _lastBudgetAlertDate = await _hiveManager.getBudgetAlertLastDate(userId);
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);
    await _maybeNotifyBudgetWarning();
  }

  Future<void> loadCategoryBudgets(String userId) async {
    _userId = userId;
    _setLoading(true);
    _errorMessage = null;
    try {
      _categoryBudgets = await _hiveManager.getCategoryBudgets(userId);
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);
  }

  Future<void> saveBudget(String userId, double amount) async {
    _userId = userId;
    _setLoading(true);
    _errorMessage = null;
    try {
      await _hiveManager.saveBudget(userId, amount);
      _monthlyBudget = amount;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);
    await _maybeNotifyBudgetWarning();
  }

  Future<void> saveCategoryBudget(
    String userId,
    String categoryId,
    double amount,
  ) async {
    _userId = userId;
    _setLoading(true);
    _errorMessage = null;
    try {
      await _hiveManager.saveCategoryBudget(userId, categoryId, amount);
      _categoryBudgets = {
        ..._categoryBudgets,
        categoryId: amount,
      };
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);
  }

  void _onTransactionsChanged() {
    notifyListeners();
    _maybeNotifyBudgetWarning();
  }

  Future<void> _maybeNotifyBudgetWarning() async {
    if (_alertInProgress) return;
    final userId = _userId;
    if (userId == null) return;
    if (_monthlyBudget == null || _monthlyBudget! <= 0) return;
    if (progress < 0.8) return;

    final now = DateTime.now();
    final last = _lastBudgetAlertDate ??
        await _hiveManager.getBudgetAlertLastDate(userId);
    if (_isSameDay(last, now)) return;

    _alertInProgress = true;
    await NotificationService.instance.showBudgetWarning(
      percent: progress,
      remaining: remaining,
    );
    await _hiveManager.saveBudgetAlertLastDate(userId, now);
    _lastBudgetAlertDate = now;
    _alertInProgress = false;
  }

  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    txnProvider.removeListener(_onTransactionsChanged);
    super.dispose();
  }
}
