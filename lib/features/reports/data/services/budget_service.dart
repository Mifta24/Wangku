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

  Future<Map<String, double>> fetchCategoryBudgets(String userId) async {
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
  }

  Future<void> saveCategoryBudget(
    String userId,
    String categoryId,
    double amount,
  ) async {
    await _supabase.from(_budgetsTable).upsert(
      {
        'user_id': userId,
        'category_id': categoryId,
        'amount': amount,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,category_id',
    );
  }

  Future<void> deleteCategoryBudget(String userId, String categoryId) async {
    await _supabase
        .from(_budgetsTable)
        .delete()
        .eq('user_id', userId)
        .eq('category_id', categoryId);
  }

  Future<void> deleteAllUserBudgets(String userId) async {
    try {
      await _supabase.from(_budgetsTable).delete().eq('user_id', userId);
    } catch (e) {
      throw Exception('Gagal hapus semua budget: ${e.toString()}');
    }
  }
}
