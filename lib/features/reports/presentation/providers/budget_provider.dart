import 'package:flutter/material.dart';

import '../../../../core/database/hive_manager.dart';
import '../../../../core/notifications/app_notification_record.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../dashboard/data/repositories/app_notification_repository.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../data/repositories/budget_repository.dart';

class BudgetProvider extends ChangeNotifier {
  final TransactionProvider txnProvider;
  final BudgetRepository _budgetRepository = BudgetRepository();
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

  static const double _warningThreshold = 0.8;

  BudgetProvider({required this.txnProvider}) {
    txnProvider.addListener(_onTransactionsChanged);
  }

  Map<String, double> get categoryBudgets => _categoryBudgets;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get notificationsEnabled => _notificationsEnabled;

  double get monthExpense {
    return txnProvider.monthTransactions
        .where((t) => t.type == 'expense' && _categoryBudgets.containsKey(t.categoryId))
        .fold<double>(0.0, (p, e) => p + e.amount);
  }

  double get totalCategoryBudget =>
      _categoryBudgets.values.fold(0.0, (sum, v) => sum + v);

  double categoryExpense(String categoryId) {
    return txnProvider.monthTransactions
        .where((t) => t.type == 'expense' && t.categoryId == categoryId)
        .fold<double>(0.0, (p, e) => p + e.amount);
  }

  double? categoryBudget(String categoryId) => _categoryBudgets[categoryId];

  double categoryProgress(String categoryId) {
    final budget = categoryBudget(categoryId);
    if (budget == null || budget <= 0) return 0.0;
    return (categoryExpense(categoryId) / budget).clamp(0.0, 1.0);
  }

  double categoryRemaining(String categoryId) {
    final budget = categoryBudget(categoryId);
    if (budget == null) return 0.0;
    return (budget - categoryExpense(categoryId)).clamp(0.0, double.infinity);
  }

  double get remaining =>
      (totalCategoryBudget - monthExpense).clamp(0.0, double.infinity);

  double get progress {
    final total = totalCategoryBudget;
    if (total <= 0) return 0.0;
    return (monthExpense / total).clamp(0.0, 1.0);
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

  Future<void> loadCategoryBudgets(String userId) async {
    _userId = userId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      // Supabase utama, Hive fallback (ditangani di repository)
      _categoryBudgets = await _budgetRepository.getCategoryBudgets(userId);
      // Reset alert date cache supaya dicek ulang dari Hive
      _lastBudgetAlertDate = await _hiveManager.getBudgetAlertLastDate(userId);
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
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
      await _budgetRepository.saveCategoryBudget(userId, categoryId, amount);
      _categoryBudgets = {..._categoryBudgets, categoryId: amount};
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();

    // Cek langsung apakah pengeluaran yang sudah ada sudah melewati threshold
    // Ini penting saat budget dihapus lalu ditambah lagi — tidak perlu tunggu transaksi baru
    try {
      final category = txnProvider.categories
          .where((c) => c.id == categoryId)
          .firstOrNull;
      if (category != null) {
        await checkCategoryWarningAfterTransaction(categoryId, category.name);
      }
    } catch (_) {}
  }

  Future<void> deleteCategoryBudget(String userId, String categoryId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _budgetRepository.deleteCategoryBudget(userId, categoryId);
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
  ) async {
    if (!_notificationsEnabled) return;
    final budget = categoryBudget(categoryId);
    if (budget == null || budget <= 0) return;

    final expense = categoryExpense(categoryId);
    final ratio = expense / budget;
    if (ratio < _warningThreshold) return;

    final rem = categoryRemaining(categoryId);
    final userId = _userId;
    if (userId != null) {
      final isOver = ratio >= 1.0;
      final title = isOver ? 'Anggaran Habis!' : 'Peringatan Anggaran!';
      final body = isOver
          ? 'Pengeluaranmu di $categoryName sudah melebihi batas anggaran.'
          : 'Anggaran kategori $categoryName sisa ${_formatRupiah(rem)}.';

      // Simpan ke database dulu
      await _notificationRepository.addNotification(
        AppNotificationRecord.create(
          userId: userId,
          title: title,
          body: body,
          type: 'category_budget',
        ),
      );
      // Baru kirim push notif ke HP — supaya keduanya selalu sinkron
      await NotificationService.instance.showCategoryBudgetWarning(
        categoryName: categoryName,
        percent: ratio,
        remaining: rem,
        categoryId: categoryId,
      );
    }

    // Setelah cek kategori, cek juga total anggaran
    await _maybeNotifyBudgetWarning();
  }

  void _onTransactionsChanged() {
    if (_isDisposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed) return;
      notifyListeners();
      _maybeNotifyBudgetWarning();
    });
  }

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

  @override
  void dispose() {
    _isDisposed = true;
    txnProvider.removeListener(_onTransactionsChanged);
    super.dispose();
  }
}
