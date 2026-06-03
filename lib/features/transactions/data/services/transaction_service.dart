import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/transaction_model.dart';
import '../../domain/models/category_model.dart';

class TransactionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _transactionsTable = 'transactions';
  static const String _categoriesTable = 'categories';

  RealtimeChannel? _transactionChannel;
  RealtimeChannel? _categoryChannel;

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

  void subscribeToCategories(String userId, void Function() onChanged) {
    _categoryChannel?.unsubscribe();
    _categoryChannel = _supabase
        .channel('categories_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _categoriesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  void unsubscribeCategories() {
    _categoryChannel?.unsubscribe();
    _categoryChannel = null;
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Fetch semua transaksi untuk user tertentu dengan date range filter
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

      if (startDate != null) {
        query = query.gte('date', _dateStr(startDate));
      }
      if (endDate != null) {
        query = query.lt('date', _dateStr(endDate));
      }

      final response = await query.order('date', ascending: false);

      // Parse response dengan relation category
      return (response as List<dynamic>)
          .map((data) {
            final txn = TransactionModel.fromJson(data);
            final categoryData = data['categories'];
            final category = categoryData != null
                ? CategoryModel.fromJson(categoryData)
                : null;
            return txn.copyWith(category: category);
          })
          .toList();
    } catch (e) {
      throw Exception('Gagal fetch transaksi: ${e.toString()}');
    }
  }

  /// Fetch single transaction by ID
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

  /// Create transaksi baru
  Future<TransactionModel> createTransaction(TransactionModel transaction) async {
    try {
      final data = transaction.toJson();
      final response = await _supabase
          .from(_transactionsTable)
          .insert(data)
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

  /// Update transaksi existing
  Future<TransactionModel> updateTransaction(
    String transactionId,
    TransactionModel transaction,
  ) async {
    try {
      final data = transaction.toJson();
      // Hapus field yang read-only
      data.remove('id');
      data.remove('user_id');

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

  /// Delete transaksi
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

  /// Fetch semua kategori
  Future<List<CategoryModel>> getCategories(String userId) async {
    try {
      final response = await _supabase
          .from(_categoriesTable)
          .select()
          .or('user_id.is.null,user_id.eq.$userId')
          .order('name', ascending: true);

      return (response as List<dynamic>)
          .map((data) => CategoryModel.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Gagal fetch kategori: ${e.toString()}');
    }
  }

  /// Create custom category
  Future<CategoryModel> createCategory(CategoryModel category) async {
    try {
      final data = category.toJson();
      data.remove('id'); // let db generate UUID
      
      final response = await _supabase
          .from(_categoriesTable)
          .insert(data)
          .select()
          .single();

      return CategoryModel.fromJson(response);
    } catch (e) {
      throw Exception('Gagal membuat kategori custom: ${e.toString()}');
    }
  }

  Future<CategoryModel> updateCategory(CategoryModel category) async {
    try {
      final data = category.toJson();
      data.remove('id');
      data.remove('user_id');

      final response = await _supabase
          .from(_categoriesTable)
          .update(data)
          .eq('id', category.id)
          .select()
          .single();

      return CategoryModel.fromJson(response);
    } catch (e) {
      throw Exception('Gagal update kategori: ${e.toString()}');
    }
  }

  Future<void> deleteCategory(CategoryModel category) async {
    try {
      await _supabase
          .from(_categoriesTable)
          .delete()
          .eq('id', category.id)
          .eq('user_id', category.userId!);
    } catch (e) {
      throw Exception('Gagal hapus kategori: ${e.toString()}');
    }
  }

  /// Fetch kategori berdasarkan tipe (income/expense)
  Future<List<CategoryModel>> getCategoriesByType(String type) async {
    try {
      final response = await _supabase
          .from(_categoriesTable)
          .select()
          .eq('type', type)
          .order('name', ascending: true);

      return (response as List<dynamic>)
          .map((data) => CategoryModel.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Gagal fetch kategori: ${e.toString()}');
    }
  }

  /// Aggregate transaksi untuk dashboard (total income/expense)
  /// Return: {"total_income": 0, "total_expense": 0}
  Future<Map<String, double>> getMonthlyAggregates({
    required String userId,
    required DateTime month,
  }) async {
    try {
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 1);

      final response = await _supabase
          .from(_transactionsTable)
          .select('type, amount')
          .eq('user_id', userId)
          .gte('date', startDate.toIso8601String())
          .lt('date', endDate.toIso8601String());

      double totalIncome = 0;
      double totalExpense = 0;

      for (final row in response as List<dynamic>) {
        final amount = (row['amount'] as num).toDouble();
        if (row['type'] == 'income') {
          totalIncome += amount;
        } else {
          totalExpense += amount;
        }
      }

      return {
        'total_income': totalIncome,
        'total_expense': totalExpense,
      };
    } catch (e) {
      throw Exception('Gagal fetch aggregate: ${e.toString()}');
    }
  }

  /// Get kategori distribution untuk pie chart
  /// Return: List<{"category": "...", "total": 0, "color": "..."}> untuk bulan tertentu
  Future<List<Map<String, dynamic>>> getCategoryDistribution({
    required String userId,
    required DateTime month,
    required String type, // 'expense' atau 'income'
  }) async {
    try {
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 1);

      final response = await _supabase
          .from(_transactionsTable)
          .select('''
            amount, category_id,
            categories:category_id(id, name, color)
          ''')
          .eq('user_id', userId)
          .eq('type', type)
          .gte('date', startDate.toIso8601String())
          .lt('date', endDate.toIso8601String());

      // Group by category
      final Map<String, Map<String, dynamic>> grouped = {};

      for (final row in response as List<dynamic>) {
        final amount = (row['amount'] as num).toDouble();
        final categoryData = row['categories'];
        final categoryName = categoryData != null
            ? categoryData['name'] as String
            : 'Uncategorized';
        final categoryColor =
            categoryData != null ? categoryData['color'] as String : '#CCCCCC';

        if (!grouped.containsKey(categoryName)) {
          grouped[categoryName] = {
            'category': categoryName,
            'total': 0.0,
            'color': categoryColor,
          };
        }
        grouped[categoryName]!['total'] += amount;
      }

      return grouped.values.toList();
    } catch (e) {
      throw Exception('Gagal fetch category distribution: ${e.toString()}');
    }
  }
}
