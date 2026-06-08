import 'package:flutter/material.dart';
import '../../domain/models/transaction_model.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../../categories/domain/models/category_model.dart';
import '../../../categories/data/repositories/category_repository.dart';
import '../../../budget/data/repositories/budget_repository.dart';

class TransactionProvider extends ChangeNotifier {
  final TransactionRepository _repository = TransactionRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final BudgetRepository _budgetRepository = BudgetRepository();

  List<TransactionModel> _transactions = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _selectedMonth = DateTime.now();
  DateTime? _loadedStartDate;
  DateTime? _loadedEndDate;

  List<TransactionModel> get transactions => _transactions;
  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime get selectedMonth => _selectedMonth;

  bool hasLoadedRange(DateTime startDate, DateTime endDate) {
    final loadedStart = _loadedStartDate;
    final loadedEnd = _loadedEndDate;
    if (loadedStart == null || loadedEnd == null) return false;
    return !startDate.isBefore(loadedStart) && !endDate.isAfter(loadedEnd);
  }

  List<TransactionModel> get todayTransactions {
    final today = DateTime.now();
    return _transactions
        .where((t) =>
            t.date.year == today.year &&
            t.date.month == today.month &&
            t.date.day == today.day)
        .toList();
  }

  List<TransactionModel> get monthTransactions {
    return _transactions
        .where((t) =>
            t.date.year == _selectedMonth.year &&
            t.date.month == _selectedMonth.month)
        .toList();
  }

  double get monthIncome =>
      monthTransactions.where((t) => t.type == 'income').fold(0, (s, t) => s + t.amount);

  double get monthExpense =>
      monthTransactions.where((t) => t.type == 'expense').fold(0, (s, t) => s + t.amount);

  double get monthBalance => monthIncome - monthExpense;

  List<CategoryModel> get expenseCategories =>
      _categories.where((c) => c.type == 'expense').toList();

  List<CategoryModel> get incomeCategories =>
      _categories.where((c) => c.type == 'income').toList();

  Future<void> initialize(String userId) async {
    _setLoading(true);
    _clearError();
    try {
      await loadCategories(userId);
      final startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
      await _loadTransactions(userId, startDate, endDate);
      _setLoading(false);
      _subscribeRealtime(userId);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  void _subscribeRealtime(String userId) {
    _repository.unsubscribeTransactions();
    _categoryRepository.unsubscribeCategories();
    _repository.subscribeToTransactions(userId, () => _silentRefresh(userId));
    _categoryRepository.subscribeToCategories(userId, () => _silentRefreshCategories(userId));
  }

  Future<void> _silentRefreshCategories(String userId) async {
    try {
      final cats = await _categoryRepository.getCategories(userId);
      _categories = cats;
      _transactions = _transactions.map((t) {
        final cat = cats.cast<CategoryModel?>().firstWhere(
          (c) => c?.id == t.categoryId,
          orElse: () => null,
        );
        return cat != null ? t.copyWith(category: cat) : t;
      }).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _silentRefresh(String userId) async {
    final start = _loadedStartDate;
    final end = _loadedEndDate;
    if (start == null || end == null) return;
    try {
      final txs = await _repository.getTransactions(
        userId: userId,
        startDate: start,
        endDate: end,
      );
      _transactions = txs;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadTransactions(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      _setLoading(true);
      _clearError();
      final txs = await _repository.getTransactions(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );
      _loadedStartDate = startDate;
      _loadedEndDate = endDate;
      _transactions = txs;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Gagal load transaksi: ${e.toString()}');
      _setLoading(false);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadCategories(String userId) async {
    try {
      final cats = await _categoryRepository.getCategories(userId);
      _categories = cats;
      notifyListeners();
    } catch (e) {
      _setError('Gagal load kategori: ${e.toString()}');
      notifyListeners();
    }
  }

  Future<void> addCustomCategory(CategoryModel category) async {
    try {
      _clearError();
      final newCat = await _categoryRepository.createCategory(category);
      _categories.add(newCat);
      notifyListeners();
    } catch (e) {
      _setError('Gagal tambah kategori: ${e.toString()}');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateCategory(CategoryModel category) async {
    try {
      _clearError();
      final updated = await _categoryRepository.updateCategory(category);
      final index = _categories.indexWhere((c) => c.id == updated.id);
      if (index != -1) _categories[index] = updated;
      _transactions = _transactions.map((t) {
        final cat = _categories.cast<CategoryModel?>().firstWhere(
          (c) => c?.id == t.categoryId,
          orElse: () => null,
        );
        return cat != null ? t.copyWith(category: cat) : t;
      }).toList();
      notifyListeners();
    } catch (e) {
      _setError('Gagal update kategori: ${e.toString()}');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteCategory(CategoryModel category) async {
    try {
      _clearError();
      final isUsed = _transactions.any((t) => t.categoryId == category.id);
      if (isUsed) {
        throw Exception(
          'Kategori masih dipakai transaksi. Ubah atau hapus transaksinya dulu.',
        );
      }
      await _categoryRepository.deleteCategory(category);
      await _budgetRepository.deleteCategoryBudget(category.userId!, category.id);
      _categories.removeWhere((c) => c.id == category.id);
      notifyListeners();
    } catch (e) {
      _setError('Gagal hapus kategori: ${e.toString()}');
      notifyListeners();
      rethrow;
    }
  }

  List<CategoryModel> getFrequentCategories(String type, {int limit = 4}) {
    final relevantTxs = _transactions.where((t) => t.type == type).toList();
    if (relevantTxs.isEmpty) return [];
    final Map<String, int> frequencies = {};
    for (var tx in relevantTxs) {
      frequencies[tx.categoryId] = (frequencies[tx.categoryId] ?? 0) + 1;
    }
    final sortedIds = frequencies.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedIds
        .take(limit)
        .map((e) => _categories.cast<CategoryModel?>()
            .firstWhere((c) => c?.id == e.key, orElse: () => null))
        .whereType<CategoryModel>()
        .toList();
  }

  Future<void> loadMonth(String userId, DateTime month) async {
    _selectedMonth = month;
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 1);
    await _loadTransactions(userId, startDate, endDate);
  }

  Future<void> loadByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    await _loadTransactions(userId, startDate, endDate);
  }

  Future<void> addTransaction(TransactionModel transaction, String userId) async {
    try {
      _clearError();
      final newTxn = await _repository.addTransaction(transaction);
      if (_isWithinLoadedRange(newTxn.date)) {
        _transactions.insert(0, newTxn);
      }
      notifyListeners();
    } catch (e) {
      _setError('Gagal tambah transaksi: ${e.toString()}');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateTransaction(
    String transactionId,
    TransactionModel transaction,
  ) async {
    try {
      _clearError();
      final updated = await _repository.updateTransaction(transactionId, transaction);
      final index = _transactions.indexWhere((t) => t.id == transactionId);
      if (index != -1) {
        if (_isWithinLoadedRange(updated.date)) {
          _transactions[index] = updated;
        } else {
          _transactions.removeAt(index);
        }
      } else if (_isWithinLoadedRange(updated.date)) {
        _transactions.insert(0, updated);
      }
      notifyListeners();
    } catch (e) {
      _setError('Gagal update transaksi: ${e.toString()}');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    try {
      _clearError();
      await _repository.deleteTransaction(transactionId);
      _transactions.removeWhere((t) => t.id == transactionId);
      notifyListeners();
    } catch (e) {
      _setError('Gagal hapus transaksi: ${e.toString()}');
      notifyListeners();
      rethrow;
    }
  }

  List<TransactionModel> getTransactionsByCategory(String categoryId) {
    return monthTransactions.where((t) => t.categoryId == categoryId).toList();
  }

  Future<List<Map<String, dynamic>>> getCategoryDistribution(
    String userId,
    String type,
  ) async {
    try {
      return await _repository.getCategoryDistribution(
        userId: userId,
        month: _selectedMonth,
        type: type,
      );
    } catch (e) {
      _setError('Gagal load category distribution: ${e.toString()}');
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, double>> getMonthlyAggregates(String userId) async {
    try {
      return await _repository.getMonthlyAggregates(
        userId: userId,
        month: _selectedMonth,
      );
    } catch (e) {
      _setError('Gagal load aggregates: ${e.toString()}');
      notifyListeners();
      rethrow;
    }
  }

  List<TransactionModel> searchTransactions(String query) {
    if (query.isEmpty) return monthTransactions;
    final lowerQuery = query.toLowerCase();
    return monthTransactions
        .where((t) =>
            t.note.toLowerCase().contains(lowerQuery) ||
            t.category?.name.toLowerCase().contains(lowerQuery) == true)
        .toList();
  }

  List<TransactionModel> filterByType(String type) {
    return monthTransactions.where((t) => t.type == type).toList();
  }

  void _setLoading(bool value) => _isLoading = value;
  void _setError(String? message) => _errorMessage = message;
  void _clearError() => _errorMessage = null;

  bool _isWithinLoadedRange(DateTime date) {
    final loadedStart = _loadedStartDate;
    final loadedEnd = _loadedEndDate;
    if (loadedStart == null || loadedEnd == null) return true;
    return !date.isBefore(loadedStart) && date.isBefore(loadedEnd);
  }

  Future<void> refresh(String userId) async {
    final start = _loadedStartDate;
    final end = _loadedEndDate;
    if (start != null && end != null) {
      await _loadTransactions(userId, start, end);
    } else {
      final startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
      await _loadTransactions(userId, startDate, endDate);
    }
  }

  void clear() {
    _repository.unsubscribeTransactions();
    _categoryRepository.unsubscribeCategories();
    _transactions = [];
    _categories = [];
    _loadedStartDate = null;
    _loadedEndDate = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
