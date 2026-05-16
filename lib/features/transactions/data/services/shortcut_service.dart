import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/shortcut_model.dart';

class ShortcutService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _shortcutsTable = 'shortcuts';

  /// Fetch semua shortcuts untuk user, diurutkan berdasarkan sort_order
  Future<List<TransactionShortcut>> fetchShortcuts(String userId) async {
    try {
      final response = await _supabase
          .from(_shortcutsTable)
          .select('category_id, amount, note, sort_order')
          .eq('user_id', userId)
          .order('sort_order', ascending: true);

      return (response as List<dynamic>).map((row) {
        final amount = row['amount'];
        return TransactionShortcut(
          categoryId: row['category_id'] as String,
          amount: amount == null ? null : (amount as num).toDouble(),
          note: (row['note'] as String?) ?? '',
        );
      }).toList();
    } catch (e) {
      throw Exception('Gagal fetch shortcuts: ${e.toString()}');
    }
  }

  /// Simpan ulang semua shortcuts user (replace seluruhnya)
  Future<void> saveShortcuts(
    String userId,
    List<TransactionShortcut> shortcuts,
  ) async {
    try {
      // Hapus semua shortcuts lama dulu
      await _supabase
          .from(_shortcutsTable)
          .delete()
          .eq('user_id', userId);

      if (shortcuts.isEmpty) return;

      // Insert semua shortcuts baru dengan sort_order
      final rows = shortcuts.asMap().entries.map((entry) {
        final index = entry.key;
        final shortcut = entry.value;
        return {
          'user_id': userId,
          'category_id': shortcut.categoryId,
          'amount': shortcut.amount,
          'note': shortcut.note,
          'sort_order': index,
        };
      }).toList();

      await _supabase.from(_shortcutsTable).insert(rows);
    } catch (e) {
      throw Exception('Gagal simpan shortcuts: ${e.toString()}');
    }
  }

  /// Hapus semua shortcuts user (untuk cleanup saat logout)
  Future<void> deleteAllUserShortcuts(String userId) async {
    try {
      await _supabase
          .from(_shortcutsTable)
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Gagal hapus shortcuts: ${e.toString()}');
    }
  }
}
