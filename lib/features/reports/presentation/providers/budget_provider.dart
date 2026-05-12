import 'package:flutter/material.dart';

import '../../../../core/database/hive_manager.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';

class BudgetProvider extends ChangeNotifier {
  final TransactionProvider txnProvider;
  final HiveManager _hiveManager = HiveManager.instance;

  Map<String, double> _categoryBudgets = {};
  bool _isLoading = false;
  String? _errorMessage;
  String? _userId;
  DateTime? _lastBudgetAlertDate;
  bool _alertInProgress = false;
  bool _isDisposed = false;
  bool _notificationsEnabled = true;
  double _warningThreshold = 0.8;
  String _notificationTitle = 'Anggaran mendekati limit';
  String _notificationBody = 'Sudah terpakai {percent}%. Sisa {remaining}.';

  BudgetProvider({required this.txnProvider}) {
    txnProvider.addListener(_onTransactionsChanged);
  }

  Map<String, double> get categoryBudgets => _categoryBudgets;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get notificationsEnabled => _notificationsEnabled;
  double get warningThreshold => _warningThreshold;
  String get notificationTitle => _notificationTitle;
  String get notificationBody => _notificationBody;

  double get monthExpense => txnProvider.monthExpense;

  /// Total anggaran = jumlah semua anggaran kategori yang sudah di-set
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
    final ratio = categoryExpense(categoryId) / budget;
    return ratio.clamp(0.0, 1.0);
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
      final settings =
          await _hiveManager.getBudgetNotificationSettings(userId);
      _notificationsEnabled = (settings?['enabled'] as bool?) ?? true;
      _warningThreshold =
          ((settings?['threshold'] as num?)?.toDouble() ?? 0.8).clamp(0.1, 1.0);
      _notificationTitle =
          (settings?['title'] as String?) ?? 'Anggaran mendekati limit';
      _notificationBody = (settings?['body'] as String?) ??
          'Sudah terpakai {percent}%. Sisa {remaining}.';
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setNotificationsEnabled(String userId, bool enabled) async {
    _userId = userId;
    _notificationsEnabled = enabled;
    notifyListeners();
    await saveNotificationSettings(userId);
  }

  Future<void> saveNotificationSettings(
    String userId, {
    bool? enabled,
    double? threshold,
    String? title,
    String? body,
  }) async {
    _userId = userId;
    if (enabled != null) _notificationsEnabled = enabled;
    if (threshold != null) _warningThreshold = threshold.clamp(0.1, 1.0);
    if (title != null && title.trim().isNotEmpty) {
      _notificationTitle = title.trim();
    }
    if (body != null && body.trim().isNotEmpty) {
      _notificationBody = body.trim();
    }
    notifyListeners();
    try {
      await _hiveManager.saveBudgetNotificationSettings(
        userId,
        enabled: _notificationsEnabled,
        threshold: _warningThreshold,
        title: _notificationTitle,
        body: _notificationBody,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadCategoryBudgets(String userId) async {
    _userId = userId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _categoryBudgets = await _hiveManager.getCategoryBudgets(userId);
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
    await _maybeNotifyBudgetWarning();
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
      await _hiveManager.saveCategoryBudget(userId, categoryId, amount);
      _categoryBudgets = {
        ..._categoryBudgets,
        categoryId: amount,
      };
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Dipanggil setelah user input transaksi pengeluaran.
  /// Jika pemakaian anggaran kategori >= 80%, langsung tampilkan notifikasi.
  Future<void> checkCategoryWarningAfterTransaction(
    String categoryId,
    String categoryName,
  ) async {
    final budget = categoryBudget(categoryId);
    if (!_notificationsEnabled) return;
    if (budget == null || budget <= 0) return;
    final prog = categoryProgress(categoryId);
    if (prog < _warningThreshold) return;
    final rem = categoryRemaining(categoryId);
    await NotificationService.instance.showCategoryBudgetWarning(
      categoryName: categoryName,
      percent: prog,
      remaining: rem,
      categoryId: categoryId,
      title: _formatTemplate(_notificationTitle, categoryName, prog, rem),
      body: _formatTemplate(_notificationBody, categoryName, prog, rem),
    );
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
    await NotificationService.instance.showBudgetWarning(
      percent: progress,
      remaining: remaining,
      title: _formatTemplate(_notificationTitle, null, progress, remaining),
      body: _formatTemplate(_notificationBody, null, progress, remaining),
    );
    await _hiveManager.saveBudgetAlertLastDate(userId, now);
    _lastBudgetAlertDate = now;
    _alertInProgress = false;
  }

  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatTemplate(
    String template,
    String? categoryName,
    double percent,
    double remaining,
  ) {
    return template
        .replaceAll('{category}', categoryName ?? 'Total')
        .replaceAll('{percent}', (percent * 100).toStringAsFixed(0))
        .replaceAll('{remaining}', 'Rp ${remaining.toStringAsFixed(0)}');
  }

  @override
  void dispose() {
    _isDisposed = true;
    txnProvider.removeListener(_onTransactionsChanged);
    super.dispose();
  }
}
