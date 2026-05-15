import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../features/transactions/domain/models/transaction_model.dart';
import '../../features/transactions/domain/models/category_model.dart';
import '../../features/transactions/domain/models/shortcut_model.dart';

class HiveManager {
  static final HiveManager _instance = HiveManager._internal();

  factory HiveManager() {
    return _instance;
  }

  static HiveManager get instance => _instance;

  HiveManager._internal();

  // Box names
  static const String _transactionsBox = 'transactions';
  static const String _categoriesBox = 'categories';
  static const String _userBox = 'user';
  static const String _budgetBox = 'budget';

  // Lazy initialization
  Box<dynamic>? _txnBox;
  Box<dynamic>? _catBox;
  Box<dynamic>? _userBoxInstance;
  Box<dynamic>? _budgetBoxInstance;

  /// Inisialisasi semua boxes (call di main.dart)
  Future<void> initializeBoxes() async {
    try {
      _txnBox = await Hive.openBox<dynamic>(_transactionsBox);
      _catBox = await Hive.openBox<dynamic>(_categoriesBox);
      _userBoxInstance = await Hive.openBox<dynamic>(_userBox);
      _budgetBoxInstance = await Hive.openBox<dynamic>(_budgetBox);
    } catch (e) {
      debugPrint('Error initializing Hive boxes: $e');
      rethrow;
    }
  }

  /// Save transaksi ke Hive
  Future<void> saveTransaction(TransactionModel transaction) async {
    try {
      final box = _txnBox ?? await Hive.openBox<dynamic>(_transactionsBox);
      await box.put(transaction.id, transaction.toJson());
    } catch (e) {
      debugPrint('Error saving transaction: $e');
      rethrow;
    }
  }

  /// Get transaksi by ID
  Future<TransactionModel?> getTransaction(String id) async {
    try {
      final box = _txnBox ?? await Hive.openBox<dynamic>(_transactionsBox);
      final data = box.get(id);
      if (data == null) return null;
      return TransactionModel.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('Error getting transaction: $e');
      return null;
    }
  }

  /// Get semua transaksi untuk user tertentu
  Future<List<TransactionModel>> getTransactions(String userId) async {
    try {
      final box = _txnBox ?? await Hive.openBox<dynamic>(_transactionsBox);
      final transactions = <TransactionModel>[];

      for (final key in box.keys) {
        final data = box.get(key);
        if (data != null) {
          final txn = TransactionModel.fromJson(Map<String, dynamic>.from(data));
          if (txn.userId == userId) {
            transactions.add(txn);
          }
        }
      }

      // Sort by date descending
      transactions.sort((a, b) => b.date.compareTo(a.date));
      return transactions;
    } catch (e) {
      debugPrint('Error getting transactions: $e');
      return [];
    }
  }

  /// Cache multiple transactions (untuk sync dari API)
  Future<void> cacheTransactions(List<TransactionModel> transactions) async {
    try {
      final box = _txnBox ?? await Hive.openBox<dynamic>(_transactionsBox);
      for (final txn in transactions) {
        await box.put(txn.id, txn.toJson());
      }
    } catch (e) {
      debugPrint('Error caching transactions: $e');
    }
  }

  /// Delete transaksi by ID
  Future<void> deleteTransaction(String id) async {
    try {
      final box = _txnBox ?? await Hive.openBox<dynamic>(_transactionsBox);
      await box.delete(id);
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
      rethrow;
    }
  }

  /// Clear semua transaksi untuk user tertentu
  Future<void> clearTransactionsForUser(String userId) async {
    try {
      final box = _txnBox ?? await Hive.openBox<dynamic>(_transactionsBox);
      final keysToDelete = <dynamic>[];

      for (final key in box.keys) {
        final data = box.get(key);
        if (data != null) {
          final txn = TransactionModel.fromJson(Map<String, dynamic>.from(data));
          if (txn.userId == userId) {
            keysToDelete.add(key);
          }
        }
      }

      await box.deleteAll(keysToDelete);
    } catch (e) {
      debugPrint('Error clearing transactions: $e');
    }
  }

  /// Save kategori ke Hive
  Future<void> saveCategory(CategoryModel category) async {
    try {
      final box = _catBox ?? await Hive.openBox<dynamic>(_categoriesBox);
      await box.put(category.id, category.toJson());
    } catch (e) {
      debugPrint('Error saving category: $e');
      rethrow;
    }
  }

  /// Get kategori by ID
  Future<CategoryModel?> getCategory(String id) async {
    try {
      final box = _catBox ?? await Hive.openBox<dynamic>(_categoriesBox);
      final data = box.get(id);
      if (data == null) return null;
      return CategoryModel.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('Error getting category: $e');
      return null;
    }
  }

  /// Get semua kategori
  Future<List<CategoryModel>> getCategories() async {
    try {
      final box = _catBox ?? await Hive.openBox<dynamic>(_categoriesBox);
      final categories = <CategoryModel>[];

      for (final key in box.keys) {
        final data = box.get(key);
        if (data != null) {
          categories.add(CategoryModel.fromJson(Map<String, dynamic>.from(data)));
        }
      }

      return categories;
    } catch (e) {
      debugPrint('Error getting categories: $e');
      return [];
    }
  }

  /// Cache multiple categories
  Future<void> cacheCategories(List<CategoryModel> categories) async {
    try {
      final box = _catBox ?? await Hive.openBox<dynamic>(_categoriesBox);
      for (final cat in categories) {
        await box.put(cat.id, cat.toJson());
      }
    } catch (e) {
      debugPrint('Error caching categories: $e');
    }
  }

  /// Save user budget setting
  Future<void> saveBudget(String userId, double monthlyBudget) async {
    try {
      final box = _budgetBoxInstance ?? await Hive.openBox<dynamic>(_budgetBox);
      await box.put('${userId}_budget', {
        'userId': userId,
        'amount': monthlyBudget,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving budget: $e');
      rethrow;
    }
  }

  /// Save user budget per category
  Future<void> saveCategoryBudget(
    String userId,
    String categoryId,
    double monthlyBudget,
  ) async {
    try {
      final box = _budgetBoxInstance ?? await Hive.openBox<dynamic>(_budgetBox);
      final key = '${userId}_category_budget_$categoryId';
      await box.put(key, {
        'userId': userId,
        'categoryId': categoryId,
        'amount': monthlyBudget,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving category budget: $e');
      rethrow;
    }
  }

  /// Get user budget
  Future<double?> getBudget(String userId) async {
    try {
      final box = _budgetBoxInstance ?? await Hive.openBox<dynamic>(_budgetBox);
      final data = box.get('${userId}_budget');
      if (data == null) return null;
      return (data['amount'] as num).toDouble();
    } catch (e) {
      debugPrint('Error getting budget: $e');
      return null;
    }
  }

  /// Get user budget per category
  Future<double?> getCategoryBudget(String userId, String categoryId) async {
    try {
      final box = _budgetBoxInstance ?? await Hive.openBox<dynamic>(_budgetBox);
      final data = box.get('${userId}_category_budget_$categoryId');
      if (data == null) return null;
      return (data['amount'] as num).toDouble();
    } catch (e) {
      debugPrint('Error getting category budget: $e');
      return null;
    }
  }

  /// Save last budget alert date (prevent repeated warnings)
  Future<void> saveBudgetAlertLastDate(String userId, DateTime date) async {
    try {
      final box = _budgetBoxInstance ?? await Hive.openBox<dynamic>(_budgetBox);
      await box.put('${userId}_budget_alert_last', date.toIso8601String());
    } catch (e) {
      debugPrint('Error saving budget alert date: $e');
      rethrow;
    }
  }

  /// Get last budget alert date
  Future<DateTime?> getBudgetAlertLastDate(String userId) async {
    try {
      final box = _budgetBoxInstance ?? await Hive.openBox<dynamic>(_budgetBox);
      final raw = box.get('${userId}_budget_alert_last');
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    } catch (e) {
      debugPrint('Error getting budget alert date: $e');
      return null;
    }
  }

  /// Save daily reminder settings
  Future<void> saveDailyReminder(
    String userId, {
    required bool enabled,
    required int hour,
    required int minute,
    String title = 'Jangan lupa catat transaksi',
    String body = 'Catat pemasukan dan pengeluaran hari ini supaya rapi.',
  }) async {
    try {
      final box = _budgetBoxInstance ?? await Hive.openBox<dynamic>(_budgetBox);
      await box.put('${userId}_daily_reminder', {
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
        'title': title,
        'body': body,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving daily reminder: $e');
      rethrow;
    }
  }

  /// Get daily reminder settings
  Future<Map<String, dynamic>?> getDailyReminder(String userId) async {
    try {
      final box = _budgetBoxInstance ?? await Hive.openBox<dynamic>(_budgetBox);
      final data = box.get('${userId}_daily_reminder');
      if (data == null) return null;
      return Map<String, dynamic>.from(data as Map);
    } catch (e) {
      debugPrint('Error getting daily reminder: $e');
      return null;
    }
  }

  /// Get all category budgets for user
  Future<Map<String, double>> getCategoryBudgets(String userId) async {
    try {
      final box = _budgetBoxInstance ?? await Hive.openBox<dynamic>(_budgetBox);
      final budgets = <String, double>{};
      final prefix = '${userId}_category_budget_';

      for (final key in box.keys) {
        if (key is String && key.startsWith(prefix)) {
          final data = box.get(key);
          if (data == null) continue;
          final amount = data['amount'];
          if (amount == null) continue;
          final categoryId = key.substring(prefix.length);
          budgets[categoryId] = (amount as num).toDouble();
        }
      }

      return budgets;
    } catch (e) {
      debugPrint('Error getting category budgets: $e');
      return {};
    }
  }

  /// Get transaksi yang pending sync (offline transactions)
  Future<List<TransactionModel>> getPendingTransactions() async {
    try {
      final box = _txnBox ?? await Hive.openBox<dynamic>(_transactionsBox);
      final pending = <TransactionModel>[];

      // Pending transactions adalah yang dibuat saat offline (bisa di-detect dari timestamp atau flag)
      // Untuk simplicity, kita assume semua transaksi yang belum synced masih di Hive
      // Di production, tambahkan "synced" flag atau timestamp comparison
      for (final key in box.keys) {
        final data = box.get(key);
        if (data != null) {
          final txn = TransactionModel.fromJson(Map<String, dynamic>.from(data));
          // Check if transaksi belum synced (bisa via timestamp atau flag)
          pending.add(txn);
        }
      }

      return pending;
    } catch (e) {
      debugPrint('Error getting pending transactions: $e');
      return [];
    }
  }

  /// Logout - clear user data
  Future<void> clearUserData(String userId) async {
    try {
      await clearTransactionsForUser(userId);
      final userBox = _userBoxInstance ?? await Hive.openBox<dynamic>(_userBox);
      await userBox.delete(userId);
    } catch (e) {
      debugPrint('Error clearing user data: $e');
    }
  }

  /// Save current user id for background tasks
  Future<void> saveCurrentUserId(String userId) async {
    try {
      final userBox = _userBoxInstance ?? await Hive.openBox<dynamic>(_userBox);
      await userBox.put('current_user_id', userId);
    } catch (e) {
      debugPrint('Error saving current user id: $e');
    }
  }

  /// Get current user id for background tasks
  Future<String?> getCurrentUserId() async {
    try {
      final userBox = _userBoxInstance ?? await Hive.openBox<dynamic>(_userBox);
      return userBox.get('current_user_id') as String?;
    } catch (e) {
      debugPrint('Error getting current user id: $e');
      return null;
    }
  }

  /// Clear current user id
  Future<void> clearCurrentUserId() async {
    try {
      final userBox = _userBoxInstance ?? await Hive.openBox<dynamic>(_userBox);
      await userBox.delete('current_user_id');
    } catch (e) {
      debugPrint('Error clearing current user id: $e');
    }
  }

  /// Save user custom shortcuts
  Future<void> saveShortcuts(String userId, List<String> categoryIds) async {
    await saveShortcutPresets(
      userId,
      categoryIds
          .map((categoryId) => TransactionShortcut(categoryId: categoryId))
          .toList(),
    );
  }

  Future<void> saveBudgetNotificationSettings(
    String userId, {
    required bool enabled,
    double threshold = 0.8,
    String title = 'Anggaran mendekati limit',
    String body = 'Sudah terpakai {percent}%. Sisa {remaining}.',
  }) async {
    try {
      final box = _budgetBoxInstance ?? await Hive.openBox<dynamic>(_budgetBox);
      await box.put('${userId}_budget_notification', {
        'enabled': enabled,
        'threshold': threshold,
        'title': title,
        'body': body,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving budget notification settings: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getBudgetNotificationSettings(
    String userId,
  ) async {
    try {
      final box = _budgetBoxInstance ?? await Hive.openBox<dynamic>(_budgetBox);
      final data = box.get('${userId}_budget_notification');
      if (data == null) return null;
      return Map<String, dynamic>.from(data as Map);
    } catch (e) {
      debugPrint('Error getting budget notification settings: $e');
      return null;
    }
  }

  /// Delete category budget
  Future<void> deleteCategoryBudget(String userId, String categoryId) async {
    try {
      final box = _budgetBoxInstance ?? await Hive.openBox<dynamic>(_budgetBox);
      await box.delete('${userId}_category_budget_$categoryId');
    } catch (e) {
      debugPrint('Error deleting category budget: $e');
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      final box = _catBox ?? await Hive.openBox<dynamic>(_categoriesBox);
      await box.delete(id);
    } catch (e) {
      debugPrint('Error deleting category: $e');
      rethrow;
    }
  }

  Future<void> saveShortcutPresets(
    String userId,
    List<TransactionShortcut> shortcuts,
  ) async {
    try {
      final userBox = _userBoxInstance ?? await Hive.openBox<dynamic>(_userBox);
      await userBox.put(
        '${userId}_shortcuts',
        shortcuts.map((shortcut) => shortcut.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('Error saving shortcuts: $e');
    }
  }

  /// Get user custom shortcuts
  Future<List<String>> getShortcuts(String userId) async {
    final shortcuts = await getShortcutPresets(userId);
    return shortcuts.map((shortcut) => shortcut.categoryId).toList();
  }

  Future<List<TransactionShortcut>> getShortcutPresets(String userId) async {
    try {
      final userBox = _userBoxInstance ?? await Hive.openBox<dynamic>(_userBox);
      final data = userBox.get('${userId}_shortcuts');
      if (data == null) return [];
      final rawItems = List<dynamic>.from(data as List);

      return rawItems.map((item) {
        if (item is String) {
          return TransactionShortcut(categoryId: item);
        }
        return TransactionShortcut.fromJson(Map<String, dynamic>.from(item as Map));
      }).where((shortcut) => shortcut.categoryId.isNotEmpty).toList();
    } catch (e) {
      debugPrint('Error getting shortcuts: $e');
      return [];
    }
  }

  /// Close all boxes (call saat app shutdown)
  Future<void> closeBoxes() async {
    try {
      await _txnBox?.close();
      await _catBox?.close();
      await _userBoxInstance?.close();
      await _budgetBoxInstance?.close();
    } catch (e) {
      debugPrint('Error closing Hive boxes: $e');
    }
  }
}
