import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../transactions/data/repositories/transaction_repository.dart';
import '../../../transactions/domain/models/transaction_model.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../data/services/report_service.dart';

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
  final ReportService _reportService = ReportService();
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
  double _previousIncomeTotal = 0.0;
  double _previousExpenseTotal = 0.0;
  bool _isLoading = false;
  TransactionProvider? _transactionProvider;
  int _loadRequestId = 0;
  PeriodReportResult? _lastRpcResult;

  ReportProvider({String? userId}) : _userId = userId {
    if (_userId != null) {
      _loadData();
    }
  }

  void attachTransactionProvider(TransactionProvider provider) {
    if (_transactionProvider == provider) return;
    _transactionProvider?.removeListener(_onTransactionsChanged);
    _transactionProvider = provider;
    provider.addListener(_onTransactionsChanged);
  }

  void init(String userId) {
    if (_userId == userId) return;
    _userId = userId;
    _currentDate = DateTime.now();
    _periodType = PeriodType.month;
    _transactionType = TransactionType.expense;
    _loadData();
  }

  void refreshFromTransactions(List<TransactionModel> transactions) {
    final (start, end) = _currentPeriodRange();
    final provider = _transactionProvider;
    if (provider != null && !provider.hasLoadedRange(start, end)) {
      _loadData();
      return;
    }

    _lastRpcResult = null;
    _transactions = _filterTransactionsForCurrentPeriod(transactions);
    _processData(notify: true);
  }

  // Getters
  PeriodType get periodType => _periodType;
  TransactionType get transactionType => _transactionType;
  DateTime get currentDate => _currentDate;
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  List<CategoryDistribution> get categories => _categories;
  List<TrendPoint> get trendPoints => _trendPoints;
  double get totalAmount => _totalAmount;
  double get incomeTotal => _incomeTotal;
  double get expenseTotal => _expenseTotal;
  double get netAmount => _incomeTotal - _expenseTotal;
  double get previousNetAmount => _previousIncomeTotal - _previousExpenseTotal;
  double? get netChangePercentage {
    final prev = previousNetAmount;
    if (prev == 0) return null;
    return (netAmount - prev) / prev.abs() * 100;
  }
  bool get isLoading => _isLoading;

  void setPeriodType(PeriodType type) {
    if (_periodType == type) return;
    _periodType = type;
    _loadData();
  }

  void setTransactionType(TransactionType type) {
    if (_transactionType == type) return;
    _transactionType = type;
      _processData(notify: true); // Doesn't need fetch, just re-filter
  }

  (DateTime, DateTime) get currentPeriodRange => _currentPeriodRange();

  Future<void> reload() => _loadData();

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
    final requestId = ++_loadRequestId;
    _isLoading = true;
    notifyListeners();

    final (start, end) = _currentPeriodRange();
    final userId = _userId;

    if (userId == null) {
      _lastRpcResult = null;
      _transactions = [];
      _previousIncomeTotal = 0.0;
      _previousExpenseTotal = 0.0;
      _processData();
      _isLoading = false;
      notifyListeners();
      return;
    }

    final (prevStart, prevEnd) = _previousPeriodRange();

    try {
      // Jalankan RPC (agregat + prev period) dan fetch transaksi periode ini secara paralel.
      // Transaksi tetap dibutuhkan untuk halaman detail kategori (report.transactions).
      PeriodReportResult? rpcResult;
      List<TransactionModel> currentTx = [];

      await Future.wait([
        _reportService
            .getPeriodReport(
              userId: userId,
              start: start,
              end: end,
              prevStart: prevStart,
              prevEnd: prevEnd,
              periodType: _periodType,
            )
            .then((r) => rpcResult = r),
        _repository
            .getTransactions(userId: userId, startDate: start, endDate: end)
            .then((t) => currentTx = t),
      ]);

      if (requestId != _loadRequestId) return;
      _lastRpcResult = rpcResult;
      _transactions = _filterTransactionsInRange(currentTx, start, end);
      _previousIncomeTotal = rpcResult?.prevIncome ?? 0.0;
      _previousExpenseTotal = rpcResult?.prevExpense ?? 0.0;
    } catch (e) {
      if (requestId != _loadRequestId) return;
      debugPrint('Fetch report gagal, fallback ke raw fetch: $e');
      try {
        final results = await Future.wait([
          _repository.getTransactions(userId: userId, startDate: start, endDate: end),
          _repository.getTransactions(userId: userId, startDate: prevStart, endDate: prevEnd),
        ]);
        if (requestId != _loadRequestId) return;
        _lastRpcResult = null;
        _transactions = _filterTransactionsInRange(results[0], start, end);
        final prevTx = _filterTransactionsInRange(results[1], prevStart, prevEnd);
        _previousIncomeTotal = prevTx.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
        _previousExpenseTotal = prevTx.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);
      } catch (e2) {
        if (requestId != _loadRequestId) return;
        debugPrint('Fallback fetch juga gagal: $e2');
        _lastRpcResult = null;
        _transactions = [];
        _previousIncomeTotal = 0.0;
        _previousExpenseTotal = 0.0;
      }
    }

    if (requestId != _loadRequestId) return;
    _processData();
    _isLoading = false;
    notifyListeners();
  }

  void _processData({bool notify = false}) {
    final rpc = _lastRpcResult;
    _trendPoints = _buildTrendPoints();

    if (rpc != null) {
      _incomeTotal = rpc.currentIncome;
      _expenseTotal = rpc.currentExpense;

      final typeStr = _transactionType == TransactionType.expense ? 'expense' : 'income';
      final relevantCats = rpc.categories.where((c) => c.type == typeStr).toList();
      _totalAmount = relevantCats.fold(0.0, (sum, c) => sum + c.total);

      if (_totalAmount == 0) {
        _categories = [];
        if (notify) notifyListeners();
        return;
      }

      _categories = relevantCats.map((c) => CategoryDistribution(
        categoryId: c.categoryId,
        name: c.name,
        icon: c.icon,
        total: c.total,
        color: c.color,
        percentage: c.total / _totalAmount,
      )).toList()
        ..sort((a, b) => b.total.compareTo(a.total));
      if (notify) notifyListeners();
      return;
    }

    // Fallback: hitung dari _transactions (offline / refreshFromTransactions)
    _incomeTotal = _transactions.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
    _expenseTotal = _transactions.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);

    final typeStr = _transactionType == TransactionType.expense ? 'expense' : 'income';
    final relevantTxs = _transactions.where((t) => t.type == typeStr).toList();
    _totalAmount = relevantTxs.fold(0.0, (sum, t) => sum + t.amount);

    if (_totalAmount == 0) {
      _categories = [];
      if (notify) notifyListeners();
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

    _categories = sums.entries.map((e) => CategoryDistribution(
      categoryId: e.key,
      name: names[e.key]!,
      icon: icons[e.key] ?? '',
      total: e.value,
      color: colors[e.key]!,
      percentage: e.value / _totalAmount,
    )).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    if (notify) notifyListeners();
  }

  List<TransactionModel> _filterTransactionsForCurrentPeriod(
    List<TransactionModel> transactions,
  ) {
    final (start, end) = _currentPeriodRange();
    return _filterTransactionsInRange(transactions, start, end);
  }

  List<TransactionModel> _filterTransactionsInRange(
    List<TransactionModel> transactions,
    DateTime start,
    DateTime end,
  ) {
    return transactions
        .where((t) => !t.date.isBefore(start) && t.date.isBefore(end))
        .toList();
  }

  (DateTime, DateTime) _currentPeriodRange() {
    switch (_periodType) {
      case PeriodType.week:
        final weekday = _currentDate.weekday;
        final start = DateTime(
          _currentDate.year,
          _currentDate.month,
          _currentDate.day,
        ).subtract(Duration(days: weekday - 1));
        return (start, start.add(const Duration(days: 7)));
      case PeriodType.month:
        final start = DateTime(_currentDate.year, _currentDate.month, 1);
        return (start, DateTime(_currentDate.year, _currentDate.month + 1, 1));
      case PeriodType.year:
        final start = DateTime(_currentDate.year, 1, 1);
        return (start, DateTime(_currentDate.year + 1, 1, 1));
    }
  }

  (DateTime, DateTime) _previousPeriodRange() {
    switch (_periodType) {
      case PeriodType.week:
        final weekday = _currentDate.weekday;
        final currentStart = DateTime(
          _currentDate.year,
          _currentDate.month,
          _currentDate.day,
        ).subtract(Duration(days: weekday - 1));
        return (currentStart.subtract(const Duration(days: 7)), currentStart);
      case PeriodType.month:
        final prevStart = DateTime(_currentDate.year, _currentDate.month - 1, 1);
        final prevEnd = DateTime(_currentDate.year, _currentDate.month, 1);
        return (prevStart, prevEnd);
      case PeriodType.year:
        return (
          DateTime(_currentDate.year - 1, 1, 1),
          DateTime(_currentDate.year, 1, 1),
        );
    }
  }

  void _onTransactionsChanged() {
    final provider = _transactionProvider;
    if (provider == null) return;
    final (start, end) = _currentPeriodRange();
    if (provider.hasLoadedRange(start, end)) {
      refreshFromTransactions(provider.transactions);
    } else {
      _loadData();
    }
  }

  @override
  void dispose() {
    _transactionProvider?.removeListener(_onTransactionsChanged);
    super.dispose();
  }

  List<TrendPoint> _buildTrendPoints() {
    final rpc = _lastRpcResult;

    switch (_periodType) {
      case PeriodType.week:
        final weekday = _currentDate.weekday;
        final start = DateTime(_currentDate.year, _currentDate.month, _currentDate.day)
            .subtract(Duration(days: weekday - 1));
        final income = List<double>.filled(7, 0);
        final expense = List<double>.filled(7, 0);

        if (rpc != null) {
          for (final p in rpc.trend) {
            final date = DateTime.parse(p.bucket);
            final index = date.difference(start).inDays;
            if (index < 0 || index >= 7) continue;
            income[index] = p.income;
            expense[index] = p.expense;
          }
        } else {
          for (final t in _transactions) {
            final local = t.date.toLocal();
            final date = DateTime(local.year, local.month, local.day);
            final index = date.difference(start).inDays;
            if (index < 0 || index >= 7) continue;
            if (t.type == 'income') { income[index] += t.amount; }
            else { expense[index] += t.amount; }
          }
        }

        return List.generate(7, (i) => TrendPoint(
          label: DateFormat('E', 'id_ID').format(start.add(Duration(days: i))),
          income: income[i],
          expense: expense[i],
        ));

      case PeriodType.month:
        final lastDay = DateTime(_currentDate.year, _currentDate.month + 1, 0).day;
        final weekCount = ((lastDay - 1) ~/ 7) + 1;
        final income = List<double>.filled(weekCount, 0);
        final expense = List<double>.filled(weekCount, 0);

        if (rpc != null) {
          for (final p in rpc.trend) {
            final index = int.tryParse(p.bucket) ?? -1;
            if (index < 0 || index >= weekCount) continue;
            income[index] = p.income;
            expense[index] = p.expense;
          }
        } else {
          for (final t in _transactions) {
            final index = (t.date.toLocal().day - 1) ~/ 7;
            if (index < 0 || index >= weekCount) continue;
            if (t.type == 'income') { income[index] += t.amount; }
            else { expense[index] += t.amount; }
          }
        }

        return List.generate(weekCount, (i) => TrendPoint(
          label: 'M${i + 1}',
          income: income[i],
          expense: expense[i],
        ));

      case PeriodType.year:
        final income = List<double>.filled(12, 0);
        final expense = List<double>.filled(12, 0);

        if (rpc != null) {
          for (final p in rpc.trend) {
            final index = (int.tryParse(p.bucket) ?? 0) - 1;
            if (index < 0 || index >= 12) continue;
            income[index] = p.income;
            expense[index] = p.expense;
          }
        } else {
          for (final t in _transactions) {
            final index = t.date.toLocal().month - 1;
            if (index < 0 || index >= 12) continue;
            if (t.type == 'income') { income[index] += t.amount; }
            else { expense[index] += t.amount; }
          }
        }

        return List.generate(12, (i) => TrendPoint(
          label: DateFormat('MMM', 'id_ID').format(DateTime(_currentDate.year, i + 1, 1)),
          income: income[i],
          expense: expense[i],
        ));
    }
  }
}
