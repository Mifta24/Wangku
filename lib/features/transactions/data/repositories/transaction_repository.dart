import 'package:uuid/uuid.dart';
import '../../domain/models/transaction_model.dart';
import '../../domain/models/category_model.dart';
import '../services/transaction_service.dart';

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

  @override
  Future<List<TransactionModel>> getTransactions({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _service.fetchTransactions(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<TransactionModel> addTransaction(TransactionModel transaction) async {
    final newTx = transaction.id.isEmpty
        ? transaction.copyWith(id: const Uuid().v4())
        : transaction;
    return _service.createTransaction(newTx);
  }

  @override
  Future<TransactionModel> updateTransaction(
    String id,
    TransactionModel transaction,
  ) async {
    return _service.updateTransaction(id, transaction);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _service.deleteTransaction(id);
  }

  @override
  Future<List<CategoryModel>> getCategories({required String userId, String? type}) async {
    final categories = await _service.getCategories(userId);
    if (type != null) {
      return categories.where((c) => c.type == type).toList();
    }
    return categories;
  }

  @override
  Future<CategoryModel> createCategory(CategoryModel category) async {
    return _service.createCategory(category);
  }

  @override
  Future<CategoryModel> updateCategory(CategoryModel category) async {
    return _service.updateCategory(category);
  }

  @override
  Future<void> deleteCategory(CategoryModel category) async {
    await _service.deleteCategory(category);
  }

  @override
  Future<Map<String, double>> getMonthlyAggregates({
    required String userId,
    required DateTime month,
  }) async {
    return _service.getMonthlyAggregates(userId: userId, month: month);
  }

  @override
  Future<List<Map<String, dynamic>>> getCategoryDistribution({
    required String userId,
    required DateTime month,
    required String type,
  }) async {
    return _service.getCategoryDistribution(
      userId: userId,
      month: month,
      type: type,
    );
  }

  void subscribeToTransactions(String userId, void Function() onChanged) {
    _service.subscribeToTransactions(userId, onChanged);
  }

  void unsubscribeTransactions() {
    _service.unsubscribeTransactions();
  }

  void subscribeToCategories(String userId, void Function() onChanged) {
    _service.subscribeToCategories(userId, onChanged);
  }

  void unsubscribeCategories() {
    _service.unsubscribeCategories();
  }
}
