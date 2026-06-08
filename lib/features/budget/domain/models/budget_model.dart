import 'package:freezed_annotation/freezed_annotation.dart';

part 'budget_model.freezed.dart';
part 'budget_model.g.dart';

@freezed
abstract class BudgetModel with _$BudgetModel {
  const BudgetModel._();

  const factory BudgetModel({
    String? id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'category_id') required String categoryId,
    required double amount,
    @JsonKey(
      name: 'created_at',
      fromJson: _dateTimeFromJson,
      toJson: _dateTimeToJson,
    )
    DateTime? createdAt,
    @JsonKey(
      name: 'updated_at',
      fromJson: _dateTimeFromJson,
      toJson: _dateTimeToJson,
    )
    DateTime? updatedAt,
  }) = _BudgetModel;

  factory BudgetModel.fromJson(Map<String, dynamic> json) =>
      _$BudgetModelFromJson(json);

  Map<String, dynamic> toSupabaseJson() {
    return toJson()
      ..remove('id')
      ..remove('created_at')
      ..remove('updated_at')
      ..removeWhere((_, value) => value == null);
  }
}

DateTime? _dateTimeFromJson(String? value) {
  return value == null ? null : DateTime.parse(value).toLocal();
}

String? _dateTimeToJson(DateTime? value) {
  return value?.toUtc().toIso8601String();
}
