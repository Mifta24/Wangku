import 'category_model.dart';

class TransactionShortcut {
  const TransactionShortcut({
    required this.categoryId,
    this.amount,
    this.note = '',
  });

  final String categoryId;
  final double? amount;
  final String note;

  Map<String, dynamic> toJson() => {
        'categoryId': categoryId,
        'amount': amount,
        'note': note,
      };

  factory TransactionShortcut.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'];
    return TransactionShortcut(
      categoryId: json['categoryId']?.toString() ?? '',
      amount: amount == null ? null : (amount as num).toDouble(),
      note: json['note']?.toString() ?? '',
    );
  }
}

class TransactionShortcutPreset {
  const TransactionShortcutPreset({
    required this.category,
    required this.shortcut,
  });

  final CategoryModel category;
  final TransactionShortcut shortcut;
}
