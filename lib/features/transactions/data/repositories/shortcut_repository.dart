import '../../../../core/database/hive_manager.dart';
import '../../domain/models/shortcut_model.dart';
import '../services/shortcut_service.dart';

class ShortcutRepository {
  final ShortcutService _service = ShortcutService();
  final HiveManager _hive = HiveManager.instance;

  /// Ambil shortcuts: Supabase utama, Hive fallback
  Future<List<TransactionShortcut>> getShortcuts(String userId) async {
    try {
      final shortcuts = await _service.fetchShortcuts(userId);
      // Update cache Hive
      await _hive.saveShortcutPresets(userId, shortcuts);
      return shortcuts;
    } catch (_) {
      // Offline: pakai cache Hive
      return _hive.getShortcutPresets(userId);
    }
  }

  /// Simpan shortcuts: Supabase dulu, lalu cache Hive
  Future<void> saveShortcuts(
    String userId,
    List<TransactionShortcut> shortcuts,
  ) async {
    await _service.saveShortcuts(userId, shortcuts);
    await _hive.saveShortcutPresets(userId, shortcuts);
  }

  /// Hapus semua shortcuts user (dipanggil saat logout)
  Future<void> clearUserShortcuts(String userId) async {
    try {
      await _service.deleteAllUserShortcuts(userId);
    } catch (_) {}
    await _hive.saveShortcutPresets(userId, []);
  }
}
