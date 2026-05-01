import 'package:flutter/material.dart';
import '../../domain/models/transaction_model.dart';
import '../../domain/models/category_model.dart';
import '../../data/repositories/transaction_repository.dart';

class TransactionProvider extends ChangeNotifier {
  final TransactionRepository _repository = TransactionRepository();

  // State
  List<TransactionModel> _transactions = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _selectedMonth = DateTime.now();

  // Getters
  List<TransactionModel> get transactions => _transactions;
  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime get selectedMonth => _selectedMonth;

  // Computed getters
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

  double get monthIncome {
    return monthTransactions
        .where((t) => t.type == 'income')
        .fold(0, (sum, t) => sum + t.amount);
  }

  double get monthExpense {
    return monthTransactions
        .where((t) => t.type == 'expense')
        .fold(0, (sum, t) => sum + t.amount);
  }

  double get monthBalance => monthIncome - monthExpense;

  List<CategoryModel> get expenseCategories =>
      _categories.where((c) => c.type == 'expense').toList();

  List<CategoryModel> get incomeCategories =>
      _categories.where((c) => c.type == 'income').toList();

  /// Load initial data (categories + transaksi untuk bulan ini)
  Future<void> initialize(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      // Load categories
      await loadCategories();

      // Load transaksi bulan ini
      final startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
      await _loadTransactions(userId, startDate, endDate);

      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  /// Load transaksi dengan date range
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

  /// Load categories
  Future<void> loadCategories() async {
    try {
      final cats = await _repository.getCategories();
      _categories = cats;
      notifyListeners();
    } catch (e) {
      _setError('Gagal load kategori: ${e.toString()}');
      notifyListeners();
    }
  }

  /// Load transaksi untuk bulan tertentu
  Future<void> loadMonth(String userId, DateTime month) async {
    _selectedMonth = month;
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 1);
    await _loadTransactions(userId, startDate, endDate);
  }

  /// Load transaksi untuk rentang tanggal tertentu.
  Future<void> loadByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    await _loadTransactions(userId, startDate, endDate);
  }

  /// Add transaksi baru (Quick Add)
  Future<void> addTransaction(
    TransactionModel transaction,
    String userId,
  ) async {
    try {
      _clearError();
      final newTxn = await _repository.addTransaction(transaction);

      // Tambah ke state lokal immediately untuk UI responsiveness
      _transactions.insert(0, newTxn);
      notifyListeners();
    } catch (e) {
      _setError('Gagal tambah transaksi: ${e.toString()}');
      notifyListeners();
      rethrow;
    }
  }

  /// Update transaksi
  Future<void> updateTransaction(
    String transactionId,
    TransactionModel transaction,
  ) async {
    try {
      _clearError();
      final updated = await _repository.updateTransaction(
        transactionId,
        transaction,
      );

      // Update di state
      final index = _transactions.indexWhere((t) => t.id == transactionId);
      if (index != -1) {
        _transactions[index] = updated;
        notifyListeners();
      }
    } catch (e) {
      _setError('Gagal update transaksi: ${e.toString()}');
      notifyListeners();
      rethrow;
    }
  }

  /// Delete transaksi
  Future<void> deleteTransaction(String transactionId) async {
    try {
      _clearError();
      await _repository.deleteTransaction(transactionId);

      // Remove dari state
      _transactions.removeWhere((t) => t.id == transactionId);
      notifyListeners();
    } catch (e) {
      _setError('Gagal hapus transaksi: ${e.toString()}');
      notifyListeners();
      rethrow;
    }
  }

  /// Get transaksi berdasarkan kategori
  List<TransactionModel> getTransactionsByCategory(String categoryId) {
    return monthTransactions
        .where((t) => t.categoryId == categoryId)
        .toList();
  }

  /// Get kategori distribution untuk pie chart
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

  /// Get monthly aggregates (income vs expense)
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

  /// Search transaksi
  List<TransactionModel> searchTransactions(String query) {
    if (query.isEmpty) return monthTransactions;

    final lowerQuery = query.toLowerCase();
    return monthTransactions
        .where((t) =>
            t.note.toLowerCase().contains(lowerQuery) ||
            t.category?.name.toLowerCase().contains(lowerQuery) == true)
        .toList();
  }

  /// Filter transaksi by type
  List<TransactionModel> filterByType(String type) {
    return monthTransactions.where((t) => t.type == type).toList();
  }

  /// Private helper methods
  void _setLoading(bool value) {
    _isLoading = value;
  }

  void _setError(String? message) {
    _errorMessage = message;
  }

  void _clearError() {
    _errorMessage = null;
  }

  /// Refresh data (call when app comes back to foreground)
  Future<void> refresh(String userId) async {
    final startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    await _loadTransactions(userId, startDate, endDate);
  }

  /// Clear state (on logout)
  void clear() {
    _transactions = [];
    _categories = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
