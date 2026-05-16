import '../../../../core/database/hive_manager.dart';
import '../services/budget_service.dart';

class BudgetRepository {
  final BudgetService _service = BudgetService();
  final HiveManager _hive = HiveManager.instance;

  /// Ambil semua budget kategori: Supabase utama, Hive fallback
  Future<Map<String, double>> getCategoryBudgets(String userId) async {
    try {
      final budgets = await _service.fetchCategoryBudgets(userId);
      // Update cache Hive supaya sinkron
      for (final entry in budgets.entries) {
        await _hive.saveCategoryBudget(userId, entry.key, entry.value);
      }
      return budgets;
    } catch (_) {
      // Offline: pakai data Hive
      return _hive.getCategoryBudgets(userId);
    }
  }

  /// Simpan budget kategori: Supabase dulu, lalu update cache Hive
  Future<void> saveCategoryBudget(
    String userId,
    String categoryId,
    double amount,
  ) async {
    // Simpan ke Supabase
    await _service.saveCategoryBudget(userId, categoryId, amount);
    // Update cache lokal
    await _hive.saveCategoryBudget(userId, categoryId, amount);
  }

  /// Hapus budget kategori dari Supabase dan Hive
  Future<void> deleteCategoryBudget(String userId, String categoryId) async {
    try {
      await _service.deleteCategoryBudget(userId, categoryId);
    } catch (_) {
      // Lanjut hapus lokal meski server gagal
    }
    await _hive.deleteCategoryBudget(userId, categoryId);
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
