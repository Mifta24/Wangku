import 'package:flutter/material.dart';

import '../../../../core/database/hive_manager.dart';
import '../../../../core/notifications/app_notification_record.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../dashboard/data/repositories/app_notification_repository.dart';
import '../../../transactions/data/repositories/transaction_repository.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/services/report_service.dart';

class BudgetProvider extends ChangeNotifier {
  final TransactionProvider txnProvider;
  final BudgetRepository _budgetRepository = BudgetRepository();
  final TransactionRepository _transactionRepository = TransactionRepository();
  final ReportService _reportService = ReportService();
  final HiveManager _hiveManager = HiveManager.instance;
  final AppNotificationRepository _notificationRepository =
      AppNotificationRepository();

  Map<String, double> _categoryBudgets = {};
  bool _isLoading = false;
  String? _errorMessage;
  String? _userId;
  DateTime? _lastBudgetAlertDate;
  bool _alertInProgress = false;
  bool _isDisposed = false;
  bool _notificationsEnabled = true;
  DateTime _selectedMonth = DateTime.now();

  static const double _warningThreshold = 0.8;

  BudgetProvider({required this.txnProvider}) {
    txnProvider.addListener(_onTransactionsChanged);
  }

  Map<String, double> get categoryBudgets => _categoryBudgets;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get notificationsEnabled => _notificationsEnabled;
  DateTime get selectedMonth => _selectedMonth;
  bool get isCurrentMonth => _isSameMonth(_selectedMonth, DateTime.now());
  String get periodLabel {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  double get monthExpense {
    return txnProvider.transactions
        .where(
          (t) =>
              t.type == 'expense' &&
              _categoryBudgets.containsKey(t.categoryId) &&
              _isSameMonth(t.date, _selectedMonth),
        )
        .fold<double>(0.0, (p, e) => p + e.amount);
  }

  double get totalCategoryBudget =>
      _categoryBudgets.values.fold(0.0, (sum, v) => sum + v);

  double categoryExpense(String categoryId) {
    return txnProvider.transactions
        .where(
          (t) =>
              t.type == 'expense' &&
              t.categoryId == categoryId &&
              _isSameMonth(t.date, _selectedMonth),
        )
        .fold<double>(0.0, (p, e) => p + e.amount);
  }

  double? categoryBudget(String categoryId) => _categoryBudgets[categoryId];

  double categoryProgress(String categoryId) {
    final budget = categoryBudget(categoryId);
    if (budget == null || budget <= 0) return 0.0;
    return categoryExpense(categoryId) / budget;
  }

  double categoryRemaining(String categoryId) {
    final budget = categoryBudget(categoryId);
    if (budget == null) return 0.0;
    return budget - categoryExpense(categoryId);
  }

  double get remaining => totalCategoryBudget - monthExpense;

  double get progress {
    final total = totalCategoryBudget;
    if (total <= 0) return 0.0;
    return monthExpense / total;
  }

  Future<void> loadBudget(String userId) async {
    _userId = userId;
    try {
      _lastBudgetAlertDate = await _hiveManager.getBudgetAlertLastDate(userId);
      final settings = await _hiveManager.getBudgetNotificationSettings(userId);
      _notificationsEnabled = (settings?['enabled'] as bool?) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setNotificationsEnabled(String userId, bool enabled) async {
    _userId = userId;
    _notificationsEnabled = enabled;
    notifyListeners();
    try {
      await _hiveManager.saveBudgetNotificationSettings(
        userId,
        enabled: _notificationsEnabled,
      );
    } catch (_) {}
  }

  Future<void> loadCategoryBudgets(String userId, [DateTime? month]) async {
    _userId = userId;
    if (month != null) {
      _selectedMonth = DateTime(month.year, month.month, 1);
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      // Supabase utama, Hive fallback (ditangani di repository)
      _categoryBudgets = await _budgetRepository.getCategoryBudgets(
        userId,
        _selectedMonth,
      );
      // Reset alert date cache supaya dicek ulang dari Hive
      _lastBudgetAlertDate = await _hiveManager.getBudgetAlertLastDate(userId);
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
    _budgetRepository.subscribeToBudgets(userId, _silentRefreshBudgets);
  }

  Future<void> _silentRefreshBudgets() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      _categoryBudgets = await _budgetRepository.getCategoryBudgets(userId, _selectedMonth);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setSelectedMonth(String userId, DateTime month) async {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final targetMonth = DateTime(month.year, month.month, 1);
    if (targetMonth.isAfter(currentMonth)) return;
    await loadCategoryBudgets(userId, targetMonth);
  }

  Future<void> previousMonth(String userId) {
    return setSelectedMonth(
      userId,
      DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1),
    );
  }

  Future<void> nextMonth(String userId) {
    return setSelectedMonth(
      userId,
      DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1),
    );
  }

  Future<bool> copyPreviousMonthBudgets(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final previousMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );
      final previousBudgets = await _budgetRepository.getCategoryBudgets(
        userId,
        previousMonth,
      );
      if (previousBudgets.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      for (final entry in previousBudgets.entries) {
        await _budgetRepository.saveCategoryBudget(
          userId,
          entry.key,
          entry.value,
          _selectedMonth,
        );
      }
      _categoryBudgets = previousBudgets;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> saveCategoryBudget(
    String userId,
    String categoryId,
    double amount,
  ) async {
    _userId = userId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _budgetRepository.saveCategoryBudget(
        userId,
        categoryId,
        amount,
        _selectedMonth,
      );
      _categoryBudgets = {..._categoryBudgets, categoryId: amount};
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteCategoryBudget(String userId, String categoryId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _budgetRepository.deleteCategoryBudget(
        userId,
        categoryId,
        _selectedMonth,
      );
      _categoryBudgets = Map.from(_categoryBudgets)..remove(categoryId);
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Cek & kirim notif kategori setelah input transaksi pengeluaran.
  Future<void> checkCategoryWarningAfterTransaction(
    String categoryId,
    String categoryName,
    DateTime transactionDate,
  ) async {
    if (!_notificationsEnabled) return;
    if (!_isSameMonth(transactionDate, DateTime.now())) return;
    final userId = _userId;
    if (userId == null) return;

    final now = DateTime.now();
    double ratio;
    double rem;

    try {
      final alerts = await _reportService.checkBudgetAlerts(
        userId: userId,
        year: now.year,
        month: now.month,
      );
      final item = alerts.where((a) => a.categoryId == categoryId).firstOrNull;
      if (item == null || item.budget <= 0) return;
      ratio = item.spent / item.budget;
      rem = item.budget - item.spent;
    } catch (_) {
      // Fallback ke kalkulasi lokal jika RPC gagal
      final budget = await _categoryBudgetForMonth(categoryId, now);
      if (budget == null || budget <= 0) return;
      final expense = await _categoryExpenseForMonth(categoryId, now)
          .catchError((_) => categoryExpense(categoryId));
      ratio = expense / budget;
      rem = budget - expense;
    }

    if (ratio < _warningThreshold) return;

    final isOver = ratio >= 1.0;
    final title = isOver ? 'Anggaran Habis!' : 'Peringatan Anggaran!';
    final body = isOver
        ? 'Pengeluaranmu di $categoryName sudah melebihi batas anggaran.'
        : 'Anggaran kategori $categoryName sisa ${_formatRupiah(rem)}.';

    await _notificationRepository.addNotification(
      AppNotificationRecord.create(
        userId: userId,
        title: title,
        body: body,
        type: 'category_budget',
      ),
    );
    await NotificationService.instance.showCategoryBudgetWarning(
      categoryName: categoryName,
      percent: ratio,
      remaining: rem,
      categoryId: categoryId,
    );

    // Total anggaran — dinonaktifkan sementara
    // await _maybeNotifyBudgetWarning();
  }

  void _onTransactionsChanged() {
    if (_isDisposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed) return;
      notifyListeners();
      // _maybeNotifyBudgetWarning();
    });
  }

  // ignore: unused_element
  Future<void> _maybeNotifyBudgetWarning() async {
    if (_alertInProgress) return;
    final userId = _userId;
    if (userId == null) return;
    if (!_notificationsEnabled) return;
    if (totalCategoryBudget <= 0) return;
    if (progress < _warningThreshold) return;

    final now = DateTime.now();
    final last = _lastBudgetAlertDate ??
        await _hiveManager.getBudgetAlertLastDate(userId);
    if (_isSameDay(last, now)) return;

    _alertInProgress = true;
    final isOver = progress >= 1.0;
    final title = isOver ? 'Anggaran Habis!' : 'Peringatan Anggaran!';
    final body = isOver
        ? 'Total pengeluaran kamu sudah melebihi batas anggaran.'
        : 'Total pengeluaran kamu sudah mencapai ${(progress * 100).toStringAsFixed(0)}% dari anggaran.';

    // Simpan ke database dulu
    await _notificationRepository.addNotification(
      AppNotificationRecord.create(
        userId: userId,
        title: title,
        body: body,
        type: 'budget',
      ),
    );
    // Baru kirim push notif ke HP — supaya keduanya selalu sinkron
    await NotificationService.instance.showBudgetWarning(
      percent: progress,
      remaining: remaining,
    );
    await _hiveManager.saveBudgetAlertLastDate(userId, now);
    _lastBudgetAlertDate = now;
    _alertInProgress = false;
  }

  String _formatRupiah(double amount) {
    final absAmount = amount.abs().toStringAsFixed(0);
    String result = '';
    int count = 0;
    for (var i = absAmount.length - 1; i >= 0; i--) {
      result = absAmount[i] + result;
      count++;
      if (count == 3 && i > 0) {
        result = '.$result';
        count = 0;
      }
    }
    return 'Rp $result';
  }

  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  Future<double> _categoryExpenseForMonth(
    String categoryId,
    DateTime month,
  ) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final userId = _userId;

    if (txnProvider.hasLoadedRange(start, end)) {
      return txnProvider.transactions
          .where(
            (t) =>
                t.type == 'expense' &&
                t.categoryId == categoryId &&
                !t.date.isBefore(start) &&
                t.date.isBefore(end),
          )
          .fold<double>(0.0, (p, e) => p + e.amount);
    }

    if (userId == null) return categoryExpense(categoryId);

    final transactions = await _transactionRepository.getTransactions(
      userId: userId,
      startDate: start,
      endDate: end,
    );

    return transactions
        .where((t) => t.type == 'expense' && t.categoryId == categoryId)
        .fold<double>(0.0, (p, e) => p + e.amount);
  }

  Future<double?> _categoryBudgetForMonth(
    String categoryId,
    DateTime month,
  ) async {
    if (_isSameMonth(month, _selectedMonth)) return categoryBudget(categoryId);
    final userId = _userId;
    if (userId == null) return null;
    final budgets = await _budgetRepository.getCategoryBudgets(userId, month);
    return budgets[categoryId];
  }

  @override
  void dispose() {
    _isDisposed = true;
    txnProvider.removeListener(_onTransactionsChanged);
    _budgetRepository.unsubscribeBudgets();
    super.dispose();
  }
}
