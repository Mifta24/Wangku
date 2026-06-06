import '../../../../core/database/hive_manager.dart';
import '../services/budget_service.dart';

class BudgetRepository {
  final BudgetService _service = BudgetService();
  final HiveManager _hive = HiveManager.instance;

  Future<Map<String, double>> getCategoryBudgets(String userId) async {
    try {
      final budgets = await _service.fetchCategoryBudgets(userId);
      for (final entry in budgets.entries) {
        await _hive.saveCategoryBudget(userId, entry.key, entry.value);
      }
      return budgets;
    } catch (_) {
      return _hive.getCategoryBudgets(userId);
    }
  }

  Future<void> saveCategoryBudget(
    String userId,
    String categoryId,
    double amount,
  ) async {
    await _service.saveCategoryBudget(userId, categoryId, amount);
    await _hive.saveCategoryBudget(userId, categoryId, amount);
  }

  Future<void> deleteCategoryBudget(String userId, String categoryId) async {
    try {
      await _service.deleteCategoryBudget(userId, categoryId);
    } catch (_) {}
    await _hive.deleteCategoryBudget(userId, categoryId);
  }

  void subscribeToBudgets(String userId, void Function() onChanged) {
    _service.subscribeToBudgets(userId, onChanged);
  }

  void unsubscribeBudgets() {
    _service.unsubscribeBudgets();
  }

  Future<void> clearUserBudgets(String userId) async {
    try {
      await _service.deleteAllUserBudgets(userId);
    } catch (_) {}
    final budgets = await _hive.getCategoryBudgets(userId);
    for (final categoryId in budgets.keys) {
      await _hive.deleteCategoryBudget(userId, categoryId);
    }
  }
}
