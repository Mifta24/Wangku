import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/category_model.dart';

class CategoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _categoriesTable = 'categories';

  RealtimeChannel? _categoryChannel;

  void subscribeToCategories(String userId, void Function() onChanged) {
    _categoryChannel?.unsubscribe();
    _categoryChannel = _supabase
        .channel('categories_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _categoriesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  void unsubscribeCategories() {
    _categoryChannel?.unsubscribe();
    _categoryChannel = null;
  }

  Future<List<CategoryModel>> getCategories(String userId) async {
    try {
      final response = await _supabase
          .from(_categoriesTable)
          .select()
          .or('user_id.is.null,user_id.eq.$userId')
          .order('name', ascending: true);

      return (response as List<dynamic>)
          .map((data) => CategoryModel.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Gagal fetch kategori: ${e.toString()}');
    }
  }

  Future<CategoryModel> createCategory(CategoryModel category) async {
    try {
      final data = category.toJson()..remove('id');
      final response = await _supabase
          .from(_categoriesTable)
          .insert(data)
          .select()
          .single();
      return CategoryModel.fromJson(response);
    } catch (e) {
      throw Exception('Gagal membuat kategori: ${e.toString()}');
    }
  }

  Future<CategoryModel> updateCategory(CategoryModel category) async {
    try {
      final data = category.toJson()
        ..remove('id')
        ..remove('user_id');
      final response = await _supabase
          .from(_categoriesTable)
          .update(data)
          .eq('id', category.id)
          .select()
          .single();
      return CategoryModel.fromJson(response);
    } catch (e) {
      throw Exception('Gagal update kategori: ${e.toString()}');
    }
  }

  Future<void> deleteCategory(CategoryModel category) async {
    try {
      await _supabase
          .from(_categoriesTable)
          .delete()
          .eq('id', category.id)
          .eq('user_id', category.userId!);
    } catch (e) {
      throw Exception('Gagal hapus kategori: ${e.toString()}');
    }
  }
}
