import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/transaction_model.dart';
import '../../../categories/domain/models/category_model.dart';

class TransactionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _transactionsTable = 'transactions';

  RealtimeChannel? _transactionChannel;

  void subscribeToTransactions(String userId, void Function() onChanged) {
    _transactionChannel?.unsubscribe();
    _transactionChannel = _supabase
        .channel('transactions_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _transactionsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  void unsubscribeTransactions() {
    _transactionChannel?.unsubscribe();
    _transactionChannel = null;
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<List<TransactionModel>> fetchTransactions({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase
          .from(_transactionsTable)
          .select('''
            id, user_id, category_id, amount, note, date, type,
            categories:category_id(id, name, icon, color, type)
          ''')
          .eq('user_id', userId);

      if (startDate != null) query = query.gte('date', _dateStr(startDate));
      if (endDate != null) query = query.lt('date', _dateStr(endDate));

      final response = await query.order('date', ascending: false);

      return (response as List<dynamic>).map((data) {
        final txn = TransactionModel.fromJson(data);
        final categoryData = data['categories'];
        final category = categoryData != null
            ? CategoryModel.fromJson(categoryData)
            : null;
        return txn.copyWith(category: category);
      }).toList();
    } catch (e) {
      throw Exception('Gagal fetch transaksi: ${e.toString()}');
    }
  }

  Future<TransactionModel?> getTransaction(String transactionId) async {
    try {
      final response = await _supabase
          .from(_transactionsTable)
          .select('''
            id, user_id, category_id, amount, note, date, type,
            categories:category_id(id, name, icon, color, type)
          ''')
          .eq('id', transactionId)
          .maybeSingle();

      if (response == null) return null;
      final txn = TransactionModel.fromJson(response);
      final categoryData = response['categories'];
      final category = categoryData != null
          ? CategoryModel.fromJson(categoryData)
          : null;
      return txn.copyWith(category: category);
    } catch (e) {
      throw Exception('Gagal fetch transaksi: ${e.toString()}');
    }
  }

  Future<TransactionModel> createTransaction(TransactionModel transaction) async {
    try {
      final response = await _supabase
          .from(_transactionsTable)
          .insert(transaction.toJson())
          .select('''
            id, user_id, category_id, amount, note, date, type,
            categories:category_id(id, name, icon, color, type)
          ''')
          .single();

      final txn = TransactionModel.fromJson(response);
      final categoryData = response['categories'];
      final category = categoryData != null
          ? CategoryModel.fromJson(categoryData)
          : null;
      return txn.copyWith(category: category);
    } catch (e) {
      throw Exception('Gagal membuat transaksi: ${e.toString()}');
    }
  }

  Future<TransactionModel> updateTransaction(
    String transactionId,
    TransactionModel transaction,
  ) async {
    try {
      final data = transaction.toJson()
        ..remove('id')
        ..remove('user_id');

      final response = await _supabase
          .from(_transactionsTable)
          .update(data)
          .eq('id', transactionId)
          .select('''
            id, user_id, category_id, amount, note, date, type,
            categories:category_id(id, name, icon, color, type)
          ''')
          .single();

      final txn = TransactionModel.fromJson(response);
      final categoryData = response['categories'];
      final category = categoryData != null
          ? CategoryModel.fromJson(categoryData)
          : null;
      return txn.copyWith(category: category);
    } catch (e) {
      throw Exception('Gagal update transaksi: ${e.toString()}');
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _supabase
          .from(_transactionsTable)
          .delete()
          .eq('id', transactionId);
    } catch (e) {
      throw Exception('Gagal hapus transaksi: ${e.toString()}');
    }
  }

  Future<Map<String, double>> getMonthlyAggregates({
    required String userId,
    required DateTime month,
  }) async {
    try {
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 1);
      final response = await _supabase.rpc('get_monthly_aggregates', params: {
        'p_user_id': userId,
        'p_start_date': _dateStr(startDate),
        'p_end_date': _dateStr(endDate),
      });
      final data = response as Map<String, dynamic>;
      return {
        'total_income': (data['total_income'] as num).toDouble(),
        'total_expense': (data['total_expense'] as num).toDouble(),
      };
    } catch (e) {
      throw Exception('Gagal fetch aggregate: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getCategoryDistribution({
    required String userId,
    required DateTime month,
    required String type,
  }) async {
    try {
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 1);

      final response = await _supabase
          .from(_transactionsTable)
          .select('amount, category_id, categories:category_id(id, name, color)')
          .eq('user_id', userId)
          .eq('type', type)
          .gte('date', startDate.toIso8601String())
          .lt('date', endDate.toIso8601String());

      final Map<String, Map<String, dynamic>> grouped = {};
      for (final row in response as List<dynamic>) {
        final amount = (row['amount'] as num).toDouble();
        final categoryData = row['categories'];
        final name = categoryData?['name'] as String? ?? 'Uncategorized';
        final color = categoryData?['color'] as String? ?? '#CCCCCC';
        if (!grouped.containsKey(name)) {
          grouped[name] = {'category': name, 'total': 0.0, 'color': color};
        }
        grouped[name]!['total'] += amount;
      }
      return grouped.values.toList();
    } catch (e) {
      throw Exception('Gagal fetch category distribution: ${e.toString()}');
    }
  }
}
