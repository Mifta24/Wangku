import 'package:supabase_flutter/supabase_flutter.dart';

class BudgetService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _budgetsTable = 'budgets';

  RealtimeChannel? _budgetChannel;

  void subscribeToBudgets(String userId, void Function() onChanged) {
    _budgetChannel?.unsubscribe();
    _budgetChannel = _supabase
        .channel('budgets_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _budgetsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  void unsubscribeBudgets() {
    _budgetChannel?.unsubscribe();
    _budgetChannel = null;
  }

  /// Fetch semua budget kategori untuk user
  Future<Map<String, double>> fetchCategoryBudgets(
    String userId, [
    DateTime? month,
  ]) async {
    final targetMonth = month ?? DateTime.now();
    try {
      final response = await _supabase
          .from(_budgetsTable)
          .select('category_id, amount, budget_year, budget_month')
          .eq('user_id', userId)
          .eq('budget_year', targetMonth.year)
          .eq('budget_month', targetMonth.month);

      final result = <String, double>{};
      for (final row in response as List<dynamic>) {
        result[row['category_id'] as String] =
            (row['amount'] as num).toDouble();
      }
      return result;
    } catch (e) {
      if (!_isSameMonth(targetMonth, DateTime.now())) {
        throw Exception('Gagal fetch budget: ${e.toString()}');
      }
      return _fetchLegacyCategoryBudgets(userId);
    }
  }

  /// Simpan atau update budget untuk satu kategori (upsert)
  Future<void> saveCategoryBudget(
    String userId,
    String categoryId,
    double amount,
    [DateTime? month]
  ) async {
    final targetMonth = month ?? DateTime.now();
    try {
      await _supabase.from(_budgetsTable).upsert(
        {
          'user_id': userId,
          'category_id': categoryId,
          'amount': amount,
          'budget_year': targetMonth.year,
          'budget_month': targetMonth.month,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,category_id,budget_year,budget_month',
      );
    } catch (e) {
      if (!_isSameMonth(targetMonth, DateTime.now())) {
        throw Exception('Gagal simpan budget: ${e.toString()}');
      }
      await _saveLegacyCategoryBudget(userId, categoryId, amount);
    }
  }

  /// Hapus budget untuk satu kategori
  Future<void> deleteCategoryBudget(
    String userId,
    String categoryId,
    [DateTime? month]
  ) async {
    final targetMonth = month ?? DateTime.now();
    try {
      await _supabase
          .from(_budgetsTable)
          .delete()
          .eq('user_id', userId)
          .eq('category_id', categoryId)
          .eq('budget_year', targetMonth.year)
          .eq('budget_month', targetMonth.month);
    } catch (e) {
      if (!_isSameMonth(targetMonth, DateTime.now())) {
        throw Exception('Gagal hapus budget: ${e.toString()}');
      }
      await _deleteLegacyCategoryBudget(userId, categoryId);
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

  Future<Map<String, double>> _fetchLegacyCategoryBudgets(String userId) async {
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

  Future<void> _saveLegacyCategoryBudget(
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

  Future<void> _deleteLegacyCategoryBudget(
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

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }
}
