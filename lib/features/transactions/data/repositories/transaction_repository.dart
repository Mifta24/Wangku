import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/transaction_model.dart';
import '../../domain/models/category_model.dart';
import '../services/transaction_service.dart';
import '../../../../core/database/hive_manager.dart';

abstract class ITransactionRepository {
  Future<List<TransactionModel>> getTransactions({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<TransactionModel> addTransaction(TransactionModel transaction);
  Future<TransactionModel> updateTransaction(
    String id,
    TransactionModel transaction,
  );
  Future<void> deleteTransaction(String id);
  Future<List<CategoryModel>> getCategories({required String userId, String? type});
  Future<CategoryModel> createCategory(CategoryModel category);
  Future<CategoryModel> updateCategory(CategoryModel category);
  Future<void> deleteCategory(CategoryModel category);
  Future<Map<String, double>> getMonthlyAggregates({
    required String userId,
    required DateTime month,
  });
  Future<List<Map<String, dynamic>>> getCategoryDistribution({
    required String userId,
    required DateTime month,
    required String type,
  });
}

class TransactionRepository implements ITransactionRepository {
  final TransactionService _service = TransactionService();
  final HiveManager _hiveManager = HiveManager.instance;

  @override
  Future<List<TransactionModel>> getTransactions({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Try fetch dari Supabase
      final transactions = await _service.fetchTransactions(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );

      // Cache ke Hive
      await _hiveManager.cacheTransactions(transactions);
      return transactions;
    } catch (e) {
      // Fallback ke Hive cache jika offline
      final cached = await _hiveManager.getTransactions(userId);
      if (cached.isNotEmpty) {
        return cached;
      }
      // Jika tidak ada cache dan online gagal, throw error
      rethrow;
    }
  }

  @override
  Future<TransactionModel> addTransaction(TransactionModel transaction) async {
    try {
      // Generate ID client-side untuk instant UI update
      final newTx = transaction.copyWith(
        id: const Uuid().v4(),
      );

      // Try sync ke Supabase immediately
      final syncedTx = await _service.createTransaction(newTx);

      // Cache hasil
      await _hiveManager.saveTransaction(syncedTx);
      return syncedTx;
    } catch (e) {
      // Jika offline, simpan ke Hive dengan marker "pending_sync"
      final newTx = transaction.copyWith(
        id: const Uuid().v4(),
      );
      await _hiveManager.saveTransaction(newTx);
      // Return local copy, akan di-sync saat online
      return newTx;
    }
  }

  @override
  Future<TransactionModel> updateTransaction(
    String id,
    TransactionModel transaction,
  ) async {
    try {
      final updated = await _service.updateTransaction(id, transaction);
      await _hiveManager.saveTransaction(updated);
      return updated;
    } catch (e) {
      // Fallback: update di Hive saja
      final local = transaction.copyWith(id: id);
      await _hiveManager.saveTransaction(local);
      return local;
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    try {
      await _service.deleteTransaction(id);
      await _hiveManager.deleteTransaction(id);
    } catch (e) {
      // Fallback: hapus dari Hive saja
      await _hiveManager.deleteTransaction(id);
    }
  }

  @override
  Future<List<CategoryModel>> getCategories({required String userId, String? type}) async {
    try {
      // Kita fetch semua category (global + milik user)
      final categories = await _service.getCategories(userId);

      // Cache ke Hive
      await _hiveManager.cacheCategories(categories);
      
      if (type != null) {
        return categories.where((c) => c.type == type).toList();
      }
      return categories;
    } catch (e) {
      // Fallback ke Hive cache
      final cached = await _hiveManager.getCategories();
      if (cached.isNotEmpty) {
        if (type != null) {
          return cached.where((c) => c.type == type).toList();
        }
        return cached;
      }
      // Jika tidak ada cache, throw
      rethrow;
    }
  }

  @override
  Future<CategoryModel> createCategory(CategoryModel category) async {
    try {
      final newCat = await _service.createCategory(category);
      // Kita tambahkan juga ke local cache
      final currentCached = await _hiveManager.getCategories();
      await _hiveManager.cacheCategories([...currentCached, newCat]);
      return newCat;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<CategoryModel> updateCategory(CategoryModel category) async {
    try {
      final updated = await _service.updateCategory(category);
      await _hiveManager.saveCategory(updated);
      return updated;
    } catch (e) {
      // Fallback: update di Hive saja (offline)
      await _hiveManager.saveCategory(category);
      return category;
    }
  }

  @override
  Future<void> deleteCategory(CategoryModel category) async {
    try {
      await _service.deleteCategory(category);
      await _hiveManager.deleteCategory(category.id);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, double>> getMonthlyAggregates({
    required String userId,
    required DateTime month,
  }) async {
    try {
      return await _service.getMonthlyAggregates(
        userId: userId,
        month: month,
      );
    } catch (e) {
      // Fallback: compute dari Hive cache
      final txs = await _hiveManager.getTransactions(userId);
      double totalIncome = 0;
      double totalExpense = 0;

      for (final tx in txs) {
        final isThisMonth = tx.date.year == month.year &&
            tx.date.month == month.month;
        if (isThisMonth) {
          if (tx.type == 'income') {
            totalIncome += tx.amount;
          } else {
            totalExpense += tx.amount;
          }
        }
      }

      return {
        'total_income': totalIncome,
        'total_expense': totalExpense,
      };
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCategoryDistribution({
    required String userId,
    required DateTime month,
    required String type,
  }) async {
    try {
      return await _service.getCategoryDistribution(
        userId: userId,
        month: month,
        type: type,
      );
    } catch (e) {
      // Fallback: compute dari Hive
      final txs = await _hiveManager.getTransactions(userId);

      final Map<String, Map<String, dynamic>> grouped = {};

      for (final tx in txs) {
        final isThisMonth = tx.date.year == month.year &&
            tx.date.month == month.month;
        if (isThisMonth && tx.type == type) {
          final catName = tx.category?.name ?? 'Uncategorized';
          final catColor = tx.category?.color ?? '#CCCCCC';

          if (!grouped.containsKey(catName)) {
            grouped[catName] = {
              'category': catName,
              'total': 0.0,
              'color': catColor,
            };
          }
          grouped[catName]!['total'] += tx.amount;
        }
      }

      return grouped.values.toList();
    }
  }

  /// Sync pending transactions to Supabase (call this when online)
  Future<void> syncPendingTransactions(String userId) async {
    try {
      final pending = await _hiveManager.getPendingTransactions();
      for (final tx in pending) {
        try {
          await _service.createTransaction(tx);
        } catch (e) {
          // Log error tapi lanjut ke transaksi berikutnya
          debugPrint('Sync error untuk ${tx.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Sync pending failed: $e');
    }
  }
}
