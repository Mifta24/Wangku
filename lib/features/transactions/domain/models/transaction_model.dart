import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../categories/domain/models/category_model.dart';

part 'transaction_model.freezed.dart';
part 'transaction_model.g.dart';

@freezed
abstract class TransactionModel with _$TransactionModel {
  const factory TransactionModel({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'category_id') required String categoryId,
    required double amount,
    required String note,
    required DateTime date,
    @Default('expense') String type, // 'income' or 'expense'
    @JsonKey(includeFromJson: false, includeToJson: false) CategoryModel? category, // Untuk join relation lokal
  }) = _TransactionModel;

  factory TransactionModel.fromJson(Map<String, dynamic> json) => _$TransactionModelFromJson(json);
}
