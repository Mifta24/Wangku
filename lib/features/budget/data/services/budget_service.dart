import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/budget_model.dart';

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

  Future<List<BudgetModel>> fetchCategoryBudgets(String userId) async {
    final response = await _supabase
        .from(_budgetsTable)
        .select()
        .eq('user_id', userId);

    return (response as List<dynamic>)
        .map((row) => BudgetModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCategoryBudget(
    String userId,
    String categoryId,
    double amount,
  ) async {
    final model = BudgetModel(
      userId: userId,
      categoryId: categoryId,
      amount: amount,
    );
    await _supabase.from(_budgetsTable).upsert(
      model.toSupabaseJson(),
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
