import 'package:supabase_flutter/supabase_flutter.dart';

class BudgetService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _budgetsTable = 'budgets';

  /// Fetch semua budget kategori untuk user
  Future<Map<String, double>> fetchCategoryBudgets(String userId) async {
    try {
      final response = await _supabase
          .from(_budgetsTable)
          .select('category_id, amount')
          .eq('user_id', userId);

      final result = <String, double>{};
      for (final row in response as List<dynamic>) {
        result[row['category_id'] as String] =
            (row['amount'] as num).toDouble();
      }
      return result;
    } catch (e) {
      throw Exception('Gagal fetch budget: ${e.toString()}');
    }
  }

  /// Simpan atau update budget untuk satu kategori (upsert)
  Future<void> saveCategoryBudget(
    String userId,
    String categoryId,
    double amount,
  ) async {
    try {
      await _supabase.from(_budgetsTable).upsert(
        {
          'user_id': userId,
          'category_id': categoryId,
          'amount': amount,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,category_id',
      );
    } catch (e) {
      throw Exception('Gagal simpan budget: ${e.toString()}');
    }
  }

  /// Hapus budget untuk satu kategori
  Future<void> deleteCategoryBudget(
    String userId,
    String categoryId,
  ) async {
    try {
      await _supabase
          .from(_budgetsTable)
          .delete()
          .eq('user_id', userId)
          .eq('category_id', categoryId);
    } catch (e) {
      throw Exception('Gagal hapus budget: ${e.toString()}');
    }
  }

  /// Hapus semua budget user (untuk cleanup saat logout)
  Future<void> deleteAllUserBudgets(String userId) async {
    try {
      await _supabase
          .from(_budgetsTable)
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Gagal hapus semua budget: ${e.toString()}');
    }
  }
}
