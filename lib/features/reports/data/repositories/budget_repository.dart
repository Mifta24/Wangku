import '../services/budget_service.dart';

class BudgetRepository {
  final BudgetService _service = BudgetService();

  Future<Map<String, double>> getCategoryBudgets(String userId) async {
    return _service.fetchCategoryBudgets(userId);
  }

  Future<void> saveCategoryBudget(
    String userId,
    String categoryId,
    double amount,
  ) async {
    await _service.saveCategoryBudget(userId, categoryId, amount);
  }

  Future<void> deleteCategoryBudget(String userId, String categoryId) async {
    await _service.deleteCategoryBudget(userId, categoryId);
  }

  void subscribeToBudgets(String userId, void Function() onChanged) {
    _service.subscribeToBudgets(userId, onChanged);
  }

  void unsubscribeBudgets() {
    _service.unsubscribeBudgets();
  }

  Future<void> clearUserBudgets(String userId) async {
    await _service.deleteAllUserBudgets(userId);
  }
}
