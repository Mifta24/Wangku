import '../../../../core/database/hive_manager.dart';
import '../services/budget_service.dart';

class BudgetRepository {
  final BudgetService _service = BudgetService();
  final HiveManager _hive = HiveManager.instance;

  /// Ambil budget kategori: coba dari Supabase, kalau gagal (offline) pakai cache Hive
  Future<Map<String, double>> getCategoryBudgets(
    String userId, [
    DateTime? month,
  ]) async {
    final targetMonth = month ?? DateTime.now();
    try {
      final budgets = await _service.fetchCategoryBudgets(userId, targetMonth);
      // Update cache Hive supaya sinkron
      for (final entry in budgets.entries) {
        await _hive.saveCategoryBudget(
          userId,
          entry.key,
          entry.value,
          targetMonth,
        );
      }
      return budgets;
    } catch (_) {
      // Offline: pakai data Hive
      return _hive.getCategoryBudgets(userId, targetMonth);
    }
  }

  /// Simpan budget kategori: Supabase dulu, lalu update cache Hive
  Future<void> saveCategoryBudget(
    String userId,
    String categoryId,
    double amount,
    [DateTime? month]
  ) async {
    final targetMonth = month ?? DateTime.now();
    // Simpan ke Supabase
    await _service.saveCategoryBudget(userId, categoryId, amount, targetMonth);
    // Update cache lokal
    await _hive.saveCategoryBudget(userId, categoryId, amount, targetMonth);
  }

  /// Hapus budget kategori dari Supabase dan Hive
  Future<void> deleteCategoryBudget(
    String userId,
    String categoryId, [
    DateTime? month,
  ]) async {
    final targetMonth = month ?? DateTime.now();
    try {
      await _service.deleteCategoryBudget(userId, categoryId, targetMonth);
    } catch (_) {
      // Lanjut hapus lokal meski server gagal
    }
    await _hive.deleteCategoryBudget(userId, categoryId, targetMonth);
  }

  void subscribeToBudgets(String userId, void Function() onChanged) {
    _service.subscribeToBudgets(userId, onChanged);
  }

  void unsubscribeBudgets() {
    _service.unsubscribeBudgets();
  }

  /// Hapus semua budget user (dipanggil saat logout)
  Future<void> clearUserBudgets(String userId) async {
    try {
      await _service.deleteAllUserBudgets(userId);
    } catch (_) {}
    // Hapus dari Hive juga
    final budgets = await _hive.getCategoryBudgets(userId);
    for (final categoryId in budgets.keys) {
      await _hive.deleteCategoryBudget(userId, categoryId);
    }
  }
}
