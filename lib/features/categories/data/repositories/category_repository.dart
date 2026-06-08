import '../../domain/models/category_model.dart';
import '../services/category_service.dart';

class CategoryRepository {
  final CategoryService _service = CategoryService();

  Future<List<CategoryModel>> getCategories(String userId) {
    return _service.getCategories(userId);
  }

  Future<CategoryModel> createCategory(CategoryModel category) {
    return _service.createCategory(category);
  }

  Future<CategoryModel> updateCategory(CategoryModel category) {
    return _service.updateCategory(category);
  }

  Future<void> deleteCategory(CategoryModel category) {
    return _service.deleteCategory(category);
  }

  void subscribeToCategories(String userId, void Function() onChanged) {
    _service.subscribeToCategories(userId, onChanged);
  }

  void unsubscribeCategories() {
    _service.unsubscribeCategories();
  }
}
