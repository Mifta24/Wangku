import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../transactions/data/repositories/transaction_repository.dart';
import '../../../transactions/domain/models/transaction_model.dart';

enum PeriodType { week, month, year }
enum TransactionType { expense, income }

class CategoryDistribution {
  final String categoryId;
  final String name;
  final String icon;
  final double total;
  final String color; // hex
  final double percentage;

  CategoryDistribution({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.total,
    required this.color,
    required this.percentage,
  });
}

class TrendPoint {
  final String label;
  final double income;
  final double expense;

  TrendPoint({
    required this.label,
    required this.income,
    required this.expense,
  });
}

class ReportProvider extends ChangeNotifier {
  final TransactionRepository _repository = TransactionRepository();
  String? _userId;

  PeriodType _periodType = PeriodType.month;
  TransactionType _transactionType = TransactionType.expense;
  DateTime _currentDate = DateTime.now();
  
  List<TransactionModel> _transactions = [];
  List<CategoryDistribution> _categories = [];
  List<TrendPoint> _trendPoints = [];
  double _totalAmount = 0.0;
  double _incomeTotal = 0.0;
  double _expenseTotal = 0.0;
  bool _isLoading = false;

  ReportProvider({String? userId}) : _userId = userId {
    if (_userId != null) {
      _loadData();
    }
  }

  void init(String userId) {
    if (_userId == userId) return;
    _userId = userId;
    _loadData();
  }

  // Getters
  PeriodType get periodType => _periodType;
  TransactionType get transactionType => _transactionType;
  DateTime get currentDate => _currentDate;
  List<CategoryDistribution> get categories => _categories;
  List<TrendPoint> get trendPoints => _trendPoints;
  double get totalAmount => _totalAmount;
  double get incomeTotal => _incomeTotal;
  double get expenseTotal => _expenseTotal;
  double get netAmount => _incomeTotal - _expenseTotal;
  bool get isLoading => _isLoading;

  void setPeriodType(PeriodType type) {
    if (_periodType == type) return;
    _periodType = type;
    _loadData();
  }

  void setTransactionType(TransactionType type) {
    if (_transactionType == type) return;
    _transactionType = type;
    _processData(); // Doesn't need fetch, just re-filter
  }

  void nextPeriod() {
    switch (_periodType) {
      case PeriodType.week:
        _currentDate = _currentDate.add(const Duration(days: 7));
        break;
      case PeriodType.month:
        _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1);
        break;
      case PeriodType.year:
        _currentDate = DateTime(_currentDate.year + 1, 1, 1);
        break;
    }
    _loadData();
  }

  void previousPeriod() {
    switch (_periodType) {
      case PeriodType.week:
        _currentDate = _currentDate.subtract(const Duration(days: 7));
        break;
      case PeriodType.month:
        _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1);
        break;
      case PeriodType.year:
        _currentDate = DateTime(_currentDate.year - 1, 1, 1);
        break;
    }
    _loadData();
  }

  String get periodLabel {
    switch (_periodType) {
      case PeriodType.week:
        final weekday = _currentDate.weekday;
        final start = _currentDate.subtract(Duration(days: weekday - 1));
        final end = start.add(const Duration(days: 6));
        final format = DateFormat('d MMM');
        return '${format.format(start)} - ${format.format(end)}';
      case PeriodType.month:
        return DateFormat('MMMM yyyy', 'id_ID').format(_currentDate);
      case PeriodType.year:
        return _currentDate.year.toString();
    }
  }

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    DateTime start, end;
    switch (_periodType) {
      case PeriodType.week:
        final weekday = _currentDate.weekday;
        start = _currentDate.subtract(Duration(days: weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = start.add(const Duration(days: 7));
        break;
      case PeriodType.month:
        start = DateTime(_currentDate.year, _currentDate.month, 1);
        end = DateTime(_currentDate.year, _currentDate.month + 1, 1);
        break;
      case PeriodType.year:
        start = DateTime(_currentDate.year, 1, 1);
        end = DateTime(_currentDate.year + 1, 1, 1);
        break;
    }

    try {
      final userId = _userId;
      if (userId == null) return;
      
      _transactions = await _repository.getTransactions(
        userId: userId,
        startDate: start,
        endDate: end,
      );
    } catch (e) {
      debugPrint('Error loading report data: $e');
      _transactions = [];
    }

    _processData();
    _isLoading = false;
    notifyListeners();
  }

  void _processData() {
    _incomeTotal = _transactions
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
    _expenseTotal = _transactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);
    _trendPoints = _buildTrendPoints();

    final typeStr = _transactionType == TransactionType.expense ? 'expense' : 'income';
    final relevantTxs = _transactions.where((t) => t.type == typeStr).toList();
    
    _totalAmount = relevantTxs.fold(0.0, (sum, t) => sum + t.amount);

    if (_totalAmount == 0) {
      _categories = [];
      notifyListeners();
      return;
    }

    final Map<String, double> sums = {};
    final Map<String, String> names = {};
    final Map<String, String> colors = {};
    final Map<String, String> icons = {};

    for (final t in relevantTxs) {
      final cid = t.categoryId;
      sums[cid] = (sums[cid] ?? 0) + t.amount;
      names[cid] = t.category?.name ?? 'Lain-lain';
      colors[cid] = t.category?.color ?? '#CCCCCC';
      icons[cid] = t.category?.icon ?? '';
    }

    final List<CategoryDistribution> cats = sums.entries.map((e) {
      return CategoryDistribution(
        categoryId: e.key,
        name: names[e.key]!,
        icon: icons[e.key] ?? '',
        total: e.value,
        color: colors[e.key]!,
        percentage: e.value / _totalAmount,
      );
    }).toList();

    cats.sort((a, b) => b.total.compareTo(a.total));
    _categories = cats;
    notifyListeners();
  }

  List<TrendPoint> _buildTrendPoints() {
    switch (_periodType) {
      case PeriodType.week:
        final weekday = _currentDate.weekday;
        final start = DateTime(
          _currentDate.year,
          _currentDate.month,
          _currentDate.day,
        ).subtract(Duration(days: weekday - 1));
        final income = List<double>.filled(7, 0);
        final expense = List<double>.filled(7, 0);

        for (final transaction in _transactions) {
          final date = DateTime(
            transaction.date.year,
            transaction.date.month,
            transaction.date.day,
          );
          final index = date.difference(start).inDays;
          if (index < 0 || index >= 7) continue;
          if (transaction.type == 'income') {
            income[index] += transaction.amount;
          } else {
            expense[index] += transaction.amount;
          }
        }

        return List.generate(7, (index) {
          final date = start.add(Duration(days: index));
          return TrendPoint(
            label: DateFormat('E', 'id_ID').format(date),
            income: income[index],
            expense: expense[index],
          );
        });
      case PeriodType.month:
        final lastDay = DateTime(_currentDate.year, _currentDate.month + 1, 0).day;
        final weekCount = ((lastDay - 1) ~/ 7) + 1;
        final income = List<double>.filled(weekCount, 0);
        final expense = List<double>.filled(weekCount, 0);

        for (final transaction in _transactions) {
          final index = (transaction.date.day - 1) ~/ 7;
          if (index < 0 || index >= weekCount) continue;
          if (transaction.type == 'income') {
            income[index] += transaction.amount;
          } else {
            expense[index] += transaction.amount;
          }
        }

        return List.generate(
          weekCount,
          (index) => TrendPoint(
            label: 'M${index + 1}',
            income: income[index],
            expense: expense[index],
          ),
        );
      case PeriodType.year:
        final income = List<double>.filled(12, 0);
        final expense = List<double>.filled(12, 0);

        for (final transaction in _transactions) {
          final index = transaction.date.month - 1;
          if (index < 0 || index >= 12) continue;
          if (transaction.type == 'income') {
            income[index] += transaction.amount;
          } else {
            expense[index] += transaction.amount;
          }
        }

        return List.generate(12, (index) {
          final date = DateTime(_currentDate.year, index + 1, 1);
          return TrendPoint(
            label: DateFormat('MMM', 'id_ID').format(date),
            income: income[index],
            expense: expense[index],
          );
        });
    }
  }
}
