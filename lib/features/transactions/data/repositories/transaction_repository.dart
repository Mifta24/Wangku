import 'package:uuid/uuid.dart';
import '../../domain/models/transaction_model.dart';
import '../services/transaction_service.dart';

abstract class ITransactionRepository {
  Future<List<TransactionModel>> getTransactions({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<TransactionModel> addTransaction(TransactionModel transaction);
  Future<TransactionModel> updateTransaction(String id, TransactionModel transaction);
  Future<void> deleteTransaction(String id);
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
  }) {
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
  ) {
    return _service.updateTransaction(id, transaction);
  }

  @override
  Future<void> deleteTransaction(String id) {
    return _service.deleteTransaction(id);
  }

  @override
  Future<Map<String, double>> getMonthlyAggregates({
    required String userId,
    required DateTime month,
  }) {
    return _service.getMonthlyAggregates(userId: userId, month: month);
  }

  @override
  Future<List<Map<String, dynamic>>> getCategoryDistribution({
    required String userId,
    required DateTime month,
    required String type,
  }) {
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
}
